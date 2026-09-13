import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

enum AppBranch { hours, readings, prayerbook, bible }

enum TopChromeOwner { shell, reader, legacy }

@immutable
class AppRouteDescriptor {
  const AppRouteDescriptor({
    required this.id,
    required this.branch,
    required this.defaultChromeMode,
    required this.topChromeOwner,
    this.isBranchRoot = false,
    this.reserveShellTopInset = false,
  });

  final String id;
  final AppBranch branch;
  final ReaderChromeMode defaultChromeMode;
  final TopChromeOwner topChromeOwner;
  final bool isBranchRoot;
  final bool reserveShellTopInset;
}

@immutable
class AppRouteEntry {
  const AppRouteEntry({
    required this.id,
    required this.descriptor,
    this.documentKey = '',
  });

  final String id;
  final AppRouteDescriptor descriptor;
  final String documentKey;
}

class BranchShellController extends ReaderChromeModeController {
  BranchShellController(this.branch, this.rootDescriptor)
    : _activeDescriptor = rootDescriptor,
      super(rootDescriptor.defaultChromeMode);

  final AppBranch branch;
  final AppRouteDescriptor rootDescriptor;
  final Map<String, AppRouteDescriptor> _entries = {};
  final Map<String, ReaderChromeMode> _overrides = {};
  final Set<String> _contextualBottomSlots = {};
  String? _activeEntryId;
  AppRouteDescriptor _activeDescriptor;

  String? get activeEntryId => _activeEntryId;
  AppRouteDescriptor get activeDescriptor => _activeDescriptor;
  bool get isAtRoot => _activeDescriptor.isBranchRoot;
  bool get navigationDockSuppressed =>
      _activeEntryId != null && _contextualBottomSlots.contains(_activeEntryId);

  bool containsEntry(String entryId) => _entries.containsKey(entryId);

  void activate(AppRouteEntry entry) {
    final routeChanged =
        _activeEntryId != entry.id || _activeDescriptor != entry.descriptor;
    _entries[entry.id] = entry.descriptor;
    _activeEntryId = entry.id;
    _activeDescriptor = entry.descriptor;
    _publishResolvedMode(routeChanged: routeChanged);
  }

  void reveal(AppRouteEntry entry) {
    final routeChanged =
        _activeEntryId != entry.id || _activeDescriptor != entry.descriptor;
    _entries[entry.id] = entry.descriptor;
    _activeEntryId = entry.id;
    _activeDescriptor = entry.descriptor;
    _publishResolvedMode(routeChanged: routeChanged);
  }

  void remove(AppRouteEntry entry, {AppRouteEntry? revealed}) {
    _entries.remove(entry.id);
    _overrides.remove(entry.id);
    _contextualBottomSlots.remove(entry.id);
    if (revealed != null) {
      reveal(revealed);
    } else if (_activeEntryId == entry.id) {
      _activeEntryId = null;
      _activeDescriptor = rootDescriptor;
      _publishResolvedMode();
    }
  }

  void request(String entryId, ReaderChromeMode mode) {
    if (_activeEntryId != entryId || !_entries.containsKey(entryId)) return;
    _overrides[entryId] = mode;
    _publishResolvedMode();
  }

  void resetActiveOverride() {
    final entryId = _activeEntryId;
    if (entryId != null) _overrides.remove(entryId);
    _publishResolvedMode();
  }

  void resetEntry(AppRouteEntry entry) {
    if (_activeEntryId != entry.id) return;
    _overrides.remove(entry.id);
    _contextualBottomSlots.remove(entry.id);
    activate(entry);
  }

  void requestContextualBottomSlot(String entryId, {required bool visible}) {
    if (_activeEntryId != entryId || !_entries.containsKey(entryId)) return;
    final changed = visible
        ? _contextualBottomSlots.add(entryId)
        : _contextualBottomSlots.remove(entryId);
    if (changed) notifyListeners();
  }

