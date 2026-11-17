import 'package:mybrev_flutter/models/day.dart';

/// Printed Belarusian Liturgy of the Hours:
/// pp. 394–395, 419–420, 442–443, 1317–1321.
const _triduumAntiphons = <int, String>{
  5: 'Хрыстус стаў дзеля нас паслухмяным * ажно да смерці.',
  6: 'Хрыстус стаў дзеля нас паслухмяным ажно да смерці, * смерці крыжовай.',
  7: 'Хрыстус стаў дзеля нас паслухмяным ажно да смерці, смерці крыжовай. * Таму Бог узвысіў Яго і даў Яму імя па-над усялякае імя.',
};

const _solemnityPrayer =
    '<p>Просім Цябе, Пане, наведай гэты дом і аддалі ад яго ўсе варожыя подступы. Няхай Твае святыя анёлы апякуюцца ім і захоўваюць нас у спакоі, а Тваё благаслаўленне няхай заўсёды будзе над намі. Праз Хрыста, Пана нашага.</p>';

int? triduumWeekday(LiturgicalDay day) {
  final weekday = day.dayOfWeek ?? int.tryParse(day.field('_dayOfWeek') ?? '');
  if (day.field('_ordoOfficeKind') != 'triduum') return null;
  return const [5, 6, 7].contains(weekday) ? weekday : null;
}

String triduumAntiphon(LiturgicalDay day) {
  final text = _triduumAntiphons[triduumWeekday(day)];
  return text == null ? '' : '<p><span style="color:red">Ант.</span> $text</p>';
}

String triduumVespersNotice(LiturgicalDay day) => switch (triduumWeekday(day)) {
  5 => 'Нешпары чытаюць толькі тыя, хто не ўдзельнічае ў вечаровай Імшы Вячэры Пана.',
  6 => 'Нешпары чытаюць толькі тыя, хто не ўдзельнічае ў Літургіі Мукі Пана.',
  _ => '',
};

String triduumComplineNotice(LiturgicalDay day) =>
    triduumWeekday(day) == 7
        ? 'Камплету чытаюць толькі тыя, хто не ўдзельнічае ў Пасхальнай вігіліі.'
        : '';

String goodFridayIntercessionsRubric(LiturgicalDay day) =>
    triduumWeekday(day) == 6
        ? 'У якасці просьбаў будзе пахвальным выкарыстаць агульную малітву, якая пададзена ў Імшале на гэты дзень. Аднак на выбар могуць выкарыстоўвацца ніжэйпададзеныя просьбы або малітва ў маўчанні ў прапанаваных тут інтэнцыях.'
        : '';

String specialComplinePrayer(LiturgicalDay day) {
  final kind = day.field('_ordoOfficeKind');
  final isWeekdaySolemnity =
      kind == 'solemnity' && day.dayOfWeek != 1;
  return kind == 'triduum' || isWeekdaySolemnity
      ? _solemnityPrayer
      : '';
}
