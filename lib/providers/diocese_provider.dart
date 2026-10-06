import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';

/// Settings «Літургічны каляндар»: the dioceses whose celebrations the Hours
/// and the Ordo show. At least one; the engine resolves one diocese per
/// call and the presentation unites them.
///
/// `primary` is managed automatically: the diocese chosen first. It decides
/// the default context of a shared option and the order of the rows — the
/// result is deterministic for the same selection.
class DioceseSelection {
  const DioceseSelection({required this.selected, required this.primary});

  static const initial = DioceseSelection(
    selected: [kDefaultDiocese],
    primary: kDefaultDiocese,
  );

  /// In the canonical order of [kDioceses].
  final List<String> selected;
  final String primary;

  /// Primary first, then the others in the canonical order.
  List<String> get ordered => [
    primary,
    ...selected.where((id) => id != primary),
  ];

  bool get isMultiple => selected.length > 1;
  bool contains(String id) => selected.contains(id);
}

/// Full names (Settings, Ordo explanations).
const kDioceseNames = {
  'minsk-mohilev': 'Мінска-Магілёўская архідыяцэзія',
  'grodno': 'Гродзенская дыяцэзія',
  'pinsk': 'Пінская дыяцэзія',
  'vitebsk': 'Віцебская дыяцэзія',
};

/// Short names for the Settings list.
const kDioceseShortNames = {
  'minsk-mohilev': 'Мінска-Магілёўская',
  'grodno': 'Гродзенская',
  'pinsk': 'Пінская',
  'vitebsk': 'Віцебская',
};

/// Badges of a diocesan option (mybrev `DIOCESE_BADGES`).
const kDioceseBadges = {
  'minsk-mohilev': 'Мінск',
  'grodno': 'Гродна',
  'pinsk': 'Пінск',
  'vitebsk': 'Віцебск',
};

class DioceseSelectionNotifier extends Notifier<DioceseSelection> {
  static const _boxName = 'settings';
  static const selectedKey = 'liturgicalDioceses';
  static const primaryKey = 'liturgicalPrimaryDiocese';

  /// Keys an earlier build or the web export may have written.
  static const legacyKeys = ['diocese', 'selectedDiocese', 'liturgicalDiocese'];

  Box? get _box => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;

  @override
  DioceseSelection build() => read(_box);

  /// The stored selection, migrating a former single-diocese key.
  static DioceseSelection read(Box? box) {
    if (box == null) return DioceseSelection.initial;
    final raw = box.get(selectedKey);
    List<String> selected = const [];
    if (raw is String) {
      try {
        selected = (jsonDecode(raw) as List).map((e) => '$e').toList();
      } catch (_) {}
    } else if (raw is List) {
      selected = raw.map((e) => '$e').toList();
    }
    if (selected.isEmpty) {
      for (final key in legacyKeys) {
        final legacy = normalizeDioceseId(box.get(key)?.toString());
        if (kDioceses.contains(legacy)) {
          selected = [legacy];
          break;
        }
      }
    }
    final normalized = _canonical(selected);
    if (normalized.isEmpty) return DioceseSelection.initial;
    final storedPrimary = normalizeDioceseId(box.get(primaryKey)?.toString());
    return DioceseSelection(
      selected: normalized,
      primary: normalized.contains(storedPrimary)
          ? storedPrimary
          : (selected
                .map(normalizeDioceseId)
                .firstWhere(
                  normalized.contains,
                  orElse: () => normalized.first,
                )),
    );
  }

  static List<String> _canonical(Iterable<String> ids) {
    final wanted = {for (final id in ids) normalizeDioceseId(id)};
    return [
      for (final id in kDioceses)
        if (wanted.contains(id)) id,
    ];
  }

  /// Adds or removes [diocese]. The last diocese cannot be removed (returns
  /// false); removing the primary makes the next selected one primary.
  bool toggle(String diocese) {
    final id = normalizeDioceseId(diocese);
    if (!kDioceses.contains(id)) return false;
    final current = state;
    if (current.contains(id)) {
      if (current.selected.length == 1) return false;
      final selected = current.selected.where((item) => item != id).toList();
      _set(
        DioceseSelection(
          selected: selected,
          primary: current.primary == id ? selected.first : current.primary,
        ),
      );
    } else {
      _set(
        DioceseSelection(
          selected: _canonical([...current.selected, id]),
          primary: current.primary,
        ),
      );
    }
    return true;
  }

  void setPrimary(String diocese) {
    final id = normalizeDioceseId(diocese);
    if (!kDioceses.contains(id)) return;
    _set(
      DioceseSelection(
        selected: _canonical([...state.selected, id]),
        primary: id,
      ),
    );
  }

  void _set(DioceseSelection next) {
    state = next;
    final box = _box;
    if (box == null) return;
    box.put(selectedKey, jsonEncode(next.selected));
    box.put(primaryKey, next.primary);
  }
}

final dioceseSelectionProvider =
    NotifierProvider<DioceseSelectionNotifier, DioceseSelection>(
      DioceseSelectionNotifier.new,
    );
