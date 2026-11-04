import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/data/database_key_store.dart';
import 'package:greeting_app/data/database_encryption.dart';
import 'package:greeting_app/models/crm_models.dart';

void main() {
  test(
    'Encrypt legacy data, protect key and retain records across app updates',
    () async {
      final dir = Directory.systemTemp.createTempSync('encrypted_crm');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/crm.sqlite3';
      final schema = File('assets/schema_v1.sql').readAsStringSync();
      final legacy = CrmDatabase.unencryptedForTesting(path);
      await legacy.initialize(schema);
      await legacy.saveOrganization(
        const Organization(name: 'Confidential unit'),
      );
      await legacy.saveContact(
        const Contact(
          firstName: 'Private',
          lastName: 'Record',
          notes: 'Sensitive family details',
        ),
      );
      expect(hasPlaintextSqliteHeader(File(path)), isTrue);
      final secured = CrmDatabase(path);
      final first = await secured.initialize(schema);
      expect(first['contacts']!.single['last_name'], 'Record');
      expect(hasPlaintextSqliteHeader(File(path)), isFalse);
      expect(
        hasPlaintextSqliteHeader(File('$path.pre-encryption.enc')),
        isFalse,
      );
      final bytes = File(path).readAsBytesSync();
      expect(
        String.fromCharCodes(bytes),
        isNot(contains('Sensitive family details')),
      );
      final noKey = sqlite3.open(path);
      try {
        expect(
          () => noKey.select('SELECT * FROM contacts'),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        noKey.close();
      }
      final wrongKey = sqlite3.open(path);
      try {
        configureCipher(wrongKey);
        expect(() => applyDatabaseKey(wrongKey, '0' * 64), throwsStateError);
      } finally {
        wrongKey.close();
      }
      final protectedKey = File('$path.key.dpapi').readAsBytesSync();
      final key = DatabaseKeyStore.loadOrCreate(path);
      expect(String.fromCharCodes(protectedKey), isNot(contains(key)));
      final backup = sqlite3.open('$path.pre-encryption.enc');
      try {
        configureCipher(backup);
        applyDatabaseKey(backup, key);
        expect(backup.select('SELECT * FROM contacts'), hasLength(1));
      } finally {
        backup.close();
      }
      // A replacement application instance uses the same persistent key and files.
      final upgraded = CrmDatabase(path);
      expect(await upgraded.initialize(schema), first);
      await upgraded.saveContact(
        const Contact(firstName: 'New', lastName: 'After update'),
      );
      expect(
        (await CrmDatabase(path).initialize(schema))['contacts'],
        hasLength(2),
      );
      expect(File('$path.key.dpapi').readAsBytesSync(), protectedKey);
      File('$path.key.dpapi').renameSync('$path.key.saved');
      final before = File(path).readAsBytesSync();
      expect(() => CrmDatabase(path), throwsStateError);
      expect(File(path).readAsBytesSync(), before);
      expect(File('$path.key.dpapi').existsSync(), isFalse);
    },
    skip: !Platform.isWindows,
  );

  test(
    'Encrypted schema updates keep records and create an encrypted recovery snapshot',
    () async {
      final dir = Directory.systemTemp.createTempSync('encrypted_upgrade');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/crm.sqlite3';
      final schema = File('assets/schema_v1.sql').readAsStringSync();
      await CrmDatabase(path).initialize(schema);
      await CrmDatabase(path).saveContact(
        const Contact(firstName: 'Retained', lastName: 'Across versions'),
      );
      final key = DatabaseKeyStore.loadOrCreate(path);
      var db = sqlite3.open(path);
      configureCipher(db);
      applyDatabaseKey(db, key);
      db.execute('ALTER TABLE interactions DROP COLUMN follow_up_at_utc');
      db.execute('DELETE FROM crm_app_migrations WHERE version>=15');
      db.execute('DROP TABLE map_settings');
      for (final table in ['contacts', 'organizations']) {
        for (final column in ['latitude', 'longitude', 'coordinate_source']) {
          db.execute('ALTER TABLE $table DROP COLUMN $column');
        }
      }
      db.close();
      final updated = await CrmDatabase(path).initialize(schema);
      expect(updated['contacts']!.single['last_name'], 'Across versions');
      final recoveryPath = '$path.pre-v$crmSchemaVersion.enc';
      expect(hasPlaintextSqliteHeader(File(recoveryPath)), isFalse);
      db = sqlite3.open(recoveryPath);
      configureCipher(db);
      applyDatabaseKey(db, key);
      expect(
        db
            .select('SELECT MAX(version) AS version FROM crm_app_migrations')
            .single['version'],
        14,
      );
      expect(db.select('SELECT * FROM contacts'), hasLength(1));
      db.close();
      db = sqlite3.open(path);
      configureCipher(db);
      applyDatabaseKey(db, key);
      db.execute('INSERT INTO crm_app_migrations(version) VALUES (999)');
      db.close();
      await expectLater(CrmDatabase(path).initialize(schema), throwsStateError);
      db = sqlite3.open(path);
      configureCipher(db);
      applyDatabaseKey(db, key);
      expect(db.select('SELECT * FROM contacts'), hasLength(1));
      expect(
        db
            .select('SELECT MAX(version) AS version FROM crm_app_migrations')
            .single['version'],
        999,
      );
      db.close();
    },
    skip: !Platform.isWindows,
  );

  test('Fresh databases are encrypted on the first write', () async {
    final dir = Directory.systemTemp.createTempSync('new_encrypted_crm');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/crm.sqlite3';
    await CrmDatabase(
      path,
    ).initialize(File('assets/schema_v1.sql').readAsStringSync());
    expect(hasPlaintextSqliteHeader(File(path)), isFalse);
    final db = sqlite3.open(path);
    try {
      expect(
        () => db.select('SELECT * FROM contacts'),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      db.close();
    }
  }, skip: !Platform.isWindows);
}
