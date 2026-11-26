import 'dart:convert';

import 'package:crypto/crypto.dart';

typedef AccessSetsV2Code = ({String codeId, String canonical});

final accessSetId = RegExp(r'^[a-z][a-z0-9-]{0,63}$');
const _symbols = '[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]';
final _ascii = RegExp(r'^[A-Za-z0-9 \t\r\n-]+$');
final _trim = RegExp(r'^[ \t\r\n]+|[ \t\r\n]+$');
final _format = RegExp(
  '^([A-Z]{3,10})-([0-9]{8})-($_symbols{16})-'
  '($_symbols{24}|$_symbols{4}(?:-$_symbols{4}){5})\$',
);

/// Wire format from mybrev PR #320. Prefix and date carry no entitlement.
AccessSetsV2Code? parseAccessSetsV2Code(Object? input) {
  if (input is! String || !_ascii.hasMatch(input)) return null;
  final match = _format.firstMatch(input.replaceAll(_trim, '').toUpperCase());
  if (match == null) return null;
  final date = match[2]!;
  final year = int.parse(date.substring(0, 4));
  final month = int.parse(date.substring(4, 6));
  final day = int.parse(date.substring(6));
  final utc = DateTime.utc(year, month, day);
  if (year == 0 || utc.year != year || utc.month != month || utc.day != day) {
    return null;
  }
  final codeId = match[3]!;
  final secret = match[4]!.replaceAll('-', '');
  return (codeId: codeId, canonical: '${match[1]}-$date-$codeId-$secret');
}

String accessSetsV2CodeProof(String canonical) =>
    sha256.convert(utf8.encode('mybrev/access-code/v2\n$canonical')).toString();
