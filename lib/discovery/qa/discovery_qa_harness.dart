import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/qa/qa_scenarios.dart';

/// Debug/test-only surface for the discovery engine. It is reachable only
/// from `discovery_qa_main.dart` and widget tests; nothing in the app imports
/// it, so a release build never contains it (see 03-state-contract.md).
class QaHintPresenter extends ChangeNotifier implements HintPresenter {
  HintDefinition? shown;

  @override
  Future<bool> present(HintDefinition hint) {
    shown = hint;
    notifyListeners();
    final mounted = Completer<bool>();
    // Count as shown only after the card has really been laid out.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => mounted.complete(shown == hint),
    );
    return mounted.future;
  }

  @override
  void dismiss() {
    if (shown == null) return;
    shown = null;
    notifyListeners();
  }
}

class DiscoveryQaApp extends StatefulWidget {
  const DiscoveryQaApp({super.key, required this.storage, this.clock});

  /// Isolated storage; never the app's own Hive data.
  final DiscoveryStorage storage;
  final FakeDiscoveryClock? clock;

  @override
  State<DiscoveryQaApp> createState() => _DiscoveryQaAppState();
}

class _DiscoveryQaAppState extends State<DiscoveryQaApp> {
  late final FakeDiscoveryClock _clock =
      widget.clock ?? FakeDiscoveryClock(DateTime.now());
  QaHintPresenter _presenter = QaHintPresenter();
  int _generation = 0;

  void _restart() => setState(() {
    _generation++;
    _presenter = QaHintPresenter();
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Discovery QA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: ProviderScope(
        key: ValueKey(_generation),
        overrides: [
          discoveryStorageProvider.overrideWithValue(widget.storage),
          discoveryClockProvider.overrideWithValue(_clock),
          hintPresenterProvider.overrideWithValue(_presenter),
        ],
        child: DiscoveryQaScreen(
          clock: _clock,
          presenter: _presenter,
          generation: _generation,
          onRestart: _restart,
        ),
      ),
    );
  }
}

class DiscoveryQaScreen extends ConsumerStatefulWidget {
  const DiscoveryQaScreen({
    super.key,
    required this.clock,
    required this.presenter,
    required this.generation,
    required this.onRestart,
  });

  final FakeDiscoveryClock clock;
  final QaHintPresenter presenter;
  final int generation;
  final VoidCallback onRestart;

  @override
  ConsumerState<DiscoveryQaScreen> createState() => _DiscoveryQaScreenState();
}

class _DiscoveryQaScreenState extends ConsumerState<DiscoveryQaScreen> {
  QaScenario _scenario = QaScenario.withVariants;
  int _visit = 0;
  String _note = '';

  Future<void> _select(QaScenario scenario) async {
    final coordinator = await ref.read(discoveryCoordinatorProvider.future);
    await coordinator.repository.setHintsEnabled(scenario.hintsEnabled);
    if (!mounted) return;
    setState(() {
      _scenario = scenario;
      _visit = coordinator.beginVisit('readings');
      _note = '';
    });
  }

