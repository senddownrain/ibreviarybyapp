import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/constants/legal_links.dart';

void main() {
  test('privacy policy points to the standalone HTTPS hosting route', () {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'ibreviaryby.web.app');
    expect(uri.path, '/privacy');
    expect(uri.query, isEmpty);
    expect(uri.fragment, isEmpty);
  });
}
