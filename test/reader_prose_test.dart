import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'support/compendium_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:mybrev_flutter/models/reader_alignment.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/reader_prose.dart';
import 'package:mybrev_flutter/widgets/reader_prose.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  Future<void> setTextAlignment(ReaderAlignment value) async =>
      state = state.copyWith(textAlignment: value);
}

final _catechism = readBundledCompendium().units
    .expand((u) => u.questions)
    .first;
void main() {
  testWidgets('Prayerbook and Catechism use semantic prose alignment', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ReaderTypographyScope(
          useSystemFonts: true,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    PrayerContent(
                      prayer: const Prayer(
                        id: 'prose-test',
                        title: 'Малітва',
                        textFormat: 'mybrev-markdown',
                        body:
                            'Прозавы абзац **малітвы**.\n\n:::rubric\nРубрыка\n:::',
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    CompendiumAnswer(
                      question: _catechism,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final mode in ReaderAlignment.values) {
      await container.read(settingsProvider.notifier).setTextAlignment(mode);
      await tester.pumpAndSettle();
      final html = tester.widget<Html>(find.byType(Html));
      expect(html.style['.reader-prose']!.textAlign, mode.textAlign);
      final parsed = parser.parseFragment(html.data!);
      expect(parsed.querySelector('.reader-prose strong')!.text, 'малітвы');
      expect(parsed.querySelector('.prayer-rubric .reader-prose'), isNull);
      final answers = find.descendant(
        of: find.byType(CompendiumAnswer),
        matching: find.byType(Text),
      );
      final prose = tester
          .widgetList<Text>(answers)
          .where((w) => w.textSpan != null);
      expect(prose, isNotEmpty);
      expect(prose.every((w) => w.textAlign == mode.textAlign), isTrue);
    }
  });

  test('prose aligns; fixed lines, markers and responses stay at start', () {
    for (final mode in ReaderAlignment.values) {
      expect(proseTextAlign(mode, 'Звычайны абзац.'), mode.textAlign);
      for (final text in [
        'Радок\nРадок',
        'Радок * працяг',
        'Радок † працяг',
        'Н. Адказ',
        'R. Answer',
        '• Пункт спіса',
        '1. Пункт спіса',
        '— Адказ',
      ]) {
        expect(proseTextAlign(mode, text), TextAlign.start);
      }
      expect(proseTextAlign(mode, 'Гімн', enabled: false), TextAlign.start);
    }
  });
  test('only prose paragraphs are marked; inline content and href are intact', () {
    const html =
        '<h2>Назва</h2><p>Проза <em>курсіў</em> <strong>тоўсты</strong> <a href="https://example.org">спасылка</a>.</p>'
        '<p>Радок<br>Радок</p><ul><li><p>Спіс</p></li></ul>'
        '<div class="prayer-rubric"><p>Рубрыка</p></div>'
        '<p><span class="prayer-speaker">С.</span> Дыялог</p>'
        '<p class="mass-response">Адказ</p><p class="mass-spoken">Проза Імшы</p>'
        '<p class="liturgical-reference">Ян 1</p><p class="psalm-strophe">Страфа</p>';
    final before = parser.parseFragment(html);
    final after = parser.parseFragment(prepareReaderProseHtml(html));
    expect(after.text, before.text);
    expect(after.querySelectorAll('.reader-prose').map((p) => p.text), [
      'Проза курсіў тоўсты спасылка.',
      'Проза Імшы',
    ]);
    expect(after.querySelector('a')!.attributes['href'], 'https://example.org');
    expect(after.querySelectorAll('em, strong'), hasLength(2));
  });
  testWidgets('HTML alignment reacts immediately without losing inline links', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);
    var taps = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ReaderProseHtml(
              data:
                  '<p>Абзац <a href="local:link">спасылка</a>.</p><p>Радок<br>радок</p>',
              style: const {},
              onLinkTap: (_, _, _) => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Html rendered() => tester.widget<Html>(find.byType(Html));
    expect(rendered().style['.reader-prose']!.textAlign, TextAlign.start);
    await container
        .read(settingsProvider.notifier)
        .setTextAlignment(ReaderAlignment.justify);
    await tester.pumpAndSettle();
    expect(rendered().style['.reader-prose']!.textAlign, TextAlign.justify);
    rendered().onLinkTap!('local:link', {}, null);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