  void _publishResolvedMode({bool routeChanged = false}) {
    final resolved = _activeEntryId == null
        ? _activeDescriptor.defaultChromeMode
        : _overrides[_activeEntryId] ?? _activeDescriptor.defaultChromeMode;
    if (value != resolved) {
      value = resolved;
    } else if (routeChanged) {
      // Shell chrome depends on the active descriptor and owner as well as on
      // the coarse Full/Compact/Hidden value. Publish Full -> Full route
      // changes so local Back controls cannot be covered by stale shell chrome.
      notifyListeners();
    }
  }
}

class BranchRouteObserver extends NavigatorObserver {
  BranchRouteObserver(this.controller);

  final BranchShellController controller;

  void _updateController(VoidCallback update) {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // Navigator observers also run while branch Navigators are mounting.
      // Their shell listeners must not rebuild ancestors during that build.
      binding.addPostFrameCallback((_) {
        if (navigator?.mounted != true) return;
        update();
      });
    } else {
      update();
    }
  }

  AppRouteEntry? _entry(Route<dynamic>? route) =>
      route?.settings.arguments is AppRouteEntry
      ? route!.settings.arguments! as AppRouteEntry
      : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final entry = _entry(route);
    if (entry != null) _updateController(() => controller.activate(entry));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final entry = _entry(route);
    if (entry != null) {
      final revealed = _entry(previousRoute);
      _updateController(() => controller.remove(entry, revealed: revealed));
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    final entry = _entry(route);
    if (entry != null) {
      final revealed = _entry(previousRoute);
      _updateController(() => controller.remove(entry, revealed: revealed));
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final oldEntry = _entry(oldRoute);
    final newEntry = _entry(newRoute);
    _updateController(() {
      if (oldEntry != null) controller.remove(oldEntry);
      if (newEntry != null) controller.activate(newEntry);
    });
  }
}

class AppShellState extends ChangeNotifier {
  AppShellState({required List<AppRouteDescriptor> roots})
    : assert(roots.length == AppBranch.values.length),
      branches = {
        for (final descriptor in roots)
          descriptor.branch: BranchShellController(
            descriptor.branch,
            descriptor,
          ),
      } {
    for (final controller in branches.values) {
      controller.addListener(notifyListeners);
    }
  }

  final Map<AppBranch, BranchShellController> branches;
  AppBranch _activeBranch = AppBranch.hours;
  OraReturnToken? _oraReturnToken;

  AppBranch get activeBranch => _activeBranch;
  BranchShellController get activeController => branches[_activeBranch]!;
  OraReturnToken? get oraReturnToken => _oraReturnToken;

  void setActiveBranch(AppBranch branch) {
    if (_activeBranch == branch) return;
    _activeBranch = branch;
    notifyListeners();
  }

  void rememberOraReturn() {
    final hours = branches[AppBranch.hours]!;
    final entryId = hours.activeEntryId;
    if (entryId == null) return;
    _oraReturnToken = OraReturnToken(hoursEntryId: entryId);
    notifyListeners();
  }

  bool canReturnToOra() {
    final token = _oraReturnToken;
    return token != null &&
        branches[AppBranch.hours]!.containsEntry(token.hoursEntryId);
  }

  void clearOraReturn() {
    if (_oraReturnToken == null) return;
    _oraReturnToken = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in branches.values) {
      controller
        ..removeListener(notifyListeners)
        ..dispose();
    }
    super.dispose();
  }
}

@immutable
class OraReturnToken {
  const OraReturnToken({required this.hoursEntryId});

  final String hoursEntryId;
}

class AppRouteEntryAdapter extends StatefulWidget {
  const AppRouteEntryAdapter({
    super.key,
    required this.entry,
    required this.controller,
    required this.child,
  });

  final AppRouteEntry entry;
  final BranchShellController controller;
  final Widget child;

  @override
  State<AppRouteEntryAdapter> createState() => _AppRouteEntryAdapterState();
}

class _AppRouteEntryAdapterState extends State<AppRouteEntryAdapter> {
  late _RouteChromeController _readerController;

  @override
  void initState() {
    super.initState();
    _readerController = _RouteChromeController(widget.controller, widget.entry);
  }

