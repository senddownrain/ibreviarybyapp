/// The Pompeii novena: 54 days built into the app (owner, 28.11). It has no
/// Firestore documents and no editor; every prayer text is taken from the
/// public prayers the app already has, never written here. Pure.
library;

import 'package:mybrev_flutter/novena/novena_definition.dart';

/// The ordinary «Пампейская навэнна» prayer.
const kPompeiiNovenaId = 'v4g6eUqZvze29v5vq4o1';

/// «Асноўныя малітвы» and «Святы Ружанец».
const kPompeiiBasicsId = 'import-08-asnounyya-malitvy-na-pratsyagu-dnya';
const kPompeiiRosaryId = 'pi_b637715ba63663141e0f';

const kPompeiiDays = 54;

/// Days 1–27 ask, days 28–54 give thanks. By the number of the day, never by
/// the number of marks.
const kPompeiiPhaseDays = 27;

bool isPompeiiThanksgiving(int day) => day > kPompeiiPhaseDays;

String pompeiiPhaseTitle(int day) =>
    isPompeiiThanksgiving(day) ? 'Малітва падзякі' : 'Малітва просьбы';

NovenaBlock _heading(String text) => NovenaBlock(
  kind: 'section',
  title: null,
  markdown: '## $text',
  collapsible: false,
  prayerId: null,
);

NovenaBlock _rubric(String text) => NovenaBlock(
  kind: 'rubric',
  title: null,
  markdown: text,
  collapsible: false,
  prayerId: null,
);

class _Missing implements Exception {}

/// The section without its own heading line (the block gets a title instead).
String _body(NovenaPrayer prayer, String heading) {
  final section = novenaSectionText(prayer.text, heading);
  if (section == null) throw _Missing();
  final body = section.split('\n').skip(1).join('\n').trim();
  if (body.isEmpty) throw _Missing();
  return body;
}

String _line(NovenaPrayer prayer, String start) =>
    prayer.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith(start))
        .firstOrNull ??
    (throw _Missing());

/// The two day orders, or null when a needed public text is not there: the
/// tracker is then not offered, and no text is ever substituted.
({List<NovenaBlock> petition, List<NovenaBlock> thanksgiving})? pompeiiOrders(
  Map<String, NovenaPrayer> prayers,
) {
  NovenaPrayer need(String id) {
    final prayer = prayers[id];
    if (prayer == null || prayer.priestOnly) throw _Missing();
    return prayer;
  }

  try {
    final novena = need(kPompeiiNovenaId);
    final basics = need(kPompeiiBasicsId);
    final rosary = need(kPompeiiRosaryId);

    NovenaBlock basic(String title, String heading) => NovenaBlock(
      kind: 'prayer',
      title: title,
      markdown: _body(basics, heading),
      collapsible: true,
      prayerId: basics.id,
    );
    NovenaBlock own(String start) => NovenaBlock(
      kind: 'text',
      title: null,
      markdown: _line(novena, start),
      collapsible: false,
      prayerId: novena.id,
    );

    final request = _line(novena, 'Называем просьбу');
    final offering = own('Гэты Ружанец малюся');
    final invocation = own('Каралева Ружанца Святога, маліся за нас!');
    final start = [
      _heading('Пачатковыя малітвы'),
      _rubric('Чытаюцца адзін раз у дзень.'),
      basic('Веру ў Бога', '### Апостальскі сімвал веры'),
      basic('Ойча наш', '### Малітва Панская'),
      basic('Вітай, Марыя (3 разы)', '### Анёльскае прывітанне'),
      basic('Хвала Айцу', '### Праслаўленне Найсвяцейшай Тройцы'),
      _rubric(request),
      offering,
    ];

    List<NovenaBlock> order(String phaseStart) {
      final phase = own(phaseStart);
      NovenaBlock part(String title, String heading) => NovenaBlock(
        kind: 'part',
        title: title,
        // The closing prayer is at hand where the part ends.
        markdown: [
          _body(rosary, heading),
          ':::rubric\nПасля гэтай часткі Ружанца:\n:::',
          phase.markdown,
          '${invocation.markdown} _(3 разы)_',
        ].join('\n\n'),
        collapsible: true,
        prayerId: rosary.id,
      );
      return [
        ...start,
        _heading('Святы Ружанец'),
        _rubric('Часткі Ружанца можна маліцца на працягу ўсяго дня.'),
        part('Радасныя таямніцы', '## Радасныя таямніцы'),
        part('Балесныя таямніцы', '## Балесныя таямніцы'),
        part('Хвалебныя таямніцы', '## Хвалебныя таямніцы'),
        part('Таямніцы святла (паводле жадання)', '## Таямніцы святла'),
        _heading('Пасля кожнай часткі Ружанца'),
        phase,
        invocation,
        _rubric('3 разы'),
      ];
    }

    return (
      petition: order('Памятай, о міласэрная'),
      thanksgiving: order('Што ж я магу даць Табе'),
    );
  } on _Missing {
    return null;
  }
}

/// All 54 days; the days of one phase share one list.
List<List<NovenaBlock>>? pompeiiDays(Map<String, NovenaPrayer> prayers) {
  final orders = pompeiiOrders(prayers);
  if (orders == null) return null;
  return [
    for (var day = 1; day <= kPompeiiDays; day++)
      isPompeiiThanksgiving(day) ? orders.thanksgiving : orders.petition,
  ];
}
