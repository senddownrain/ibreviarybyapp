import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';

/// Shared geometry for selectors; their owners keep separate business states.
abstract final class LiturgicalSelectorTokens {
  static const inset = 16.0;
  static const titleSize = 21.0;
  static const radius = 12.0;
}

class LiturgicalSelectorSheet extends StatelessWidget {
  const LiturgicalSelectorSheet({
    super.key,
    required this.children,
    required this.scrollKey,
    this.title = 'Іншыя варыянты',
    this.doneKey,
    this.doneLabel = 'Гатова',
  });

  final List<Widget> children;
  final Key scrollKey;
  final Key? doneKey;
  final String title;
  final String doneLabel;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: LiturgicalSelectorTokens.titleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыць',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: scrollKey,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: doneKey,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(doneLabel),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class LiturgicalSelectorHeading extends StatelessWidget {
  const LiturgicalSelectorHeading(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// RadioGroup is supplied by the caller. Colour never encodes selection.
class LiturgicalCelebrationChoice extends StatelessWidget {
  const LiturgicalCelebrationChoice({
    super.key,
    required this.value,
    required this.title,
    required this.selected,
    required this.colors,
    this.subtitle,
  });
  final String value;
  final String title;
  final String? subtitle;
  final bool selected;
  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.surfaceContainerHigh
          : Colors.transparent,
      borderRadius: BorderRadius.circular(LiturgicalSelectorTokens.radius),
      child: RadioListTile<String>(
        value: value,
        selected: selected,
        selectedTileColor: Colors.transparent,
        contentPadding: const EdgeInsets.only(right: 16),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null || subtitle!.isEmpty
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        secondary: VestmentMarker(colors: colors.toSet().toList(), size: 16),
      ),
    );
  }
}
