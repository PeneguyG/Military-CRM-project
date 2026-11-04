import 'soundex_helper.dart';

/// Used after the base CREATE TABLE schema, for new and existing databases.
const soundexMigrations = <String>[
  "ALTER TABLE organizations ADD COLUMN soundex_index TEXT NOT NULL DEFAULT ''",
  "ALTER TABLE contacts ADD COLUMN name_soundex TEXT NOT NULL DEFAULT ''",
  "ALTER TABLE contacts ADD COLUMN soundex_index TEXT NOT NULL DEFAULT ''",
  "ALTER TABLE contact_notes ADD COLUMN soundex_index TEXT NOT NULL DEFAULT ''",
  "ALTER TABLE organization_notes ADD COLUMN soundex_index TEXT NOT NULL DEFAULT ''",
];

class PhoneticSearchWhereClause {
  const PhoneticSearchWhereClause(this.where, this.whereArgs);
  final String where;
  final List<String> whereArgs;
}

/// Pass where/whereArgs to db.query, or to sqlite3's select.
PhoneticSearchWhereClause buildPhoneticSearchWhereClause(
  String userQuery,
  List<String> textColumns,
) {
  if (textColumns.isEmpty ||
      textColumns.any(
        (c) => !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(c),
      )) {
    throw ArgumentError('Supply nonempty, unqualified SQL column identifiers');
  }
  final query = userQuery.trim().toLowerCase();
  if (query.isEmpty) return const PhoneticSearchWhereClause('1 = 1', []);
  final args = <String>[];
  String literal(String value) =>
      value.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_');
  String raw(String term) {
    args.add('%${literal(term)}%');
    final target = textColumns
        .map((c) => "COALESCE(LOWER($c), '')")
        .join(" || ' ' || ");
    return "($target) LIKE ? ESCAPE '!'";
  }

  final exact = raw(query);
  final clauses = <String>[];
  final tokens = SoundexHelper.tokens(query);
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    final text = raw(token);
    final code = SoundexHelper.tokenCode(token);
    if (code.isEmpty) {
      clauses.add(text);
    } else {
      final prefix = code.replaceAll('0', '');
      args.add(i == tokens.length - 1 ? '% $prefix%' : '% $code %');
      clauses.add(
        "($text OR (' ' || COALESCE(soundex_index, '') || ' ') LIKE ?)",
      );
    }
  }
  return PhoneticSearchWhereClause(
    clauses.isEmpty ? exact : '($exact OR (${clauses.join(' AND ')}))',
    args,
  );
}
