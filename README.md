# Steel Wings CRM

Steel Wings CRM is the Windows and macOS desktop application in `test_flutter`.

## Desktop build and run

Use an SDK compatible with the committed lockfile: Flutter 3.47+ / Dart 3.13+.
The manifest's older minimum does not satisfy the current locked dependencies.

| Step | Windows (PowerShell) | macOS (Terminal, ARM64 or Intel) |
| --- | --- | --- |
| Prerequisites | Flutter, Visual Studio Desktop development with C++, Developer Mode | Flutter, full Xcode with command-line tools and accepted license; macOS 12+ runtime |
| Dependencies | `cd test_flutter; flutter pub get` | `cd test_flutter && flutter pub get` |
| Run | `flutter run -d windows` | `flutter run -d macos` |
| Release | `flutter build windows --release` | From repository root: `bash scripts/macos.sh build` |
| Verify | `flutter analyze; flutter test` | From repository root: `bash scripts/macos.sh check` |

On macOS, the script also offers `bash scripts/macos.sh run` and accepts extra
Flutter options. It works from any directory; set `FLUTTER` to an SDK executable
if it is not on PATH. Release builds request both ARM64 and x86_64 and the script
checks every bundled native binary for both slices. Use a Flutter SDK and plugin
versions that still supply Intel support; a failed architecture check must be
resolved before distributing a build to both CPU families.

Launch a built Mac app with:

```sh
open "test_flutter/build/macos/Build/Products/Release/Steel Wings CRM.app"
```

Keep the complete `.app` bundle together. The macOS app uses its application
support directory and the user's Keychain; Windows retains its existing data
directory and DPAPI keys. macOS sandbox access permits networking and files
selected through the native picker. Custom database paths outside the sandbox
may be inaccessible. Sign and notarize macOS builds for external distribution.
See [platform inventory and verification](docs/PLATFORM_SUPPORT.md) for the
architecture, dependency inventory and native acceptance checks.

## Run the Windows app

### Launch an existing build

If the project already has a Windows build, open
`test_flutter\build\windows\x64\runner\Debug\steel_wings.exe` from File
Explorer, or run this from the repository folder in PowerShell:

```powershell
Start-Process .\test_flutter\build\windows\x64\runner\Debug\steel_wings.exe
```

Keep the executable with the other files in its `Debug` folder, including the
`data` folder and DLLs. The executable does not run by itself when copied out of
that folder. Sign in with the password configured for your copy of the app.

### Run from source

Install Flutter compatible with the lockfile (currently 3.47+) and Visual Studio with the **Desktop development
with C++** workload, then open PowerShell in the repository folder and run:

```powershell
cd .\test_flutter
flutter pub get
flutter run -d windows
```

To create a Windows release build instead, run this from `test_flutter`:

```powershell
flutter build windows --release
```

The release executable is at
`test_flutter\build\windows\x64\runner\Release\steel_wings.exe`. Keep the
whole `Release` folder together when moving or sharing the build.

The app asks for its password at sign-in. Use the lock control in the app to
return to the sign-in screen.

## Local data

Records are saved in a local SQLite database and remain available after the app
closes. The database is stored in the platform application-support folder, in a
`MilitaryCRM` subfolder, as `military_crm.sqlite3`. In the app, open Settings to
view the exact database path. For additional database and development details,
see [`test_flutter/README.md`](test_flutter/README.md).

## Python SQLite helper

The repository also contains a Python SQLite helper. It requires Python 3.10+
and SQLite with FTS5; it has no third-party Python package dependencies.

```python
from military_crm import MilitaryCRMDatabase

with MilitaryCRMDatabase('military_crm.sqlite3') as db:
    db.initialize_database()
    organization = db.add_organization('Operations Group', industry='Defense')
    contact = db.add_contact('Jane', 'Smith', organization,
                             primary_phone='+1 (512) 555-0100',
                             talking_points='Training and readiness')
    db.log_interaction(contact, 'Call', 'Outbound', 'Discussed training',
                       follow_up_required=True, follow_up_date='2026-11-03')
    print(db.search_records('readiness', industry='Defense'))
    print(db.search_records('Smyth', use_soundex=True))
    print(db.get_uncontacted_contacts(30))
    print(db.get_distinct_organizations_contacted('2026-10-01', '2026-10-31'))
    print(db.get_contact_action_uris(contact))
```

Optional keyword fields follow `schema.sql`. Methods return inserted IDs, lists
of dictionaries, an integer count, or URI dictionaries as appropriate. Missing
contacts raise `KeyError`; absent phones yield `None` URI values. Phone numbers
preserve a supplied international prefix; extensions and alphabetic numbers
raise `ValueError`. The application can render returned URIs as clickable links.

`CRMDatabaseError` wraps SQLite errors and preserves their cause. Failed writes
roll back automatically. Use one instance per thread. Foreign keys are enabled
on every helper connection; external SQLite clients must enable them too.

Timestamps are UTC, with helper input normalized from ISO timestamps (naive input
means UTC). Direct SQL writers must use `YYYY-MM-DD HH:MM:SS[.ffffff]` in UTC so
indexed comparisons remain correct. Date ranges include both calendar dates.
All interaction types and directions count as contact. Organization counts use
the contact's current organization; they do not preserve affiliation history.

FTS indexes names, organization notes, general notes, and talking points, with
triggers maintaining organization renames, reassignment, and deletion. Literal
FTS tokens are combined with AND; substring and optional surname Soundex matches
are alternatives. Industry/location filters apply to all alternatives. LIKE
wildcards and FTS operators in user text are treated literally. SQLite LIKE and
the fallback English Soundex provide limited Unicode name matching.

`queries.sql` provides standalone query examples. `schema.sql` is transactional
and repeatable, with `user_version = 1`; initialization rebuilds FTS and should
run during startup/maintenance, not on every request. Future schema changes need
explicit versioned migrations; `CREATE TABLE IF NOT EXISTS` does not migrate
existing tables. WAL allows readers during writes, with a ten-second busy timeout.

SQLite files and backups contain personal data, including family details and
photos. Deploy with restricted filesystem access, encrypted storage, and a
backup/retention policy appropriate to the application. SQLite itself does not
provide encryption or application-level access control. Use SQLite's backup API
for live backups rather than copying only the database file while WAL is active.

Run verification with `python -m unittest -v`.
