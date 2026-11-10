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
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiturgicalDayHeader(
              sectionTitle: 'Літургія гадзінаў',
              keyPrefix: 'hours',
              presentation: presentation,
              metadata: metadata,
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

  testWidgets('shows the selected celebration rank before psalter week', (
    tester,
  ) async {
    await showHeader(tester, presentation: sample());
    final text = tester.widget<Text>(
      find.byKey(const Key('hours-day-metadata')),
    );
    expect(
      text.textSpan!.toPlainText(),
      'Успамін · Аўторак · IV тыдзень Псалтыра',
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

  testWidgets('uses one short Minsk chip instead of full diocese text', (
    tester,
  ) async {
    await showHeader(
      tester,
      presentation: sample(
        place: 'Мінска-Магілёўская архідыяцэзія',
        badges: const ['Мінск'],
      ),
    );
    expect(find.text('Мінска-Магілёўская архідыяцэзія'), findsNothing);
    expect(find.text('Мінск'), findsOneWidget);
    expect(find.byType(Chip), findsOneWidget);
    expect(find.byKey(const Key('hours-celebration-dioceses')), findsOneWidget);
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
    expect(find.text('Віцебская дыяцэзія'), findsNothing);
    expect(find.text('Віцебск'), findsOneWidget);
    expect(find.byType(Chip), findsOneWidget);
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
    expect(find.text('Мінск'), findsOneWidget);
    expect(find.text('Віцебск'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(2));
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
    expect(text.textSpan!.toPlainText(), 'Аўторак · IV тыдзень Псалтыра');
    final emphasis = text.textSpan!.children!.first as TextSpan;
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
    final emphasis = text.textSpan!.children!.first as TextSpan;
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
    expect(text.textSpan!.toPlainText(), 'Нядзеля · IV тыдзень Псалтыра');
    tester.view.reset();
  });
}
