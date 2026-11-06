import 'package:mybrev_flutter/theme/app_theme_preference.dart';
// iOS visual audit harness (Codemagic + iOS Simulator).
//
// Runs the real app (Firebase, Hive, sync, shell and dock) and walks key
// states. At each state it prints `AUDIT_SHOT::<name>` and holds the frame;
// `scripts/ios_visual_audit.sh` captures the real simulator screen (status bar
// and home indicator included) with `xcrun simctl io screenshot`.
//
// Pass selection: --dart-define=AUDIT_PASS=main|dark|compact|large-text
//
// Audit infrastructure only: no production behaviour is changed. States that
// cannot be reached are logged as `AUDIT_BLOCKED::<name>::<reason>`.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';

const _pass = String.fromEnvironment('AUDIT_PASS', defaultValue: 'main');
const _massPrayerId = 'eMmCtxwyJ75ogmL5rwye';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Render continuously so the simulator shows the real frame when captured.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('iOS visual audit ($_pass)', (tester) async {
    final audit = _Audit(tester);
    app.main();
    await audit.waitFor(
      find.byKey(const Key('app-dock-full')),
      const Duration(seconds: 60),
      'app shell',
    );
    // First launch syncs today's liturgical data; give it time to arrive.
    await audit.waitFor(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('hours-hour-'),
      ),
      const Duration(seconds: 150),
      'hours list',
    );
    audit.log('AUDIT_INFO::textScale=${audit.textScale}');

    switch (_pass) {
      case 'dark':
        appThemePreferenceController.value = AppThemePreference.dark;
        await audit.settle();
        await audit.darkPass();
      case 'compact':
        await audit.compactPass();
      case 'large-text':
        await audit.largeTextPass();
      default:
        appThemePreferenceController.value = AppThemePreference.light;
        await audit.settle();
        await audit.mainPass();
    }
    audit.log('AUDIT_DONE::$_pass');
  }, timeout: const Timeout(Duration(minutes: 25)));
}

class _Audit {
  _Audit(this.tester);

  final WidgetTester tester;

  double get textScale {
    final context = tester.element(find.byType(Navigator).first);
    return MediaQuery.textScalerOf(context).scale(1);
  }

  void log(String line) {
    // ignore: avoid_print
    print(line);
  }

