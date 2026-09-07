import 'package:flutter/material.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

typedef AlternativeContentBuilder =
    Widget Function(BuildContext context, String html);

/// Flutter counterpart of web `AlternativeText.vue`.
class AlternativeText extends StatefulWidget {
  const AlternativeText({
    super.key,
    required this.text,
    required this.contentBuilder,
    this.label = 'Выбар варыянта',
    this.kind = 'generic',
    this.controller,
    this.showPicker = true,
  });

  final String text;
  final String label;
  final String kind;
  final ValueNotifier<int>? controller;
  final bool showPicker;
  final AlternativeContentBuilder contentBuilder;

  @override
  State<AlternativeText> createState() => _AlternativeTextState();
}

class _AlternativeTextState extends State<AlternativeText> {
  late List<LiturgicalAlternative> _options;
  int _internalIndex = 0;

  int get _activeIndex {
    final requested = widget.controller?.value ?? _internalIndex;
    if (_options.isEmpty) return 0;
    return requested.clamp(0, _options.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _parse();
    widget.controller?.addListener(_handleExternalSelection);
  }

  @override
  void didUpdateWidget(covariant AlternativeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleExternalSelection);
      widget.controller?.addListener(_handleExternalSelection);
    }
    if (oldWidget.text != widget.text || oldWidget.kind != widget.kind) {
      _internalIndex = 0;
      _parse();
      if (widget.controller != null && widget.controller!.value != 0) {
        widget.controller!.value = 0;
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleExternalSelection);
    super.dispose();
  }

  void _parse() {
    _options = getLiturgicalAlternatives(widget.text, kind: widget.kind);
  }

  void _handleExternalSelection() {
    if (mounted) setState(() {});
  }

  void _select(int index) {
    if (widget.controller case final controller?) {
      if (controller.value != index) controller.value = index;
    } else {
      setState(() => _internalIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty) return const SizedBox.shrink();
    final active = _options[_activeIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPicker && _options.length > 1) ...[
          _AlternativePicker(
            label: widget.label,
            options: _options,
            activeIndex: _activeIndex,
            onSelect: _select,
          ),
          const SizedBox(height: 18),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey('${widget.kind}-$_activeIndex-${active.title}'),
            child: widget.contentBuilder(context, active.html),
          ),
        ),
      ],
    );
  }
}

class _AlternativePicker extends StatelessWidget {
  const _AlternativePicker({
    required this.label,
    required this.options,
    required this.activeIndex,
    required this.onSelect,
  });

  final String label;
  final List<LiturgicalAlternative> options;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reader = ReaderTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: reader.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 9),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
                height: 1.3,
              ),
            ),
          ),
          for (var index = 0; index < options.length; index++) ...[
            _AlternativeOption(
              index: index,
              title: options[index].title,
              selected: index == activeIndex,
              onTap: () => onSelect(index),
            ),
            if (index != options.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _AlternativeOption extends StatelessWidget {
  const _AlternativeOption({
    required this.index,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reader = ReaderTheme.of(context);
    return Material(
      color: selected
          ? cs.primary.withValues(alpha: 0.10)
          : cs.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? cs.primary.withValues(alpha: 0.28) : reader.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? cs.primary : cs.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: selected
                      ? PhosphorIcon(
                          PhosphorIconsBold.check,
                          size: 17,
                          color: cs.primary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
