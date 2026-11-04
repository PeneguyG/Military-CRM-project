# Encrypted Windows storage and software updates

Production `CrmDatabase(path)` connections require encryption. The Windows build
bundles SQLite3 Multiple Ciphers, configured with its SQLCipher AES-256 profile.
The app refuses to continue if the encryption engine or protected key is missing.
`CrmDatabase.unencryptedForTesting` is reserved for disposable test fixtures.

## Persistent location

The normal Windows database remains at:

`%APPDATA%\com.example\Steel Wings CRM\MilitaryCRM\military_crm.sqlite3`

This path is deliberately independent of the executable, build number, and
future display-name changes. Replacing the installation directory does not touch
this folder. `CRM_DATABASE_PATH` still explicitly selects a different database;
changing it does not move or merge records.

The adjacent `.key.dpapi` file holds a randomly generated 256-bit key protected
with Windows DPAPI for the current account. Updates reuse it; never regenerate,
delete or ship this file as part of a release. Preserve the full data folder and
the Windows user profile. A database copy alone cannot be decrypted on a new
account or computer; portable password-protected export is not implemented.

## Migration and recovery

On the first encrypted open, the app verifies the existing database, copies its
complete schema and records directly into an encrypted `.pre-encryption.enc`
recovery file, verifies that copy, checkpoints the plaintext WAL and encrypts the
original database in place. The key is flushed and verified before migration.
No extra plaintext backup is created. Old plaintext files/backups elsewhere are
not modified; file encryption cannot erase historical disk or cloud copies.

Before an additive schema upgrade, an encrypted `.pre-vN.enc` recovery copy is
created. `crmSchemaVersion` is the migration target and must increase with new
migrations. Initialization never drops or recreates an existing CRM database.
Future schema versions fail closed instead of downgrading or resetting data.
Recovery copies are migration snapshots, not ongoing backups.

To restore a recovery copy, close all CRM processes, preserve the complete data
folder, and restore the chosen encrypted snapshot as the main database together
with its original `.key.dpapi` file. Restore the database as a coherent SQLite
file set; stale WAL/SHM files from a different database must not be paired with
it. Recovery requires the original Windows account/DPAPI credentials.

The old Python SQLite helper and ordinary SQLite viewers cannot read encrypted
production files. The Dart sample loader now uses the protected connection.
`dart run tool/secure_database.dart <existing-path>` performs migration without
adding sample records and never prints the key.

Key protection currently targets Windows. Other platforms fail explicitly
rather than silently saving plaintext until their secure key stores are added.

## Verification

Encryption tests exercise new databases, existing-data migration, unreadability
without a key, wrong-key rejection, encrypted recovery-copy reopening, record
persistence after a replacement app instance, stable protected keys, and missing
key failure without replacing the database.

Implementation references:
- https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html
- https://utelle.github.io/SQLite3MultipleCiphers/docs/configuration/config_sql_pragmas/
- https://learn.microsoft.com/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata
