# Military CRM preview

A single-user Flutter Material 3 preview with Contacts and Organizations tabs.
Requires Flutter 3.35+ and Dart 3.4+ (or the Dart version bundled with Flutter).

## Run

From this directory:

```powershell
flutter pub get
flutter run -d windows
```

The Windows runner is included. For Android or iOS, generate the desired runner
with `flutter create --platforms=android,ios .` on a suitable development host.
Local photos use `dart:io`, so this preview targets native platforms, not web.
Enter a readable local image file path in the contact form. Missing or unreadable
images show a fallback avatar. Phone actions require an installed application
that handles `tel:` or `sms:` links; failures show a message.

On Windows, enable Developer Mode in Windows Settings to allow Flutter's plugin
symlinks. The Windows CMake configuration uses short intermediate paths with
CMake 4.2+ to prevent MSBuild tracking-file failures in deeply nested checkouts.
With older CMake versions, use a shorter checkout path if MSBuild reports missing
`.tlog` directories or path-length errors.

## Features

- Desktop list/detail split view and mobile pushed detail routes.
- Search, contact status filters, and active/archived record filters.
- Complete organization and contact forms, including optional family and photo fields.
- Linked contacts, status badges, talking points, notes, and interaction history.
- Call/text launcher with an optional manual log prompt after a successful launch.
- Manual interactions with summary and optional follow-up date.
- Archive/restore preserves all fields, relationships, and historical interactions.
- Local-time automatic light theme from 06:00 until 18:00; dark otherwise.
  The sun/moon button overrides it; the clock button restores automatic mode.

## Storage and integration

The sample data is fictional. `CrmStore` is intentionally in memory, as requested
for the integration preview: changes reset when the application restarts. This
is not a persistent or encrypted database implementation.

`lib/models/crm_models.dart` contains immutable models with SQLite-compatible
snake_case maps, integer booleans, string enums, and ISO-8601 dates. `copyWith`
can explicitly clear nullable fields. Use these maps with a SQLite repository;
remove the null `id` key before an auto-increment insert if required by your adapter.
Only publish store changes after durable writes succeed when adding persistence.
Never use DELETE or cascading deletes for organizations or contacts: update
`is_archived` only. Archiving an organization does not archive its contacts.
Interaction organization IDs capture the association at the time of logging.

Pages accept a shared `CrmStore`; OrganizationsPage also accepts
`onSelectContact(Contact)` for navigation into the contact dossier.
The additional shared form and browser files are required by both pages.

## Verify

```powershell
flutter analyze
flutter test
```

Tests cover model round trips, nullable clearing, preservation through archive /
restore, mobile editing and logging, desktop search/detail, and navigation from
an archived organization to its archived contact.
