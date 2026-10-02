import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/reader.dart';

/// Mock-only comparison of the current reader anatomy and the Phase 4A
/// proposal. This screen never reads production content or changes a reader.
enum ReaderLabScenario { hours, prayer, mass, bible, compendium, song }

enum ReaderLabVersion { current, normalized }

class _Sample {
  const _Sample({
    required this.label,
    required this.eyebrow,
    required this.title,
    required this.metadata,
    required this.heading,
    required this.body,
    this.source,
  });

  final String label;
  final String eyebrow;
  final String title;
  final String metadata;
  final String heading;
  final String body;
  final String? source;
}

const _samples = <ReaderLabScenario, _Sample>{
  ReaderLabScenario.hours: _Sample(
    label: 'Гадзіны',
    eyebrow: '2 кастрычніка · Звычайны перыяд',
    title: 'Малітва пасля поўдня',
    metadata: 'Пятніца · ІІІ тыдзень Псалтыра',
    heading: 'Псалмодыя',
    body:
        'Антыфона. Госпадзе, пачуй мой голас.\n\nПсальм. Да Цябе ўзношу душу маю; на Цябе спадзяюся.',
  ),
  ReaderLabScenario.prayer: _Sample(
    label: 'Малітва',
    eyebrow: 'МАЛІТВА',
    title: 'Малітва перад пачаткам працы',
    metadata: 'На кожны дзень',
    heading: 'Малітва',
    body:
        'Божа, благаславі працу нашых рук. Дай нам мудрасць, спакой і ўвагу да людзей побач.',
  ),
  ReaderLabScenario.mass: _Sample(
    label: 'Імша',
    eyebrow: 'ЛІТУРГІЯ',
    title: 'Парадак святой Імшы',
    metadata: 'Беларуская мова',
    heading: 'Літургія слова',
    body:
        'Святар: Пан з вамі.\n\nНарод: І з духам тваім.\n\nРубрыка: усе ўстаюць перад чытаннем Евангелля.',
  ),
  ReaderLabScenario.bible: _Sample(
    label: 'Біблія',
    eyebrow: 'НОВЫ ЗАПАВЕТ',
    title: 'Евангелле паводле Яна',
    metadata: 'Раздзел 3 · Пераклад Новага Запавету',
    heading: 'Раздзел 3',
    body:
        '16  Бо так палюбіў Бог свет, што аддаў Сына Свайго Адзінароднага.\n\n17  Бог паслаў Сына ў свет, каб свет быў збаўлены праз Яго.',
  ),
  ReaderLabScenario.compendium: _Sample(
    label: 'Кампендый',
    eyebrow: 'ПЫТАННЕ 43',
    title: 'Што азначае вера ў адзінага Бога?',
    metadata: 'Частка I · Раздзел I · Вызнанне веры',
    heading: 'Адказ',
    body:
        'Вера ў адзінага Бога азначае пазнаваць Яго веліч, жыць у падзяцы і давяраць Яму ў кожнай справе.',
    source: 'Крыніца: Кампендый Катэхізіса Каталіцкага Касцёла',
  ),
  ReaderLabScenario.song: _Sample(
    label: 'Спеў',
    eyebrow: 'СПЕЎНІК',
    title: 'Прыйдзі, Дух Святы',
    metadata: 'Духоўныя спевы · Пяцідзясятніца',
    heading: 'Рэфрэн',
    body:
        'C        G\nПрыйдзі, Дух Святы,\nAm       F\nасвятлі нашы сэрцы.\n\nКуплет 1. Няхай Тваё святло вядзе нас.',
    source: 'Крыніца: спеўнік парафіі',
  ),
};

class ReaderConsistencyLabScreen extends StatefulWidget {
  const ReaderConsistencyLabScreen({super.key, this.readerScale = 1});

  /// Audit-only Aa input. Production keeps using Settings through
  /// ReadingScaffold; tests can vary Aa independently of the system scaler.
  final double readerScale;

  @override
  State<ReaderConsistencyLabScreen> createState() =>
      _ReaderConsistencyLabScreenState();
}

