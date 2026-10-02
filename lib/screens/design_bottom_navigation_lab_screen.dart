import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

/// Isolated, mock-only comparison. No production reader imports this bar.
enum LabScenario { mass, bible, hours, compendium }

enum LabVariant { oneRow, selectorFirst, adaptive }

extension on LabScenario {
  String get label => switch (this) {
    LabScenario.mass => 'Імша',
    LabScenario.bible => 'Біблія',
    LabScenario.hours => 'Гадзіны',
    LabScenario.compendium => 'Кампендый',
  };
}

extension on LabVariant {
  String get label => switch (this) {
    LabVariant.oneRow => 'A · Стрэлкі',
    LabVariant.selectorFirst => 'B · Выбар',
    LabVariant.adaptive => 'C · Адаптыўны',
  };
}

class _ScenarioData {
  const _ScenarioData({
    required this.title,
    required this.eyebrow,
    required this.labels,
    required this.initialIndex,
    required this.stressLabel,
  });

  final String title;
  final String eyebrow;
  final List<String> labels;
  final int initialIndex;
  final String stressLabel;
}

const _scenarios = <LabScenario, _ScenarioData>{
  LabScenario.mass: _ScenarioData(
    title: 'Парадак святой Імшы',
    eyebrow: 'МАЛІТОЎНІК · СВЯТАЯ ІМША',
    labels: [
      'Уступныя абрады',
      'Літургія слова',
      'Эўхарыстычная літургія',
      'Абрад Камуніі',
      'Абрад заканчэння',
    ],
    initialIndex: 1,
    stressLabel: 'Эўхарыстычная літургія і абрад прыняцця святой Камуніі',
  ),
  LabScenario.bible: _ScenarioData(
    title: 'Евангелле паводле Яна',
    eyebrow: 'БІБЛІЯ',
    labels: [
      'Евангелле паводле Яна 2',
      'Евангелле паводле Яна 3',
      'Евангелле паводле Яна 4',
    ],
    initialIndex: 1,
    stressLabel: 'Евангелле паводле Яна, раздзел трэці',
  ),
  LabScenario.hours: _ScenarioData(
    title: 'Літургія гадзінаў',
    eyebrow: 'ЛІТУРГІЯ · СЁННЯ',
    // The composite “Агульная гадзіна” is deliberately excluded.
    labels: [
      'Заклік',
      'Гадзіна чытанняў',
      'Ютрань',
      'Малітва перад поўднем',
      'Малітва апоўдні',
      'Малітва пасля поўдня',
      'Нешпары',
      'Камплета',
    ],
    initialIndex: 2,
    stressLabel: 'Малітва пасля поўдня ў літургіі гадзінаў',
  ),
  LabScenario.compendium: _ScenarioData(
    title: 'Кампендый Катэхізіса',
    eyebrow: 'МАЛІТОЎНІК · КАМПЕНДЫЙ',
    labels: ['Пытанне 42', 'Пытанне 43', 'Пытанне 44'],
    initialIndex: 1,
    stressLabel: 'Пытанне 43 · Што азначае вера ў адзінага Бога?',
  ),
};

class BottomNavigationLabScreen extends StatefulWidget {
  const BottomNavigationLabScreen({super.key});

  @override
  State<BottomNavigationLabScreen> createState() =>
      _BottomNavigationLabScreenState();
}

class _BottomNavigationLabScreenState extends State<BottomNavigationLabScreen> {
  static const _barGap = 14.0;
  static const _contentGap = 24.0;

  LabScenario _scenario = LabScenario.mass;
  LabVariant _variant = LabVariant.oneRow;
  int _index = _scenarios[LabScenario.mass]!.initialIndex;
  double _previewWidth = 390;
  double _textScale = 1;
  bool _longLabel = false;
  final ValueNotifier<double> _barHeight = ValueNotifier<double>(56);

  _ScenarioData get _data => _scenarios[_scenario]!;
  String get _currentLabel =>
      _longLabel ? _data.stressLabel : _data.labels[_index];

  @override
  void dispose() {
    _barHeight.dispose();
    super.dispose();
  }

