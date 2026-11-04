import 'dart:io';
import '../lib/data/crm_database.dart';
import '../lib/data/database_key_store.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || !File(arguments.single).existsSync()) {
    stderr.writeln(
      'Usage: dart run tool/secure_database.dart <existing-database-path>',
    );
    exitCode = 64;
    return;
  }
  final path = arguments.single;
  final database = CrmDatabase(path);
  final schema = File.fromUri(
    Platform.script.resolve('../assets/schema_v1.sql'),
  ).readAsStringSync();
  final snapshot = await database.initialize(schema);
  if (hasPlaintextSqliteHeader(File(path)))
    throw StateError('Database is not encrypted.');
  stdout.writeln(
    'Encryption verified. Preserved ${snapshot['organizations']!.length} organizations, ${snapshot['contacts']!.length} contacts and ${snapshot['interactions']!.length} interactions.',
  );
}
