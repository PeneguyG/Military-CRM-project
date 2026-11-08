import 'dart:convert';
import 'utils/offline_map_helper.dart';
import 'utils/rich_text_content.dart';
import 'package:flutter/foundation.dart';
import 'models/crm_models.dart';
import 'data/crm_database.dart';

/// Publishes persisted data only after a successful commit. The default memory
/// constructor remains available for isolated widget tests.
class CrmStore extends ChangeNotifier {
  CrmStore({
    List<Organization> organizations = const [],
    List<Contact> contacts = const [],
    List<InteractionLog> interactions = const [],
    List<ContactNote> contactNotes = const [],
    List<OrganizationNote> organizationNotes = const [],
    List<ProfileTagDefinition> profileTags = const [],
  }) : _organizations = List.of(organizations),
       _contacts = List.of(contacts),
       _interactions = List.of(interactions),
       _contactNotes = List.of(contactNotes),
       _organizationNotes = List.of(organizationNotes),
       _profileTags = List.of(profileTags);
  final List<Organization> _organizations;
  final List<Contact> _contacts;
  final List<InteractionLog> _interactions;
  final List<ContactNote> _contactNotes;
  final List<OrganizationNote> _organizationNotes;
  final List<ProfileTagDefinition> _profileTags;
  UserLocation userLocation = UserLocation.demo;
  CrmDatabase? _database;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  String? get databasePath => _database?.path;
  static Future<CrmStore> open(CrmDatabase database, String schema) async {
    final snapshot = await database.initialize(schema);
    final store = CrmStore().._database = database;
    store._apply(snapshot);
    return store;
  }