  void _selectScenario(LabScenario scenario) => setState(() {
    _scenario = scenario;
    _index = _scenarios[scenario]!.initialIndex;
  });

  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _data.labels.length) return;
    setState(() => _index = next);
  }

  Future<void> _openOutline() async {
    final colors = IbColors.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.min(
              MediaQuery.sizeOf(sheetContext).height * .75,
              650,
            ),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Text(
                  'Змест · ${_scenario.label}',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              if (_variant == LabVariant.selectorFirst)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        key: const Key('lab-outline-previous'),
                        onPressed: _index == 0
                            ? null
                            : () => Navigator.pop(sheetContext, _index - 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Назад'),
                      ),
                      TextButton.icon(
                        key: const Key('lab-outline-next'),
                        onPressed: _index == _data.labels.length - 1
                            ? null
                            : () => Navigator.pop(sheetContext, _index + 1),
                        icon: const Icon(Icons.chevron_right),
                        iconAlignment: IconAlignment.end,
                        label: const Text('Далей'),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < _data.labels.length; i++)
                ListTile(
                  key: Key('lab-outline-item-$i'),
                  selected: i == _index,
                  title: Text(_data.labels[i]),
                  leading: Text('${i + 1}'),
                  trailing: i == _index ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _index = selected);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) {
          void update(VoidCallback action) {
            setState(action);
            updateSheet(() {});
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Параметры lab',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text('Шырыня preview'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final width in const [320.0, 360.0, 390.0, 700.0])
                        ChoiceChip(
                          key: Key('lab-width-${width.toInt()}'),
                          label: Text('${width.toInt()} px'),
                          selected: _previewWidth == width,
                          onSelected: (_) =>
                              update(() => _previewWidth = width),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('System text'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final scale in const [1.0, 1.5, 2.0])
                        ChoiceChip(
                          key: Key('lab-scale-${(scale * 100).toInt()}'),
                          label: Text('${(scale * 100).toInt()}%'),
                          selected: _textScale == scale,
                          onSelected: (_) => update(() => _textScale = scale),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    key: const Key('lab-long-label'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Доўгая беларуская назва'),
                    value: _longLabel,
                    onChanged: (value) => update(() => _longLabel = value),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('lab-settings-done'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Гатова'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = IbColors.of(context);
    return Scaffold(
      key: const Key('bottom-navigation-lab'),
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('Bottom navigation lab'),
        leading: IconButton(
          tooltip: 'Выйсці з lab',
          onPressed: () => context.go('/hours'),
          icon: const Icon(Icons.close),
        ),
        actions: [
          IconButton(
            key: const Key('lab-settings'),
            tooltip: 'Шырыня і маштаб тэксту',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          ColoredBox(
            color: colors.surfaceRaised,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                children: [
                  _choiceRow<LabScenario>(
                    values: LabScenario.values,
                    selected: _scenario,
                    label: (value) => value.label,
                    keyFor: (value) => Key('lab-scenario-${value.name}'),
                    onSelected: _selectScenario,
                  ),
                  _choiceRow<LabVariant>(
                    values: LabVariant.values,
                    selected: _variant,
                    label: (value) => value.label,
                    keyFor: (value) => Key('lab-variant-${value.name}'),
                    onSelected: (variant) => setState(() => _variant = variant),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(_previewWidth, constraints.maxWidth);
                final media = MediaQuery.of(context);
                return Center(
                  child: SizedBox(
                    key: const Key('lab-preview-frame'),
                    width: width,
                    height: constraints.maxHeight,
                    child: MediaQuery(
                      data: media.copyWith(
                        textScaler: TextScaler.linear(_textScale),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildPreview(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceRow<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required Key Function(T) keyFor,
    required ValueChanged<T> onSelected,
  }) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                key: keyFor(value),
                label: Text(label(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildPreview() => ReaderScaffold(
    semanticLabel: 'Prototype reader: ${_data.title}',
    showAmbient: false,
    enableDoubleTapFullscreen: false,
    chromeMode: ReaderChromeMode.compact,
    onBack: () => context.go('/hours'),
    onSwipePrevious: _variant == LabVariant.selectorFirst && _index > 0
        ? () => _step(-1)
        : null,
    onSwipeNext:
        _variant == LabVariant.selectorFirst && _index < _data.labels.length - 1
        ? () => _step(1)
        : null,
    contextHeader: ReaderContextHeader(
      eyebrow: _data.eyebrow,
      title: _data.title,
      metadata: 'Prototype · ${_variant.label}',
    ),
    content: _MockDocument(
      label: _currentLabel,
      barHeight: _barHeight,
      barGap: _barGap,
      contentGap: _contentGap,
    ),
    overlay: _LabBottomBar(
      variant: _variant,
      label: _currentLabel,
      position: _index + 1,
      total: _data.labels.length,
      hasPrevious: _index > 0,
      hasNext: _index < _data.labels.length - 1,
      onPrevious: () => _step(-1),
      onNext: () => _step(1),
      onOpenOutline: _openOutline,
      onHeight: (height) {
        if (mounted && (_barHeight.value - height).abs() > .5) {
          _barHeight.value = height;
        }
      },
      gap: _barGap,
    ),
  );
}

class _MockDocument extends StatelessWidget {
  const _MockDocument({
    required this.label,
    required this.barHeight,
    required this.barGap,
    required this.contentGap,
  });

  final String label;
  final ValueListenable<double> barHeight;
  final double barGap;
  final double contentGap;

  @override
  Widget build(BuildContext context) {
    final colors = IbColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        for (var i = 0; i < 9; i++) ...[
          Text(
            'Гэта ўзор доўгага тэксту для праверкі чытання. '
            'Пракруціце старонку, каб пераканацца: ніжняя панэль '
            'не закрывае апошні абзац.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.ink, height: 1.65),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Апошні абзац застаецца цалкам бачным над панэллю.',
          key: const Key('lab-last-paragraph'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.ink),
        ),
        ValueListenableBuilder<double>(
          valueListenable: barHeight,
          builder: (context, height, _) => SizedBox(
            key: const Key('lab-content-reserve'),
            height: floatingOverlayContentReserve(
              overlayHeight: height,
              overlayBottom: floatingOverlayBottom(context, gap: barGap),
              readerBottomPadding:
                  ReaderContentSurface.bottomSpacing +
                  MediaQuery.paddingOf(context).bottom,
              contentGap: contentGap,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabBottomBar extends StatelessWidget {
  const _LabBottomBar({
    required this.variant,
    required this.label,
    required this.position,
    required this.total,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenOutline,
    required this.onHeight,
    required this.gap,
  });

  final LabVariant variant;
  final String label;
  final int position;
  final int total;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenOutline;
  final ValueChanged<double> onHeight;
  final double gap;

  @override
  Widget build(BuildContext context) => FloatingOverlayPositioned(
    gap: gap,
    left: 12,
    right: 12,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _LabHeightReporter(
          onHeight: onHeight,
          child: AdaptiveChromeSurface(
            key: const Key('lab-reader-bar'),
            role: ChromeSurfaceRole.navigation,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final style = Theme.of(context).textTheme.labelLarge;
                final painter =
                    TextPainter(
                      text: TextSpan(text: label, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout(
                      maxWidth: math.max(1, constraints.maxWidth - 2 * 56 - 42),
                    );
                final stacked =
                    constraints.maxWidth < 330 || painter.didExceedMaxLines;
                painter.dispose();

                if (variant == LabVariant.selectorFirst) {
                  return _selector(context, showPosition: true);
                }
                if (variant == LabVariant.adaptive && stacked) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _selector(context, showPosition: false),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _arrow(false),
                          Text('$position / $total'),
                          _arrow(true),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _arrow(false),
                    Expanded(child: _selector(context, showPosition: false)),
                    _arrow(true),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _arrow(bool next) => SizedBox(
    width: 56,
    height: 56,
    child: IconButton(
      key: Key(next ? 'lab-next' : 'lab-previous'),
      tooltip: next ? 'Наступны раздзел' : 'Папярэдні раздзел',
      onPressed: next
          ? (hasNext ? onNext : null)
          : (hasPrevious ? onPrevious : null),
      icon: PhosphorIcon(
        next ? PhosphorIconsBold.caretRight : PhosphorIconsBold.caretLeft,
        size: 22,
      ),
    ),
  );

  Widget _selector(BuildContext context, {required bool showPosition}) {
    final colors = IbColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const Key('lab-current-selector'),
        borderRadius: BorderRadius.circular(24),
        onTap: onOpenOutline,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        key: const Key('lab-current-label'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showPosition)
                        Text(
                          '$position з $total',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.inkMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabHeightReporter extends SingleChildRenderObjectWidget {
  const _LabHeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLabHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLabHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderLabHeightReporter extends RenderProxyBox {
  _RenderLabHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
