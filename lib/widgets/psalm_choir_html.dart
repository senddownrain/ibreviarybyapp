import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/widgets/hyphenated_html.dart';

/// Renders psalm strophes as two alternating choirs.
///
/// Tapping a strophe keeps its choir at full contrast and dims the other one.
/// Tapping the selected choir again returns the psalm to its neutral state.
class PsalmChoirHtml extends StatefulWidget {
  final String html;
  final Map<String, Style> style;
  final TextStyle textStyle;
  final Color textColor;
  final Color rubricColor;

  const PsalmChoirHtml({
    super.key,
    required this.html,
    required this.style,
    required this.textStyle,
    required this.textColor,
    required this.rubricColor,
  });

  @override
  State<PsalmChoirHtml> createState() => _PsalmChoirHtmlState();
}

class _PsalmChoirHtmlState extends State<PsalmChoirHtml> {
  int? _selectedChoir;

  @override
  void didUpdateWidget(PsalmChoirHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _selectedChoir = null;
  }

  @override
  Widget build(BuildContext context) {
    // The alternating inset already identifies the choirs, so the selection
    // state only needs a restrained contrast change.
    final dimmedText = widget.textColor.withValues(alpha: 0.60);
    final dimmedRubric = widget.rubricColor.withValues(alpha: 0.60);

    return HyphenatedHtml(
      key: ValueKey(_selectedChoir),
      data: preparePsalmChoirHtml(widget.html, selectedChoir: _selectedChoir),
      textStyle: widget.textStyle,
      onLinkTap: (url, attributes, element) {
        final choir = switch (url) {
          'psalm-choir:1' => 1,
          'psalm-choir:2' => 2,
          _ => null,
        };
        if (choir == null) return;
        setState(() {
          _selectedChoir = _selectedChoir == choir ? null : choir;
        });
      },
      style: {
        ...widget.style,
        '.psalm-choir-strophe': Style(
          color: widget.textColor,
          textDecoration: TextDecoration.none,
        ),
        '.psalm-choir-muted': Style(
          color: dimmedText,
          textDecoration: TextDecoration.none,
        ),
        '.psalm-choir-muted .psalm-marker': Style(color: dimmedRubric),
        '.psalm-choir-muted .liturgical-rubric-inline': Style(
          color: dimmedRubric,
        ),
      },
    );
  }
}
