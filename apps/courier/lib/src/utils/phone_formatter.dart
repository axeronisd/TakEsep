/// Normalize a phone number to international format with leading `+`.
///
/// Handles common Kyrgyzstan phone formats:
/// - "996700123456"   → "+996700123456"
/// - "+996700123456"  → "+996700123456"
/// - "0700123456"     → "+996700123456"
/// - "700123456"      → "+996700123456"
/// - "996 700 123 456" / dashes / parentheses → cleaned and prefixed
///
/// Returns empty string if input has no digits.
String normalizePhoneForDial(String raw) {
  if (raw.isEmpty) return '';

  // Strip everything except digits and leading '+'
  final hasPlus = raw.trim().startsWith('+');
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  // Strip trailing ".0" artifact (when phone was stored as a number)
  digits = digits.replaceAll(RegExp(r'\.0$'), '');
  if (digits.isEmpty) return '';

  // Already international with '+'
  if (hasPlus) return '+$digits';

  // Starts with country code 996
  if (digits.startsWith('996')) return '+$digits';

  // Local Kyrgyz format: 0XXXXXXXXX (10 digits) → +996XXXXXXXXX
  if (digits.startsWith('0') && digits.length == 10) {
    return '+996${digits.substring(1)}';
  }

  // Bare local number 9 digits (700123456) → +996700123456
  if (digits.length == 9) return '+996$digits';

  // Fallback: prepend '+' to whatever digits we have
  return '+$digits';
}
