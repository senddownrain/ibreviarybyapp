import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/prayer_menu_category.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/prayer_category_comment.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(fontSize: 24);
}

void main() {
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

  testWidgets('comment is collapsed, keyboard accessible and uses reader text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: const ReaderTypographyScope(
          useSystemFonts: true,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PrayerCategoryCommentSection(
                  comment: PrayerCategoryComment(
                    content:
                        'Тэкст **каментарыя**. [Спасылка](/prayer/example)\n\n'
                        ':::rubric\nПрыклад рубрыкі.\n:::\n\n'
                        '[Небяспечная спасылка](javascript:alert%281%29)',
                    sourceId: 'ojcha-nash-2022',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tile = find.ancestor(
      of: find.byType(ListTile),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.expanded != null,
      ),
    );
    final body = find.byType(Html);
    final source = find.text('Крыніца: Малітоўнік «Ойча наш» (Мінск, 2022)');
    expect(body, findsNothing);
    expect(source, findsNothing);
    expect(
      tester.getSemantics(tile).flagsCollection.isExpanded,
      Tristate.isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(tile).flagsCollection.isExpanded,
      Tristate.isTrue,
    );
    final html = tester.widget<Html>(body);
    expect(html.data, contains('<strong>каментарыя</strong>'));
    expect(html.data, contains('href="/prayer/example"'));
    expect(html.data, contains('class="prayer-rubric"'));
    expect(html.data, isNot(contains('href="javascript:')));
    expect(html.style['body']!.fontSize!.value, 24);
    expect(source, findsOneWidget);

    await tester.tap(find.text('Пра гэты раздзел'));
    await tester.pumpAndSettle();
    expect(body, findsNothing);
    expect(source, findsNothing);
  });
}
