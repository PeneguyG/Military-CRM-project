import 'dart:io';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import '../models/crm_models.dart';

typedef DatabaseSnapshot = Map<String, List<Map<String, Object?>>>;

/// Each operation owns a short-lived connection in a background isolate.
/// SQLite's transactions serialize writers, including the Python helper.
class CrmDatabase {
  const CrmDatabase(this.path);
  final String path;

  Future<DatabaseSnapshot> initialize(String schema) =>
      _run('initialize', {'schema': schema});
  Future<DatabaseSnapshot> load() => _run('load', {});
  Future<DatabaseSnapshot> saveOrganization(Organization item) =>
      _run('organization', item.toMap());
  Future<DatabaseSnapshot> saveContact(Contact item) =>
      _run('contact', item.toMap());
  Future<DatabaseSnapshot> logInteraction(InteractionLog item) =>
      _run('interaction', item.toMap());
  Future<DatabaseSnapshot> archiveOrganization(int id, bool archived) =>
      _run('archiveOrganization', {'id': id, 'archived': archived ? 1 : 0});
  Future<DatabaseSnapshot> archiveContact(int id, bool archived) =>
      _run('archiveContact', {'id': id, 'archived': archived ? 1 : 0});

  Future<DatabaseSnapshot> _run(String operation, Map<String, Object?> data) {
    final databasePath = path;
    return Isolate.run(() => _execute(databasePath, operation, data));
  }
}

DatabaseSnapshot _execute(
  String path,
  String operation,
  Map<String, Object?> data,
) {
  if (operation == 'initialize') File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 10000;');
    if (operation == 'initialize') {
      db.execute('PRAGMA journal_mode = WAL;');
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      if (tables.isEmpty) db.execute(data['schema'] as String);
      if (db.userVersion != 1)
        throw StateError('Unsupported CRM schema version ${db.userVersion}.');
      _migrate(db);
    }
    db.execute(
      operation == 'load' || operation == 'initialize'
          ? 'BEGIN;'
          : 'BEGIN IMMEDIATE;',
    );
    switch (operation) {
      case 'organization':
        _saveOrganization(db, data);
      case 'contact':
        _saveContact(db, data);
      case 'interaction':
        final followUp = data['follow_up_date'] as String?;
        _insert(db, 'interactions', {
          'contact_id': data['contact_id'],
          'organization_id': data['organization_id'],
          'interaction_type': data['type'] == 'In-Person'
              ? 'In-Person Meeting'
              : data['type'],
          'direction': 'Outbound',
          'occurred_at': DateTime.parse(data['date'] as String)
              .toUtc()
              .toIso8601String()
              .replaceFirst('T', ' ')
              .replaceAll('Z', ''),
          'summary': data['summary'],
          'follow_up_required': followUp == null ? 0 : 1,
          'follow_up_date': followUp?.substring(0, 10),
        });
      case 'archiveOrganization':
      case 'archiveContact':
        final table = operation == 'archiveOrganization'
            ? 'organizations'
            : 'contacts';
        _update(db, table, data['id'] as int, {
          'is_archived': data['archived'],
        });
      case 'initialize':
      case 'load':
        break;
      default:
        throw ArgumentError('Unknown database operation');
    }
    final snapshot = _snapshot(db);
    db.execute('COMMIT;');
    return snapshot;
  } catch (_) {
    if (!db.autocommit) db.execute('ROLLBACK;');
    rethrow;
  } finally {
    db.close();
  }
}

void _migrate(Database db) {
  // The Python repository owns user_version=1. Track additive Flutter extensions
  // separately so its repeatable schema initialization remains compatible.
  db.execute('BEGIN IMMEDIATE;');
  try {
    db.execute(
      'CREATE TABLE IF NOT EXISTS crm_app_migrations (version INTEGER PRIMARY KEY);',
    );
    final versions = db.select(
      'SELECT version FROM crm_app_migrations ORDER BY version DESC',
    );
    final version = versions.isEmpty ? 0 : versions.first['version'] as int;
    if (version > 1)
      throw StateError('This database requires a newer CRM application.');
    if (version == 0) {
      db.execute('''
        ALTER TABLE organizations ADD COLUMN address TEXT;
        ALTER TABLE organizations ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1));
        ALTER TABLE contacts ADD COLUMN address TEXT;
        ALTER TABLE contacts ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1));
        ALTER TABLE contacts ADD COLUMN status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive','deceased'));
        ALTER TABLE interactions ADD COLUMN organization_id INTEGER REFERENCES organizations(id);
        UPDATE interactions SET organization_id = (SELECT organization_id FROM contacts WHERE contacts.id=interactions.contact_id);
        CREATE TRIGGER organizations_preserve BEFORE DELETE ON organizations BEGIN
          SELECT RAISE(ABORT, 'Organizations must be archived, never deleted');
        END;
        CREATE TRIGGER contacts_preserve BEFORE DELETE ON contacts BEGIN
          SELECT RAISE(ABORT, 'Contacts must be archived, never deleted');
        END;
        INSERT INTO crm_app_migrations(version) VALUES(1);
      ''');
    }
    db.execute('COMMIT;');
  } catch (_) {
    db.execute('ROLLBACK;');
    rethrow;
  }
}

