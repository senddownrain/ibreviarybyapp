import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

void main() {
  test('reader defaults to justified prose without overwriting a saved choice', () {
    expect(const SettingsState().textAlignment, TextAlign.justify);
    expect(normalizeTextAlignment(null), TextAlign.justify);
    expect(normalizeTextAlignment('unknown'), TextAlign.justify);
    expect(normalizeTextAlignment('justify'), TextAlign.justify);
    expect(normalizeTextAlignment('left'), TextAlign.left);
    expect(normalizeTextAlignment('start'), TextAlign.left);
    expect(
      const SettingsState().copyWith(textAlignment: TextAlign.left).textAlignment,
      TextAlign.left,
    );
  });
}
