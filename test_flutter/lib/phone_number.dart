import 'package:flutter/services.dart';

/// Returns the digits stored in a phone number, without punctuation.
String phoneDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Formats up to ten digits as a U.S. phone number while a user is typing.
///
/// The closing parenthesis appears once the area code is complete, and the
/// hyphen appears once the subscriber number begins.
String formatUsPhoneDigits(String digits) {
  final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
  if (limited.isEmpty) return '';
  if (limited.length < 3) return '($limited';
  if (limited.length == 3) return '($limited)';
  if (limited.length <= 6) {
    return '(${limited.substring(0, 3)})${limited.substring(3)}';
  }
  return '(${limited.substring(0, 3)})'
      '${limited.substring(3, 6)}-'
      '${limited.substring(6)}';
}

/// Applies the U.S. display mask to stored phone values when possible.
///
/// A leading country code of 1 is removed from eleven-digit U.S. values.
/// Unusual legacy values with extensions or other characters are preserved.
String formatPhoneForDisplay(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || !RegExp(r'^[\d\s()+.-]+$').hasMatch(trimmed)) {
    return trimmed;
  }

  var digits = phoneDigits(trimmed);
  if (digits.length == 11 && digits.startsWith('1')) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) return trimmed;
  return formatUsPhoneDigits(digits);
}

/// Normalizes an existing phone value for editing while retaining legacy
/// values that cannot safely be interpreted as a U.S. number.
String formatPhoneForEditing(String value) => formatPhoneForDisplay(value);

/// Adds punctuation as digits are entered and prevents more than ten digits.
class UsPhoneNumberFormatter extends TextInputFormatter {
  const UsPhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = phoneDigits(newValue.text);
    // Accept a pasted U.S. number with its optional country prefix.
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);

    var baseDigitOffset = _digitsBefore(
      newValue.text,
      newValue.selection.baseOffset,
    );
    var extentDigitOffset = _digitsBefore(
      newValue.text,
      newValue.selection.extentOffset,
    );

    // If backspace or delete removes only generated punctuation, remove the
    // adjacent digit too so the mask never makes deletion feel stuck.
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        digits == phoneDigits(oldValue.text) &&
        oldValue.text.length > newValue.text.length) {
      final oldCaret = oldValue.selection.extentOffset;
      final isBackspace = newValue.selection.extentOffset < oldCaret;
      final deletedOffset = isBackspace ? oldCaret - 1 : oldCaret;
      if (deletedOffset >= 0 && deletedOffset < oldValue.text.length) {
        final deletedCharacter = oldValue.text[deletedOffset];
        if (!RegExp(r'\d').hasMatch(deletedCharacter)) {
          final digitBefore = _digitsBefore(oldValue.text, deletedOffset);
          final digitToRemove = isBackspace
              ? (digitBefore - 1).clamp(0, digits.length)
              : digitBefore.clamp(0, digits.length);
          if (digitToRemove < digits.length) {
            digits = digits.replaceRange(digitToRemove, digitToRemove + 1, '');
            baseDigitOffset = digitToRemove;
            extentDigitOffset = digitToRemove;
          }
        }
      }
    }

    final formatted = formatUsPhoneDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _offsetAfterDigits(formatted, baseDigitOffset),
        extentOffset: _offsetAfterDigits(formatted, extentDigitOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }

  int _digitsBefore(String value, int offset) {
    final safeOffset = offset.clamp(0, value.length);
    return phoneDigits(value.substring(0, safeOffset)).length;
  }

  int _offsetAfterDigits(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;

    var seen = 0;
    for (var index = 0; index < formatted.length; index++) {
      if (RegExp(r'\d').hasMatch(formatted[index])) {
        seen++;
        if (seen == digitCount) {
          // Place the caret after any mask punctuation and before the next
          // digit, so typing continues in the expected position.
          var next = index + 1;
          while (next < formatted.length &&
              !RegExp(r'\d').hasMatch(formatted[next])) {
            next++;
          }
          return next;
        }
      }
    }
    return formatted.length;
  }
}
