import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'database_key_store.dart';

void configureCipher(Database db) {
  if (db.select('PRAGMA cipher').isEmpty) {
    throw StateError(
      'The bundled SQLite encryption engine is unavailable. Refusing to open unencrypted storage.',
    );
  }
  db.execute(
    "PRAGMA cipher='sqlcipher'; PRAGMA legacy=4; PRAGMA temp_store=MEMORY; PRAGMA busy_timeout=10000;",
  );
}

void applyDatabaseKey(Database db, String key, {bool rekey = false}) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key))
    throw StateError('Invalid database key.');
  try {
    db.execute("PRAGMA ${rekey ? 'rekey' : 'key'}='$key'");
    db.select('SELECT count(*) FROM sqlite_master');
  } catch (_) {
    // SQLite exceptions can contain the SQL statement, which includes the key.
    throw StateError(
      'Cannot unlock or encrypt the database. The database and recovery files have been preserved.',
    );
  }
}

void verifyDatabase(Database db) {
  final result = db.select('PRAGMA integrity_check');
  if (result.length != 1 || result.single.values.single != 'ok') {
    throw StateError(
      'Database integrity verification failed. No schema changes were applied.',
    );
  }
}

Future<void> encryptedBackup(Database source, String path, String key) async {
  final file = File(path);
  if (file.existsSync()) {
    final existing = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      configureCipher(existing);
      applyDatabaseKey(existing, key);
      verifyDatabase(existing);
    } finally {
      existing.close();
    }
    return;
  }
  final pending = File('$path.pending');
  if (pending.existsSync()) pending.deleteSync();
  final target = sqlite3.open(pending.path);
  try {
    configureCipher(target);
    applyDatabaseKey(target, key);
    // Page-level backups cannot change SQLite reserved-byte layouts between
    // plaintext and SQLCipher. Copy the complete logical schema under a read
    // transaction directly into an encrypted destination (no plaintext file).
    source.execute('BEGIN');
    target.execute('BEGIN');
    try {
      String quote(String name) => '"' + name.replaceAll('"', '""') + '"';
      final schema = source.select(
        "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY rowid",
      );
      final shadowTables = source
          .select('PRAGMA table_list')
          .where((row) => row['type'] == 'shadow')
          .map((row) => row['name'])
          .toSet();
      for (final table in schema.where(
        (row) => row['type'] == 'table' && !shadowTables.contains(row['name']),
      )) {
        target.execute(table['sql'] as String);
        final name = quote(table['name'] as String);
        final ordinaryColumns = source
            .select('PRAGMA table_xinfo($name)')
            .where((column) => column['hidden'] == 0)
            .map((column) => quote(column['name'] as String))
            .join(',');
        final isVirtual = (table['sql'] as String).toUpperCase().contains(
          'CREATE VIRTUAL TABLE',
        );
        final columns = isVirtual ? 'rowid, $ordinaryColumns' : ordinaryColumns;
        final rows = source.select('SELECT $columns FROM $name');
        if (rows.isNotEmpty) {
          final insert = target.prepare(
            'INSERT INTO $name ($columns) VALUES (${List.filled(rows.columnNames.length, '?').join(',')})',
          );
          try {
            for (final row in rows) {
              insert.execute(row.values.toList());
            }
          } finally {
            insert.close();
          }
        }
      }
      if (source
          .select("SELECT name FROM sqlite_master WHERE name='sqlite_sequence'")
          .isNotEmpty) {
        target.execute('DELETE FROM sqlite_sequence');
        for (final row in source.select(
          'SELECT name, seq FROM sqlite_sequence',
        )) {
          target.execute(
            'INSERT INTO sqlite_sequence(name, seq) VALUES (?, ?)',
            [row['name'], row['seq']],
          );
        }
      }
      for (final object in schema.where((row) => row['type'] != 'table')) {
        target.execute(object['sql'] as String);
      }
      target.userVersion = source.userVersion;
      target.execute('COMMIT');
      source.execute('COMMIT');
    } catch (_) {
      if (!target.autocommit) target.execute('ROLLBACK');
      if (!source.autocommit) source.execute('ROLLBACK');
      rethrow;
    }
    verifyDatabase(target);
  } finally {
    target.close();
  }
  final check = sqlite3.open(pending.path, mode: OpenMode.readOnly);
  try {
    configureCipher(check);
    applyDatabaseKey(check, key);
    verifyDatabase(check);
  } finally {
    check.close();
  }
  if (hasPlaintextSqliteHeader(pending))
    throw StateError('Recovery copy encryption verification failed.');
  pending.renameSync(path);
}

Future<Database> openEncryptedDatabase(String path, String key) async {
  final file = File(path);
  final plaintext = hasPlaintextSqliteHeader(file);
  final db = sqlite3.open(path);
  try {
    configureCipher(db);
    if (plaintext) {
      if (db.userVersion != 1)
        throw StateError('Unsupported database; encryption migration stopped.');
      verifyDatabase(db);
      await encryptedBackup(db, '$path.pre-encryption.enc', key);
      // Checkpoint and remove the plaintext WAL before the in-place rekey.
      final mode = db.select('PRAGMA journal_mode=DELETE').single.values.single;
      if (mode != 'delete')
        throw StateError(
          'Close other CRM/database applications before encryption.',
        );
      applyDatabaseKey(db, key, rekey: true);
      verifyDatabase(db);
      if (hasPlaintextSqliteHeader(file))
        throw StateError('Encryption verification failed.');
    } else {
      applyDatabaseKey(db, key);
    }
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}
