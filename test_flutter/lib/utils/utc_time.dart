/// SQLite CURRENT_TIMESTAMP values have no suffix but are UTC by contract.
DateTime parseUtcTimestamp(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  final hasZone = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(normalized);
  return DateTime.parse(hasZone ? normalized : '${normalized}Z').toUtc();
}

/// A date alone is a calendar day, not an instant. Only timed follow-ups convert.
String? followUpUtc(String? date, String? time) {
  if (date == null || time == null || time.isEmpty) return null;
  final day = DateTime.parse(date);
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
  if (match == null)
    throw FormatException('Follow-up time must use HH:mm', time);
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59)
    throw FormatException('Invalid follow-up time', time);
  return DateTime(
    day.year,
    day.month,
    day.day,
    hour,
    minute,
  ).toUtc().toIso8601String();
}
