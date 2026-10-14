import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/utils/prayer_html.dart';

/// Safe read-only equivalent of the web's Turndown path. Author emphasis is
/// retained; presentation CSS is not a rubric signal. Nothing is persisted.
String prayerLegacyHtmlToMarkdown(String source) {
  final fragment = parseFragment(sanitizePrayerHtml(source));
  String escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAllMapped(RegExp(r'[\*_\[\]<>`#]'), (m) => '\\${m[0]}')
      .replaceAllMapped(
        RegExp(r'(^|\n)( *)([-+])(?=\s)'),
        (m) => '${m[1]}${m[2]}\\${m[3]}',
      )
      .replaceAllMapped(
        RegExp(r'(^|\n)( *\d+)\.(?=\s)'),
        (m) => '${m[1]}${m[2]}\\.',
      );
  String render(dom.Node node, {bool pre = false}) {
    if (node is dom.Text) {
      return pre
          ? node.data
          : escape(node.data.replaceAll(RegExp(r'\s+'), ' '));
    }
    if (node is! dom.Element) {
      return node.nodes.map((n) => render(n, pre: pre)).join();
    }
    final tag = node.localName!;
    final content = node.nodes.map((n) => render(n, pre: pre)).join();
    String emphasis(String delimiter) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) return content;
      final left = RegExp(r'^\s*').firstMatch(content)![0]!;
      final right = RegExp(r'\s*$').firstMatch(content)![0]!;
      return '$left$delimiter$trimmed$delimiter$right';
    }

    if (tag == 'br') return '  \n';
    if (tag == 'hr') return '\n\n---\n\n';
    if (tag == 'strong' || tag == 'b') return emphasis('**');
    if (tag == 'em' || tag == 'i') return emphasis('_');
    if (tag == 'pre') {
      final text = node.text.replaceAll(RegExp(r'\r\n?'), '\n').trimRight();
      var fence = '```';
      while (text.contains(fence)) {
        fence += '`';
      }
      return '\n\n$fence\n$text\n$fence\n\n';
    }
    if (tag == 'code' && node.parent?.localName != 'pre') {
      final text = node.text.replaceAll('\n', ' ');
      var fence = '`';
      while (text.contains(fence)) {
        fence += '`';
      }
      final padding =
          text.startsWith('`') ||
              text.endsWith('`') ||
              (text.startsWith(' ') &&
                  text.endsWith(' ') &&
                  text.trim().isNotEmpty)
          ? ' '
          : '';
      return '$fence$padding$text$padding$fence';
    }
    if (tag == 'a') {
      final href = node.attributes['href'];
      if (href == null || href.isEmpty) return content;
      final destination = href.replaceAll('(', '\\(').replaceAll(')', '\\)');
      final title = node.attributes['title'];
      final suffix = title == null || title.isEmpty
          ? ''
          : ' "${title.replaceAll('"', '\\"')}"';
      return '[$content]($destination$suffix)';
    }
    if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
      return '\n\n${'#' * int.parse(tag[1])} ${content.trim()}\n\n';
    }
    if (tag == 'blockquote') {
      return '\n\n${content.trim().split('\n').map((line) => '> $line').join('\n')}\n\n';
    }
    if (tag == 'ul' || tag == 'ol') {
      var number = int.tryParse(node.attributes['start'] ?? '') ?? 1;
      final items = <String>[];
      for (final child in node.children.where((n) => n.localName == 'li')) {
        final body = child.nodes.map((n) => render(n)).join().trim();
        final marker = tag == 'ol' ? '${number++}. ' : '- ';
        final parts = body.split('\n');
        items.add(
          '$marker${parts.first}${parts.skip(1).map((line) => '\n${' ' * marker.length}$line').join()}',
        );
      }
      return '\n\n${items.join('\n')}\n\n';
    }
    bool inList() {
      for (var parent = node.parent; parent != null; parent = parent.parent) {
        if (parent.localName == 'li') return true;
      }
      return false;
    }

    if (tag == 'p' &&
        !inList() &&
        node.classes.any(
          (c) => {'rubric', 'mass-rubric-line'}.contains(c.toLowerCase()),
        )) {
      return content.trim().isEmpty
          ? ''
          : '\n\n:::rubric\n${content.trim()}\n:::\n\n';
    }
    if ({
      'p',
      'div',
      'section',
      'article',
      'header',
      'footer',
      'aside',
      'table',
      'tr',
      'dl',
      'dt',
      'dd',
      'center',
    }.contains(tag)) {
      return '\n\n${content.trim()}\n\n';
    }
    return content;
  }

  return render(fragment)
      .replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