String _address(Map<String, Object?> row) =>
    row['address'] as String? ??
    [
          'address_line1',
          'address_line2',
          'city',
          'state',
          'postal_code',
          'country',
        ]
        .map((key) => row[key] as String? ?? '')
        .where((v) => v.isNotEmpty)
        .join(', ');

Map<String, Object?> _organization(Map<String, Object?> r) => {
  ...r,
  'address': _address(r),
};
Map<String, Object?> _contact(Map<String, Object?> r) => {
  ...r,
  'address': _address(r),
  'title': r['rank_or_title'],
  'phone': r['primary_phone'],
  'children_info': r['children_details'],
  'notes': r['general_notes'],
};
DatabaseSnapshot _snapshot(Database db) => {
  'organizations': db
      .select('SELECT * FROM organizations ORDER BY id')
      .map((r) => Organization.fromMap(_organization(r)).toMap())
      .toList(),
  'contacts': db
      .select('SELECT * FROM contacts ORDER BY id')
      .map((r) => Contact.fromMap(_contact(r)).toMap())
      .toList(),
  'interactions': db
      .select('SELECT * FROM interactions ORDER BY occurred_at, id')
      .map(
        (r) => <String, Object?>{
          'id': r['id'],
          'contact_id': r['contact_id'],
          'organization_id': r['organization_id'],
          'date': '${(r['occurred_at'] as String).replaceFirst(' ', 'T')}Z',
          'type': r['interaction_type'] == 'In-Person Meeting'
              ? 'In-Person'
              : r['interaction_type'],
          'summary': r['summary'],
          'follow_up_date': r['follow_up_date'],
          'follow_up_completed': r['follow_up_completed'],
        },
      )
      .toList(),
};

void _saveOrganization(Database db, Map<String, Object?> m) {
  final values = {
    for (final key in [
      'name',
      'industry',
      'address',
      'phone',
      'email',
      'notes',
      'is_archived',
    ])
      key: m[key],
  };
  final id = m['id'] as int?;
  if (id == null) {
    _insert(db, 'organizations', values);
    return;
  }
  final rows = db.select('SELECT * FROM organizations WHERE id=?', [id]);
  if (rows.isEmpty) throw StateError('Organization no longer exists');
  final original = Organization.fromMap(_organization(rows.single)).toMap();
  values.removeWhere((key, value) => original[key] == value);
  _update(db, 'organizations', id, values);
}

void _saveContact(Database db, Map<String, Object?> m) {
  const fields = {
    'organization_id': 'organization_id',
    'first_name': 'first_name',
    'last_name': 'last_name',
    'title': 'rank_or_title',
    'phone': 'primary_phone',
    'email': 'email',
    'address': 'address',
    'spouse_name': 'spouse_name',
    'children_info': 'children_details',
    'photo_path': 'photo_path',
    'notes': 'general_notes',
    'talking_points': 'talking_points',
    'status': 'status',
    'is_archived': 'is_archived',
  };
  final values = <String, Object?>{};
  final id = m['id'] as int?;
  Map<String, Object?>? original;
  if (id != null) {
    final rows = db.select('SELECT * FROM contacts WHERE id=?', [id]);
    if (rows.isEmpty) throw StateError('Contact no longer exists');
    original = Contact.fromMap(_contact(rows.single)).toMap();
    if (rows.single['photo_blob'] != null && m['photo_path'] != null) {
      throw StateError(
        'This contact has an embedded photo. Its existing photo must be preserved.',
      );
    }
  }
  for (final entry in fields.entries) {
    if (original == null || original[entry.key] != m[entry.key])
      values[entry.value] = m[entry.key];
  }
  if (id == null) {
    _insert(db, 'contacts', values);
  } else {
    _update(db, 'contacts', id, values);
  }
}

void _insert(Database db, String table, Map<String, Object?> values) {
  db.execute(
    'INSERT INTO $table (${values.keys.join(',')}) VALUES (${List.filled(values.length, '?').join(',')})',
    values.values.toList(),
  );
}

void _update(Database db, String table, int id, Map<String, Object?> values) {
  if (values.isEmpty) return;
  db.execute(
    'UPDATE $table SET ${values.keys.map((k) => '$k=?').join(',')} WHERE id=?',
    [...values.values, id],
  );
  if (db.updatedRows != 1) throw StateError('Record no longer exists');
}
