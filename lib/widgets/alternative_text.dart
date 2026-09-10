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
            compactTitle: widget.kind == 'gospel-antiphon'
                ? active.title
                : null,
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
    this.compactTitle,
    required this.onSelect,
  });

  final String label;
  final List<LiturgicalAlternative> options;
  final int activeIndex;
  final String? compactTitle;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    final base = ReaderTheme.of(context).body(16);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('alternative-picker-trigger'),
        onPressed: () async {
          final selected = await showModalBottomSheet<int>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (sheetContext) => _AlternativeSheet(
              label: label,
              options: options,
              activeIndex: activeIndex,
            ),
          );
          if (selected != null) onSelect(selected);
        },
        icon: const PhosphorIcon(PhosphorIconsRegular.listChecks, size: 19),
        label: Text(
          compactTitle ?? 'Варыянт ${activeIndex + 1} з ${options.length}',
        ),
        style: TextButton.styleFrom(
          foregroundColor: reader.rubric,
          minimumSize: const Size(48, 48),
          textStyle: base.copyWith(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AlternativeSheet extends StatelessWidget {
  const _AlternativeSheet({
    required this.label,
    required this.options,
    required this.activeIndex,
  });

  final String label;
  final List<LiturgicalAlternative> options;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(label, style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                children: [
                  for (var index = 0; index < options.length; index++)
                    ListTile(
                      key: ValueKey('alternative-option-$index'),
                      minTileHeight: 56,
                      selected: index == activeIndex,
                      title: Text(options[index].title),
                      subtitle: Text(
                        'Варыянт ${index + 1} з ${options.length}',
                      ),
                      trailing: index == activeIndex
                          ? PhosphorIcon(
                              PhosphorIconsBold.check,
                              color: cs.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, index),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
