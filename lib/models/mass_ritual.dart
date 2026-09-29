/// Holy Mass as one ritual with language variants.
///
/// Variants are ordinary prayer documents (or a bundled fallback text); the
/// semantic section taxonomy connects them independently of visible titles.
library;

part 'mass_ritual_data.dart';

class MassSectionDef {
  const MassSectionDef({required this.id, required this.title, this.parent});

  final String id;
  final String title;
  final String? parent;

  bool get isMajor => parent == null;
}

class MassVariant {
  const MassVariant({
    required this.language,
    required this.label,
    required this.shortLabel,
    required this.prayerId,
    required this.title,
    required this.markers,
    this.bundledAsset,
    this.strongMarksResponses = false,
    this.source,
  });

  final String language;
  final String label;
  final String shortLabel;
  final String prayerId;
  final String title;
  final Map<String, List<String>> markers;
  final String? bundledAsset;
  final bool strongMarksResponses;
  final String? source;
}

/// A semantic section found in a rendered variant.
class LocatedMassSection {
  const LocatedMassSection({
    required this.blockIndex,
    required this.sectionId,
    required this.title,
    this.parent,
  });

  final int blockIndex;
  final String sectionId;
  final String title;
  final String? parent;

  bool get isMajor => parent == null;
}

class MassRitual {
  const MassRitual({
    required this.schemaVersion,
    required this.id,
    required this.primaryPrayerId,
    required this.defaultLanguage,
    required this.sections,
    required this.variants,
    this.aliases = const {},
  });

  final int schemaVersion;
  final String id;
  final String primaryPrayerId;
  final String defaultLanguage;
  final List<MassSectionDef> sections;
  final List<MassVariant> variants;

  /// Former section ids (for example `liturgy-of-the-eucharist`) mapped to
  /// their current canonical id.
  final Map<String, String> aliases;

  /// The five canonical major sections, in ritual order.
  List<MassSectionDef> get majorSections => [
    for (final s in sections)
      if (s.isMajor) s,
  ];

  /// Current id for [id], resolving backward-compatible aliases.
  String? canonicalSectionId(String? id) =>
      id == null ? null : aliases[id] ?? id;

  /// The major section that [sectionId] belongs to (itself when major).
  MassSectionDef? majorSectionOf(String? sectionId) {
    final def = section(sectionId);
    if (def == null) return null;
    return def.isMajor ? def : section(def.parent);
  }

  /// 1-based position of the major section containing [sectionId].
  int? majorPositionOf(String? sectionId) {
    final major = majorSectionOf(sectionId);
    if (major == null) return null;
    return majorSections.indexWhere((s) => s.id == major.id) + 1;
  }

  MassVariant? variant(String? language) {
    for (final v in variants) {
      if (v.language == language) return v;
    }
    return null;
  }

  MassVariant? variantForPrayerId(String prayerId) {
    for (final v in variants) {
      if (v.prayerId == prayerId) return v;
    }
    return null;
  }

  MassSectionDef? section(String? id) {
    final canonical = canonicalSectionId(id);
    for (final s in sections) {
      if (s.id == canonical) return s;
    }
    return null;
  }

  String resolveLanguage(String? requested, String? stored) {
    if (variant(requested) != null) return requested!;
    if (variant(stored) != null) return stored!;
    return defaultLanguage;
  }

  /// Finds configured section markers among block texts in document order.
  List<LocatedMassSection> locateSections(
    MassVariant variant,
    List<String> blockTexts,
  ) {
    final index = <String, String>{};
    variant.markers.forEach((key, markers) {
      final sectionId = section(key)?.id;
      if (sectionId == null) return;
      for (final marker in markers) {
        index.putIfAbsent(normalizeMassMarker(marker), () => sectionId);
      }
    });
    final seen = <String>{};
    final located = <LocatedMassSection>[];
    for (var i = 0; i < blockTexts.length; i++) {
      final sectionId = index[normalizeMassMarker(blockTexts[i])];
      if (sectionId == null || !seen.add(sectionId)) continue;
      located.add(
        LocatedMassSection(
          blockIndex: i,
          sectionId: sectionId,
          title: blockTexts[i].replaceAll(RegExp(r'\s+'), ' ').trim(),
          parent: section(sectionId)!.parent,
        ),
      );
    }
    return located;
  }

  /// Target after a language switch: same section, its parent, the closest
  /// preceding section in ritual order, then the next one.
  String? resolveSectionTarget(String? requested, Iterable<String> available) {
    final ids = available.map(canonicalSectionId).whereType<String>().toSet();
    final sectionId = canonicalSectionId(requested);
    if (sectionId == null || ids.isEmpty) return null;
    if (ids.contains(sectionId)) return sectionId;
    final order = sections.indexWhere((s) => s.id == sectionId);
    if (order < 0) return null;
    final parent = sections[order].parent;
    if (parent != null && ids.contains(parent)) return parent;
    for (var i = order - 1; i >= 0; i--) {
      if (ids.contains(sections[i].id)) return sections[i].id;
    }
    for (var i = order + 1; i < sections.length; i++) {
      if (ids.contains(sections[i].id)) return sections[i].id;
    }
    return null;
  }
}

String normalizeMassMarker(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[’‘`]'), "'")
    .replaceAll(RegExp(r'''[*_#:.,;!?«»"()\[\]—–-]+'''), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The section whose heading is the last one at or above [readingLine].
String? activeMassSectionAt(
  List<({String sectionId, double top})> tops,
  double readingLine,
) {
  String? active;
  for (final entry in tops) {
    if (entry.top <= readingLine) {
      active = entry.sectionId;
    } else {
      break;
    }
  }
  return active ?? (tops.isEmpty ? null : tops.first.sectionId);
}
