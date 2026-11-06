import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:win32/win32.dart';

bool hasPlaintextSqliteHeader(File file) {
  if (!file.existsSync() || file.lengthSync() == 0) return false;
  final handle = file.openSync();
  try {
    return latin1.decode(handle.readSync(16)) == 'SQLite format 3\x00';
  } finally {
    handle.closeSync();
  }
}

/// Database keys are protected by Windows DPAPI or macOS Keychain.
/// The key is never stored as plaintext beside the database.
class DatabaseKeyStore {
  static String loadOrCreate(String databasePath) {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Encrypted CRM storage currently requires Windows DPAPI.',
      );
    }
    final database = File(databasePath);
    database.parent.createSync(recursive: true);
    final keyFile = File('$databasePath.key.dpapi');
    final lock = File('$databasePath.key.lock').openSync(mode: FileMode.append);
    lock.lockSync(FileLock.blockingExclusive);
    try {
      if (keyFile.existsSync()) {
        final key = _protect(keyFile.readAsBytesSync(), decrypt: true);
        if (key.length != 32)
          throw StateError('The stored database key is invalid.');
        return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      }
      if (File('$databasePath.pre-encryption.enc').existsSync()) {
        throw StateError(
          'The recovery database key is missing. Restore the original key file before continuing.',
        );
      }
      if (database.existsSync() &&
          database.lengthSync() > 0 &&
          !hasPlaintextSqliteHeader(database)) {
        throw StateError(
          'The encrypted database key is missing. Restore the original key file; the database has not been changed.',
        );
      }
      final random = Random.secure();
      final key = Uint8List.fromList(
        List.generate(32, (_) => random.nextInt(256)),
      );
      final protected = _protect(key);
      // Persist and verify the protected key before encrypting any database data.
      final pending = File('$databasePath.key.dpapi.pending');
      pending.writeAsBytesSync(protected, flush: true);
      final verified = _protect(pending.readAsBytesSync(), decrypt: true);
      if (base64Encode(key) != base64Encode(verified))
        throw StateError('Could not verify database key storage.');
      pending.renameSync(keyFile.path);
      return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } finally {
      lock.unlockSync();
      lock.closeSync();
    }
  }

  /// Stores the macOS database key in the user's Keychain.
  static Future<String> loadOrCreateMacOS(String databasePath) async {
    final database = File(databasePath);
    database.parent.createSync(recursive: true);
    final lock = File('$databasePath.key.lock').openSync(mode: FileMode.append);
    lock.lockSync(FileLock.blockingExclusive);
    try {
      final itemKey =
          'crm_database_key_v1_${base64Url.encode(utf8.encode(database.absolute.path)).replaceAll('=', '')}';
      const storage = FlutterSecureStorage(
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );
      final storedKey = await storage.read(key: itemKey);
      if (storedKey != null) {
        if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(storedKey)) {
          throw StateError('The stored database key is invalid.');
        }
        return storedKey;
      }
      if (File('$databasePath.pre-encryption.enc').existsSync()) {
        throw StateError(
          'The recovery database key is missing. Restore the original key before continuing.',
        );
      }
      if (database.existsSync() &&
          database.lengthSync() > 0 &&
          !hasPlaintextSqliteHeader(database)) {
        throw StateError(
          'The encrypted database key is missing. Restore the original key; the database has not been changed.',
        );
      }

      final random = Random.secure();
      final key = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await storage.write(key: itemKey, value: key);
      if (await storage.read(key: itemKey) != key) {
        throw StateError('Could not verify database key storage in Keychain.');
      }
      return key;
    } finally {
      lock.unlockSync();
      lock.closeSync();
    }
  }

  static Uint8List _protect(Uint8List bytes, {bool decrypt = false}) {
    final input = calloc<CRYPT_INTEGER_BLOB>();
    final output = calloc<CRYPT_INTEGER_BLOB>();
    final buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    input.ref
      ..cbData = bytes.length
      ..pbData = buffer;
    try {
      final result = decrypt
          ? CryptUnprotectData(
              input,
              null,
              null,
              null,
              0x1 /* CRYPTPROTECT_UI_FORBIDDEN */,
              output,
            )
          : CryptProtectData(
              input,
              null,
              null,
              null,
              0x1 /* CRYPTPROTECT_UI_FORBIDDEN */,
              output,
            );
      if (!result.value)
        throw StateError(
          'Windows could not ${decrypt ? 'unlock' : 'protect'} the database key. Use the original Windows account.',
        );
      return Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
    } finally {
      buffer.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      calloc.free(buffer);
      if (output.ref.pbData != nullptr) {
        output.ref.pbData
            .asTypedList(output.ref.cbData)
            .fillRange(0, output.ref.cbData, 0);
        LocalFree(HLOCAL(output.ref.pbData));
      }
      calloc.free(input);
      calloc.free(output);
    }
  }
}
