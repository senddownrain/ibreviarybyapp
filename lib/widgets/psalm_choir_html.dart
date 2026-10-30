import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';

/// One transient selection for every psalm and canticle in an open Office.
class PsalmodyScope extends InheritedNotifier<ValueNotifier<int?>> {
  const PsalmodyScope({
    super.key,
    required ValueNotifier<int?> controller,
    required this.verseLayout,
    required this.markerBreakMode,
    required super.child,
  }) : super(notifier: controller);

  final PsalmVerseLayout verseLayout;
  final PsalmMarkerBreakMode markerBreakMode;

  static PsalmodyScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PsalmodyScope>();

  @override
  bool updateShouldNotify(PsalmodyScope oldWidget) =>
      verseLayout != oldWidget.verseLayout ||
      markerBreakMode != oldWidget.markerBreakMode ||
      super.updateShouldNotify(oldWidget);
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

  const PsalmChoirHtml({
    super.key,
    required this.html,
    required this.style,
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
    final scope = PsalmodyScope.maybeOf(context);
    final selected = scope == null ? _selectedChoir : scope.notifier!.value;
    final aligned = scope?.verseLayout == PsalmVerseLayout.alignedLeft;
    final breakAfter =
        scope?.markerBreakMode == PsalmMarkerBreakMode.breakAfterMarker;
    // The alternating inset already identifies the choirs, so the selection
    // state only needs a restrained contrast change.
    final dimmedText = widget.textColor.withValues(alpha: 0.60);
    // The strophes below are links, and links are not merged into the hour's
    // text node for screen readers; the body is spoken as one plain label.
    return Semantics(
      label: psalmPlainText(widget.html),
      excludeSemantics: true,
      child: Html(
        key: ValueKey((selected, aligned, breakAfter)),
        data: preparePsalmChoirHtml(
          widget.html,
          selectedChoir: selected,
          breakAfterMarker: breakAfter,
        ),
        onLinkTap: (url, attributes, element) {
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
          if (aligned) ...{
            '.psalm-strophe-even': Style(
              margin: Margins.only(
                left: 0,
                bottom:
                    widget.style['.psalm-strophe']?.margin?.bottom?.value ?? 8,
              ),
            ),
            '.psalm-strophe-even.semantic-last': Style(margin: Margins.zero),
          },
          '.psalm-line': Style(display: Display.block, margin: Margins.zero),
          '.psalm-continuation': Style(
            // With alternating strophes, every line uses its paragraph's inset,
            // including lines that wrap to fit the screen.
            padding: !aligned && breakAfter
                ? HtmlPaddings.zero
                : HtmlPaddings.only(
                    left:
                        MediaQuery.textScalerOf(context).scale(
                          widget.style['p']?.fontSize?.value ??
                              widget.style['body']?.fontSize?.value ??
                              16,
                        ) *
                        .8,
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
