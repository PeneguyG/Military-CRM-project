import 'dart:convert';

/// Versioned envelope keeps legacy plain-text records readable without migration.
class RichTextContent {
  static List<Map<String, dynamic>>? operations(String value) {
    try {
      final data = jsonDecode(value);
      if (data is! Map || data['crmRichText'] != 1 || data['ops'] is! List)
        return null;
      final ops = (data['ops'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (ops.isEmpty ||
          ops.any((op) => op['insert'] is! String) ||
          !(ops.last['insert'] as String).endsWith('\n'))
        return null;
      return ops;
    } catch (_) {
      return null;
    }
  }

  static String plainText(String value) =>
      operations(
        value,
      )?.map((op) => op['insert'] as String).join().trimRight() ??
      value;

  static String encode(List<Map<String, dynamic>> ops) =>
      jsonEncode({'crmRichText': 1, 'ops': ops});
}
