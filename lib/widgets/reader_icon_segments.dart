import 'package:flutter/material.dart';

/// Segments with a shared 48dp minimum tap height and accessible choice labels.
class ReaderIconSegments<T extends Object> extends StatelessWidget {
  const ReaderIconSegments({
    super.key,
    required this.value,
    required this.choices,
    required this.label,
    required this.onChanged,
    required this.content,
    this.segmentKey,
  });

  final T value;
  final List<T> choices;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Widget Function(BuildContext, T) content;
  final Key Function(T)? segmentKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(10);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              for (final choice in choices)
                Expanded(
                  child: Semantics(
                    key: segmentKey?.call(choice),
                    label: label(choice),
                    button: true,
                    selected: value == choice,
                    inMutuallyExclusiveGroup: true,
                    onTap: () => onChanged(choice),
                    child: Tooltip(
                      message: label(choice),
                      excludeFromSemantics: true,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: value == choice
                              ? cs.primary.withValues(alpha: .12)
                              : Colors.transparent,
                          border: choice == choices.first
                              ? null
                              : Border(
                                  left: BorderSide(color: cs.outlineVariant),
                                ),
                        ),
                        child: InkWell(
                          excludeFromSemantics: true,
                          onTap: () => onChanged(choice),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Center(
                              child: IconTheme.merge(
                                data: IconThemeData(
                                  color: value == choice
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                                child: Builder(
                                  builder: (context) =>
                                      content(context, choice),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
