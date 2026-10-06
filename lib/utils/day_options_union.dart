/// Hours for several dioceses (port of mybrev `dayOptionsUnion.js`): each
/// diocese is resolved on its own (the engine takes one diocese), the legal
/// options are united here, at the presentation layer.
///
/// ```text
/// same celebration, rank and Office document in every diocese → one row
/// an option of only some dioceses                            → diocese badges
/// same celebration, different rank or content                → distinct rows
/// ```
///
/// A row remembers the diocese to open it in (`contextDiocese`): the primary
/// when it has the row, else the first that has it.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

String _unionKey(DayOption option) => [
  option.ordo?.optionId ?? option.key,
  option.ordo?.rank ?? option.day?.rank ?? '',
  option.dayId ?? '',
].join('|');

/// [results]: (diocese, options), primary first.
List<DayOption> unionDayOptions(
  List<(String, List<DayOption>)> results, {
  String? primary,
}) {
  final primaryId = primary ?? (results.isEmpty ? null : results.first.$1);
  final rows = <String, (DayOption, List<String>, int)>{};
  var position = 0;
  for (final (diocese, options) in results) {
    for (final option in options) {
      final key = _unionKey(option);
      final row = rows[key];
      if (row == null) {
        rows[key] = (option, [diocese], ++position);
      } else {
        row.$2.add(diocese);
      }
    }
  }
  final all = results.length;
  final sorted = rows.values.toList();
  stableSort(sorted, (a, b) {
    final order = a.$1.order.compareTo(b.$1.order);
    return order != 0 ? order : a.$3.compareTo(b.$3);
  });
  return [
    for (final (option, dioceses, _) in sorted)
      () {
        final context = dioceses.contains(primaryId)
            ? primaryId!
            : dioceses.first;
        return option.copyWith(
          key: all > 1 ? '${option.key}@$context' : option.key,
          dioceses: List.unmodifiable(dioceses),
          contextDiocese: context,
          badges: dioceses.length == all
              ? const []
              : [for (final id in dioceses) kDioceseBadges[id] ?? id],
        );
      }(),
  ];
}
