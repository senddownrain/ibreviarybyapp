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
    this.anchors = const {},
    this.bundledAsset,
    this.strongMarksResponses = false,
    this.source,
    this.classify = const {},
    this.speakerLabels = const {},
    this.roleLabels = const {},
    this.roleMarkers = const {},
    this.roleCues = const {},
    this.callRole,
  });

  final String language;
  final String label;
  final String shortLabel;
  final String prayerId;
  final String title;

  /// Blocks that become the visible heading of a section. For a major
  /// section the canonical Belarusian title comes first and the heading of a
  /// not yet migrated text second.
  final Map<String, List<String>> markers;

  /// Blocks that carry a section location without changing their visible type.
  final Map<String, List<String>> anchors;
  final String? bundledAsset;

  /// English convention: a whole bold line is the people's part.
  final bool strongMarksResponses;
  final String? source;

  /// Block type (`heading`, `rubric`, `comment`, `posture`, `alternative`)
  /// to the markers of the blocks that have it.
  final Map<String, List<String>> classify;

  /// Speaker prefix in the text (`С.`, `Н.:`, `V.`) to its role.
  final Map<String, String> speakerLabels;

  /// Role to the compact label shown in a dialogue (`С.`/`Н.`, `V.`/`R.`).
  final Map<String, String> roleLabels;

  /// Role to the texts said by it without a prefix or a cue (Gloria, Credo).
  final Map<String, List<String>> roleMarkers;

  /// Role to the rubric phrases that announce it («народ адказвае»).
  final Map<String, List<String>> roleCues;

  /// Role of the call in a call-and-response paragraph without a prefix.
  final String? callRole;
}

/// How speaker roles are presented (shared ritual metadata).
class MassRolePolicy {
  const MassRolePolicy({
    this.showSpeakerLabels = false,
    this.labelPolicy,
    this.responseRoles = const ['people', 'all'],
  });

  final bool showSpeakerLabels;

  /// `dialogue`: a label only in a real call-and-response exchange.
  final String? labelPolicy;

  /// Roles whose lines are responses.
  final List<String> responseRoles;
}

/// A semantic section found in a rendered variant.
class LocatedMassSection {
  const LocatedMassSection({
    required this.blockIndex,
    required this.sectionId,
    required this.title,
    this.parent,
    this.heading = true,
  });

  final int blockIndex;
  final String sectionId;
  final String title;
  final String? parent;
  final bool heading;

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
    this.roles = const [],
    this.rolePolicy = const MassRolePolicy(),
  });

  final int schemaVersion;
  final String id;
  final String primaryPrayerId;
  final String defaultLanguage;
  final List<MassSectionDef> sections;
  final List<MassVariant> variants;
  final List<String> roles;
  final MassRolePolicy rolePolicy;

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

  /// Finds section headings among block texts. Sections are searched in
  /// ritual order, each after the previous one found, so a repeated line
  /// marks only the section that follows.
  List<LocatedMassSection> locateSections(
    MassVariant variant,
    List<String> blockTexts,
  ) {
    final texts = [for (final text in blockTexts) normalizeMassMarker(text)];
    final located = <LocatedMassSection>[];
    var last = -1;
    for (final def in sections) {
      final markers = variant.markers[def.id] ?? const <String>[];
      final anchors = variant.anchors[def.id] ?? const <String>[];
      if (markers.isEmpty && anchors.isEmpty) continue;
      for (var i = last + 1; i < texts.length; i++) {
        final heading = markers.any(
          (m) => _markerMatchesNormalized(m, texts[i]),
        );
        final anchored = anchors.any(
          (m) => _markerMatchesNormalized(m, texts[i]),
        );
        if (!heading && !anchored) {
          continue;
        }
        last = i;
        located.add(
          LocatedMassSection(
            blockIndex: i,
            sectionId: def.id,
            title: blockTexts[i].replaceAll(RegExp(r'\s+'), ' ').trim(),
            parent: def.parent,
            heading: heading,
          ),
        );
        break;
      }
    }
    return located;
  }

  /// Target after a language switch: same section, the nearest preceding
  /// sibling, its parent, the closest preceding section in ritual order, then
  /// the next one.
  String? resolveSectionTarget(String? requested, Iterable<String> available) {
    final ids = available.map(canonicalSectionId).whereType<String>().toSet();
    final sectionId = canonicalSectionId(requested);
    if (sectionId == null || ids.isEmpty) return null;
    if (ids.contains(sectionId)) return sectionId;
    final order = sections.indexWhere((s) => s.id == sectionId);
    if (order < 0) return null;
    final parent = sections[order].parent;
    if (parent != null) {
      for (var i = order - 1; i >= 0 && sections[i].parent == parent; i--) {
        if (ids.contains(sections[i].id)) return sections[i].id;
      }
      if (ids.contains(parent)) return parent;
    }
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
    .replaceAll(RegExp(r'''[*_#:.,;!?«»"()\[\]—–…-]+'''), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// A marker matches the whole normalized text; a marker ending with `…`
/// matches every text that starts with it.
bool massMarkerMatches(String marker, String text) =>
    _markerMatchesNormalized(marker, normalizeMassMarker(text));

bool _markerMatchesNormalized(String marker, String normalizedText) {
  final raw = marker.trim();
  final key = normalizeMassMarker(raw);
  if (key.isEmpty) return false;
  if (normalizedText == key) return true;
  return raw.endsWith('…') && normalizedText.startsWith('$key ');
}

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
