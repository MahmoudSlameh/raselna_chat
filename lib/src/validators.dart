import 'models.dart';
import 'strings.dart';

/// Arabic-Indic (٠-٩) and Persian (۰-۹) digits become ASCII; the rest stays.
String normalizeDigits(String text) {
  final b = StringBuffer();
  for (final r in text.runes) {
    if (r >= 0x660 && r <= 0x669) {
      b.writeCharCode(r - 0x660 + 0x30);
    } else if (r >= 0x6F0 && r <= 0x6F9) {
      b.writeCharCode(r - 0x6F0 + 0x30);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

final _phone = RegExp(r'^\+?[0-9][0-9 \-]{5,18}[0-9]$');
final _number = RegExp(r'^-?[0-9]+([.,][0-9]+)?$');
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// A quick check before sending, so the customer sees a hint at once. The
/// server validates again and its message wins.
String? validateAnswer(InputKind kind, String raw, RaselnaStrings s) {
  final text = normalizeDigits(raw.trim());
  if (text.isEmpty) return s.invalidEmpty;
  switch (kind) {
    case InputKind.phone:
      final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (!_phone.hasMatch(text) || digits.length < 7 || digits.length > 15) {
        return s.invalidPhone;
      }
    case InputKind.number:
      if (!_number.hasMatch(text)) return s.invalidNumber;
    case InputKind.email:
      if (!_email.hasMatch(text) || text.length > 254) return s.invalidEmail;
    case InputKind.text:
    case InputKind.date:
    case InputKind.secret:
      break;
  }
  return null;
}

/// What is actually sent for an answer of [kind].
String answerText(InputKind kind, String raw) {
  final text = raw.trim();
  return switch (kind) {
    InputKind.phone || InputKind.number => normalizeDigits(text),
    _ => text,
  };
}
