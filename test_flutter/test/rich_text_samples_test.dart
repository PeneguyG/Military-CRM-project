import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/data/soundex_samples.dart';
import 'package:greeting_app/models/crm_models.dart';
import 'package:greeting_app/pages/rich_text_widgets.dart';
import 'package:greeting_app/utils/rich_text_content.dart';
import 'package:greeting_app/utils/soundex_helper.dart';

void main() {
  test('Rich text preserves plain text and indexes visible words only', () {
    const legacy = 'Plain notes stay plain.';
    expect(RichTextContent.plainText(legacy), legacy);
    expect(RichTextContent.plainText('{invalid JSON'), '{invalid JSON');
    final content = RichTextContent.encode([
      {
        'insert': 'Smith',
        'attributes': {'bold': true, 'link': 'https://hidden.example.com'},
      },
      {'insert': '\n'},
    ]);
    final organization = Organization(name: 'Unit', notes: content);
    expect(organization.searchText, contains('Smith'));
    expect(organization.searchText, isNot(contains('hidden')));
    expect(organization.soundexIndex, contains('S530'));
    expect(Organization.fromMap(organization.toMap()).notes, content);
  });

  test(
    'Sample import is atomic, repeat safe, complete and survives reopening',
    () async {
      final dir = Directory.systemTemp.createTempSync('crm_rich_samples');
      addTearDown(() => dir.deleteSync(recursive: true));
      final db = CrmDatabase.unencryptedForTesting('${dir.path}/crm.sqlite3');
      final schema = File('assets/schema_v1.sql').readAsStringSync();
      var store = await CrmStore.open(db, schema);
      await store.saveOrganization(
        const Organization(name: 'Existing organization'),
      );
      await store.loadSoundexSamples();
      await store.loadSoundexSamples();
      expect(store.organizations, hasLength(4));
      expect(store.contacts, hasLength(6));
      expect(store.contactNotes, hasLength(6));
      expect(store.organizationNotes, hasLength(3));
      expect(store.interactions, hasLength(6));
      for (final c in store.contacts) {
        expect(store.organization(c.organizationId), isNotNull);
        expect(c.phoneNumbers, hasLength(2));
        expect(c.emailAddresses, hasLength(2));
        expect(c.children, hasLength(1));
        expect(c.spouseName, isNotEmpty);
        expect(RichTextContent.operations(c.talkingPoints), isNotNull);
      }
      for (final pair in [
        ('Smyth', 'Smith'),
        ('Ashcroft', 'Ashcraft'),
        ('Fister', 'Pfister'),
        ('Jaxon', 'Jackson'),
        ('Rupert', 'Robert'),
      ]) {
        expect(
          store.contacts.any(
            (c) => SoundexHelper.matchesQuery(
              pair.$1,
              rawTargetText: c.searchText,
              precomputedSoundex: c.fullSoundexIndex,
            ),
          ),
          isTrue,
        );
      }
      final contact = store.contacts.first;
      final rich = SoundexSamples.note('Updated', 'Smyth family visit');
      await store.saveContact(contact.copyWith(talkingPoints: rich));
      store.dispose();
      store = await CrmStore.open(db, schema);
      expect(store.contact(contact.id)!.talkingPoints, rich);
      expect(
        store.organizations.any((o) => o.name == 'Existing organization'),
        isTrue,
      );
      store.dispose();
    },
  );

  testWidgets('Rich editor formats, saves and renders without exposing JSON', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Smith briefing');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RichTextEditor(controller: controller, label: 'Note'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      quill.ChangeSource.local,
    );
    editor.controller.formatSelection(quill.Attribute.bold);
    await tester.pumpAndSettle();
    expect(
      RichTextContent.operations(controller.text)!.first['attributes'],
      containsPair('bold', true),
    );
    expect(RichTextContent.plainText(controller.text), 'Smith briefing');
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RichTextView(controller.text))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(quill.QuillEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
