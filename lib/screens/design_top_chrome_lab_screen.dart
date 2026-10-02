import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/ib_colors.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Phase 3A is a mock-only composition lab. No production screen uses it.
enum TopLabScenario {
  gallery,
  hoursRoot,
  readingsRoot,
  prayerbookRoot,
  bibleRoot,
  oraReader,
  prayerReader,
  bibleReader,
  massReader,
}

enum TopLabVariant { inline, structured, adaptive }

extension on TopLabScenario {
  String get label => switch (this) {
    TopLabScenario.gallery => 'Чатыры карані',
    TopLabScenario.hoursRoot => 'Літургія',
    TopLabScenario.readingsRoot => 'Чытанні',
    TopLabScenario.prayerbookRoot => 'Малітоўнік',
    TopLabScenario.bibleRoot => 'Біблія',
    TopLabScenario.oraReader => 'Ora',
    TopLabScenario.prayerReader => 'Малітва',
    TopLabScenario.bibleReader => 'Раздзел Бібліі',
    TopLabScenario.massReader => 'Святая Імша',
  };

  bool get isRoot => switch (this) {
    TopLabScenario.hoursRoot ||
    TopLabScenario.readingsRoot ||
    TopLabScenario.prayerbookRoot ||
    TopLabScenario.bibleRoot => true,
    _ => false,
  };

  String get branch => switch (this) {
    TopLabScenario.hoursRoot || TopLabScenario.oraReader => 'ЛІТУРГІЯ',
    TopLabScenario.readingsRoot => 'ЧЫТАННІ',
    TopLabScenario.prayerbookRoot ||
    TopLabScenario.prayerReader ||
    TopLabScenario.massReader => 'МАЛІТОЎНІК',
    _ => 'БІБЛІЯ',
  };

  String get title => switch (this) {
    TopLabScenario.hoursRoot => 'Літургія',
    TopLabScenario.readingsRoot => 'Чытанні',
    TopLabScenario.prayerbookRoot => 'Малітоўнік',
    TopLabScenario.bibleRoot => 'Біблія',
    TopLabScenario.oraReader => 'Ютрань',
    TopLabScenario.prayerReader => 'Малітва да Найсвяцейшай Панны Марыі',
    TopLabScenario.bibleReader => 'Евангелле паводле Яна',
    TopLabScenario.massReader => 'Святая Імша',
    TopLabScenario.gallery => '',
  };
}

extension on TopLabVariant {
  String get label => switch (this) {
    TopLabVariant.inline => 'A · лёгкі верх',
    TopLabVariant.structured => 'B · асобны радок',
    TopLabVariant.adaptive => 'C · адаптыўны',
  };
}

class TopChromeLabScreen extends StatefulWidget {
  const TopChromeLabScreen({super.key});

  @override
  State<TopChromeLabScreen> createState() => _TopChromeLabScreenState();
}

class _TopChromeLabScreenState extends State<TopChromeLabScreen> {
  TopLabScenario _scenario = TopLabScenario.gallery;
  TopLabVariant _variant = TopLabVariant.inline;
  TargetPlatform _platform = TargetPlatform.android;
  double _width = 390;
  double _scale = 1;
  bool _longTitle = false;
  String _lastAction = 'Націсніце дзеянне ў макеце для праверкі.';

