/// Dependency-free American Soundex; numeric and short tokens stay literal.
class SoundexHelper {
  static List<String> tokens(String text) => RegExp(
    r'[a-z0-9]+',
  ).allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();

  static String encodeWord(String word) {
    final letters = word.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
    if (letters.isEmpty) return '';
    String digit(String c) {
      for (final entry in const {
        'BFPV': '1',
        'CGJKQSXZ': '2',
        'DT': '3',
        'L': '4',
        'MN': '5',
        'R': '6',
      }.entries) {
        if (entry.key.contains(c)) return entry.value;
      }
      return '';
    }

    var result = letters[0];
    var previous = digit(letters[0]);
    for (var i = 1; i < letters.length && result.length < 4; i++) {
      final letter = letters[i];
      if (letter == 'H' || letter == 'W') continue;
      final code = digit(letter);
      if (code.isNotEmpty && code != previous) result += code;
      previous = code;
    }
    return result.padRight(4, '0');
  }

  static String tokenCode(String token) =>
      token.length > 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(token)
      ? encodeWord(token)
      : '';

  static String encodePhrase(String text) => tokens(
    text,
  ).map(tokenCode).where((code) => code.isNotEmpty).toSet().join(' ');

  static bool matchesQuery(
    String query, {
    required String rawTargetText,
    String? precomputedSoundex,
  }) {
    final normalized = query.trim().toLowerCase();
    final target = rawTargetText.toLowerCase();
    if (target.contains(normalized)) return true;
    final words = tokens(normalized);
    if (words.isEmpty) return false;
    final targetWords = tokens(target);
    final codes = (precomputedSoundex ?? encodePhrase(target))
        .split(' ')
        .toSet();
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (targetWords.any((t) => t.contains(word))) continue;
      final code = tokenCode(word);
      if (code.isNotEmpty && codes.contains(code)) continue;
      // Ignore padding for the word still being typed: "smy" suggests "Smith".
      if (i == words.length - 1 &&
          code.isNotEmpty &&
          codes.any(
            (candidate) => candidate.startsWith(code.replaceAll('0', '')),
          ))
        continue;
      return false;
    }
    return true;
  }
}
