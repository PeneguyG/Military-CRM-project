import 'dart:io';
import '../lib/data/crm_database.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/load_soundex_samples.dart <database-path>',
    );
    exitCode = 64;
    return;
  }
  final database = CrmDatabase(arguments.single);
  final schema = File.fromUri(
    Platform.script.resolve('../assets/schema_v1.sql'),
  ).readAsStringSync();
  final before = await database.initialize(schema);
  final after = await database.loadSoundexSamples();
  stdout.writeln(
    'Added ${after['organizations']!.length - before['organizations']!.length} organizations and ${after['contacts']!.length - before['contacts']!.length} contacts.',
  );
}
