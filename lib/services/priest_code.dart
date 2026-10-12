import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Web contract v3: mybrev/src/utils/priestCode.mjs (7122bb2).
/// Validate ASCII before uppercasing; Unicode lookalikes never normalize.
String? normalizePriestCode(String value) {
  if (!RegExp(r'^[A-Za-z2-9\- \t\r\n]*$').hasMatch(value)) return null;
  final code = value
      .replaceAll(RegExp(r'^[ \t\r\n]+|[ \t\r\n]+$'), '')
      .toUpperCase();
  if (!RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ2-9-]+$').hasMatch(code) ||
      code.startsWith('-') ||
      code.endsWith('-') ||
      code.contains('--')) {
    return null;
  }
  final normalized = code.replaceAll('-', '');
  return normalized.length >= 24 && normalized.length <= 64 ? normalized : null;
}

String? priestCodeProof(String value) {
  final normalized = normalizePriestCode(value);
  return normalized == null
      ? null
      : sha256.convert(utf8.encode(normalized)).toString();
}
