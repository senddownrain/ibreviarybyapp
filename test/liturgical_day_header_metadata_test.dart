import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  testWidgets('compact variants control stays beside an ordinary weekday', (
    tester,
  ) async {
    var taps = 0;
    await showHeader(
      tester,
      presentation: sample(rank: 'Будні дзень'),
      onVariants: () => taps++,
    );
    final action = find.byKey(const Key('hours-alternatives-control'));
    final metadata = find.byKey(const Key('hours-day-metadata'));
    expect(action, findsOneWidget);
    expect(find.text('Варыянты'), findsOneWidget);
    expect(find.text('Іншыя варыянты'), findsNothing);
    expect(tester.getRect(action).left, greaterThan(tester.getRect(metadata).left));
    expect(
      (tester.getRect(action).center.dy - tester.getRect(metadata).center.dy).abs(),
      lessThan(12),
    );
    await tester.tap(action);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });

  testWidgets('long metadata wraps variants right without overflow', (
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
    final metadata = find.byKey(const Key('readings-day-metadata'));
    expect(action, findsOneWidget);
    expect(tester.getTopLeft(action).dy,
        greaterThan(tester.getBottomLeft(metadata).dy));
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });

}
