import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:greeting_app/data/crm_database.dart';
import 'package:greeting_app/models/crm_models.dart';
import 'package:greeting_app/utils/utc_time.dart';

void main() {
  test('UTC parser accepts SQLite, UTC, and offset timestamps', () {
    final expected = DateTime.utc(2026, 11, 4, 16, 30);
    for (final value in [
      '2026-11-04 16:30:00',
      '2026-11-04T16:30:00Z',
      '2026-11-04T10:30:00-06:00',
    ]) {
      expect(parseUtcTimestamp(value), expected);
      expect(parseUtcTimestamp(value).isUtc, isTrue);
    }
    final note = ContactNote.fromMap({
      'contact_id': 1,
      'note_text': 'Legacy',
      'created_at': '2026-11-04 16:30:00',
    });
    expect(note.createdAt, expected);
    expect(note.toMap()['created_at'], '2026-11-04T16:30:00.000Z');
    final local = DateTime(2026, 11, 4, 10, 30);
    expect(
      ContactNote(
        contactId: 1,
        text: 'New',
        createdAt: local,
      ).toMap()['created_at'],
      local.toUtc().toIso8601String(),
    );
  });
  test(
    'Timed follow-ups convert to UTC; date-only follow-ups remain dates',
    () {
      for (final month in [1, 7, 11]) {
        final date = DateTime(2026, month, 4, 10, 30);
        expect(
          followUpUtc(date.toIso8601String(), '10:30'),
          date.toUtc().toIso8601String(),
        );
      }
      expect(followUpUtc('2026-11-04', null), isNull);
      expect(() => followUpUtc('2026-11-04', '25:00'), throwsFormatException);
    },
  );
  test('UTC storage survives reopening and legacy schedules migrate', () async {
    final dir = Directory.systemTemp.createTempSync('utc_crm');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/crm.sqlite3';
    final database = CrmDatabase.unencryptedForTesting(path);
    final schema = File('assets/schema_v1.sql').readAsStringSync();
    await database.initialize(schema);
    await database.saveContact(
      const Contact(firstName: 'Jane', lastName: 'Smith'),
    );
    final local = DateTime(2026, 11, 4, 10, 30);
    await database.logInteraction(
      InteractionLog(
        contactId: 1,
        date: local,
        type: 'Call',
        summary: 'Test',
        followUpDate: DateTime(2026, 11, 5),
        followUpTime: '09:15',
      ),
    );
    var db = sqlite3.open(path);
    final row = db.select('SELECT * FROM interactions').single;
    expect(parseUtcTimestamp(row['occurred_at'] as String), local.toUtc());
    expect(
      row['follow_up_at_utc'],
      DateTime(2026, 11, 5, 9, 15).toUtc().toIso8601String(),
    );
    // Recreate the immediately previous schema to exercise actual backfill.
    db.execute('ALTER TABLE interactions DROP COLUMN follow_up_at_utc');
    db.execute('DELETE FROM crm_app_migrations WHERE version>=15');
    db.execute('DROP TABLE map_settings');
    for (final table in ['contacts', 'organizations']) {
      for (final column in ['latitude', 'longitude', 'coordinate_source']) {
        db.execute('ALTER TABLE $table DROP COLUMN $column');
      }
    }
    db.close();
    final snapshot = await database.initialize(schema);
    final log = InteractionLog.fromMap(snapshot['interactions']!.single);
    expect(log.date, local.toUtc());
    expect(log.date.isUtc, isTrue);
    expect(log.followUpDate, DateTime(2026, 11, 5));
    expect(log.followUpTime, '09:15');
    db = sqlite3.open(path);
    expect(
      db
          .select('SELECT follow_up_at_utc FROM interactions')
          .single['follow_up_at_utc'],
      DateTime(2026, 11, 5, 9, 15).toUtc().toIso8601String(),
    );
    db.close();
  });
}