class _ReaderConsistencyLabScreenState
    extends State<ReaderConsistencyLabScreen> {
  ReaderLabScenario scenario = ReaderLabScenario.hours;
  ReaderLabVersion version = ReaderLabVersion.current;
  late double readerScale = widget.readerScale;

  @override
  Widget build(BuildContext context) {
    final sample = _samples[scenario]!;
    final normalized = version == ReaderLabVersion.normalized;
    final reader = ReaderTheme.of(context);
    final theme = Theme.of(context);
    final bodySize = 16.0 * readerScale;
    final bodyStyle = reader.body(bodySize);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('reader-lab-scroll'),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reader consistency lab',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Макет з прыкладамі; тэксты і дзеянні не звязаныя з production.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in _samples.entries)
                          ChoiceChip(
                            key: Key('lab-scenario-${entry.key.name}'),
                            label: Text(entry.value.label),
                            selected: scenario == entry.key,
                            onSelected: (_) =>
                                setState(() => scenario = entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in ReaderLabVersion.values)
                          ChoiceChip(
                            key: Key('lab-version-${option.name}'),
                            label: Text(option.name.toUpperCase()),
                            selected: version == option,
                            onSelected: (_) => setState(() => version = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in [0.7, 1.0, 1.8])
                          ChoiceChip(
                            key: Key('lab-aa-${(option * 100).round()}'),
                            label: Text('Aa ${(option * 100).round()}%'),
                            selected: readerScale == option,
                            onSelected: (_) =>
                                setState(() => readerScale = option),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: normalized ? 660 : 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        key: const Key('lab-context'),
                        padding: EdgeInsets.fromLTRB(
                          22,
                          10,
                          22,
                          normalized ? 12 : 22,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sample.eyebrow,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: reader.rubric,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              sample.title,
                              key: const Key('lab-title'),
                              style: normalized
                                  ? reader.displayTitle(32)
                                  : theme.textTheme.headlineSmall?.copyWith(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w600,
                                      height: 1.18,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sample.metadata,
                              key: const Key('lab-metadata'),
                              style: normalized
                                  ? theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: ReaderTheme.metadataHeight,
                                    )
                                  : theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      ColoredBox(
                        key: const Key('lab-page'),
                        color: reader.surface,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            normalized ? 16 : 25,
                            22,
                            normalized ? 32 : 42,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                sample.heading,
                                key: const Key('lab-first-section'),
                                style: reader.blockHeading(bodySize),
                              ),
                              const SizedBox(height: 8),
                              _DomainSample(
                                scenario: scenario,
                                sample: sample,
                                bodyStyle: bodyStyle,
                                reader: reader,
                              ),
                              if (sample.source != null) ...[
                                const SizedBox(height: 28),
                                Divider(color: reader.border),
                                const SizedBox(height: 12),
                                Text(
                                  sample.source!,
                                  key: const Key('lab-source'),
                                  style: reader.metadata(bodySize),
                                ),
                              ],
                              if (scenario == ReaderLabScenario.hours) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    '· · ·',
                                    style: reader.metadata(bodySize),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 1, key: Key('lab-end')),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _DomainSample extends StatelessWidget {
  const _DomainSample({
    required this.scenario,
    required this.sample,
    required this.bodyStyle,
    required this.reader,
  });

  final ReaderLabScenario scenario;
  final _Sample sample;
  final TextStyle bodyStyle;
  final ReaderTheme reader;

  @override
  Widget build(BuildContext context) {
    if (scenario == ReaderLabScenario.mass) {
      return Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Святар: '),
            const TextSpan(
              text: 'Пан з вамі.\n\n',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: 'Народ: І з духам тваім.\n\n'),
            TextSpan(
              text: 'Усе ўстаюць перад Евангеллем.',
              style: bodyStyle.copyWith(
                color: reader.rubric,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        style: bodyStyle,
      );
    }
    if (scenario == ReaderLabScenario.bible) {
      return Column(
        children: [
          for (final verse in [
            'Бо так палюбіў Бог свет, што аддаў Сына Свайго Адзінароднага.',
            'Бог паслаў Сына ў свет, каб свет быў збаўлены праз Яго.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: verse.startsWith('Бо') ? '16  ' : '17  ',
                      style: bodyStyle.copyWith(
                        color: reader.rubric,
                        fontSize: bodyStyle.fontSize! * 0.64,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: verse),
                  ],
                ),
                style: bodyStyle,
              ),
            ),
        ],
      );
    }
    if (scenario == ReaderLabScenario.song) {
      return Text(
        sample.body,
        style: bodyStyle.copyWith(height: ReaderTheme.hymnHeight),
      );
    }
    return Text(sample.body, style: bodyStyle);
  }
}
