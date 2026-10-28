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
  }) : _organizations = List.of(organizations),
       _contacts = List.of(contacts),
       _interactions = List.of(interactions);
  final List<Organization> _organizations;
  final List<Contact> _contacts;
  final List<InteractionLog> _interactions;
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
    final organizations = snapshot['organizations']!
        .map(Organization.fromMap)
        .toList();
    final contacts = snapshot['contacts']!.map(Contact.fromMap).toList();
    final interactions = snapshot['interactions']!
        .map(InteractionLog.fromMap)
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
        !InteractionLog.types.contains(item.type)) {
      throw ArgumentError('Invalid interaction');
    }
    _interactions.add(
      item.copyWith(id: _nextId(_interactions.map((i) => i.id))),
    );
    notifyListeners();
  }
}
