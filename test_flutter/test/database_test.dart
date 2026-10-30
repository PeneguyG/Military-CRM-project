import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/models/crm_models.dart';

void main() {
  final schema = File('assets/schema_v1.sql').readAsStringSync();
  late Directory directory;
  late String path;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('crm_test_');
    path = '${directory.path}/military_crm.sqlite3';
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test('Bundled schema is exactly the repository schema', () {
    expect(schema, File('../schema.sql').readAsStringSync());
  });

  test(
    'New records, edits, relationships and logs survive reopening',
    () async {
      var store = await CrmStore.open(CrmDatabase(path), schema);
      expect(store.contacts, isEmpty);
      expect(store.organizations, isEmpty);
      await store.saveOrganization(
        const Organization(
          name: "O'Brien Unit",
          industry: 'Defense',
          address: 'Base 1',
        ),
      );
      final organizationId = store.organizations.single.id!;
      await store.saveContact(
        Contact(
          organizationId: organizationId,
          firstName: 'Jane',
          lastName: 'Smith',
          title: 'Major',
          phone: '+1 202 555 0123',
          email: 'jane@example.com',
          address: 'Base 2',
          spouseName: 'Alex',
          childrenInfo: 'Two children',
          photoPath: 'C:/photos/jane.png',
          notes: "Quotes ' and SQL ; remain literal",
          talkingPoints: 'Readiness',
          status: ContactStatus.active,
        ),
      );
      final contactId = store.contacts.single.id!;
      await store.logInteraction(
        InteractionLog(
          contactId: contactId,
          organizationId: organizationId,
          date: DateTime.utc(2026, 10, 28, 14),
          type: 'In-Person',
          summary: 'Discussed readiness',
          followUpDate: DateTime(2026, 11, 3),
        ),
      );
      final contact = store.contacts.single.toMap();
      final organization = store.organizations.single.toMap();
      final interaction = store.interactions.single.toMap();
      await store.archiveContact(contactId, true);
      await store.archiveOrganization(organizationId, true);
      store.dispose();
      store = await CrmStore.open(CrmDatabase(path), schema);
      expect(store.contacts.single.isArchived, isTrue);
      expect(store.organizations.single.isArchived, isTrue);
      expect(store.interactions.single.toMap(), interaction);
      await store.archiveContact(contactId, false);
      await store.archiveOrganization(organizationId, false);
      expect(store.contacts.single.toMap(), contact);
      expect(store.organizations.single.toMap(), organization);
      await store.saveContact(
        store.contacts.single.copyWith(
          firstName: 'Janet',
          organizationId: null,
          photoPath: null,
        ),
      );
      await Future.wait([
        store.saveOrganization(const Organization(name: 'Second Unit')),
        store.saveOrganization(const Organization(name: 'Third Unit')),
      ]);
      store.dispose();
      store = await CrmStore.open(CrmDatabase(path), schema);
      addTearDown(store.dispose);
      expect(store.contacts.single.firstName, 'Janet');
      expect(store.contacts.single.organizationId, isNull);
      expect(store.contacts.single.photoPath, isNull);
      expect(store.interactions.single.organizationId, organizationId);
      expect(store.organizations.map((o) => o.id).toSet().length, 3);
      final db = sqlite3.open(path);
      try {
        final row = db.select('SELECT * FROM interactions').single;
        expect(row['interaction_type'], 'In-Person Meeting');
        expect(row['occurred_at'], '2026-10-28 14:00:00.000');
        expect(row['follow_up_required'], 1);
        expect(row['follow_up_date'], '2026-11-03');
        expect(
          db.select(
            "SELECT rowid FROM contacts_fts WHERE contacts_fts MATCH 'Janet'",
          ),
          hasLength(1),
        );
      } finally {
        db.close();
      }
    },
  );

  test('Existing Python schema migrates without losing unmodeled fields', () async {
    var db = sqlite3.open(path);
    db.execute(schema);
    db.execute(
      "INSERT INTO organizations(name,address_line1,city,website) VALUES('Existing Unit','1 Main St','Nashville','https://example.com')",
    );
    db.execute(
      "INSERT INTO contacts(first_name,last_name,organization_id,rank_or_title,primary_phone,secondary_phone,city,photo_blob,children_details,general_notes) VALUES('Alex','Existing',1,'Captain','5550100','5550199','Nashville',X'010203','Child details','Original notes')",
    );
    db.execute(
      "INSERT INTO interactions(contact_id,interaction_type,direction,summary,follow_up_required,follow_up_date,follow_up_completed) VALUES(1,'Briefing','Inbound','Briefed unit',1,'2026-11-03',1)",
    );
    final beforeContact = Map<String, Object?>.of(
      db.select('SELECT * FROM contacts').single,
    );
    final beforeOrg = Map<String, Object?>.of(
      db.select('SELECT * FROM organizations').single,
    );
    db.close();
    var store = await CrmStore.open(CrmDatabase(path), schema);
    expect(store.organizations.single.address, '1 Main St, Nashville');
    expect(store.contacts.single.title, 'Captain');
    expect(store.contacts.single.childrenInfo, 'Child details');
    expect(store.contacts.single.status, ContactStatus.active);
    expect(store.interactions.single.type, 'Briefing');
    await store.archiveContact(1, true);
    await store.archiveOrganization(1, true);
    await store.archiveContact(1, false);
    await store.archiveOrganization(1, false);
    db = sqlite3.open(path);
    try {
      final after = db.select('SELECT * FROM contacts').single;
      for (final key in beforeContact.keys.where(
        (key) => key != 'updated_at',
      )) {
        expect(after[key], beforeContact[key], reason: 'Contact field $key');
      }
      final afterOrg = db.select('SELECT * FROM organizations').single;
      for (final key in beforeOrg.keys.where((key) => key != 'updated_at')) {
        expect(
          afterOrg[key],
          beforeOrg[key],
          reason: 'Organization field $key',
        );
      }
    } finally {
      db.close();
    }
    await store.saveContact(
      store.contacts.single.copyWith(firstName: 'Updated'),
    );
    await store.saveOrganization(
      store.organizations.single.copyWith(name: 'Renamed Unit'),
    );
    store.dispose();
    // Python initialization is repeatable and must not remove the extensions.
    db = sqlite3.open(path);
    db.execute(schema);
    db.close();
    store = await CrmStore.open(CrmDatabase(path), schema);
    addTearDown(store.dispose);
    db = sqlite3.open(path);
    try {
      final row = db.select('SELECT * FROM contacts').single;
      expect(row['secondary_phone'], '5550199');
      expect(row['city'], 'Nashville');
      expect(row['address'], isNull);
      expect(row['photo_blob'], [1, 2, 3]);
      expect(
        db.select('SELECT website FROM organizations').single['website'],
        'https://example.com',
      );
      expect(
        db
            .select('SELECT direction,follow_up_completed FROM interactions')
            .single['follow_up_completed'],
        1,
      );
      expect(
        db.select(
          "SELECT rowid FROM contacts_fts WHERE contacts_fts MATCH 'Renamed'",
        ),
        hasLength(1),
      );
      expect(
        () => db.execute('DELETE FROM contacts WHERE id=1'),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db.execute('DELETE FROM organizations WHERE id=1'),
        throwsA(isA<SqliteException>()),
      );
      expect(db.select('SELECT * FROM interactions'), hasLength(1));
    } finally {
      db.close();
    }
  });

  test(
    'Failed writes roll back and leave the store unchanged; queue recovers',
    () async {
      final store = await CrmStore.open(CrmDatabase(path), schema);
      addTearDown(store.dispose);
      await expectLater(
        store.saveContact(
          const Contact(
            firstName: 'Jane',
            lastName: 'Smith',
            organizationId: 999,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(store.contacts, isEmpty);
      await expectLater(
        store.saveOrganization(const Organization(name: '  ')),
        throwsA(isA<SqliteException>()),
      );
      expect(store.organizations, isEmpty);
      await store.saveOrganization(const Organization(name: 'Valid unit'));
      await store.saveContact(
        Contact(
          firstName: 'Jane',
          lastName: 'Smith',
          organizationId: store.organizations.single.id,
        ),
      );
      await expectLater(
        store.logInteraction(
          InteractionLog(
            contactId: 1,
            date: DateTime.now(),
            type: 'Call',
            summary: '',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(store.interactions, isEmpty);
      final reopened = await CrmStore.open(CrmDatabase(path), schema);
      addTearDown(reopened.dispose);
      expect(reopened.contacts, hasLength(1));
      expect(reopened.organizations, hasLength(1));
      expect(reopened.interactions, isEmpty);
    },
  );

  test(
    'Unknown schema versions fail without replacing existing records',
    () async {
      final db = sqlite3.open(path);
      db.execute(schema);
      db.execute(
        "INSERT INTO organizations(name) VALUES('Keep me'); PRAGMA user_version=99;",
      );
      db.close();
      await expectLater(
        CrmStore.open(CrmDatabase(path), schema),
        throwsStateError,
      );
      final check = sqlite3.open(path);
      try {
        expect(
          check.select('SELECT name FROM organizations').single['name'],
          'Keep me',
        );
        expect(check.userVersion, 99);
      } finally {
        check.close();
      }
    },
  );
}
