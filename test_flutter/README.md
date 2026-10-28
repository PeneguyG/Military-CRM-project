# Military CRM

Single-user Flutter Material 3 CRM with persistent SQLite storage.
Requires Flutter 3.38+ and Dart 3.10+; verified with the installed Flutter SDK.

## Run

From this directory:

```powershell
flutter pub get
flutter run -d windows
```

New installations start empty. Add an organization in Organizations, then add a
contact in Contacts and assign it to that organization. Saved records, edits,
archives, restores, and interaction logs survive application restarts.

The database is `military_crm.sqlite3` under the platform application-support
folder, in a `MilitaryCRM` subfolder. Click the storage icon beside "Saved locally
in SQLite" to see its exact path. Builds and `flutter clean` do not erase it.
The refresh button reloads changes made by the Python helper or another client.

To explicitly open a database created by the repository's Python helper:

```powershell
flutter run -d windows --dart-define=CRM_DATABASE_PATH=C:/data/military_crm.sqlite3
```

This opens and migrates that file in place; it does not copy or import it. Existing
version-1 files are supported. Unknown versions are rejected without replacing
records. The application does not automatically search for personal database files.

## Database integration

`assets/schema_v1.sql` is an exact bundled copy of the repository's `schema.sql`;
a test detects drift. New databases use that schema, including its FTS5 indexes,
triggers, foreign keys, and constraints. The `sqlite3` package bundles the native
SQLite library through build hooks, including Windows debug and release builds.
No Python process or separately installed SQLite executable is needed by the app.

`lib/data/crm_database.dart` performs parameterized operations in background
isolates. Connections enable foreign keys and a 10-second busy timeout; the
file uses WAL. Writes and their resulting snapshots share a transaction. The
store serializes operations and publishes changes only after commit. Save forms
wait for completion and retain typed values on failure.

The Python schema retains `user_version = 1`. Additive Flutter extensions are
tracked separately in `crm_app_migrations` (currently version 1):

- Organizations and contacts gain nullable free-form `address` and `is_archived`.
- Contacts gain `status` (active/inactive/deceased).
- Interactions gain an organization snapshot. Old rows are backfilled from the
  contact's current organization because older historical affiliation is unknown.
- Database triggers reject hard deletion of contacts and organizations.

The adapter maps rank/title, primary phone, children details, general notes, and
interaction fields to the existing schema. Existing structured addresses are
shown until a free-form address is explicitly changed. Original structured
address fields, websites, secondary phones, embedded photos, and other fields
outside the forms are retained. Embedded photos are preserved but not displayed;
assigning a photo path while a blob exists is rejected rather than deleting it.

New interactions default to Outbound, map In-Person to In-Person Meeting, use
canonical UTC timestamps, and set follow-up flags with a calendar date. Existing
Briefing/Other and inbound interactions remain readable and unchanged. Follow-up
completion and interaction direction editing are not exposed by these forms.

Archive/restore changes only `is_archived`. Archiving an organization leaves its
contacts and interaction history intact. The app database is local and is not
encrypted by this implementation. Use SQLite's backup API for live backups.

## Interface and platform notes

- Desktop list/detail split view and mobile pushed detail routes.
- Search, status filtering, active/archived views, notes and talking points.
- Local photo paths with a fallback avatar for missing files.
- Call/text actions and manual interaction logging with optional follow-up dates.
- Light theme from 06:00 to 18:00 local time; dark otherwise. The sun/moon button
  overrides it; the clock button restores automatic mode.

The Windows runner is included. Enable Windows Developer Mode for plugin symlinks.
CMake 4.2+ uses short intermediate paths to avoid MSBuild failures in deeply nested
checkouts. With older CMake, use a shorter checkout path if `.tlog` failures occur.
For Android/iOS, generate runners on a suitable host; those builds are not verified
here. `dart:io` photos and the native SQLite adapter do not target web. Telephone
and SMS actions require a registered handler on the device.

## Verify

```powershell
flutter analyze
flutter test
flutter build windows --debug
```

Tests cover persistence across reopening, version-1 migrations, field preservation,
FTS updates, rollback and queue recovery, archive/restore, SQL constraints, save
failure behavior, linked-record creation, and responsive navigation. Demo records
exist only in test fixtures; they are not inserted into the user's database.
