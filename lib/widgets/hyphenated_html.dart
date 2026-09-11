import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/utils/text_hyphenation.dart';

/// Renders HTML after calculating real line endings for the available width.
class HyphenatedHtml extends StatelessWidget {
  const HyphenatedHtml({
    super.key,
    required this.data,
    required this.style,
    required this.textStyle,
    this.onLinkTap,
  });

  final String data;
  final Map<String, Style> style;
  final TextStyle textStyle;
  final OnTap? onLinkTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Html(
      data: wrapReaderHtml(
        data,
        style: textStyle,
        maxWidth: constraints.maxWidth,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      ),
      style: style,
      onLinkTap: onLinkTap,
    ),
  );
}
