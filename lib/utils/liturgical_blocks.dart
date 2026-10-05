import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/utils/liturgical_html.dart';

enum PsalmMetadataRole { service, muted, subtitle }

class PsalmMetadataLine {
  const PsalmMetadataLine(this.html, this.role);
  final String html;
  final PsalmMetadataRole role;
}

class LiturgicalPsalmModel {
  const LiturgicalPsalmModel({
    this.openingAntiphon,
    required this.metadata,
    required this.bodyHtml,
    this.repeatedAntiphon,
    this.leadingHtml = '',
    this.trailingHtml = '',
  });

  final String? openingAntiphon;
  final List<PsalmMetadataLine> metadata;
  final String bodyHtml;
  final String? repeatedAntiphon;
  final String leadingHtml;
  final String trailingHtml;
}

/// Converts both external and structured psalm sources to the same roles.
/// Source paragraph margins are removed at each semantic boundary.
List<LiturgicalPsalmModel> parseLiturgicalPsalms(
  String source, {
  String? openingAntiphon,
  String? repeatedAntiphon,
  String? sourceAntiphon,
}) {
  final formatted = formatPsalmHtml(
    stripEmbeddedAntiphon(
      source,
      externalAntiphon: sourceAntiphon ?? repeatedAntiphon,
    ),
  );
  final root = parseFragment(formatted);
  if (!ownsStructuredPsalmPackage(source)) {
    return [_parsePsalm(root, openingAntiphon, repeatedAntiphon)];
  }

  final segments = root.querySelectorAll('.ora-ant, .ora-psalm');
  final result = <LiturgicalPsalmModel>[];
  String? pendingAntiphon;
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment.classes.contains('ora-ant')) {
      pendingAntiphon = segment.innerHtml;
      continue;
    }
    String? closing;
    if (i + 1 < segments.length &&
        segments[i + 1].classes.contains('ora-ant')) {
      closing = segments[++i].innerHtml;
    }
    result.add(
      _parsePsalm(parseFragment(segment.innerHtml), pendingAntiphon, closing),
    );
    pendingAntiphon = null;
  }
  if (result.isEmpty) {
    return [_parsePsalm(root, openingAntiphon, repeatedAntiphon)];
  }
  // Preserve supplementary source nodes around a structured package. They
  // are not psalm roles, so they render as ordinary document content.
  final direct = root.nodes.whereType<dom.Element>().toList();
  final indices = <int>[
    for (var i = 0; i < direct.length; i++)
      if (direct[i].classes.contains('ora-ant') ||
          direct[i].classes.contains('ora-psalm'))
        i,
  ];
  if (indices.isNotEmpty) {
    String extras(Iterable<dom.Element> elements) => elements
        .where(
          (element) =>
              !element.classes.contains('ora-ant') &&
              !element.classes.contains('ora-psalm') &&
              element.querySelector('.ora-ant, .ora-psalm') == null,
        )
        .map((element) => element.outerHtml)
        .join();
    final leading = extras(direct.take(indices.first));
    final trailing = extras(direct.skip(indices.last + 1));
    final between = extras(
      direct.skip(indices.first + 1).take(indices.last - indices.first - 1),
    );
    final first = result.first;
    result[0] = LiturgicalPsalmModel(
      openingAntiphon: first.openingAntiphon,
      metadata: first.metadata,
      bodyHtml: first.bodyHtml,
      repeatedAntiphon: first.repeatedAntiphon,
      leadingHtml: normalizeSemanticBody(leading),
      trailingHtml: normalizeSemanticBody(between),
    );
    final lastIndex = result.length - 1;
    final last = result[lastIndex];
    result[lastIndex] = LiturgicalPsalmModel(
      openingAntiphon: last.openingAntiphon,
      metadata: last.metadata,
      bodyHtml: last.bodyHtml,
      repeatedAntiphon: last.repeatedAntiphon,
      leadingHtml: last.leadingHtml,
      trailingHtml: '${last.trailingHtml}${normalizeSemanticBody(trailing)}',
    );
  }
  return result;
}

LiturgicalPsalmModel _parsePsalm(
  dom.DocumentFragment root,
  String? opening,
  String? repeated,
) {
  final metadata = <PsalmMetadataLine>[];
  for (final node in root.nodes.whereType<dom.Element>().toList()) {
    if (!node.classes.contains('psalm-metadata') &&
        !node.classes.contains('ora-sub')) {
      break;
    }
    final role =
        node.classes.contains('psalm-subtitle') ||
            node.classes.contains('ora-sub')
        ? PsalmMetadataRole.subtitle
        : node.querySelector('.liturgical-rubric-inline') != null ||
              node.text.trim().toLowerCase().startsWith('псальм')
        ? PsalmMetadataRole.service
        : PsalmMetadataRole.muted;
    metadata.add(PsalmMetadataLine(node.innerHtml, role));
    node.remove();
  }
  return LiturgicalPsalmModel(
    openingAntiphon: opening,
    metadata: metadata,
    bodyHtml: normalizeSemanticBody(root.outerHtml),
    repeatedAntiphon: repeated,
  );
}

/// Keeps stanza margins inside the body while removing source-owned edges.
String normalizeSemanticBody(String html) {
  final root = parseFragment(html);
  for (final element in root.querySelectorAll('*')) {
    final style = element.attributes['style'];
    if (style == null) continue;
    final cleaned = style
        .replaceAll(
          RegExp(r'(^|;)\s*margin(?:-[a-z]+)?\s*:[^;]*', caseSensitive: false),
          '',
        )
        .trim();
    if (cleaned.isEmpty) {
      element.attributes.remove('style');
    } else {
      element.attributes['style'] = cleaned;
    }
  }
  final elements = root.nodes.whereType<dom.Element>().toList();
  if (elements.isNotEmpty) {
    elements.first.classes.add('semantic-first');
    elements.last.classes.add('semantic-last');
  }
  return root.outerHtml;
}
