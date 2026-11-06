import '../utils/offline_map_helper.dart';
import 'database_encryption.dart';
import 'database_key_store.dart';
import '../utils/utc_time.dart';
import 'soundex_samples.dart';
import '../utils/rich_text_content.dart';
import '../utils/crm_search_queries.dart';
import '../utils/soundex_helper.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import '../models/crm_models.dart';

const crmSchemaVersion = 16;

typedef DatabaseSnapshot = Map<String, List<Map<String, Object?>>>;

/// Each operation owns a short-lived connection in a background isolate.
/// Production connections require a key protected by the platform key store.
class CrmDatabase {
  factory CrmDatabase(String path) {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Use CrmDatabase.open on macOS; other platforms are not supported.',
      );
    }
    return CrmDatabase._(path, DatabaseKeyStore.loadOrCreate(path));
  }

  static Future<CrmDatabase> open(String path) async {
    if (Platform.isMacOS) {
      return CrmDatabase._(
        path,
        await DatabaseKeyStore.loadOrCreateMacOS(path),
      );
    }
    if (Platform.isWindows) return CrmDatabase(path);
    throw UnsupportedError('Encrypted CRM storage supports Windows and macOS.');
  }

  const CrmDatabase._(this.path, this._encryptionKey);

  /// Explicit opt-out only for isolated tests of legacy schemas.
  const CrmDatabase.unencryptedForTesting(this.path) : _encryptionKey = null;
  final String? _encryptionKey;
  final String path;

  Future<DatabaseSnapshot> initialize(String schema) =>
      _run('initialize', {'schema': schema});
  Future<DatabaseSnapshot> saveMapSettings(Map<String, Object?> settings) =>
      _run('mapSettings', settings);
  Future<DatabaseSnapshot> load() => _run('load', {});
  Future<DatabaseSnapshot> loadSoundexSamples() => _run('soundexSamples', {});
  Future<DatabaseSnapshot> saveOrganization(Organization item) =>
      _run('organization', item.toMap());
  Future<DatabaseSnapshot> saveContact(Contact item) =>
      _run('contact', item.toMap());
  Future<DatabaseSnapshot> addContactNote(ContactNote item) =>
      _run('contactNote', item.toMap());
  Future<DatabaseSnapshot> addOrganizationNote(OrganizationNote item) =>
      _run('organizationNote', item.toMap());
  Future<DatabaseSnapshot> saveProfileTag(ProfileTagDefinition item) =>
      _run('profileTag', item.toMap());
  Future<DatabaseSnapshot> deleteProfileTag(int id) =>
      _run('deleteProfileTag', {'id': id});
  Future<DatabaseSnapshot> logInteraction(InteractionLog item) =>
      _run('interaction', item.toMap());
  Future<DatabaseSnapshot> archiveOrganization(int id, bool archived) =>
      _run('archiveOrganization', {'id': id, 'archived': archived ? 1 : 0});
  Future<DatabaseSnapshot> archiveContact(int id, bool archived) =>
      _run('archiveContact', {'id': id, 'archived': archived ? 1 : 0});

  Future<DatabaseSnapshot> _run(String operation, Map<String, Object?> data) {
    final databasePath = path;
    final encryptionKey = _encryptionKey;
    return Isolate.run(
      () => _execute(databasePath, operation, data, encryptionKey),
    );
  }
}

