import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/data/database_key_store.dart';
import 'package:greeting_app/models/crm_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS encrypted open reuses its Keychain key and preserves records',
      () async {
    // Unit-test the macOS routing and key lifecycle. Native Keychain access
    // additionally needs a signed Runner smoke test on a Mac.
    FlutterSecureStorage.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('macos_crm_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'CRM with spaces.sqlite3');
    final schema = File('assets/schema_v1.sql').readAsStringSync();
    final db = await CrmDatabase.open(path);
    await db.initialize(schema);
    await db.saveContact(const Contact(firstName: 'Mac', lastName: 'Native'));
    final key = await DatabaseKeyStore.loadOrCreateMacOS(path);
    final reopened = await CrmDatabase.open(path);
    expect((await reopened.load())['contacts']!.single['last_name'], 'Native');
    expect(await DatabaseKeyStore.loadOrCreateMacOS(path), key);
    expect(hasPlaintextSqliteHeader(File(path)), isFalse);
    expect(File('$path.key.dpapi').existsSync(), isFalse);
    final raw = sqlite3.open(path);
    try {
      expect(() => raw.select('SELECT * FROM contacts'),
          throwsA(isA<SqliteException>()));
    } finally {
      raw.close();
    }
    final before = File(path).readAsBytesSync();
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(CrmDatabase.open(path), throwsStateError);
    expect(File(path).readAsBytesSync(), before);
  }, skip: !Platform.isMacOS);
}
