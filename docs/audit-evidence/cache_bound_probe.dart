// Exact arithmetic used by HiveService._putCached and removeCached.
void main() {
  final bytes = int.parse('12345');
  print('bound=${1 << 53}; cached=${bytes.clamp(0, 1 << 53)}');
}
