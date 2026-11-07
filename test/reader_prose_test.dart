import 'dart:io';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'support/compendium_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/constants/psalmody_preview.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/models/reader_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/reader_prose.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/psalmody_settings_section.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';
import 'package:mybrev_flutter/widgets/reader_text_settings.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  Future<void> setTextAlignment(ReaderTextAlignment value) async =>
      state = state.copyWith(textAlignment: value);
  @override
  Future<void> setPsalmodyMode(PsalmodyMode value) async =>
      state = state.copyWith(psalmodyMode: value);
  @override
  void setFontFamily(String value) =>
      state = state.copyWith(fontFamily: normalizeReaderFontFamily(value));
}

void main() {
  test(
    'semantic prose keeps inline nodes, links, rubrics, stanzas and Mass roles intact',
    () {
      const html =
          '<p id="prose">Звычайны абзац.</p><p id="inline">Частка <em>абзаца</em> і <a href="/bible">спасылка</a>.</p>'
          '<h2>Загаловак</h2><p><strong>Падзагаловак</strong></p><p><em>Рубрыка</em></p>'
          '<aside class="prayer-rubric"><p>Рубрыка</p></aside><ul><li><p>Спіс</p></li></ul>'
          '<p>Страфа<br>Працяг</p><p><span class="prayer-speaker">К.</span> Адказ</p><p>К. Адказ</p>'
          '<p class="liturgical-reference">Ян 1</p><p class="mass-comment">Рубрыка</p><p class="mass-response">Амэн.</p>'
          '<p class="mass-spoken" id="mass">Малітва.</p><p class="mass-spoken"><span class="mass-role">С.</span> Вітанне</p>'
          '<p><a href="/bible">Спасылка</a></p><p style="text-align:center">Подпіс</p>';
      final prepared = parseFragment(prepareReaderProseHtml(html));
      expect(prepared.querySelectorAll('.reader-prose').map((p) => p.id), [
        'prose',
        'inline',
        'mass',
      ]);
      expect(prepared.text, parseFragment(html).text);
      expect(prepared.querySelector('#inline a')!.attributes['href'], '/bible');
      expect(prepared.querySelector('#inline em')!.text, 'абзаца');
      expect(
        prepareReaderProseHtml(prepareReaderProseHtml(html)),
        prepareReaderProseHtml(html),
      );
    },
  );

  test(
    'Web PR 202 excerpt uses production psalmody in every mode, without action links',
    () {
      expect(
        psalmodyPreviewHtml,
        File('test/fixtures/psalmody-preview-web.html').readAsStringSync(),
      );
      final formatted = formatPsalmHtml(psalmodyPreviewHtml);
      for (final mode in PsalmodyMode.values) {
        final root = parseFragment(
          preparePsalmChoirHtml(formatted, mode: mode, interactive: false),
        );
        expect(root.querySelectorAll('.psalm-strophe'), hasLength(3));
        expect(root.querySelectorAll('.psalm-marker'), hasLength(3));
        expect(root.querySelector('a'), isNull);
        expect(
          root.querySelectorAll('.psalm-line'),
          hasLength(mode == PsalmodyMode.alternatingStanzas ? 0 : 6),
        );
        expect(
          root.querySelectorAll('.psalm-continuation'),
          hasLength(mode == PsalmodyMode.alternatingStanzas ? 0 : 3),
        );
        expect(
          root.text!.replaceAll(RegExp(r'\s+'), ' ').trim(),
          parseFragment(
            psalmodyPreviewHtml.replaceAll('<br />', ' '),
          ).text!.replaceAll(RegExp(r'\s+'), ' ').trim(),
        );
      }
    },
  );

  testWidgets(
    'prayer prose updates immediately; an Office opt-out stays start aligned',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      const prayer = Prayer(
        id: 'fixture',
        title: 'Малітва',
        textFormat: 'mybrev-markdown',
        body: 'Звычайны абзац з *вылучэннем*.\n\n:::rubric\nРубрыка\n:::',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Column(
                  children: [
                    PrayerContent(
                      prayer: prayer,
                      textAlignment: ref
                          .watch(settingsProvider)
                          .textAlignment
                          .textAlign,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    PrayerContent(
                      key: Key('office'),
                      prayer: prayer,
                      textStyle: TextStyle(fontSize: 16),
                      applyTextAlignment: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await container
          .read(settingsProvider.notifier)
          .setTextAlignment(ReaderTextAlignment.justify);
      await tester.pumpAndSettle();
      final html = tester.widgetList<Html>(find.byType(Html)).toList();
      expect(html.first.style['.reader-prose']!.textAlign, TextAlign.justify);
      expect(
        parseFragment(html.first.data!).querySelectorAll('.reader-prose'),
        hasLength(1),
      );
      expect(html.last.style.containsKey('.reader-prose'), isFalse);
      expect(html.last.data, isNot(contains('reader-prose')));
      final office = find.byKey(const Key('office'));
      expect(
        tester
            .widgetList<RichText>(
              find.descendant(of: office, matching: find.byType(RichText)),
            )
            .every((p) => p.textAlign != TextAlign.justify),
        isTrue,
      );
    },
  );

  testWidgets(
    'Catechism answers justify while references keep their alignment',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      final question = readBundledCompendium().units
          .expand((unit) => unit.questions)
          .first;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CompendiumAnswer(
                question: question,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );
      await container
          .read(settingsProvider.notifier)
          .setTextAlignment(ReaderTextAlignment.justify);
      await tester.pumpAndSettle();
      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(
        texts
            .where((text) => text.textSpan != null)
            .every((text) => text.textAlign == TextAlign.justify),
        isTrue,
      );
      expect(
        texts
            .where((text) => text.data?.startsWith('ККК ') ?? false)
            .every((text) => text.textAlign != TextAlign.justify),
        isTrue,
      );
    },
  );

  testWidgets(
    'live psalm preview shares the renderer and ignores prose alignment',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReaderTypographyScope(
              useSystemFonts: true,
              child: Scaffold(
                body: SingleChildScrollView(child: PsalmodySettingsSection()),
              ),
            ),
          ),
        ),
      );
      for (final mode in PsalmodyMode.values) {
        await container.read(settingsProvider.notifier).setPsalmodyMode(mode);
        await container
            .read(settingsProvider.notifier)
            .setTextAlignment(ReaderTextAlignment.justify);
        await tester.pumpAndSettle();
        final preview = find.byKey(const Key('settings-psalmody-preview'));
        expect(tester.widget<PsalmChoirHtml>(preview).interactive, isFalse);
        final html = tester.widget<Html>(
          find.descendant(of: preview, matching: find.byType(Html)),
        );
        expect(html.style['p']!.textAlign, TextAlign.left);
        expect(
          html.style['.psalm-continuation']!.padding!.left!.value,
          mode == PsalmodyMode.leftBreakIndent ? 12 : 0,
        );
        expect(
          html.style['.psalm-strophe-even']!.margin!.left!.value,
          mode == PsalmodyMode.alternatingStanzas ? 16 : 0,
        );
      }
    },
  );

  testWidgets(
    'sheet and Settings controls use the same family and alignment without scroll reset',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      final scroll = ScrollController(initialScrollOffset: 100);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const ReaderFontPicker(key: Key('settings-font')),
                    const ReaderAlignmentControl(
                      key: Key('settings-alignment'),
                    ),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showTextScalePanel(context),
                        child: const Text('Aa'),
                      ),
                    ),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Aa'));
      await tester.tap(find.text('Aa'));
      await tester.pumpAndSettle();
      final before = scroll.offset;
      final panel = find.byKey(const Key('text-scale-font-family'));
      await tester.tap(
        find.descendant(
          of: panel,
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kurale').last);
      await tester.pumpAndSettle();
      final justify = find
          .byKey(const ValueKey('reader-alignment-justify'))
          .last;
      await tester.ensureVisible(justify);
      await tester.tap(justify);
      await tester.pumpAndSettle();
      expect(
        container.read(settingsProvider).fontFamily,
        ReaderFontFamily.kurale,
      );
      expect(
        container.read(settingsProvider).textAlignment,
        ReaderTextAlignment.justify,
      );
      expect(scroll.offset, before);
      await tester.tap(find.byTooltip('Закрыць'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.descendant(
                of: find.byKey(const Key('settings-font')),
                matching: find.byType(DropdownButtonFormField<String>),
              ),
            )
            .initialValue,
        ReaderFontFamily.kurale,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('reader-alignment-justify')),
            )
            .label,
        ReaderTextAlignment.justify.label,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('reader-alignment-justify')),
            )
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );
    },
  );
}
