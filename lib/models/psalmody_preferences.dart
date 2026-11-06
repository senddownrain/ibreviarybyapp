/// Presentation only; semantic choir identity belongs to the source strophe.
enum PsalmodyMode {
  leftBreak,
  leftBreakIndent,
  alternatingStanzas;

  String get label => switch (this) {
    leftBreak => 'Злева з пераносамі',
    leftBreakIndent => 'Злева з пераносамі і водступамі',
    alternatingStanzas => 'Чаргаванне строфаў',
  };
}

/// Valid new values win. Partially stored legacy preferences keep their old
/// defaults; no legacy keys means a new installation (leftBreak).
PsalmodyMode resolvePsalmodyMode({
  Object? storedMode,
  Object? legacyLayout,
  Object? legacyBreakMode,
}) {
  for (final mode in PsalmodyMode.values) {
    if (storedMode == mode.name) return mode;
  }
  if (legacyLayout == null && legacyBreakMode == null) {
    return PsalmodyMode.leftBreak;
  }
  if (legacyLayout != 'alignedLeft') return PsalmodyMode.alternatingStanzas;
  return legacyBreakMode == 'breakAfterMarker'
      ? PsalmodyMode.leftBreakIndent
      : PsalmodyMode.leftBreak;
}
