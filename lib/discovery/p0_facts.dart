import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';

/// `ordo.diocese_cards_differ`: at least two dioceses of [kDioceses] have a
/// different set of legal options on [date] (the same resolver the Ordo uses;
/// nothing is read from the person's chosen dioceses and nothing is changed).
bool dioceseOptionsDiffer(DateTime date, OrdoEngine engine) {
  final iso = isoOf(date);
  Set<String>? first;
  for (final diocese in kDioceses) {
    final ids = {
      for (final option in engine.resolve(iso, diocese: diocese).options)
        option.id,
    };
    if (first == null) {
      first = ids;
    } else if (first.length != ids.length || !first.containsAll(ids)) {
      return true;
    }
  }
  return false;
}

/// «Папярэдні/Наступны дзень» pressed this often without ever opening the
/// date control: the person is walking day by day towards a far date.
const int kDateNavigationArrowTaps = 3;

/// Calendar sheets opened this often before the search tile is pointed out.
const int kMorePeriodsCalendarOpens = 2;
