import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

/// Builder-pattern style provider.
/// Usage: ReadingScaffold(builder: (context, textStyle) => Scaffold(...))
class ReadingScaffold extends ConsumerWidget {
  final Widget Function(BuildContext context, TextStyle textStyle) builder;

  const ReadingScaffold({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final textStyle = TextStyle(fontSize: settings.fontSize, height: 1.6);
    return builder(context, textStyle);
  }
}
