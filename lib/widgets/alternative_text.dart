import 'package:flutter/material.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
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
            kind: widget.kind,
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
    required this.kind,
    required this.options,
    required this.activeIndex,
    required this.onSelect,
  });

  final String label;
  final String kind;
  final List<LiturgicalAlternative> options;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    final active = options[activeIndex];
    final kindLabel = _kindLabel(kind);
    final compactLabel = '$kindLabel · ${activeIndex + 1} з ${options.length}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: label,
        value: '$compactLabel. ${active.title}',
        child: TextButton(
          key: const Key('alternative-picker-trigger'),
          onPressed: () async {
            final selected = await showReaderChoiceSheet<int>(
              context: context,
              title: label,
              selectedValue: activeIndex,
              choices: [
                for (var index = 0; index < options.length; index++)
                  ReaderChoice(
                    value: index,
                    key: ValueKey('alternative-option-$index'),
                    label: options[index].title,
                    subtitle: 'Варыянт ${index + 1} з ${options.length}',
                  ),
              ],
            );
            if (selected != null) onSelect(selected);
          },
          style: TextButton.styleFrom(
            foregroundColor: reader.rubric,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(compactLabel)),
                const SizedBox(width: 5),
                const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _kindLabel(String kind) => switch (kind) {
    'hymn' => 'Гімн',
    'gospel-antiphon' || 'marian-antiphon' => 'Антыфона',
    'reading' => 'Чытанне',
    'prayer' => 'Малітва',
    'intercession' => 'Просьбы',
    'psalm' => 'Псальм',
    _ => 'Варыянт',
  };
}