  @override
  void didUpdateWidget(covariant AppRouteEntryAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id == widget.entry.id &&
        oldWidget.controller == widget.controller) {
      if (oldWidget.entry.documentKey != widget.entry.documentKey) {
        widget.controller.resetEntry(widget.entry);
      }
      return;
    }
    _readerController.dispose();
    _readerController = _RouteChromeController(widget.controller, widget.entry);
  }

  @override
  void dispose() {
    _readerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _readerController,
    child: widget.child,
    builder: (context, child) {
      final hidden = _readerController.value == ReaderChromeMode.hidden;
      return PopScope<void>(
        canPop: !hidden,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && hidden) {
            _readerController.value = ReaderChromeMode.compact;
          }
        },
        child: AppRouteEntryScope(
          entry: widget.entry,
          controller: widget.controller,
          child: ReaderChromeModeScope(
            controller: _readerController,
            child: child!,
          ),
        ),
      );
    },
  );
}

class AppRouteEntryScope extends InheritedWidget {
  const AppRouteEntryScope({
    super.key,
    required this.entry,
    required this.controller,
    required super.child,
  });

  final AppRouteEntry entry;
  final BranchShellController controller;

  static AppRouteEntryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppRouteEntryScope>();

  void showContextualBottomBar(bool visible) =>
      controller.requestContextualBottomSlot(entry.id, visible: visible);

  @override
  bool updateShouldNotify(AppRouteEntryScope oldWidget) =>
      entry.id != oldWidget.entry.id || controller != oldWidget.controller;
}

class _RouteChromeController extends ReaderChromeModeController {
  _RouteChromeController(this.branchController, this.entry)
    : super(entry.descriptor.defaultChromeMode) {
    branchController.addListener(_syncFromBranch);
    _syncFromBranch();
  }

  final BranchShellController branchController;
  final AppRouteEntry entry;
  bool _syncing = false;

  @override
  set value(ReaderChromeMode newValue) {
    if (_syncing) {
      super.value = newValue;
      return;
    }
    branchController.request(entry.id, newValue);
  }

  void _syncFromBranch() {
    if (branchController.activeEntryId != entry.id) return;
    _syncing = true;
    super.value = branchController.value;
    _syncing = false;
  }

  @override
  void dispose() {
    branchController.removeListener(_syncFromBranch);
    super.dispose();
  }
}

class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    super.key,
    required this.shell,
    required this.shellState,
    required super.child,
  });

  final StatefulNavigationShell shell;
  final AppShellState shellState;

  static AppNavigationScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppNavigationScope>();
    assert(scope != null, 'AppNavigationScope is missing');
    return scope!;
  }

  static AppNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();

  void selectBranch(AppBranch branch) {
    shellState.clearOraReturn();
    final index = branch.index;
    final repeated = shell.currentIndex == index;
    if (repeated) shellState.branches[branch]!.resetActiveOverride();
    shell.goBranch(index, initialLocation: repeated);
  }

  void openReadingsFromOra(
    BuildContext context, {
    required DateTime date,
    required String dayId,
  }) {
    shellState.rememberOraReturn();
    GoRouter.of(context).go(readingsLocation(date: date, dayId: dayId));
  }

  bool returnToOra() {
    if (!shellState.canReturnToOra()) {
      shellState.clearOraReturn();
      return false;
    }
    shellState.clearOraReturn();
    shell.goBranch(AppBranch.hours.index);
    return true;
  }

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) =>
      shell != oldWidget.shell || shellState != oldWidget.shellState;
}

String readingsLocation({required DateTime date, String? dayId}) {
  final dateKey = _dateKey(date);
  final query = <String, String>{'date': dateKey};
  if (dayId != null && dayId.trim().isNotEmpty) query['dayId'] = dayId.trim();
  return Uri(path: '/readings', queryParameters: query).toString();
}

String bibleLocation({
  required String version,
  required String book,
  required int chapter,
  int? verse,
}) => Uri(
  path: '/bible',
  queryParameters: {
    'version': version,
    'book': book,
    'chapter': '$chapter',
    if (verse != null) 'verse': '$verse',
  },
).toString();

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
