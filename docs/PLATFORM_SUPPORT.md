# Desktop platform inventory and design

## Inventory

| Location | Windows assumption | macOS counterpart / handling |
| --- | --- | --- |
| `test_flutter/windows/runner/` | Win32 window/message loop, COM initialization, console attachment, DPI APIs, DWM theme and registry APIs, `User32.dll`, resources and executable manifest | Existing Cocoa/FlutterMacOS Swift runner in `test_flutter/macos/`; each host builds only its own runner |
| `test_flutter/windows/**/CMakeLists.txt` | MSVC flags, Windows Flutter DLL, plugin DLL installation, short MSBuild intermediate paths | Existing Xcode workspace, Swift plugin registration and Flutter build phases; Windows CMake files retained unchanged |
| `lib/data/database_key_store.dart` | `win32` and `ffi`: `CryptProtectData`, `CryptUnprotectData`, `LocalFree`, Windows `.key.dpapi` file | Existing asynchronous `flutter_secure_storage` Keychain implementation; DPAPI runs only after `Platform.isWindows` guard |
| `lib/data/crm_database.dart` | Synchronous constructor uses DPAPI | Shared `CrmDatabase.open` routes macOS to asynchronous Keychain before SQLite background isolates |
| `lib/main.dart` | `%APPDATA%/com.example/Steel Wings CRM`, synchronous Windows theme save | Existing runtime guards preserve Windows location; macOS uses `getApplicationSupportDirectory`; all joins use `package:path` |
| `pubspec.yaml` / lockfile | `win32`, Windows implementations of file selector, secure storage, URL launcher, path provider and Quill | Federated plugins select Darwin implementations; SQLite3 Multiple Ciphers native build hook supplies the encryption library for the target architecture |
| `test/database_test.dart` | `C:/photos/jane.png` | Intentional legacy data preservation fixture, not a runtime filesystem default |
| READMEs | Windows example paths and PowerShell commands | Retained with macOS commands alongside them |
| `tool/*.dart` | Synchronous DPAPI constructor and standalone `dart run` | Existing Windows utilities retained; macOS must use the Flutter app because Keychain requires a native plugin host |

No `.bat` or `.ps1` files or existing CI workflows were present. There are no
hardcoded drive letters in production Dart/Python paths. SQL backslash escapes
are query syntax, not filesystem paths. Python uses `pathlib` for schema loading
and standard SQLite; it does not require OS-specific changes. Existing stored
Windows photo paths are preserved; moving data does not relocate external files.

## Side-by-side architecture

Keep business logic, SQLite encryption/migrations and widgets shared. Native
windowing stays in separate Windows and macOS runners. Database key protection
stays behind `DatabaseKeyStore` and `CrmDatabase.open`; do not substitute macOS
libraries into the Windows runner or change existing Windows data/key locations.

macOS Debug/Profile and Release both allow outgoing networking for maps and
read access to files chosen through native file dialogs. Debug-only JIT and
server permissions remain intact. Arbitrary `CRM_DATABASE_PATH` overrides outside
the app sandbox may be inaccessible; use the default location on macOS.
Existing legacy photo paths outside the sandbox may also be inaccessible;
reselect the photo to store its bytes in the database.

The macOS Runner requests ARM64 and x86_64. The release script verifies both
slices in every Mach-O binary, including bundled frameworks and SQLite assets.
It fails if the selected Flutter SDK or a plugin supplies only one architecture.
CI adds Windows release and Apple Silicon/Intel macOS checks; it does not replace
the Windows CMake pipeline. The existing lockfile requires Flutter >=3.47 and
Dart >=3.13 despite the lower manifest minimum; CI enforces that lockfile.

## Verification and manual acceptance

Run the Python suite, Flutter analysis and Flutter tests, then native release
builds on Windows and both Mac CPU families. Windows DPAPI tests are retained;
the macOS test uses mocked secure storage to check key reuse, encryption,
reopening and missing-key rejection. It cannot validate native Keychain access.

On each Mac architecture, launch the built app, sign in, save a contact/photo,
open an attachment, load map tiles, change theme, quit and reopen. Confirm data
and theme persist and that Keychain access succeeds. Repeat persistence and
call/text handler checks on Windows. Distribution requires appropriate signing
and notarization; local ad-hoc builds do not establish distribution readiness.

References: [Flutter macOS sandbox configuration](https://docs.flutter.dev/platform-integration/macos/building),
[Apple universal binaries](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary),
[secure storage options](https://pub.dev/packages/flutter_secure_storage).

Local verification on November 6, 2026: all six Python tests passed using the
host's Python 3.9.6 after normalizing ISO UTC `Z` suffixes for pre-3.11 Python.
`bash -n`, `plutil -lint` (both entitlements and the Xcode project), and
`git diff --check` passed. No Flutter SDK was installed, and fetching release
metadata failed, so Flutter analysis/tests, native builds, real Keychain access
and Windows regression execution remain unverified. The added CI workflow has
not been run in this workspace.