  void _apply(DatabaseSnapshot snapshot) {
    final settings = {
      for (final row in snapshot['map_settings'] ?? <Map<String, Object?>>[])
        row['key'] as String: row['value'],
    };
    userLocation = settings['user_location'] == null
        ? UserLocation.demo
        : UserLocation.fromMap(
            Map<String, Object?>.from(
              jsonDecode(settings['user_location'] as String),
            ),
          );

    final organizations = snapshot['organizations']!
        .map(Organization.fromMap)
        .toList();
    final contacts = snapshot['contacts']!.map(Contact.fromMap).toList();
    final interactions = snapshot['interactions']!
        .map(InteractionLog.fromMap)
        .toList();
    final contactNotes = snapshot['contact_notes']!
        .map(ContactNote.fromMap)
        .toList();
    final organizationNotes = snapshot['organization_notes']!
        .map(OrganizationNote.fromMap)
        .toList();
    final profileTags = snapshot['profile_tags']!
        .map(ProfileTagDefinition.fromMap)
        .toList();
    _organizations
      ..clear()
      ..addAll(organizations);
    _contacts
      ..clear()
      ..addAll(contacts);
    _interactions
      ..clear()
      ..addAll(interactions);
    _contactNotes
      ..clear()
      ..addAll(contactNotes);
    _organizationNotes
      ..clear()
      ..addAll(organizationNotes);
    _profileTags
      ..clear()
      ..addAll(profileTags);
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist(Future<DatabaseSnapshot> Function() operation) {
    final task = _pending.then((_) async => _apply(await operation()));
    _pending = task.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return task;
  }

  Future<void> loadSoundexSamples() async {
    if (_database == null)
      throw StateError('Sample data requires a saved database.');
    await _persist(_database!.loadSoundexSamples);
  }

  Future<void> deleteSoundexSamples() async {
    if (_database == null)
      throw StateError('Sample data requires a saved database.');
    await _persist(_database!.deleteSoundexSamples);
  }

  Future<void> saveUserLocation(UserLocation location) async {
    if (!OfflineMapHelper.validCoordinates(
      location.latitude,
      location.longitude,
    ))
      throw ArgumentError('Invalid coordinates');
    if (_database != null) {
      await _persist(
        () => _database!.saveMapSettings({
          'user_location': jsonEncode(location.toMap()),
        }),
      );
    } else {
      userLocation = location;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    if (_database != null) await _persist(_database!.load);
  }

  Future<void> archiveOrganization(int id, bool archived) async {
    if (_database != null) {
      await _persist(() => _database!.archiveOrganization(id, archived));
    } else {
      await saveOrganization(organization(id)!.copyWith(isArchived: archived));
    }
  }

  Future<void> archiveContact(int id, bool archived) async {
    if (_database != null) {
      await _persist(() => _database!.archiveContact(id, archived));
    } else {
      await saveContact(contact(id)!.copyWith(isArchived: archived));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Organization> get organizations => List.unmodifiable(_organizations);
  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<InteractionLog> get interactions => List.unmodifiable(_interactions);
  List<ContactNote> get contactNotes => List.unmodifiable(_contactNotes);
  List<OrganizationNote> get organizationNotes =>
      List.unmodifiable(_organizationNotes);
  List<ProfileTagDefinition> get profileTags => List.unmodifiable(_profileTags);
  List<ContactNote> notesForContact(int contactId) => List.unmodifiable(
    _contactNotes.where((note) => note.contactId == contactId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  List<OrganizationNote> notesForOrganization(int organizationId) =>
      List.unmodifiable(
        _organizationNotes
            .where((note) => note.organizationId == organizationId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
  Organization? organization(int? id) {
    for (final item in _organizations) {
      if (item.id == id) return item;
    }
    return null;
  }

  Contact? contact(int? id) {
    for (final item in _contacts) {
      if (item.id == id) return item;
    }
    return null;
  }

  int _nextId(Iterable<int?> ids) =>
      ids.fold<int>(0, (a, b) => b != null && b > a ? b : a) + 1;
  Future<void> saveOrganization(Organization item) async {
    final previous = organization(item.id);
    final changedAddress =
        previous != null &&
        previous.address != item.address &&
        previous.latitude == item.latitude &&
        previous.longitude == item.longitude;
    if (changedAddress || (item.latitude == null && item.longitude == null)) {
      final match = OfflineMapHelper.resolve(item.address);
      item = item.copyWith(
        latitude: match?.point.latitude,
        longitude: match?.point.longitude,
        coordinateSource: match?.precision ?? '',
      );
    } else if (!OfflineMapHelper.validCoordinates(
      item.latitude,
      item.longitude,
    )) {
      throw ArgumentError('Enter both latitude and longitude in valid ranges.');
    } else if (item.coordinateSource.isEmpty ||
        previous?.latitude != item.latitude ||
        previous?.longitude != item.longitude) {
      item = item.copyWith(coordinateSource: 'Manually placed');
    }
    if (_database != null) {
      await _persist(() => _database!.saveOrganization(item));
      return;
    }
    final index = _organizations.indexWhere(
      (o) => o.id == item.id && item.id != null,
    );
    if (index < 0) {
      _organizations.add(
        item.copyWith(id: item.id ?? _nextId(_organizations.map((o) => o.id))),
      );
    } else {
      _organizations[index] = item;
    }
    notifyListeners();
  }

  Future<void> saveContact(Contact item) async {
    final previous = contact(item.id);
    final changedAddress =
        previous != null &&
        previous.address != item.address &&
        previous.latitude == item.latitude &&
        previous.longitude == item.longitude;
    if (changedAddress || (item.latitude == null && item.longitude == null)) {
      final match = OfflineMapHelper.resolve(item.address);
      item = item.copyWith(
        latitude: match?.point.latitude,
        longitude: match?.point.longitude,
        coordinateSource: match?.precision ?? '',
      );
    } else if (!OfflineMapHelper.validCoordinates(
      item.latitude,
      item.longitude,
    )) {
      throw ArgumentError('Enter both latitude and longitude in valid ranges.');
    } else if (item.coordinateSource.isEmpty ||
        previous?.latitude != item.latitude ||
        previous?.longitude != item.longitude) {
      item = item.copyWith(coordinateSource: 'Manually placed');
    }
    if (_database != null) {
      await _persist(() => _database!.saveContact(item));
      return;
    }
    if (item.organizationId != null &&
        organization(item.organizationId) == null) {
      throw ArgumentError('Organization does not exist');
    }
    final index = _contacts.indexWhere(
      (c) => c.id == item.id && item.id != null,
    );
    if (index < 0) {
      _contacts.add(
        item.copyWith(id: item.id ?? _nextId(_contacts.map((c) => c.id))),
      );
    } else {
      _contacts[index] = item;
    }
    notifyListeners();
  }

  Future<void> logInteraction(InteractionLog item) async {
    if (_database != null) {
      await _persist(() => _database!.logInteraction(item));
      return;
    }
    if (contact(item.contactId) == null ||
        (!InteractionLog.types.contains(item.type) &&
            !(item.isFollowUpOnly && item.type == 'Other'))) {
      throw ArgumentError('Invalid interaction');
    }
    _interactions.add(
      item.copyWith(id: _nextId(_interactions.map((i) => i.id))),
    );
    notifyListeners();
  }

  Future<void> addContactNote(ContactNote item) async {
    if (contact(item.contactId) == null ||
        RichTextContent.plainText(item.text).trim().isEmpty) {
      throw ArgumentError('A note needs an existing contact and text');
    }
    if (_database != null) {
      await _persist(() => _database!.addContactNote(item));
      return;
    }
    _contactNotes.add(
      ContactNote(
        id: _nextId(_contactNotes.map((note) => note.id)),
        contactId: item.contactId,
        text: item.text.trim(),
        createdAt: item.createdAt,
      ),
    );
    notifyListeners();
  }

  Future<void> addOrganizationNote(OrganizationNote item) async {
    if (organization(item.organizationId) == null ||
        RichTextContent.plainText(item.text).trim().isEmpty) {
      throw ArgumentError('A note needs an existing organization and text');
    }
    if (_database != null) {
      await _persist(() => _database!.addOrganizationNote(item));
      return;
    }
    _organizationNotes.add(
      OrganizationNote(
        id: _nextId(_organizationNotes.map((note) => note.id)),
        organizationId: item.organizationId,
        text: item.text.trim(),
        createdAt: item.createdAt,
      ),
    );
    notifyListeners();
  }

  Future<void> saveProfileTag(ProfileTagDefinition item) async {
    if (item.label.trim().isEmpty ||
        ![
          'preferred_contact',
          'life_status',
          'custom',
        ].contains(item.category)) {
      throw ArgumentError('Invalid profile tag');
    }
    if (_database != null) {
      await _persist(() => _database!.saveProfileTag(item));
      return;
    }
    if (item.category == 'custom' &&
        _profileTags.any(
          (tag) =>
              tag.category == 'custom' &&
              tag.label.toLowerCase() == item.label.trim().toLowerCase() &&
              tag.id != item.id,
        )) {
      throw ArgumentError('A custom tag with that name already exists');
    }
    final index = _profileTags.indexWhere(
      (tag) => tag.id == item.id && item.id != null,
    );
    final saved = ProfileTagDefinition(
      id: item.id ?? _nextId(_profileTags.map((tag) => tag.id)),
      category: item.category,
      value: item.value,
      label: item.label.trim(),
      colorValue: item.colorValue,
      isBuiltIn: item.isBuiltIn,
    );
    if (index < 0) {
      _profileTags.add(saved);
    } else {
      _profileTags[index] = saved;
    }
    notifyListeners();
  }

  Future<void> deleteProfileTag(int id) async {
    if (_database != null) {
      await _persist(() => _database!.deleteProfileTag(id));
      return;
    }
    _profileTags.removeWhere((tag) => tag.id == id && !tag.isBuiltIn);
    for (var index = 0; index < _contacts.length; index++) {
      final contact = _contacts[index];
      if (contact.customTagIds.contains(id)) {
        _contacts[index] = contact.copyWith(
          customTagIds: contact.customTagIds
              .where((tagId) => tagId != id)
              .toList(),
        );
      }
    }
    notifyListeners();
  }
}
