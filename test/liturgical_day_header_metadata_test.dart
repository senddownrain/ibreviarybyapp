import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/discovery/tour/tour_anchor_finder.dart';
import 'package:mybrev_flutter/discovery/tour/tour_steps.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/widgets/liturgical_day_header.dart';

void main() {
  setUpAll(() => initializeDateFormatting('be'));

  Future<void> showHeader(
    WidgetTester tester, {
    required LiturgicalDayPresentation presentation,
    String? metadata,
    double width = 390,
    String keyPrefix = 'hours',
    VoidCallback? onVariants,
    bool showVariants = true,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiturgicalDayHeader(
              sectionTitle: 'Літургія гадзінаў',
              keyPrefix: keyPrefix,
              presentation: presentation,
              metadata: metadata,
              onDateTap: () {},
              onPrevious: () {},
              onNext: () {},
              onVariants: onVariants ?? () {},
              showVariants: showVariants,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LiturgicalDayPresentation sample({
    DateTime? date,
    String rank = 'Успамін',
    String place = '',
    List<String> badges = const [],
    String contextMetadata = 'IV тыдзень Псалтыра',
  }) => LiturgicalDayPresentation(
    date: date ?? DateTime(2026, 11, 10),
    title: 'Св. Льва Вялікага, Папы і доктара Касцёла',
    rank: rank,
    accent: Colors.white,
    place: place,
    badges: badges,
    contextMetadata: contextMetadata,
  );

  testWidgets('shows celebration rank but not the psalter week in daily header', (
    tester,
  ) async {
    await showHeader(tester, presentation: sample());
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    expect(
      text.textSpan!.toPlainText(),
      'Успамін · Аўторак',
    );
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });

  testWidgets('preserves readings-specific cycle metadata', (tester) async {
    await showHeader(
      tester,
      presentation: sample(),
      metadata: 'Аўторак · Год II',
    );
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    expect(text.textSpan!.toPlainText(), 'Успамін · Аўторак · Год II');
    tester.view.reset();
  });

  testWidgets('uses full Minsk diocese name above the title, no chips', (
    tester,
  ) async {
    await showHeader(
      tester,
      presentation: sample(
        place: 'Мінска-Магілёўская архідыяцэзія',
        badges: const ['Мінск'],
      ),
    );
    expect(find.text('Мінска-Магілёўская архідыяцэзія'), findsOneWidget);
    expect(find.text('Мінск'), findsNothing);
    expect(find.byType(Chip), findsNothing);
    expect(find.byKey(const Key('hours-celebration-dioceses')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Мінска-Магілёўская архідыяцэзія')).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('hours-celebration-title'))).dy),
    );
    tester.view.reset();
  });

  testWidgets('preserves a Vitebsk-specific rank and locality', (
    tester,
  ) async {
    await showHeader(
      tester,
      presentation: sample(
        date: DateTime(2026, 11, 12),
        rank: 'Урачыстасць',
        place: 'Віцебская дыяцэзія',
        badges: const ['Віцебск'],
        contextMetadata: '',
      ),
    );
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    expect(text.textSpan!.toPlainText(), 'Урачыстасць · Чацвер');
    expect(find.text('Віцебская дыяцэзія'), findsOneWidget);
    expect(find.text('Віцебск'), findsNothing);
    expect(find.byType(Chip), findsNothing);
    tester.view.reset();
  });

  testWidgets('keeps diocese difference when locality is not supplied', (
    tester,
  ) async {
    await showHeader(
      tester,
      presentation: sample(
        place: '',
        badges: const ['Мінск', 'Віцебск'],
      ),
    );
    expect(
      find.text('Мінска-Магілёўская архідыяцэзія · Віцебская дыяцэзія'),
      findsOneWidget,
    );
    expect(find.byType(Chip), findsNothing);
    tester.view.reset();
  });

  testWidgets('ordinary shared day has no diocese label or chips', (
    tester,
  ) async {
    await showHeader(
      tester,
      presentation: sample(rank: 'Будні дзень', place: '', badges: const []),
    );
    expect(find.byKey(const Key('hours-celebration-dioceses')), findsNothing);
    expect(find.byType(Chip), findsNothing);
    tester.view.reset();
  });

  testWidgets('ordinary weekday stays prominent without a rank', (
    tester,
  ) async {
    await showHeader(
      tester,
      presentation: sample(
        rank: 'Будні дзень',
        contextMetadata: 'IV тыдзень Псалтыра',
      ),
    );
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    expect(text.textSpan!.toPlainText(), 'Аўторак');
    final emphasis = (text.textSpan! as TextSpan).children!.first as TextSpan;
    expect(emphasis.text, 'Аўторак');
    expect(emphasis.style?.fontWeight, FontWeight.w600);
    tester.view.reset();
  });

  testWidgets('memorial rank is prominent, while weekday is secondary', (
    tester,
  ) async {
    await showHeader(tester, presentation: sample());
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    final emphasis = (text.textSpan! as TextSpan).children!.first as TextSpan;
    expect(emphasis.text, 'Успамін');
    expect(emphasis.style?.fontWeight, FontWeight.w600);
    tester.view.reset();
  });

  testWidgets('does not repeat Sunday as the liturgical rank', (tester) async {
    await showHeader(
      tester,
      presentation: sample(
        date: DateTime(2026, 11, 8),
        rank: 'Нядзеля',
        contextMetadata: 'IV тыдзень Псалтыра',
      ),
    );
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    expect(text.textSpan!.toPlainText(), 'Нядзеля');
    tester.view.reset();
  });
  testWidgets('whole liturgical day is a quiet tap target, not a button chip', (
    tester,
  ) async {
    var taps = 0;
    await showHeader(
      tester,
      presentation: sample(rank: 'Будні дзень'),
      onVariants: () => taps++,
    );
    final action = find.byKey(const Key('hours-alternatives-control'));
    final title = find.byKey(const Key('hours-celebration-title'));
    final metadata = find.byKey(const Key('hours-day-metadata'));
    final edit = find.byKey(const Key('hours-celebration-edit-icon'));
    expect(action, findsOneWidget);
    expect(find.text('Варыянты'), findsNothing);
    expect(edit, findsOneWidget);
    expect(tester.getRect(action).contains(tester.getCenter(title)), isTrue);
    expect(tester.getRect(action).contains(tester.getCenter(metadata)), isTrue);
    expect(
      (tester.getRect(edit).center.dy - tester.getRect(metadata).center.dy).abs(),
      lessThan(15),
    );
    final surface = tester.widget<Ink>(
      find.descendant(of: action, matching: find.byType(Ink)),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.color!.a, closeTo(0.025, 0.0001));
    final inkWell = tester.widget<InkWell>(action);
    expect(inkWell.overlayColor!.resolve({WidgetState.pressed})!.a,
        closeTo(0.08, 0.0001));
    expect(inkWell.overlayColor!.resolve({WidgetState.hovered})!.a,
        closeTo(0.04, 0.0001));
    expect(inkWell.overlayColor!.resolve({}), isNull);
    await tester.tap(title);
    expect(taps, 1);
    await tester.tap(edit);
    expect(taps, 2);
    final card = tester.getRect(action);
    await tester.tapAt(Offset(card.left + 3, card.center.dy));
    await tester.tapAt(Offset(card.right - 3, card.center.dy));
    expect(taps, 4);
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });

  testWidgets('long feast and metadata fit at narrow width; tour targets full day', (
    tester,
  ) async {
    await showHeader(
      tester,
      width: 280,
      keyPrefix: 'readings',
      presentation: sample(rank: 'Урачыстасць'),
      metadata: 'Аўторак · Год II',
    );
    final action = find.byKey(const Key('readings-alternatives-control'));
    final title = find.byKey(const Key('readings-celebration-title'));
    final metadata = find.byKey(const Key('readings-day-metadata'));
    expect(action, findsOneWidget);
    expect(tester.getRect(action).contains(tester.getCenter(title)), isTrue);
    expect(tester.getRect(action).contains(tester.getCenter(metadata)), isTrue);
    expect(
      tester.getRect(find.byKey(const Key('readings-celebration-edit-icon'))).right,
      lessThanOrEqualTo(tester.view.physicalSize.width),
    );
    final tourVariants = defaultTourSteps.singleWhere(
      (step) => step.id == 'tour.variants',
    );
    expect(tourVariants.anchors, hasLength(1));
    expect(tourVariants.spotlightPadding, 0);
    expect(
      tourVariants.anchors.single.test('readings-alternatives-control'),
      isTrue,
    );
    expect(tourVariants.anchors.single.test('readings-celebration-title'),
        isFalse);
    final spotlight = resolveStepRect(
      tester.element(find.byType(LiturgicalDayHeader)),
      tourVariants,
    );
    final heading = tester.widget<Text>(
      find.descendant(of: title, matching: find.byType(Text)),
    );
    expect(heading.style!.fontSize, 29);
    expect(heading.textScaler!.scale(29), 29);
    expect(heading.maxLines, isNull);
    expect(spotlight, tester.getRect(action),
        reason: 'The tour must spotlight the WHOLE tappable day.');
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });

  testWidgets('nonselectable celebration has no edit glyph or tap action', (
    tester,
  ) async {
    var taps = 0;
    await showHeader(
      tester,
      presentation: sample(rank: 'Будні дзень'),
      showVariants: false,
      onVariants: () => taps++,
    );
    expect(find.byKey(const Key('hours-alternatives-control')), findsNothing);
    expect(find.byKey(const Key('hours-celebration-edit-icon')), findsNothing);
    final tourVariants = defaultTourSteps.singleWhere(
      (step) => step.id == 'tour.variants',
    );
    expect(
      resolveStepRect(
        tester.element(find.byType(LiturgicalDayHeader)),
        tourVariants,
      ),
      isNull,
      reason: 'An unavailable selector must not spotlight a dead title.',
    );
    await tester.tap(find.byKey(const Key('hours-celebration-title')));
    expect(taps, 0);
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });
  testWidgets('dark theme has a soft 3.5 percent selection surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiturgicalDayHeader(
              sectionTitle: 'Літургія гадзінаў',
              keyPrefix: 'hours',
              presentation: sample(rank: 'Будні дзень'),
              onDateTap: () {},
              onPrevious: () {},
              onNext: () {},
              onVariants: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('hours-alternatives-control'));
    final ink = tester.widget<Ink>(
      find.descendant(of: action, matching: find.byType(Ink)),
    );
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.color!.a, closeTo(0.035, 0.0001));
    expect(
      tester.widget<InkWell>(action)
          .overlayColor!.resolve({WidgetState.pressed})!.a,
      closeTo(0.08, 0.0001),
    );
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });

}
