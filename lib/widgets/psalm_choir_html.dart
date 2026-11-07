import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';

/// One transient selection for every psalm and canticle in an open Office.
class PsalmodyScope extends InheritedNotifier<ValueNotifier<int?>> {
  const PsalmodyScope({
    super.key,
    required ValueNotifier<int?> controller,
    required this.mode,
    required super.child,
  }) : super(notifier: controller);

  final PsalmodyMode mode;

  static PsalmodyScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PsalmodyScope>();

  @override
  bool updateShouldNotify(PsalmodyScope oldWidget) =>
      mode != oldWidget.mode || super.updateShouldNotify(oldWidget);
}

/// Renders psalm strophes as two alternating choirs.
///
/// Tapping a strophe dims its choir throughout the current Office.
/// Tapping the selected choir again returns to the neutral state.
class PsalmChoirHtml extends StatefulWidget {
  final String html;
  final Map<String, Style> style;
  final Color textColor;
  final Color rubricColor;
  final bool interactive;

  const PsalmChoirHtml({
    super.key,
    required this.html,
    required this.style,
    required this.textColor,
    required this.rubricColor,
    this.interactive = true,
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
    final scope = PsalmodyScope.maybeOf(context);
    final selected = scope == null ? _selectedChoir : scope.notifier!.value;
    final mode = scope?.mode ?? PsalmodyMode.leftBreak;
    final fontSize = MediaQuery.textScalerOf(context).scale(
      widget.style['p']?.fontSize?.value ??
          widget.style['body']?.fontSize?.value ??
          16,
    );
    final stropheInset = math.min(
      fontSize,
      MediaQuery.sizeOf(context).width * .08,
    );
    // Choir selection is independent of the visual presentation.
    final dimmedText = widget.textColor.withValues(alpha: 0.60);
    // The strophes below are links, and links are not merged into the hour's
    // text node for screen readers; the body is spoken as one plain label.
    return Semantics(
      label: psalmPlainText(widget.html),
      excludeSemantics: true,
      child: Html(
        key: ValueKey((selected, mode)),
        data: preparePsalmChoirHtml(
          widget.html,
          selectedChoir: selected,
          interactive: widget.interactive,
          mode: mode,
        ),
        onLinkTap: (url, attributes, element) {
          if (!widget.interactive) return;
          final choir = switch (url) {
            'psalm-choir:1' => 1,
            'psalm-choir:2' => 2,
            _ => null,
          };
          if (choir == null) return;
          if (scope != null) {
            scope.notifier!.value = selected == choir ? null : choir;
            return;
          }
          setState(() {
            _selectedChoir = _selectedChoir == choir ? null : choir;
          });
        },
        style: {
          ...widget.style,
          'p': (widget.style['p'] ?? Style()).merge(
            Style(textAlign: TextAlign.left),
          ),
          '.psalm-strophe-even': Style(
            textAlign: TextAlign.left,
            margin: Margins.only(
              left: mode == PsalmodyMode.alternatingStanzas ? stropheInset : 0,
              bottom:
                  widget.style['.psalm-strophe']?.margin?.bottom?.value ?? 8,
            ),
          ),
          '.psalm-strophe-even.semantic-last': Style(
            margin: Margins.only(
              left: mode == PsalmodyMode.alternatingStanzas ? stropheInset : 0,
            ),
          ),
          '.psalm-line': Style(display: Display.block, margin: Margins.zero),
          '.psalm-continuation': Style(
            padding: HtmlPaddings.only(
              left: mode == PsalmodyMode.leftBreakIndent ? fontSize * .75 : 0,
            ),
          ),
          '.psalm-choir-strophe': Style(
            color: widget.textColor,
            textDecoration: TextDecoration.none,
          ),
          '.psalm-marker': Style(color: widget.rubricColor),
          '.liturgical-rubric-inline': Style(color: widget.rubricColor),
          '.psalm-choir-muted': Style(
            color: dimmedText,
            textDecoration: TextDecoration.none,
          ),
        },
      ),
    );
  }
}