  /// Pumps real frames for [duration] without requiring animations to stop.
  Future<void> settle([
    Duration duration = const Duration(milliseconds: 1400),
  ]) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<bool> waitFor(Finder finder, Duration timeout, String label) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    log('AUDIT_BLOCKED::$label::not visible after ${timeout.inSeconds}s');
    return false;
  }

  Future<void> shot(String name) async {
    await settle(const Duration(milliseconds: 900));
    log('AUDIT_SHOT::$name');
    // The host captures the simulator while this frame is held.
    await settle(const Duration(milliseconds: 3200));
  }

  Future<void> go(String location) async {
    router.go(location);
    await settle(const Duration(milliseconds: 1800));
  }

  Future<void> push(String location) async {
    router.push(location);
    await settle(const Duration(milliseconds: 1800));
  }

  Future<bool> tapKey(String key, String state) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      log('AUDIT_BLOCKED::$state::missing $key');
      return false;
    }
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first, warnIfMissed: false);
    await settle();
    return true;
  }

  Future<void> back() async {
    await tester.binding.handlePopRoute();
    await settle();
  }

  Finder get _mainScrollable => find.byType(Scrollable).hitTestable();

  Future<void> scrollBy(double dy) async {
    final scrollable = _mainScrollable;
    if (scrollable.evaluate().isEmpty) return;
    final state = tester.state<ScrollableState>(scrollable.first);
    final position = state.position;
    position.jumpTo(
      (position.pixels + dy).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await settle(const Duration(milliseconds: 600));
  }

  /// Lazy lists refine their extent after reaching the end; repeat.
  Future<void> scrollToEnd() async {
    for (var i = 0; i < 6; i++) {
      final scrollable = _mainScrollable;
      if (scrollable.evaluate().isEmpty) return;
      final position = tester.state<ScrollableState>(scrollable.first).position;
      if (i > 0 && position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(position.maxScrollExtent);
      await settle(const Duration(milliseconds: 500));
    }
    await settle(const Duration(milliseconds: 600));
  }

  Future<void> scrollFraction(double fraction) async {
    final scrollable = _mainScrollable;
    if (scrollable.evaluate().isEmpty) return;
    final position = tester.state<ScrollableState>(scrollable.first).position;
    position.jumpTo(position.maxScrollExtent * fraction);
    await settle(const Duration(milliseconds: 700));
  }

  Future<void> scrollToTop() async {
    final scrollable = _mainScrollable;
    if (scrollable.evaluate().isEmpty) return;
    tester.state<ScrollableState>(scrollable.first).position.jumpTo(0);
    await settle(const Duration(milliseconds: 500));
  }

  Future<void> doubleTapReader(String state) async {
    final surface = find.byKey(const Key('reader-double-tap-surface'));
    if (surface.evaluate().isEmpty) {
      log('AUDIT_BLOCKED::$state::no reader double-tap surface');
      return;
    }
    final center = tester.getCenter(surface.first);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await settle();
  }

  String? _hourKey(List<String> preferred) {
    final keys = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('hours-hour-'),
        )
        .evaluate()
        .map((e) => (e.widget.key! as ValueKey<String>).value)
        .toSet();
    for (final type in preferred) {
      if (keys.contains('hours-hour-$type')) return 'hours-hour-$type';
    }
    return keys.isEmpty ? null : keys.first;
  }

  /// Taps the first sentence of the first long reading paragraph.
  Future<bool> selectReadingText(String state, Finder within) async {
    final paragraphs = find
        .descendant(of: within, matching: find.byType(RichText))
        .evaluate()
        .where((e) {
          final render = e.renderObject;
          return render is RenderParagraph &&
              render.text.toPlainText().length > 80;
        })
        .toList();
    if (paragraphs.isEmpty) {
      log('AUDIT_BLOCKED::$state::no reading paragraph');
      return false;
    }
    final paragraph = paragraphs.first.renderObject! as RenderParagraph;
    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
    if (boxes.isEmpty) return false;
    await tester.tapAt(paragraph.localToGlobal(boxes.first.toRect().center));
    await settle();
    return true;
  }

  // ---------------------------------------------------------------- passes

  Future<void> mainPass() async {
    // A. Hours
    await go('/hours');
    await scrollToTop();
    await shot('01-hours-root');
    await shot('dock-light');
    await scrollToEnd();
    await shot('02-hours-bottom');
    await scrollToTop();
    if (await tapKey('hours-date-action', '22-sheet-date')) {
      await shot('22-sheet-date');
      await back();
    }
    if (await tapKey('hours-alternatives-control', '23-sheet-alternatives')) {
      await shot('23-sheet-alternatives');
      await back();
    }

    // B. Ora (a long hour)
    await openOra();
    await shot('03-ora-top');
    await scrollFraction(0.45);
    await shot('04-ora-middle');
    await scrollToEnd();
    await shot('05-ora-bottom');
    await scrollFraction(0.25);
    await shot('06-ora-compact');
    await doubleTapReader('07-ora-hidden');
    await shot('07-ora-hidden');
    await doubleTapReader('07-ora-hidden-restore');

    // C. Readings
    await go('/readings');
    await scrollToTop();
    await shot('08-readings-root');
    final cycle = find.byKey(const Key('readings-cycle-metadata'));
    if (cycle.evaluate().isNotEmpty) {
      await tester.ensureVisible(cycle.first);
      await settle();
      await shot('09-readings-cycle');
      await tester.tap(cycle.first, warnIfMissed: false);
      await settle();
      await shot('09b-readings-cycle-manual');
      await back();
    } else {
      log('AUDIT_BLOCKED::09-readings-cycle::no cycle metadata today');
    }
    await scrollFraction(0.2);
    if (await selectReadingText(
      '10-readings-selection',
      find.byKey(const Key('readings-root-scroll')),
    )) {
      await shot('10-readings-selection');
      await tapKey('readings-highlight-cancel', '10-readings-selection');
    }
    if (await tapKey('readings-options-action', 'readings-options')) {
      await shot('23b-sheet-readings-options');
      await back();
    }
    await scrollToEnd();
    await shot('11-readings-bottom');

    // D. Prayerbook
    await go('/prayers');
    await scrollToTop();
    await shot('12-prayerbook-root');
    await scrollToEnd();
    await shot('13-prayerbook-bottom');

    // E. Prayer search
    await go('/prayers/all');
    await shot('14-prayer-search-closed');
    final field = find.byKey(const Key('prayer-search-field'));
    if (field.evaluate().isNotEmpty) {
      await tester.tap(field.first, warnIfMissed: false);
      // The software keyboard animates in on the simulator.
      await settle(const Duration(milliseconds: 1800));
      await shot('15-prayer-search-keyboard');
      await tester.enterText(field.first, 'малітва');
      await settle();
      await shot('16-prayer-search-results');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(const Duration(milliseconds: 1500));
      await shot('16b-prayer-search-dismissed');
    } else {
      log('AUDIT_BLOCKED::15-prayer-search-keyboard::missing search field');
    }

    // F. Prayer detail (Holy Mass: long Markdown content)
    await go('/prayers');
    await push('/prayers/prayer/$_massPrayerId');
    await shot('17-prayer-detail');
    if (await tapKey('app-overflow-open', '25-reader-menu')) {
      await tester.tap(find.text('Шрыфт'));
      await settle();
      await shot('25-sheet-text-size');
      await back();
    }
    await scrollToEnd();
    await shot('18-prayer-detail-bottom');

    // G. Bible
    await bible('19-bible-reader', '20-bible-selection', '21-bible-bottom');
    await scrollToTop();
    if (await tapKey('bible-book-chapter-picker', '24-sheet-bible')) {
      await shot('24-sheet-bible');
      await back();
    }
  }

  Future<void> openOra() async {
    await go('/hours');
    await scrollToTop();
    final key = _hourKey(['lectionis', 'laudes', 'vespers', 'completorium']);
    if (key == null) {
      log('AUDIT_BLOCKED::03-ora-top::no hour tiles');
      return;
    }
    await tapKey(key, '03-ora-top');
    await settle(const Duration(milliseconds: 2500));
    log('AUDIT_INFO::ora=$key');
  }

  Future<void> bible(String reader, String selection, String bottom) async {
    await go('/bible');
    await settle(const Duration(milliseconds: 2500));
    await shot(reader);
    final verse = find.byKey(const Key('bible-verse-3'));
    if (verse.evaluate().isNotEmpty) {
      await tester.ensureVisible(verse.first);
      await tester.tap(verse.first, warnIfMissed: false);
      await settle();
      await shot(selection);
      await tapKey('bible-highlight-cancel', selection);
    } else {
      log('AUDIT_BLOCKED::$selection::no verse 3');
    }
    await scrollToEnd();
    await shot(bottom);
  }

  Future<void> darkPass() async {
    await go('/hours');
    await scrollToTop();
    await shot('dark-01-hours-root');
    await shot('dock-dark');
    if (await tapKey('hours-date-action', 'dark-sheet-date')) {
      await shot('dark-22-sheet-date');
      await back();
    }
    await openOra();
    await scrollFraction(0.35);
    await shot('dark-04-ora-middle');
    await doubleTapReader('dark-07-ora-hidden');
    await shot('dark-07-ora-hidden');
    await doubleTapReader('dark-07-ora-hidden-restore');
    await go('/readings');
    await scrollFraction(0.2);
    if (await selectReadingText(
      'dark-10-readings-selection',
      find.byKey(const Key('readings-root-scroll')),
    )) {
      await shot('dark-10-readings-selection');
      await tapKey('readings-highlight-cancel', 'dark-10-readings-selection');
    }
    await scrollToEnd();
    await shot('dark-11-readings-bottom');
    await go('/prayers');
    await scrollToTop();
    await shot('dark-12-prayerbook-root');
    await bible(
      'dark-19-bible-reader',
      'dark-20-bible-selection',
      'dark-21-bible-bottom',
    );
  }

  /// Small iPhone: search, dock, cycle metadata, Bible palette, one sheet.
  Future<void> compactPass() async {
    await go('/hours');
    await scrollToTop();
    await shot('compact-dock');
    if (await tapKey('hours-date-action', 'compact-sheet-date')) {
      await shot('compact-sheet-date');
      await back();
    }
    await go('/readings');
    final cycle = find.byKey(const Key('readings-cycle-metadata'));
    if (cycle.evaluate().isNotEmpty) {
      await tester.ensureVisible(cycle.first);
      await settle();
      await shot('compact-readings-cycle');
    }
    await go('/prayers/all');
    final field = find.byKey(const Key('prayer-search-field'));
    if (field.evaluate().isNotEmpty) {
      await tester.tap(field.first, warnIfMissed: false);
      await settle(const Duration(milliseconds: 1800));
      await shot('compact-prayer-search-keyboard');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
    }
    await go('/bible');
    await settle(const Duration(milliseconds: 2500));
    final verse = find.byKey(const Key('bible-verse-3'));
    if (verse.evaluate().isNotEmpty) {
      await tester.tap(verse.first, warnIfMissed: false);
      await settle();
      await shot('compact-bible-selection');
      await tapKey('bible-highlight-cancel', 'compact-bible-selection');
    }
  }

  /// Enlarged Dynamic Type: dock, metadata, sheet, search, reader.
  Future<void> largeTextPass() async {
    await go('/hours');
    await scrollToTop();
    await shot('large-01-hours-dock');
    if (await tapKey('hours-date-action', 'large-sheet-date')) {
      await shot('large-22-sheet-date');
      await back();
    }
    await go('/readings');
    await scrollToTop();
    await shot('large-08-readings');
    await go('/prayers/all');
    await shot('large-14-prayer-search');
    await go('/prayers');
    await push('/prayers/prayer/$_massPrayerId');
    await shot('large-17-prayer-detail');
  }
}
