import 'package:flutter/foundation.dart';
import 'models/crm_models.dart';

/// In-memory integration preview. Replace save methods with repository writes
/// when connecting SQLite; record IDs and relationships remain stable.
class CrmStore extends ChangeNotifier {
  CrmStore(
      {List<Organization> organizations = const [],
      List<Contact> contacts = const [],
      List<InteractionLog> interactions = const []})
      : _organizations = List.of(organizations),
        _contacts = List.of(contacts),
        _interactions = List.of(interactions);
  final List<Organization> _organizations;
  final List<Contact> _contacts;
  final List<InteractionLog> _interactions;
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
  void saveOrganization(Organization item) {
    final index =
        _organizations.indexWhere((o) => o.id == item.id && item.id != null);
    if (index < 0) {
      _organizations.add(item.copyWith(
          id: item.id ?? _nextId(_organizations.map((o) => o.id))));
    } else {
      _organizations[index] = item;
    }
    notifyListeners();
  }

  void saveContact(Contact item) {
    if (item.organizationId != null &&
        organization(item.organizationId) == null) {
      throw ArgumentError('Organization does not exist');
    }
    final index =
        _contacts.indexWhere((c) => c.id == item.id && item.id != null);
    if (index < 0) {
      _contacts.add(
          item.copyWith(id: item.id ?? _nextId(_contacts.map((c) => c.id))));
    } else {
      _contacts[index] = item;
    }
    notifyListeners();
  }

  void logInteraction(InteractionLog item) {
    if (contact(item.contactId) == null ||
        !InteractionLog.types.contains(item.type)) {
      throw ArgumentError('Invalid interaction');
    }
    _interactions
        .add(item.copyWith(id: _nextId(_interactions.map((i) => i.id))));
    notifyListeners();
  }
}
