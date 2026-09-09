import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

const _hoursRoot = AppRouteDescriptor(
  id: 'hours.root',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.shell,
  isBranchRoot: true,
);
const _ora = AppRouteDescriptor(
  id: 'hours.ora',
  branch: AppBranch.hours,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.reader,
);
const _readingsRoot = AppRouteDescriptor(
  id: 'readings.root',
  branch: AppBranch.readings,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
  isBranchRoot: true,
);
const _prayerbookRoot = AppRouteDescriptor(
  id: 'prayerbook.root',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.shell,
  isBranchRoot: true,
);
const _prayerList = AppRouteDescriptor(
  id: 'prayerbook.list',
  branch: AppBranch.prayerbook,
  defaultChromeMode: ReaderChromeMode.full,
  topChromeOwner: TopChromeOwner.legacy,
);
const _bibleRoot = AppRouteDescriptor(
  id: 'bible.root',
  branch: AppBranch.bible,
  defaultChromeMode: ReaderChromeMode.compact,
  topChromeOwner: TopChromeOwner.legacy,
  isBranchRoot: true,
);

void main() {
  test(
    'route entry owns Full Compact Hidden and pop restores previous mode',
    () {
      final shell = AppShellState(
        roots: const [_hoursRoot, _readingsRoot, _prayerbookRoot, _bibleRoot],
      );
      addTearDown(shell.dispose);
      final hours = shell.branches[AppBranch.hours]!;
      const rootEntry = AppRouteEntry(id: 'root-1', descriptor: _hoursRoot);
      const oraEntry = AppRouteEntry(id: 'ora-1', descriptor: _ora);

      hours.activate(rootEntry);
      expect(hours.value, ReaderChromeMode.full);
      hours.activate(oraEntry);
      expect(hours.value, ReaderChromeMode.compact);
      hours.request(oraEntry.id, ReaderChromeMode.hidden);
      expect(hours.value, ReaderChromeMode.hidden);

      hours.resetEntry(
        const AppRouteEntry(
          id: 'ora-1',
          descriptor: _ora,
          documentKey: 'next-hour',
        ),
      );
      expect(
        hours.value,
        ReaderChromeMode.compact,
        reason: 'a new document starts from its route default',
      );
      hours.request(oraEntry.id, ReaderChromeMode.hidden);

      hours.remove(oraEntry, revealed: rootEntry);
      expect(hours.value, ReaderChromeMode.full);
      hours.request(oraEntry.id, ReaderChromeMode.hidden);
      expect(
        hours.value,
        ReaderChromeMode.full,
        reason: 'stale reader ignored',
      );
    },
  );

  test('each branch owns an independent chrome controller', () {
    final shell = AppShellState(
      roots: const [_hoursRoot, _readingsRoot, _prayerbookRoot, _bibleRoot],
    );
    addTearDown(shell.dispose);
    shell.branches[AppBranch.hours]!
      ..activate(const AppRouteEntry(id: 'ora', descriptor: _ora))
      ..request('ora', ReaderChromeMode.hidden);

    expect(shell.branches[AppBranch.readings]!.value, ReaderChromeMode.full);
    expect(shell.branches[AppBranch.bible]!.value, ReaderChromeMode.compact);
  });

  test('Full to Full route change publishes descriptor ownership', () {
    final shell = AppShellState(
      roots: const [_hoursRoot, _readingsRoot, _prayerbookRoot, _bibleRoot],
    );
    addTearDown(shell.dispose);
    final prayerbook = shell.branches[AppBranch.prayerbook]!;
    var notifications = 0;
    prayerbook.addListener(() => notifications++);

    const root = AppRouteEntry(
      id: 'prayerbook-root',
      descriptor: _prayerbookRoot,
    );
    const list = AppRouteEntry(id: 'prayer-list', descriptor: _prayerList);
    prayerbook.activate(root);
    notifications = 0;
    prayerbook.activate(list);

    expect(prayerbook.value, ReaderChromeMode.full);
    expect(prayerbook.activeEntryId, list.id);
    expect(prayerbook.activeDescriptor.topChromeOwner, TopChromeOwner.legacy);
    expect(notifications, 1);

    notifications = 0;
    prayerbook.remove(list, revealed: root);
    expect(prayerbook.activeDescriptor.topChromeOwner, TopChromeOwner.shell);
    expect(notifications, 1);
  });

  test('contextual bottom slot does not change the reader chrome mode', () {
    final shell = AppShellState(
      roots: const [_hoursRoot, _readingsRoot, _prayerbookRoot, _bibleRoot],
    );
    addTearDown(shell.dispose);
    final hours = shell.branches[AppBranch.hours]!;
    const oraEntry = AppRouteEntry(id: 'ora', descriptor: _ora);
    hours.activate(oraEntry);

    hours.requestContextualBottomSlot(oraEntry.id, visible: true);
    expect(hours.navigationDockSuppressed, isTrue);
    expect(hours.value, ReaderChromeMode.compact);

    hours.requestContextualBottomSlot(oraEntry.id, visible: false);
    expect(hours.navigationDockSuppressed, isFalse);
    expect(hours.value, ReaderChromeMode.compact);
  });

  test('Ora return token is valid only while its route entry exists', () {
    final shell = AppShellState(
      roots: const [_hoursRoot, _readingsRoot, _prayerbookRoot, _bibleRoot],
    );
    addTearDown(shell.dispose);
    final hours = shell.branches[AppBranch.hours]!;
    const oraEntry = AppRouteEntry(id: 'ora-1', descriptor: _ora);
    hours.activate(oraEntry);
    shell.rememberOraReturn();
    expect(shell.canReturnToOra(), isTrue);

    hours.remove(oraEntry);
    expect(shell.canReturnToOra(), isFalse);
  });
}
