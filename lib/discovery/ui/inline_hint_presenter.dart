import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';

/// Shows a hint in a [DiscoveryHintSlot] placed next to its real anchor.
/// The card is part of the layout (no overlay, no scrim), so it can never
/// cover a prayer or the Gospel and cannot be left behind by a route change.
class InlineHintPresenter extends ChangeNotifier implements HintPresenter {
  final Map<String, int> _slots = {};
  HintDefinition? _shown;

  HintDefinition? get shown => _shown;

  /// Anchors that currently have a mounted slot.
  Set<String> get mountedAnchors => _slots.keys.toSet();

  /// Fires when a slot is mounted, so a screen that asked too early can ask
  /// again once its anchor really exists.
  final ChangeNotifier slotMounted = _Notifier();

  void registerSlot(Iterable<String> anchorIds) {
    for (final id in anchorIds) {
      _slots[id] = (_slots[id] ?? 0) + 1;
    }
    (slotMounted as _Notifier).fire();
  }

  void unregisterSlot(Iterable<String> anchorIds) {
    var removedShown = false;
    for (final id in anchorIds) {
      final count = (_slots[id] ?? 1) - 1;
      if (count <= 0) {
        _slots.remove(id);
        if (_shown?.anchorId == id) removedShown = true;
      } else {
        _slots[id] = count;
      }
    }
    if (removedShown) _shown = null;
  }

  bool isShownAt(Iterable<String> anchorIds) =>
      _shown != null && anchorIds.contains(_shown!.anchorId);

  @override
  Future<bool> present(HintDefinition hint) async {
    if (!_slots.containsKey(hint.anchorId)) return false;
    _shown = hint;
    notifyListeners();
    // Counted only once the card has been laid out in a real frame.
    await SchedulerBinding.instance.endOfFrame;
    return _shown == hint && _slots.containsKey(hint.anchorId);
  }

  @override
  void dispose() {
    slotMounted.dispose();
    super.dispose();
  }

  @override
  void dismiss() {
    if (_shown == null) return;
    _shown = null;
    notifyListeners();
  }
}

class _Notifier extends ChangeNotifier {
  void fire() => notifyListeners();
}
