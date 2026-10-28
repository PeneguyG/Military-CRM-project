import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/models/crm_models.dart';
import 'package:greeting_app/pages/contacts_page.dart';
import 'package:greeting_app/pages/organizations_page.dart';
import 'package:greeting_app/pages/crm_widgets.dart';

void main() {
  testWidgets(
    'Save waits for commit, prevents duplicates and retains entries on failure',
    (tester) async {
      final save = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => RecordForm(
                    title: 'Add organization',
                    organizationForm: true,
                    values: const {},
                    fields: const {'name': 'Name'},
                    onSave: (_) {
                      calls++;
                      return save.future;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Keep this unit');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      save.completeError(StateError('Database unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this unit'), findsOneWidget);
      expect(find.textContaining('Your entries are retained'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Add organization and linked contact use the store save callbacks',
    (tester) async {
      final store = CrmStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => editOrganization(context, store),
                    child: const Text('New unit'),
                  ),
                  TextButton(
                    onPressed: () => editContact(
                      context,
                      store,
                      const Contact(
                        firstName: '',
                        lastName: '',
                        organizationId: 1,
                      ),
                    ),
                    child: const Text('New contact'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('New unit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Organization name *'),
        'Operations Unit',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.organizations.single.name, 'Operations Unit');
      await tester.tap(find.text('New contact'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name *'),
        'Jane',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last name *'),
        'Smith',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.contacts.single.fullName, 'Jane Smith');
      expect(
        store.contacts.single.organizationId,
        store.organizations.single.id,
      );
      expect(find.byType(RecordForm), findsNothing);
    },
  );
}
