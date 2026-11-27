import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/prayer_category_comment.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(fontSize: 24);
}

void main() {
  test('category projection removes unpublished and invalid branches', () {
    final rows = <String, Map<String, dynamic>>{
      'public': {'name': 'Public'},
      'unpublished': {'name': 'Hidden', 'published': false},
      'child': {
        'name': 'Child',
        'parentId': 'unpublished',
        'comment': {'content': 'Unpublished ancestor'},
      },
      'orphan': {
        'name': 'Orphan',
        'parentId': 'missing',
        'comment': {'content': 'Invalid ancestor'},
      },
      'canonical': {
        'name': 'Archive',
        'status': ' ARCHIVED ',
        'effectiveAccessSets': ['marian'],
      },
      'canonical-child': {
        'name': 'Hidden child',
        'parentId': 'canonical',
        'comment': {'content': 'Unpublished protected ancestor'},
      },
    };
    for (final allowRestricted in [false, true]) {
      expect(
        projectPrayerCategories(
          rows,
          allowRestricted: allowRestricted,
        ).map((row) => row.id),
        ['public'],
      );
    }
  });

  test(
    'optional category comment uses strict types and respects publication',
    () {
      PrayerCategoryComment? parse(Object? raw, [Map metadata = const {}]) =>
          PrayerMenuCategory.global('sample', {
            'comment': raw,
            ...metadata,
          }).comment;

      for (final value in [
        null,
        'legacy',
        [],
        {},
        {'content': null},
        {'content': 1},
        {'content': ' \n\t ', 'title': 'Unused', 'sourceId': 'ojcha-nash-2022'},
      ]) {
        expect(parse(value), isNull);
      }
      const content = '    code\n\nТэкст.';
      final comment = parse({
        'content': content,
        'title': '  Тлумачэнне ',
        'sourceId': '  ',
      });
      expect(comment?.content, content);
      expect(comment?.title, 'Тлумачэнне');
      expect(comment?.sourceId, isNull);
      expect(parse({'content': content}, {'published': false}), isNull);
      for (final status in [
        'draft',
        'pending',
        'review',
        'rejected',
        'archived',
      ]) {
        expect(
          parse({'content': content}, {'status': ' ${status.toUpperCase()} '}),
          isNull,
        );
      }
    },
  );

  testWidgets('comment opens a full-screen keyboard-accessible reader', (
    tester,
  ) async {
    final category = PrayerMenuCategory.global('sample', {
      'name': 'Прыклад катэгорыі',
      'comment': {
        'content':
            'Тэкст **каментарыя**. [Спасылка](/prayer/example)\n\n'
            ':::rubric\nПрыклад рубрыкі.\n:::\n\n'
            '[Небяспечная спасылка](javascript:alert%281%29)\n\n'
            "${List.filled(12, 'Доўгі тэкст для пракруткі.').join('\n\n')}",
        'sourceId': 'ojcha-nash-2022',
      },
    });
    String? openedPrayer;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_Settings.new),
          prayerMenuCategoriesProvider.overrideWithValue([category]),
        ],
        child: ReaderTypographyScope(
          useSystemFonts: true,
          child: MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Scaffold(
              body: PrayerCategoryCommentButton(
                category: category,
                onOpenPrayer: (location) => openedPrayer = location,
              ),
            ),
          ),
        ),
      ),
    );
    final chip = find.widgetWithText(TextButton, 'Пра гэты раздзел');
    final source = find.text('Крыніца: Малітоўнік «Ойча наш» (Мінск, 2022)');
    final body = find.byType(Html);
    final close = find.byTooltip('Закрыць');
    expect(body, findsNothing);
    final control = tester.getSemantics(chip).getSemanticsData();
    expect(control.flagsCollection.isButton, isTrue);
    expect(control.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(close, findsOneWidget);
    expect(find.text('Прыклад катэгорыі'), findsOneWidget);
    final html = tester.widget<Html>(body.first);
    expect(html.data, contains('<strong>каментарыя</strong>'));
    expect(html.data, contains('href="/prayer/example"'));
    expect(html.data, contains('class="prayer-rubric"'));
    expect(html.data, isNot(contains('href="javascript:')));
    expect(html.style['body']!.fontSize!.value, 24);
    final viewport = find.byKey(const Key('category-comment-reader-scroll'));
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: viewport, matching: find.byType(Scrollable)).first,
    );
    await tester.drag(viewport, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(0));
    expect(source, findsOneWidget);
    expect(close.hitTestable(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(body, findsNothing);
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    tester.widget<Html>(body.first).onLinkTap!('/prayer/example', {}, null);
    await tester.pumpAndSettle();
    expect(close, findsNothing);
    expect(openedPrayer, '/prayers/prayer/example');
  });
}
