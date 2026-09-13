/// Resolves portable MyBrev prayer links to the native reader route.
String? prayerLinkLocation(String? href) {
  if (href == null) return null;
  if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(href)) return null;
  final uri = Uri.tryParse(href);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final match = RegExp(
    r'^/(?:prayer|prayers/prayer)/([^/]+)$',
  ).firstMatch(uri.path);
  if (match == null) return null;
  try {
    final id = Uri.decodeComponent(match.group(1)!);
    if (id.isEmpty || id == 'add' || id.contains('/')) return null;
    return '/prayers/prayer/${Uri.encodeComponent(id)}';
  } on FormatException {
    return null;
  }
}
