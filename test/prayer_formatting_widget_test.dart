import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayer_form_screen.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'support/prayer_formatting_fixtures.dart';

void main() {
  testWidgets(
    'offline smoke harness opens reader, theme, narrow layout and preview',
    (tester) async {
      await tester.pumpWidget(const PrayerFormattingHarness(systemFonts: true));
      await tester.pumpAndSettle();
      expect(find.byType(Html), findsOneWidget);
      await tester.tap(find.byTooltip('Theme'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Html))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('320px'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Html)).width, lessThanOrEqualTo(320));
      await tester.tap(find.byTooltip('Legacy'));
      await tester.pumpAndSettle();
      final legacy = tester.widget<Html>(find.byType(Html));
      expect(legacy.data, isNot(contains('SECRET_SCRIPT')));
      expect(
        parseFragment(legacy.data!).querySelector('strong, b')!.text,
        'Молімся.',
      );
      await tester.tap(find.byTooltip('Preview'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('prayer-markdown-preview-toggle')),
      );
      await tester.tap(find.byKey(const Key('prayer-markdown-preview-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(Html), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    for (final size in [16.0, 28.8]) {
      testWidgets(
        'reader and preview share semantics/styles at $brightness $size',
        (tester) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget app(Widget child) => ProviderScope(
            overrides: [
              settingsProvider.overrideWith(
                () => FormattingSettings(size: size),
              ),
              liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
              allPrayersProvider.overrideWithValue([linkedPrayer]),
              localPrayersProvider.overrideWith(FormattingLocals.new),
            ],
            child: ReaderTypographyScope(
              useSystemFonts: true,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: child,
              ),
            ),
          );
          await tester.pumpWidget(
            app(const PrayerDetailScreen(prayerId: 'local_formatting')),
          );
          await tester.pumpAndSettle();
          final reader = tester.widget<Html>(find.byType(Html));
          final doc = parseFragment(reader.data!);
          expect(doc.querySelectorAll('.prayer-speaker'), hasLength(55));
          expect(doc.querySelector('blockquote .prayer-speaker'), isNull);
          expect(find.byType(SelectionArea), findsOneWidget);
          final readerStyles = reader.style;
          final richTexts = tester.widgetList<RichText>(find.byType(RichText));
          final spans = <TextSpan>[];
          void visit(InlineSpan span) {
            if (span is TextSpan) {
              spans.add(span);
              for (final child in span.children ?? <InlineSpan>[]) {
                visit(child);
              }
            }
          }

          for (final text in richTexts) {
            visit(text.text);
          }
          final label = spans.firstWhere((span) => span.text == 'К.');
          expect(label.style!.fontWeight, FontWeight.w700);
          expect(label.style!.color, readerStyles['.prayer-speaker']!.color);
          final rubric = spans.firstWhere(
            (span) => span.text == 'Усе ўстаюць.',
          );
          expect(rubric.style!.color, readerStyles['.prayer-rubric']!.color);
          expect(
            richTexts.any((text) => text.selectionRegistrar != null),
            isTrue,
          );
          expect(
            spans.any((span) => span.text?.contains('Пане, адкрый') ?? false),
            isTrue,
          );
          final spoken = spans.firstWhere(
            (span) => span.text?.contains('Пане, адкрый') ?? false,
          );
          expect(
            spoken.style?.fontWeight ?? FontWeight.normal,
            FontWeight.normal,
          );
          expect(spoken.style?.color, readerStyles['body']!.color);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            app(const PrayerFormScreen(prayerId: 'local_formatting')),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const Key('prayer-markdown-preview-toggle')),
          );
          await tester.tap(
            find.byKey(const Key('prayer-markdown-preview-toggle')),
          );
          await tester.pumpAndSettle();
          final preview = tester.widget<Html>(find.byType(Html));
          expect(preview.data, reader.data);
          for (final selector in [
            'body',
            '.prayer-speaker',
            '.prayer-rubric',
            'blockquote',
          ]) {
            expect(
              preview.style[selector]!.color,
              readerStyles[selector]!.color,
            );
            expect(
              preview.style[selector]!.fontSize?.value,
              readerStyles[selector]!.fontSize?.value,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final target in ['test-id', 'missing', 'restricted']) {
    testWidgets(
      'internal link to $target keeps access checks and back navigation',
      (tester) async {
        final source = Prayer(
          id: 'source',
          title: 'Пачатак',
          body: '[Перайсці](/prayer/$target)',
        );
        final router = GoRouter(
          initialLocation: '/prayers/prayer/source',
          routes: [
            GoRoute(
              path: '/prayers/prayer/:id',
              builder: (_, state) =>
                  PrayerDetailScreen(prayerId: state.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(FormattingSettings.new),
              liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
              allPrayersProvider.overrideWithValue([
                source,
                linkedPrayer,
                restrictedPrayer,
              ]),
              localPrayersProvider.overrideWith(FormattingLocals.new),
              protectedPrayerProvider.overrideWith((ref, id) async => null),
            ],
            child: ReaderTypographyScope(
              useSystemFonts: true,
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getTopLeft(find.text('Перайсці', findRichText: true)) +
              const Offset(20, 10),
        );
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);
        if (target == 'missing') {
          expect(find.text('Малітва не знойдзена'), findsOneWidget);
        }
        if (target == 'restricted') {
          expect(
            find.text('Малітва недаступная. Праверце доступ і злучэнне.'),
            findsOneWidget,
          );
        }
        if (target == 'test-id') {
          expect(find.text('Іншая малітва'), findsOneWidget);
        }
        expect(find.textContaining('SECRET', findRichText: true), findsNothing);
        expect(tester.takeException(), isNull);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Пачатак'), findsOneWidget);
      },
    );
  }
}
