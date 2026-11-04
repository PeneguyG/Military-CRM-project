import 'package:flutter/material.dart';
import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/pages/contacts_page.dart';
import 'package:greeting_app/pages/organizations_page.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:greeting_app/utils/soundex_helper.dart';
import 'package:greeting_app/utils/crm_search_queries.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/models/crm_models.dart';

void main() {
  testWidgets('Both tabs match phonetic notes and linked organizations live', (
    tester,
  ) async {
    final store = CrmStore(
      organizations: [
        const Organization(id: 1, name: 'Smith Brigade', industry: 'Defense'),
      ],
      contacts: [
        const Contact(
          id: 1,
          organizationId: 1,
          firstName: 'Jane',
          lastName: 'Jones',
          talkingPoints: 'Readiness',
        ),
      ],
      organizationNotes: [
        OrganizationNote(
          id: 1,
          organizationId: 1,
          text: 'Robert',
          createdAt: DateTime(2026),
        ),
      ],
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ContactsPage(store: store)),
      ),
    );
    for (final query in [
      'J',
      'Ja',
      'Jan',
      'Jane J',
      'Jane Jo',
      'S',
      'Sm',
      'Smy',
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      expect(find.text('Jane Jones'), findsOneWidget, reason: query);
    }
    await tester.enterText(find.byType(TextField), 'Smyth');
    await tester.pumpAndSettle();
    expect(find.text('Jane Jones'), findsOneWidget);
    expect(find.text('Phonetic Match (Soundex) Active'), findsNothing);
    await tester.enterText(find.byType(TextField), 'unrelated');
    await tester.pumpAndSettle();
    expect(find.text('No matching contacts'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationsPage(store: store, onSelectContact: (_) {}),
        ),
      ),
    );
    for (final query in ['S', 'Sm', 'Smy', 'Smyt', 'Smyth', 'Smith Br']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      expect(find.text('Smith Brigade'), findsOneWidget, reason: query);
    }
    await tester.enterText(find.byType(TextField), 'Rupert');
    await tester.pumpAndSettle();
    expect(find.text('Smith Brigade'), findsOneWidget);
    expect(find.text('Phonetic Match (Soundex) Active'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Brig Smith');
    await tester.pumpAndSettle();
    expect(find.text('Smith Brigade'), findsOneWidget);
    expect(find.text('Phonetic Match (Soundex) Active'), findsNothing);
  });

  test(
    'American Soundex handles duplicate consonants and vowel separators',
    () {
      for (final entry in {
        'Smith': 'S530',
        'Smyth': 'S530',
        'Ashcraft': 'A261',
        'Tymczak': 'T522',
        'Pfister': 'P236',
        'Robert': 'R163',
        'Rupert': 'R163',
        'Kowalsky': 'K420',
        'Kovalski': 'K142',
        '123': '',
      }.entries) {
        expect(SoundexHelper.encodeWord(entry.key), entry.value);
      }
      expect(
        SoundexHelper.encodePhrase('101st Airborne Brigade Smith Smyth of'),
        'A616 B623 S530',
      );
    },
  );
  test('Queries require every token, with literal short and numeric terms', () {
    expect(
      SoundexHelper.matchesQuery('smyth brig', rawTargetText: 'Smith Brigade'),
      isTrue,
    );
    expect(
      SoundexHelper.matchesQuery('smyth navy', rawTargetText: 'Smith Brigade'),
      isFalse,
    );
    expect(SoundexHelper.matchesQuery('12', rawTargetText: 'Smith'), isFalse);
    expect(SoundexHelper.matchesQuery('!!!', rawTargetText: 'Smith'), isFalse);
    expect(SoundexHelper.matchesQuery('', rawTargetText: 'Smith'), isTrue);
  });
  test('SQL parameters support mixed terms and escape wildcard input', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute(
      'CREATE TABLE records (name TEXT, notes TEXT, soundex_index TEXT)',
    );
    db.execute('INSERT INTO records VALUES (?, ?, ?)', [
      'Smith',
      'Brigade',
      'S530 B623',
    ]);
    for (final query in ['smyth brig', 'smy', 'sm', 'smith', '']) {
      final clause = buildPhoneticSearchWhereClause(query, ['name', 'notes']);
      expect(
        db.select(
          'SELECT * FROM records WHERE ${clause.where}',
          clause.whereArgs,
        ),
        hasLength(1),
      );
    }
    for (final query in ['%', '_', "' OR 1=1 --", 'smyth navy']) {
      final clause = buildPhoneticSearchWhereClause(query, ['name', 'notes']);
      expect(
        db.select(
          'SELECT * FROM records WHERE ${clause.where}',
          clause.whereArgs,
        ),
        isEmpty,
      );
    }
    expect(
      () => buildPhoneticSearchWhereClause('x', ['name); DROP TABLE records']),
      throwsArgumentError,
    );
  });
  test('Migration backfills legacy data and saves refreshed indexes', () async {
    final directory = Directory.systemTemp.createTempSync('soundex_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/crm.sqlite3';
    final schema = File('assets/schema_v1.sql').readAsStringSync();
    final legacy = sqlite3.open(path);
    legacy.execute(schema);
    legacy.execute("INSERT INTO organizations(name) VALUES ('Smith')");
    legacy.execute(
      "INSERT INTO contacts(first_name,last_name,general_notes) VALUES ('Jane','Smith','Brigade')",
    );
    legacy.close();
    final database = CrmDatabase.unencryptedForTesting(path);
    await database.initialize(schema);
    var db = sqlite3.open(path);
    expect(
      db
          .select('SELECT soundex_index FROM organizations')
          .single['soundex_index'],
      'S530',
    );
    expect(
      db.select('SELECT name_soundex FROM contacts').single['name_soundex'],
      'J500 S530',
    );
    expect(
      db
          .select('SELECT soundex_index FROM contact_notes')
          .single['soundex_index'],
      'B623',
    );
    db.close();
    await database.saveContact(
      const Contact(id: 1, firstName: 'Robert', lastName: 'Jones'),
    );
    await database.addOrganizationNote(
      OrganizationNote(
        organizationId: 1,
        text: 'Readiness',
        createdAt: DateTime.now(),
      ),
    );
    await database.initialize(schema);
    db = sqlite3.open(path);
    expect(
      db.select('SELECT name_soundex FROM contacts').single['name_soundex'],
      'R163 J520',
    );
    expect(
      db
          .select('SELECT soundex_index FROM organization_notes')
          .single['soundex_index'],
      'R352',
    );
    db.close();
  });
}
