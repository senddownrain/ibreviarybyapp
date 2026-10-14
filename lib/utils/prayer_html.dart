import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// Validate after HTML entities are decoded. Disallow controls, protocol-relative
/// URLs, backslashes and unknown schemes in Markdown and legacy HTML alike.
bool isSafePrayerHref(String href) {
  if (RegExp(r'[\x00-\x20\x7f\\]').hasMatch(href)) return false;
  final uri = Uri.tryParse(href);
  if (uri == null) return false;
  if (!uri.hasScheme) return !uri.hasAuthority && !href.startsWith('//');
  return {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme.toLowerCase());
}

const _allowedTags = {
  'p',
  'div',
  'span',
  'aside',
  'blockquote',
  'br',
  'hr',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'strong',
  'b',
  'em',
  'i',
  'u',
  's',
  'del',
  'small',
  'sub',
  'sup',
  'pre',
  'code',
  'a',
  'ul',
  'ol',
  'li',
  'dl',
  'dt',
  'dd',
  'table',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'th',
  'td',
  'caption',
  'center',
  'font',
};
const _discardTags = {
  'script',
  'style',
  'iframe',
  'object',
  'embed',
  'svg',
  'math',
  'template',
  'form',
  'input',
  'button',
  'link',
  'meta',
  'base',
  'audio',
  'video',
  'source',
};
const _presentationProperties = {
  'color',
  'background-color',
  'font-weight',
  'font-style',
  'font-size',
  'font-family',
  'text-align',
  'text-decoration',
  'line-height',
  'margin',
  'margin-top',
  'margin-bottom',
  'margin-left',
  'margin-right',
  'padding',
  'padding-top',
  'padding-bottom',
  'padding-left',
  'padding-right',
};

String sanitizePrayerHtml(String source) {
  final fragment = parseFragment(source);
  void clean(dom.Node parent) {
    for (final node in parent.nodes.toList()) {
      if (node is dom.Comment) {
        node.remove();
      } else if (node is dom.Element) {
        final tag = node.localName;
        if (_discardTags.contains(tag)) {
          node.remove();
          continue;
        }
        if (tag == 'img') {
          node.replaceWith(dom.Text(node.attributes['alt'] ?? ''));
          continue;
        }
        clean(node);
        if (!_allowedTags.contains(tag)) {
          final children = node.nodes.toList();
          for (final child in children) {
            node.parentNode!.insertBefore(child, node);
          }
          node.remove();
          continue;
        }
        for (final name in node.attributes.keys.toList()) {
          final value = node.attributes[name]!;
          final allowed =
              name == 'class' ||
              name == 'title' ||
              name == 'data-role' ||
              (tag == 'a' && name == 'href' && isSafePrayerHref(value)) ||
              ({'ol', 'li'}.contains(tag) &&
                  {'start', 'value'}.contains(name) &&
                  int.tryParse(value) != null) ||
              ({'td', 'th'}.contains(tag) &&
                  {'colspan', 'rowspan'}.contains(name) &&
                  int.tryParse(value) != null) ||
              (tag == 'font' && {'color', 'face', 'size'}.contains(name)) ||
              name == 'align';
          if (name == 'style') {
            final declarations = <String>[];
            for (final declaration in value.split(';')) {
              final colon = declaration.indexOf(':');
              if (colon < 0) continue;
              final property = declaration
                  .substring(0, colon)
                  .trim()
                  .toLowerCase();
              final cssValue = declaration.substring(colon + 1).trim();
              if (_presentationProperties.contains(property) &&
                  RegExp(r'^[\w\s#.,%()\-]+$').hasMatch(cssValue) &&
                  !RegExp(
                    r'url|expression|var\s*\(',
                    caseSensitive: false,
                  ).hasMatch(cssValue)) {
                declarations.add('$property:$cssValue');
              }
            }
            if (declarations.isEmpty) {
              node.attributes.remove(name);
            } else {
              node.attributes[name] = declarations.join(';');
            }
          } else if (!allowed) {
            node.attributes.remove(name);
          }
        }
      }
    }
  }

  clean(fragment);
  return fragment.outerHtml;
}
