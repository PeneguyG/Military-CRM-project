import 'package:flutter/material.dart';
import 'sample_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/main.dart';
import 'package:greeting_app/models/crm_models.dart';
import 'package:greeting_app/pages/contacts_page.dart';
import 'package:greeting_app/pages/organizations_page.dart';
import 'package:greeting_app/pages/crm_widgets.dart';

void main() {
  const organization = Organization(
    id: 1,
    name: 'Unit',
    industry: 'Defense',
    address: 'Base',
    phone: '5550100',
    email: 'unit@example.com',
    notes: 'Retain these notes',
  );
  const contact = Contact(
    id: 1,
    organizationId: 1,
    firstName: 'Alex',
    lastName: 'Morgan',
    title: 'Major',
    phone: '5550101',
    email: 'alex@example.com',
    address: 'Base',
    spouseName: 'Jordan',
    childrenInfo: 'Two children',
    photoPath: '/missing/photo.png',
    notes: 'Private notes',
    talkingPoints: 'Next event',
    status: ContactStatus.inactive,
  );
  final log = InteractionLog(
    id: 1,
    contactId: 1,
    organizationId: 1,
    date: DateTime.utc(2026, 1, 2, 13),
    type: 'Call',
    summary: 'Discussed event',
    followUpDate: DateTime.utc(2026, 1, 8),
  );

  test('SQLite round trips retain every field and date', () {
    expect(
      Organization.fromMap(organization.toMap()).toMap(),
      organization.toMap(),
    );
    expect(Contact.fromMap(contact.toMap()).toMap(), contact.toMap());
    expect(InteractionLog.fromMap(log.toMap()).toMap(), log.toMap());
    expect(contact.toMap()['is_archived'], 0);
    expect(contact.toMap()['status'], 'inactive');
  });
  test('Nullable copyWith supports explicit clearing and omitted values', () {
    expect(contact.copyWith(notes: 'Updated').photoPath, contact.photoPath);
    expect(
      contact
          .copyWith(organizationId: null, photoPath: null, id: null)
          .organizationId,
      isNull,
    );
    expect(contact.copyWith(photoPath: null).photoPath, isNull);
    expect(organization.copyWith(id: null).id, isNull);
    expect(log.copyWith(followUpDate: null).followUpDate, isNull);
    expect(log.copyWith(summary: 'Updated').followUpDate, log.followUpDate);
  });
  test(
    'Archive and restore retain all fields, linked records and interactions',
    () {
      final store = CrmStore(
        organizations: [organization],
        contacts: [contact],
        interactions: [log],
      );
      addTearDown(store.dispose);
      store.saveOrganization(organization.copyWith(isArchived: true));
      store.saveContact(contact.copyWith(isArchived: true));
      expect(store.organization(1)!.isArchived, isTrue);
      expect(store.contact(1)!.isArchived, isTrue);
      expect(store.contact(1)!.organizationId, 1);
      expect(store.interactions.single.toMap(), log.toMap());
      store.saveOrganization(
        store.organization(1)!.copyWith(isArchived: false),
      );
      store.saveContact(store.contact(1)!.copyWith(isArchived: false));
      expect(store.organization(1)!.toMap(), organization.toMap());
      expect(store.contact(1)!.toMap(), contact.toMap());
      store.saveContact(const Contact(firstName: 'New', lastName: 'Person'));
      expect(store.contacts.last.id, 2);
    },
  );
  testWidgets(
    'Mobile dossier pushes, edits, logs and archives without losing history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = CrmStore(
        organizations: [organization],
        contacts: [contact],
        interactions: [log],
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ContactsPage(store: store)),
        ),
      );
      await tester.tap(find.text('Alex Morgan'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactDetail), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name *'),
        'Avery',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.contact(1)!.firstName, 'Avery');
      final logButton = find.text('Log Interaction / Follow-Up');
      await tester.scrollUntilVisible(
        logButton,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ContactDetail),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(logButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Summary'),
        'Followed up on event',
      );
      await tester.tap(find.text('Save interaction'));
      await tester.pumpAndSettle();
      expect(store.interactions.length, 2);
      expect(store.interactions.last.organizationId, 1);
      await tester.scrollUntilVisible(
        find.text('Archive'),
        -300,
        scrollable: find
            .descendant(
              of: find.byType(ContactDetail),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(store.contact(1)!.isArchived, isTrue);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(store.contact(1)!.isArchived, isFalse);
      expect(store.interactions.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Desktop split view and search by organization', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sample = sampleStore();
    addTearDown(sample.dispose);
    await tester.pumpWidget(MilitaryCrmApp(store: sample));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Sentinel');
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsNothing);
    await tester.tap(find.text('Taylor Reed'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetail), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Associated archived contact opens its mobile profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sample = sampleStore();
    addTearDown(sample.dispose);
    await tester.pumpWidget(MilitaryCrmApp(store: sample));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organizations').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Veterans Outreach Unit'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Colonel (Ret.) Sam Hayes'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(OrganizationDetail),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Colonel (Ret.) Sam Hayes'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetail), findsOneWidget);
    expect(find.text('Sam Hayes'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