  @override
  Widget build(BuildContext context) {
    final scenarios = _scenario == TopLabScenario.gallery
        ? const [
            TopLabScenario.hoursRoot,
            TopLabScenario.readingsRoot,
            TopLabScenario.prayerbookRoot,
            TopLabScenario.bibleRoot,
          ]
        : [_scenario];
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 3A · Top Chrome Lab')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Макеты: змест і дзеянні не падключаныя да дадзеных.'),
            const SizedBox(height: 16),
            _controlLabel(context, 'Сцэнар'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in TopLabScenario.values)
                  ChoiceChip(
                    key: Key('lab-scenario-${value.name}'),
                    label: Text(value.label),
                    selected: _scenario == value,
                    onSelected: (_) => setState(() => _scenario = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _controlLabel(context, 'Кампазіцыя'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in TopLabVariant.values)
                  ChoiceChip(
                    key: Key('lab-variant-${value.name}'),
                    label: Text(value.label),
                    selected: _variant == value,
                    onSelected: (_) => setState(() => _variant = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _controlLabel(context, 'Шырыня'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in const [320.0, 360.0, 390.0, 700.0])
                  ChoiceChip(
                    key: Key('lab-width-${value.toInt()}'),
                    label: Text('${value.toInt()}'),
                    selected: _width == value,
                    onSelected: (_) => setState(() => _width = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _controlLabel(context, 'Сістэмны тэкст'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in const [1.0, 1.5, 2.0])
                  ChoiceChip(
                    key: Key('lab-scale-${(value * 100).toInt()}'),
                    label: Text('${(value * 100).toInt()}%'),
                    selected: _scale == value,
                    onSelected: (_) => setState(() => _scale = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _controlLabel(context, 'Платформа'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in const [
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                ])
                  ChoiceChip(
                    key: Key('lab-platform-${value.name}'),
                    label: Text(
                      value == TargetPlatform.iOS ? 'iOS' : 'Android',
                    ),
                    selected: _platform == value,
                    onSelected: (_) => setState(() => _platform = value),
                  ),
                FilterChip(
                  key: const Key('lab-long-title'),
                  label: const Text('Доўгі загаловак'),
                  selected: _longTitle,
                  onSelected: (value) => setState(() => _longTitle = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_lastAction, key: const Key('lab-action-feedback')),
            const SizedBox(height: 18),
            for (final scenario in scenarios) ...[
              Text(
                scenario.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _MockPreview(
                  key: Key('lab-preview-${scenario.name}'),
                  scenario: scenario,
                  variant: _variant,
                  platform: _platform,
                  width: _width,
                  scale: _scale,
                  longTitle: _longTitle,
                  onAction: (label) => setState(() => _lastAction = label),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controlLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

enum _Action { appearance, favorite, search, language }

extension on _Action {
  String get label => switch (this) {
    _Action.appearance => 'Выгляд тэксту',
    _Action.favorite => 'Абранае',
    _Action.search => 'Пошук',
    _Action.language => 'Мова / пераклад',
  };

  IconData get icon => switch (this) {
    _Action.appearance => Icons.text_fields_rounded,
    _Action.favorite => Icons.star_border_rounded,
    _Action.search => Icons.search_rounded,
    _Action.language => Icons.language_rounded,
  };
}

class _MockPreview extends StatelessWidget {
  const _MockPreview({
    super.key,
    required this.scenario,
    required this.variant,
    required this.platform,
    required this.width,
    required this.scale,
    required this.longTitle,
    required this.onAction,
  });

  final TopLabScenario scenario;
  final TopLabVariant variant;
  final TargetPlatform platform;
  final double width;
  final double scale;
  final bool longTitle;
  final ValueChanged<String> onAction;

  List<_Action> get _actions => switch (scenario) {
    TopLabScenario.hoursRoot => const [],
    TopLabScenario.readingsRoot => const [_Action.appearance],
    TopLabScenario.prayerbookRoot => const [_Action.search],
    TopLabScenario.bibleRoot || TopLabScenario.bibleReader => const [
      _Action.appearance,
      _Action.search,
      _Action.language,
    ],
    TopLabScenario.oraReader => const [_Action.appearance],
    TopLabScenario.prayerReader => const [_Action.appearance, _Action.favorite],
    TopLabScenario.massReader => const [_Action.appearance, _Action.language],
    TopLabScenario.gallery => const [],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(platform: platform);
    final media = MediaQuery.of(context).copyWith(
      size: Size(width, 640),
      textScaler: TextScaler.linear(scale),
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
    );
    return SizedBox(
      width: width,
      height: 640,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: theme,
          child: MediaQuery(
            data: media,
            child: Builder(
              builder: (context) {
                final colors = IbColors.of(context);
                return Material(
                  color: scenario.isRoot ? colors.page : colors.reader,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 26,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Text(
                              '9:41',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                      _chrome(context),
                      Expanded(
                        child: ListView(
                          key: Key('lab-content-${scenario.name}'),
                          padding: EdgeInsets.fromLTRB(
                            width < 360
                                ? 16
                                : width < 600
                                ? 20
                                : 24,
                            variant == TopLabVariant.inline ? 18 : 24,
                            width < 360
                                ? 16
                                : width < 600
                                ? 20
                                : 24,
                            30,
                          ),
                          children: [
                            _pageHeader(context),
                            const SizedBox(height: 22),
                            ..._content(context),
                          ],
                        ),
                      ),
                      _bottomPlaceholder(context),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _chrome(BuildContext context) {
    final colors = IbColors.of(context);
    final compact =
        width <= 360 ||
        scale >= 1.5 ||
        (variant == TopLabVariant.adaptive && width < 400);
    final visibleCount = compact
        ? 1
        : width < 700
        ? 2
        : 3;
    final visible = _actions.take(visibleCount).toList();
    final hidden = _actions.skip(visibleCount).toList();
    final hasMore =
        hidden.isNotEmpty ||
        scenario == TopLabScenario.prayerReader ||
        scenario == TopLabScenario.massReader;
    final row = Row(
      children: [
        AdaptiveChromeSurface(
          child: IconButton(
            key: Key('lab-leading-${scenario.name}'),
            tooltip: scenario.isRoot ? 'Меню' : 'Назад',
            onPressed: () => onAction(scenario.isRoot ? 'Меню' : 'Назад'),
            icon: Icon(
              scenario.isRoot
                  ? Icons.menu_rounded
                  : platform == TargetPlatform.iOS
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: variant == TopLabVariant.inline
              ? const SizedBox.shrink()
              : Text(
                  scenario.branch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.inkMuted),
                ),
        ),
        for (final action in visible) ...[
          const SizedBox(width: 4),
          AdaptiveChromeSurface(
            child: IconButton(
              key: Key('lab-action-${scenario.name}-${action.name}'),
              tooltip: action.label,
              onPressed: () => onAction(action.label),
              icon: Icon(action.icon),
            ),
          ),
        ],
        if (hasMore) ...[
          const SizedBox(width: 4),
          AdaptiveChromeSurface(
            child: SizedBox.square(
              dimension: 48,
              child: PopupMenuButton<String>(
                key: Key('lab-overflow-${scenario.name}'),
                tooltip: 'Іншыя дзеянні',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: onAction,
                itemBuilder: (context) => [
                  for (final action in hidden)
                    PopupMenuItem(
                      value: action.label,
                      child: Text(action.label),
                    ),
                  if (scenario == TopLabScenario.prayerReader)
                    const PopupMenuItem(
                      value: 'Рэдагаваць',
                      child: Text('Рэдагаваць'),
                    ),
                  if (scenario == TopLabScenario.massReader)
                    const PopupMenuItem(
                      value: 'Падзяліцца',
                      child: Text('Падзяліцца'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
    return Container(
      key: Key('lab-chrome-${scenario.name}'),
      color: variant == TopLabVariant.structured
          ? colors.surfaceRaised
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: row,
    );
  }

  Widget _pageHeader(BuildContext context) {
    final colors = IbColors.of(context);
    final title = longTitle
        ? '${scenario.title} · урачыстасць Найсвяцейшага Цела і Крыві Хрыста'
        : scenario.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scenario.branch,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          key: Key('lab-title-${scenario.name}'),
          style: ReaderTheme.of(context).displayTitle(34),
        ),
        if (!scenario.isRoot) ...[
          const SizedBox(height: 8),
          Text(
            switch (scenario) {
              TopLabScenario.oraReader => '2 кастрычніка · Анёлаў Ахоўнікаў',
              TopLabScenario.bibleReader => 'Раздзел 3 · Беларускі пераклад',
              TopLabScenario.massReader => 'Парадак Імшы · Беларуская мова',
              _ => 'Малітва · асабістая кніга',
            },
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }

  List<Widget> _content(BuildContext context) => switch (scenario) {
    TopLabScenario.hoursRoot => [
      _dayBlock(context, 'Сёння · 2 кастрычніка', 'Анёлаў Ахоўнікаў'),
      const SizedBox(height: 22),
      _section(context, 'Гадзіны'),
      _row(context, 'Ютрань', 'Ранішняя малітва'),
      _row(context, 'Гадзіна чытанняў', 'Псальмы і чытанні'),
      _row(context, 'Нешпары', 'Вячэрняя малітва'),
      const SizedBox(height: 12),
      _utility(context, 'Выбраць дату або літургічны варыянт'),
    ],
    TopLabScenario.readingsRoot => [
      _dayBlock(context, 'Сёння · 2 кастрычніка', 'Анёлаў Ахоўнікаў · цыкл II'),
      const SizedBox(height: 22),
      _section(context, 'Чытанні дня'),
      _row(context, 'Першае чытанне', 'З кнігі Зыходу'),
      _row(context, 'Псальм', 'Рэфрэн і вершы'),
      _row(context, 'Евангелле', 'Паводле Мацвея'),
      const SizedBox(height: 12),
      _utility(context, 'Іншыя варыянты і дата'),
    ],
    TopLabScenario.prayerbookRoot => [
      _utility(context, 'Пошук у бібліятэцы'),
      const SizedBox(height: 22),
      _section(context, 'На паліцы'),
      _row(context, 'Малітвы', 'Усе малітвы і мае малітвы'),
      _row(context, 'Святая Імша', 'Парадак Імшы'),
      _row(context, 'Спеўнік', 'Спевы і акорды'),
      _row(context, 'Катэхізіс', 'Кампендый'),
      _row(context, 'Сакрамэнты', 'Раздзел у распрацоўцы'),
      const SizedBox(height: 18),
      _section(context, 'Абраныя'),
      _row(context, 'Малітва перад чытаннем', 'Захавана ў бібліятэцы'),
    ],
    TopLabScenario.bibleRoot => [
      _dayBlock(context, 'Працягнуць чытанне', 'Ян 3 · апошняе месца'),
      const SizedBox(height: 18),
      _utility(context, 'Выбраць кнігу і раздзел'),
      const SizedBox(height: 22),
      _section(context, 'Евангелле паводле Яна'),
      _paragraph(
        context,
        'Так палюбіў Бог свет, што аддаў Сына свайго Адзінароднага…',
      ),
      const SizedBox(height: 18),
      _section(context, 'Нядаўнія'),
      _row(context, 'Псальмы 23', 'Беларускі пераклад'),
    ],
    _ => [
      _dayBlock(
        context,
        scenario == TopLabScenario.bibleReader
            ? 'Раздзел 3'
            : 'Кантэкст чытання',
        scenario == TopLabScenario.oraReader
            ? 'Гадзіну можна змяніць праз загаловак'
            : scenario == TopLabScenario.massReader
            ? 'Мова і раздзелы даступныя асобна'
            : 'Дзеянні чытання знаходзяцца ўверсе',
      ),
      const SizedBox(height: 22),
      if (scenario == TopLabScenario.oraReader)
        _utility(context, 'Перайсці да Чытанняў'),
      _section(
        context,
        scenario == TopLabScenario.massReader ? 'Уступныя абрады' : 'Тэкст',
      ),
      _paragraph(
        context,
        'Гэты тэкст паказвае рытм кніжнай старонкі. Загаловак і кантэкст жывуць у змесце, а дзеянні застаюцца ў ціхай верхняй зоне.',
      ),
      const SizedBox(height: 16),
      _paragraph(
        context,
        'Працяг чытання застаецца добра бачным пры змене шырыні экрана і сістэмнага памеру тэксту.',
      ),
    ],
  };

  Widget _dayBlock(BuildContext context, String label, String detail) {
    final colors = IbColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.rubric, width: 3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _row(BuildContext context, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => onAction(title),
    ),
  );

  Widget _utility(BuildContext context, String label) => OutlinedButton.icon(
    onPressed: () => onAction(label),
    icon: const Icon(Icons.arrow_forward_rounded),
    label: Text(label),
  );

  Widget _paragraph(BuildContext context, String text) =>
      Text(text, style: ReaderTheme.of(context).body(17));

  Widget _bottomPlaceholder(BuildContext context) {
    final colors = IbColors.of(context);
    return Container(
      key: Key('lab-bottom-${scenario.name}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      color: colors.surfaceRaised,
      child: Text(
        scenario.isRoot
            ? 'Літургія   ·   Чытанні   ·   Малітоўнік   ·   Біблія'
            : scenario == TopLabScenario.massReader
            ? 'Раздзелы Імшы · лакальная навігацыя'
            : scenario == TopLabScenario.bibleReader
            ? 'Папярэдні · Раздзел 3 · Наступны'
            : 'Ніжняя зона reader / dock — па выніку Phase 2B',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.inkMuted),
      ),
    );
  }
}
