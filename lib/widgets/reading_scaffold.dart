import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Applies reader typography to liturgical reading content.
class ReadingScaffold extends ConsumerWidget {
  final Widget Function(BuildContext context, TextStyle textStyle) builder;

  const ReadingScaffold({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final reader = ReaderTheme.of(context);
    final textStyle = reader.body(
      settings.fontSize,
      family: settings.resolvedFontFamily == null ? null : settings.fontFamily,
    );
    return builder(context, textStyle);
  }
}
