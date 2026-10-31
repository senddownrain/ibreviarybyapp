import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';
import 'package:mybrev_flutter/discovery/hints/p1_hints.dart';
import 'package:mybrev_flutter/discovery/hints/p2_hints.dart';

/// Registry of hint definitions with unique, stable IDs.
class HintCatalog {
  HintCatalog(Iterable<HintDefinition> hints)
    : _byId = {for (final hint in hints) hint.id: hint} {
    final all = hints.toList();
    if (_byId.length != all.length) {
      throw ArgumentError('Duplicate hint_id in catalog');
    }
  }

  /// The production catalog: one file per priority tier under `hints/`.
  factory HintCatalog.standard() =>
      HintCatalog([...p0Hints, ...p1Hints, ...p2Hints]);

  final Map<String, HintDefinition> _byId;

  Iterable<HintDefinition> get all => _byId.values;

  HintDefinition? byId(String id) => _byId[id];
}