Future<DatabaseSnapshot> _execute(
  String path,
  String operation,
  Map<String, Object?> data,
  String? encryptionKey,
) async {
  if (operation == 'initialize') File(path).parent.createSync(recursive: true);
  final lock = File('$path.operation.lock').openSync(mode: FileMode.append);
  lock.lockSync(FileLock.blockingExclusive);
  Database? connection;
  try {
    final db = connection = encryptionKey == null
        ? sqlite3.open(path)
        : await openEncryptedDatabase(path, encryptionKey);
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
        if (encryptionKey != null && tables.isNotEmpty) {
          final migrationTable = db.select(
            "SELECT name FROM sqlite_master WHERE name='crm_app_migrations'",
          );
          final version = migrationTable.isEmpty
              ? 0
              : db
                            .select(
                              'SELECT MAX(version) AS version FROM crm_app_migrations',
                            )
                            .single['version']
                        as int? ??
                    0;
          if (version < crmSchemaVersion)
            await encryptedBackup(
              db,
              '$path.pre-v$crmSchemaVersion.enc',
              encryptionKey,
            );
        }
        _migrate(db);
      }
      db.execute(
        operation == 'load' || operation == 'initialize'
            ? 'BEGIN;'
            : 'BEGIN IMMEDIATE;',
      );
      switch (operation) {
        case 'mapSettings':
          for (final entry in data.entries) {
            if (entry.key != 'user_location')
              throw ArgumentError('Unknown map setting');
            db.execute(
              'INSERT INTO map_settings(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
              [entry.key, entry.value],
            );
          }
        case 'soundexSamples':
          _loadSoundexSamples(db);
        case 'organization':
          _saveOrganization(db, data);
        case 'contact':
          _saveContact(db, data);
        case 'contactNote':
          _insert(db, 'contact_notes', {
            'contact_id': data['contact_id'],
            'note_text': data['note_text'],
            'soundex_index': SoundexHelper.encodePhrase(
              RichTextContent.plainText(data['note_text'] as String),
            ),
            'created_at': DateTime.parse(
              data['created_at'] as String,
            ).toUtc().toIso8601String(),
          });
        case 'organizationNote':
          _insert(db, 'organization_notes', {
            'organization_id': data['organization_id'],
            'note_text': data['note_text'],
            'soundex_index': SoundexHelper.encodePhrase(
              RichTextContent.plainText(data['note_text'] as String),
            ),
            'created_at': DateTime.parse(
              data['created_at'] as String,
            ).toUtc().toIso8601String(),
          });
        case 'profileTag':
          _saveProfileTag(db, data);
        case 'deleteProfileTag':
          _deleteProfileTag(db, data['id'] as int);
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
            'follow_up_time': data['follow_up_time'],
            'follow_up_at_utc': followUpUtc(
              followUp,
              data['follow_up_time'] as String?,
            ),
            'follow_up_reason': data['follow_up_reason'] ?? '',
          });
          final interactionId =
              db.select('SELECT last_insert_rowid() AS id').single['id'] as int;
          final attachments = data['attachments'];
          if (attachments is List) {
            for (final rawAttachment in attachments) {
              if (rawAttachment is! Map) continue;
              final attachment = Map<String, Object?>.from(rawAttachment);
              _insert(db, 'interaction_attachments', {
                'interaction_id': interactionId,
                'file_name': attachment['file_name'],
                'mime_type': attachment['mime_type'],
                'file_blob': attachment['file_blob'],
              });
            }
          }
        case 'archiveOrganization':
        case 'archiveContact':
          final table = operation == 'archiveOrganization'
              ? 'organizations'
              : 'contacts';
          final values = <String, Object?>{'is_archived': data['archived']};
          // The original SQLite CHECK constraint predates the app's Archived
          // status. Store Archived as its legacy Inactive value while exposing
          // the newer status through Contact.fromMap.
          if (table == 'contacts') {
            values['status'] = data['archived'] == 1 ? 'inactive' : 'active';
          }
          _update(db, table, data['id'] as int, values);
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
      connection = null;
    }
  } finally {
    connection?.close();
    lock.unlockSync();
    lock.closeSync();
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
    var version = versions.isEmpty ? 0 : versions.first['version'] as int;
    if (version > crmSchemaVersion)
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
      version = 1;
    }
    if (version < 2) {
      db.execute('''
        ALTER TABLE interactions ADD COLUMN follow_up_reason TEXT NOT NULL DEFAULT '';
        INSERT INTO crm_app_migrations(version) VALUES(2);
      ''');
      version = 2;
    }
    if (version < 3) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN prefix TEXT;
        ALTER TABLE contacts ADD COLUMN suffix TEXT;
        ALTER TABLE contacts ADD COLUMN military_branch TEXT;
        ALTER TABLE contacts ADD COLUMN military_rank TEXT;
        INSERT INTO crm_app_migrations(version) VALUES(3);
      ''');
      version = 3;
    }
    if (version < 4) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN children_json TEXT;
        INSERT INTO crm_app_migrations(version) VALUES(4);
      ''');
      version = 4;
    }
    if (version < 5) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN preferred_contact_method TEXT NOT NULL DEFAULT '';
        ALTER TABLE contacts ADD COLUMN life_status TEXT NOT NULL DEFAULT 'alive' CHECK(life_status IN ('alive','deceased'));
        CREATE TABLE contact_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
          note_text TEXT NOT NULL CHECK(length(trim(note_text)) > 0),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX idx_contact_notes_contact_created ON contact_notes(contact_id, created_at DESC, id DESC);
        UPDATE contacts SET life_status='deceased' WHERE status='deceased';
        UPDATE contacts SET status='active' WHERE status='deceased' AND is_archived=0;
        INSERT INTO contact_notes(contact_id, note_text)
          SELECT id, general_notes FROM contacts
          WHERE general_notes IS NOT NULL AND length(trim(general_notes)) > 0;
        INSERT INTO crm_app_migrations(version) VALUES(5);
      ''');
      version = 5;
    }
    if (version < 6) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN custom_tags_json TEXT NOT NULL DEFAULT '[]';
        CREATE TABLE profile_tag_definitions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL CHECK(category IN ('preferred_contact','life_status','custom')),
          value TEXT NOT NULL,
          label TEXT NOT NULL CHECK(length(trim(label)) > 0),
          color_value INTEGER NOT NULL,
          is_builtin INTEGER NOT NULL DEFAULT 0 CHECK(is_builtin IN (0,1)),
          UNIQUE(category, value),
          UNIQUE(category, label)
        );
        INSERT INTO profile_tag_definitions(category,value,label,color_value,is_builtin) VALUES
          ('preferred_contact','Call','Call',0xFF1565C0,1),
          ('preferred_contact','Text','Text',0xFF6A1B9A,1),
          ('preferred_contact','Email','Email',0xFF00796B,1),
          ('preferred_contact','In person','In person',0xFFB45309,1),
          ('life_status','alive','Alive',0xFF2E7D32,1),
          ('life_status','deceased','Deceased',0xFF616161,1);
        INSERT INTO crm_app_migrations(version) VALUES(6);
      ''');
      version = 6;
    }
    if (version < 7) {
      db.execute('''
        ALTER TABLE interactions ADD COLUMN follow_up_time TEXT;
        INSERT INTO crm_app_migrations(version) VALUES(7);
      ''');
      version = 7;
    }
    if (version < 8) {
      db.execute('''
        CREATE TABLE interaction_attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          interaction_id INTEGER NOT NULL REFERENCES interactions(id) ON DELETE CASCADE,
          file_name TEXT NOT NULL,
          mime_type TEXT,
          file_blob BLOB NOT NULL,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX idx_interaction_attachments_interaction ON interaction_attachments(interaction_id, id);
        INSERT INTO crm_app_migrations(version) VALUES(8);
      ''');
      version = 8;
    }
    if (version < 9) {
      db.execute('''
        CREATE TABLE organization_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          organization_id INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
          note_text TEXT NOT NULL CHECK(length(trim(note_text)) > 0),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX idx_organization_notes_org_created ON organization_notes(organization_id, created_at DESC, id DESC);
        INSERT INTO crm_app_migrations(version) VALUES(9);
      ''');
      version = 9;
    }
    if (version < 10) {
      db.execute('''
        ALTER TABLE organizations ADD COLUMN logo_blob BLOB;
        INSERT INTO crm_app_migrations(version) VALUES(10);
      ''');
      version = 10;
    }
    if (version < 11) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN phone_label TEXT NOT NULL DEFAULT 'Mobile';
        ALTER TABLE contacts ADD COLUMN additional_phones_json TEXT NOT NULL DEFAULT '[]';
      ''');
      final legacyPhones = db.select(
        "SELECT id, secondary_phone FROM contacts WHERE secondary_phone IS NOT NULL AND trim(secondary_phone) <> ''",
      );
      for (final row in legacyPhones) {
        db.execute('UPDATE contacts SET additional_phones_json=? WHERE id=?', [
          jsonEncode([
            {'label': 'Secondary', 'number': row['secondary_phone']},
          ]),
          row['id'],
        ]);
      }
      db.execute('INSERT INTO crm_app_migrations(version) VALUES(11);');
      version = 11;
    }
    if (version < 12) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN contact_status TEXT NOT NULL DEFAULT 'active'
          CHECK(contact_status IN ('active','inactive'));
        UPDATE contacts SET is_archived=1
          WHERE status='inactive' AND is_archived=0;
        INSERT INTO crm_app_migrations(version) VALUES(12);
      ''');
      version = 12;
    }
    if (version < 13) {
      db.execute('''
        ALTER TABLE contacts ADD COLUMN email_label TEXT NOT NULL DEFAULT 'Primary';
        ALTER TABLE contacts ADD COLUMN additional_emails_json TEXT NOT NULL DEFAULT '[]';
        INSERT INTO crm_app_migrations(version) VALUES(13);
      ''');
    }
    if (version < 14) {
      for (final statement in soundexMigrations) {
        db.execute(statement);
      }
      for (final row in db.select('SELECT * FROM organizations')) {
        _update(db, 'organizations', row['id'] as int, {
          'soundex_index': Organization.fromMap(
            _organization(row),
          ).soundexIndex,
        });
      }
      for (final row in db.select('SELECT * FROM contacts')) {
        final contact = Contact.fromMap(_contact(row));
        _update(db, 'contacts', row['id'] as int, {
          'name_soundex': contact.nameSoundex,
          'soundex_index': contact.fullSoundexIndex,
        });
      }
      for (final table in ['contact_notes', 'organization_notes']) {
        for (final row in db.select('SELECT id, note_text FROM $table')) {
          _update(db, table, row['id'] as int, {
            'soundex_index': SoundexHelper.encodePhrase(
              RichTextContent.plainText(row['note_text'] as String),
            ),
          });
        }
      }
      db.execute('INSERT INTO crm_app_migrations(version) VALUES(14)');
    }
    if (version < 15) {
      db.execute('ALTER TABLE interactions ADD COLUMN follow_up_at_utc TEXT');
      // Legacy schedules are wall-clock values in the current device timezone.
      // Preserve their intended local appointment time when deriving UTC.
      for (final row in db.select(
        'SELECT id, follow_up_date, follow_up_time FROM interactions WHERE follow_up_date IS NOT NULL AND follow_up_time IS NOT NULL',
      )) {
        final utc = followUpUtc(
          row['follow_up_date'] as String?,
          row['follow_up_time'] as String?,
        );
        db.execute('UPDATE interactions SET follow_up_at_utc=? WHERE id=?', [
          utc,
          row['id'],
        ]);
      }
      db.execute('INSERT INTO crm_app_migrations(version) VALUES(15)');
    }
    if (version < 16) {
      for (final table in ['organizations', 'contacts']) {
        db.execute(
          'ALTER TABLE $table ADD COLUMN latitude REAL CHECK(latitude BETWEEN -90 AND 90)',
        );
        db.execute(
          'ALTER TABLE $table ADD COLUMN longitude REAL CHECK(longitude BETWEEN -180 AND 180)',
        );
        db.execute(
          "ALTER TABLE $table ADD COLUMN coordinate_source TEXT NOT NULL DEFAULT ''",
        );
        for (final row in db.select('SELECT * FROM $table')) {
          final sampleMaps = table == 'organizations'
              ? SoundexSamples.organizations.map((o) => o.toMap())
              : SoundexSamples.contacts([0, 0, 0], 0).map((c) => c.toMap());
          final sample = sampleMaps
              .where(
                (sample) =>
                    sample['address'] == _address(row) &&
                    (table == 'organizations'
                        ? sample['name'] == row['name']
                        : sample['email'] == row['email']),
              )
              .firstOrNull;
          final match = OfflineMapHelper.resolve(_address(row));
          if (sample != null) {
            _update(db, table, row['id'] as int, {
              'latitude': sample['latitude'],
              'longitude': sample['longitude'],
              'coordinate_source': 'Fictional demo pin',
            });
          } else if (match != null)
            _update(db, table, row['id'] as int, {
              'latitude': match.point.latitude,
              'longitude': match.point.longitude,
              'coordinate_source': match.precision,
            });
        }
      }
      db.execute('CREATE TABLE map_settings(key TEXT PRIMARY KEY, value TEXT)');
      db.execute('INSERT INTO crm_app_migrations(version) VALUES(16)');
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
DatabaseSnapshot _snapshot(Database db) {
  final attachmentRows = db.select(
    'SELECT * FROM interaction_attachments ORDER BY interaction_id, id',
  );
  final attachmentsByInteraction = <int, List<Map<String, Object?>>>{};
  for (final row in attachmentRows) {
    final interactionId = row['interaction_id'] as int;
    attachmentsByInteraction
        .putIfAbsent(interactionId, () => <Map<String, Object?>>[])
        .add({
          'id': row['id'],
          'file_name': row['file_name'],
          'mime_type': row['mime_type'],
          'file_blob': row['file_blob'],
        });
  }

  return {
    'map_settings': db
        .select('SELECT key, value FROM map_settings')
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
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
        .map((r) {
          final occurredAt = r['occurred_at']?.toString();
          final safeOccurredAt = occurredAt ?? '1970-01-01 00:00:00';
          final scheduled = r['follow_up_at_utc'] == null
              ? null
              : parseUtcTimestamp(r['follow_up_at_utc'] as String).toLocal();
          return <String, Object?>{
            'id': r['id'],
            'contact_id': r['contact_id'],
            'organization_id': r['organization_id'],
            'date': parseUtcTimestamp(safeOccurredAt).toIso8601String(),
            'type': r['interaction_type'] == 'In-Person Meeting'
                ? 'In-Person'
                : r['interaction_type'] ?? 'Call',
            'summary': r['summary']?.toString() ?? '',
            'follow_up_date':
                scheduled?.toIso8601String().substring(0, 10) ??
                r['follow_up_date'],
            'follow_up_time': scheduled == null
                ? r['follow_up_time']
                : '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
            'follow_up_reason': r['follow_up_reason']?.toString() ?? '',
            'follow_up_completed': r['follow_up_completed'],
            'attachments': attachmentsByInteraction[r['id'] as int] ?? const [],
          };
        })
        .toList(),
    'contact_notes': db
        .select('SELECT * FROM contact_notes ORDER BY created_at DESC, id DESC')
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
    'organization_notes': db
        .select(
          'SELECT * FROM organization_notes ORDER BY created_at DESC, id DESC',
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
    'profile_tags': db
        .select('SELECT * FROM profile_tag_definitions ORDER BY category, id')
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
  };
}

void _saveOrganization(Database db, Map<String, Object?> m) {
  final values = {
    for (final key in [
      'latitude',
      'longitude',
      'coordinate_source',
      'soundex_index',
      'name',
      'industry',
      'address',
      'phone',
      'email',
      'notes',
      'logo_blob',
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
  values.removeWhere(
    (key, value) => _sameOrganizationValue(key, original[key], value),
  );
  _update(db, 'organizations', id, values);
}

bool _sameOrganizationValue(String key, Object? first, Object? second) {
  if (key != 'logo_blob') return first == second;
  if (identical(first, second)) return true;
  if (first == null || second == null) return first == second;
  if (first is! List<int> || second is! List<int>) return first == second;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

void _saveContact(Database db, Map<String, Object?> m) {
  const fields = {
    'latitude': 'latitude',
    'longitude': 'longitude',
    'coordinate_source': 'coordinate_source',
    'name_soundex': 'name_soundex',
    'soundex_index': 'soundex_index',
    'organization_id': 'organization_id',
    'prefix': 'prefix',
    'first_name': 'first_name',
    'last_name': 'last_name',
    'suffix': 'suffix',
    'military_branch': 'military_branch',
    'military_rank': 'military_rank',
    'preferred_contact_method': 'preferred_contact_method',
    'life_status': 'life_status',
    'custom_tags_json': 'custom_tags_json',
    'title': 'rank_or_title',
    'phone': 'primary_phone',
    'phone_label': 'phone_label',
    'additional_phones_json': 'additional_phones_json',
    'email': 'email',
    'email_label': 'email_label',
    'additional_emails_json': 'additional_emails_json',
    'address': 'address',
    'spouse_name': 'spouse_name',
    'children_info': 'children_details',
    'children_json': 'children_json',
    'photo_path': 'photo_path',
    'photo_blob': 'photo_blob',
    'notes': 'general_notes',
    'talking_points': 'talking_points',
    'status': 'status',
    'contact_status': 'contact_status',
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
    if (original == null ||
        !_sameContactValue(entry.key, original[entry.key], m[entry.key])) {
      // Keep legacy status values compatible; app statuses are stored in the
      // dedicated contact_status column and archiving remains separate.
      values[entry.value] = entry.key == 'status'
          ? (m['status'] == 'archived' ? 'inactive' : 'active')
          : m[entry.key];
    }
  }
  if (id == null) {
    _insert(db, 'contacts', values);
  } else {
    _update(db, 'contacts', id, values);
  }
}

void _saveProfileTag(Database db, Map<String, Object?> data) {
  final values = <String, Object?>{
    'category': data['category'],
    'value': data['value'],
    'label': data['label'],
    'color_value': data['color_value'],
    'is_builtin': data['is_builtin'] ?? 0,
  };
  final id = data['id'] as int?;
  if (id == null) {
    _insert(db, 'profile_tag_definitions', values);
  } else {
    _update(db, 'profile_tag_definitions', id, values);
  }
}

void _deleteProfileTag(Database db, int id) {
  final definitions = db.select(
    'SELECT category FROM profile_tag_definitions WHERE id=? AND is_builtin=0',
    [id],
  );
  if (definitions.isEmpty) return;
  final contacts = db.select('SELECT id, custom_tags_json FROM contacts');
  for (final contact in contacts) {
    final encoded = contact['custom_tags_json']?.toString() ?? '[]';
    final decoded = jsonDecode(encoded);
    if (decoded is List && decoded.contains(id)) {
      db.execute('UPDATE contacts SET custom_tags_json=? WHERE id=?', [
        jsonEncode(decoded.where((value) => value != id).toList()),
        contact['id'],
      ]);
    }
  }
  db.execute('DELETE FROM profile_tag_definitions WHERE id=?', [id]);
}

bool _sameContactValue(String key, Object? first, Object? second) {
  if (key != 'photo_blob') return first == second;
  if (identical(first, second)) return true;
  if (first == null || second == null) return first == second;
  if (first is! List<int> || second is! List<int>) return first == second;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
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

void _loadSoundexSamples(Database db) {
  db.execute(
    'CREATE TABLE IF NOT EXISTS crm_sample_imports (name TEXT PRIMARY KEY)',
  );
  if (db
      .select("SELECT name FROM crm_sample_imports WHERE name='soundex_v1'")
      .isNotEmpty)
    return;
  final existingTag = db.select(
    "SELECT id FROM profile_tag_definitions WHERE category='custom' AND value='soundex_demo'",
  );
  int tagId;
  if (existingTag.isNotEmpty) {
    tagId = existingTag.single['id'] as int;
  } else {
    _insert(db, 'profile_tag_definitions', {
      'category': 'custom',
      'value': 'soundex_demo',
      'label': 'Fictional Soundex demo',
      'color_value': 0xFF00796B,
      'is_builtin': 0,
    });
    tagId = db.lastInsertRowId;
  }
  final organizationIds = <int>[];
  final now = DateTime.now().toUtc();
  for (final organization in SoundexSamples.organizations) {
    _saveOrganization(db, organization.toMap());
    final id = db.lastInsertRowId;
    organizationIds.add(id);
    final text = SoundexSamples.note(
      'Planning follow-up',
      'Schedule the next quarterly review and confirm venue availability.',
    );
    _insert(db, 'organization_notes', {
      'organization_id': id,
      'note_text': text,
      'soundex_index': SoundexHelper.encodePhrase(
        RichTextContent.plainText(text),
      ),
      'created_at': now.toIso8601String(),
    });
  }
  for (final contact in SoundexSamples.contacts(organizationIds, tagId)) {
    _saveContact(db, contact.toMap());
    final id = db.lastInsertRowId;
    final text = SoundexSamples.note(
      'Introductory meeting',
      'Discussed logistics, family activities, and the next leadership workshop.',
    );
    _insert(db, 'contact_notes', {
      'contact_id': id,
      'note_text': text,
      'soundex_index': SoundexHelper.encodePhrase(
        RichTextContent.plainText(text),
      ),
      'created_at': now.toIso8601String(),
    });
    _insert(db, 'interactions', {
      'contact_id': id,
      'organization_id': contact.organizationId,
      'interaction_type': 'Call',
      'direction': 'Outbound',
      'occurred_at': now
          .toIso8601String()
          .replaceFirst('T', ' ')
          .replaceFirst('Z', ''),
      'summary':
          'Fictional demo: reviewed the training calendar and confirmed the next planning meeting.',
      'follow_up_required': 1,
      'follow_up_date': now
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10),
      'follow_up_time': '10:00',
      'follow_up_at_utc': followUpUtc(
        now.add(const Duration(days: 7)).toIso8601String().substring(0, 10),
        '10:00',
      ),
      'follow_up_reason': 'Send the workshop agenda and confirm attendance',
      'follow_up_completed': 0,
    });
  }
  db.execute("INSERT INTO crm_sample_imports(name) VALUES ('soundex_v1')");
}