  Future<void> _show(DiscoveryCoordinator coordinator) async {
    final result = await coordinator.request(_scenario.context(_visit));
    if (!mounted) return;
    setState(
      () => _note = result.presented ? 'Паказана: ${result.label}' : 'no-op',
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinatorAsync = ref.watch(discoveryCoordinatorProvider);
    final state = ref.watch(discoveryStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Discovery QA (debug)')),
      body: coordinatorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Памылка: $e')),
        data: (coordinator) {
          if (_visit == 0) {
            _visit = coordinator.beginVisit('readings');
          }
          final decision = coordinator.peek(_scenario.context(_visit));
          final matches =
              coordinator.presented != null ||
              decision.label == _scenario.expected ||
              state?.records['readings.day_variants']?.dismissed == true;
          final reason = decision.reasons.entries
              .where((e) => e.key.startsWith('readings.day') || e.key == '*')
              .map((e) => '${e.key}: ${e.value.name}')
              .join('\n');
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
                children: [
                  Text(
                    'Сесія ${coordinator.repository.sessionIndex} · '
                    'перазапускаў: ${widget.generation}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final s in QaScenario.values)
                        ChoiceChip(
                          key: ValueKey('qa_scenario_${s.name}'),
                          label: Text(s.label),
                          selected: _scenario == s,
                          onSelected: (_) => _select(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Вынік', style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    decision.label,
                    key: const ValueKey('qa_result'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: matches ? Colors.green.shade700 : Colors.red,
                    ),
                  ),
                  Text(
                    'Чакалася: ${_scenario.expected}',
                    key: const ValueKey('qa_expected'),
                  ),
                  if (reason.isNotEmpty)
                    Text(reason, key: const ValueKey('qa_reason')),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('qa_show'),
                    onPressed: () => _show(coordinator),
                    child: const Text('Паказаць hint / no-op'),
                  ),
                  if (_note.isNotEmpty)
                    Text(_note, key: const ValueKey('qa_note')),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        key: const ValueKey('qa_restart'),
                        onPressed: widget.onRestart,
                        child: const Text('Імітаваць перазапуск'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('qa_plus_6m'),
                        onPressed: () => setState(
                          () =>
                              widget.clock.advance(const Duration(minutes: 6)),
                        ),
                        child: const Text('+6 хв'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('qa_plus_1d'),
                        onPressed: () => setState(
                          () => widget.clock.advance(const Duration(days: 1)),
                        ),
                        child: const Text('+1 дзень'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('qa_reset'),
                    onPressed: () async {
                      await coordinator.repository.resetHistory();
                      if (!mounted) return;
                      setState(() {
                        _visit = coordinator.beginVisit('readings');
                        _note = 'Гісторыю скінута';
                      });
                    },
                    child: const Text(
                      'Скінуць толькі гісторыю падказак у тэставым профілі',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state == null
                        ? ''
                        : 'hintsEnabled=${state.hintsEnabled} · '
                              'дзень_варыянты: seen='
                              '${state.record('readings.day_variants').seenCount}, '
                              'dismissed='
                              '${state.record('readings.day_variants').dismissed}, '
                              'snooze='
                              '${state.record('readings.day_variants').snoozeCount}',
                    key: const ValueKey('qa_state'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: ListenableBuilder(
                  listenable: widget.presenter,
                  builder: (context, _) {
                    final hint = widget.presenter.shown;
                    if (hint == null) return const SizedBox.shrink();
                    final record = coordinator.repository.state.record(hint.id);
                    return _HintCard(
                      hint: hint,
                      canSnooze: coordinator.policy.canSnooze(hint, record),
                      onResponse: (r) async {
                        await coordinator.respond(hint.id, r);
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.hint,
    required this.canSnooze,
    required this.onResponse,
  });

  final HintDefinition hint;
  final bool canSnooze;
  final ValueChanged<HintResponse> onResponse;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('qa_hint_card'),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hint.copyBe,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (hint.actionLabelBe != null)
                  TextButton(
                    key: const ValueKey('qa_hint_act'),
                    onPressed: () => onResponse(HintResponse.acted),
                    child: Text(hint.actionLabelBe!),
                  ),
                TextButton(
                  key: const ValueKey('qa_hint_ack'),
                  onPressed: () => onResponse(HintResponse.acknowledged),
                  child: const Text('Зразумела'),
                ),
                if (canSnooze)
                  TextButton(
                    key: const ValueKey('qa_hint_later'),
                    onPressed: () => onResponse(HintResponse.later),
                    child: const Text('Пазней'),
                  ),
                TextButton(
                  key: const ValueKey('qa_hint_never'),
                  onPressed: () => onResponse(HintResponse.never),
                  child: const Text('Не паказваць'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
