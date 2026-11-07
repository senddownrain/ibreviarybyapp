import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:mybrev_flutter/models/reader_alignment.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/psalmody_example.dart';
import 'package:mybrev_flutter/widgets/reader_text_settings.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  void setFontFamily(String family) =>
      state = state.copyWith(fontFamily: family);
  @override
  Future<void> setTextAlignment(ReaderAlignment value) async =>
      state = state.copyWith(textAlignment: value);
  @override
  Future<void> setPsalmodyMode(PsalmodyMode value) async =>
      state = state.copyWith(psalmodyMode: value);
}

void main() {
  test(
    'example exactly matches the independently captured Web PR 202 source',
    () {
      final source =
          jsonDecode(
                File(
                  'test/fixtures/psalmody_preview_web.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(psalmodyExampleHtml, source['html']);
      expect(source['reference'], 'Псальм 63 (62), 2–3');
      final example = parser.parseFragment(psalmodyExampleHtml);
      expect(example.querySelectorAll('p'), hasLength(3));
      expect(example.querySelectorAll('br'), hasLength(3));
      expect(example.text!.split('*'), hasLength(4));
    },
  );
  testWidgets(
    'live example uses the production psalm algorithm for every mode',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ReaderTypographyScope(
            useSystemFonts: true,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: PsalmodyExample()),
              ),
            ),
          ),
        ),
      );
      for (final mode in PsalmodyMode.values) {
        await container.read(settingsProvider.notifier).setPsalmodyMode(mode);
        await tester.pumpAndSettle();
        final html = tester.widget<Html>(find.byType(Html));
        final dom = parser.parseFragment(html.data!);
        expect(dom.querySelectorAll('.psalm-strophe'), hasLength(3));
        expect(
          dom.querySelectorAll('.psalm-continuation').isEmpty,
          mode == PsalmodyMode.alternatingStanzas,
        );
        expect(
          html.style['.psalm-continuation']!.padding!.left!.value,
          mode == PsalmodyMode.leftBreakIndent ? 12 : 0,
        );
        expect(
          html.style['.psalm-strophe-even']!.margin!.left!.value,
          mode == PsalmodyMode.alternatingStanzas ? 16 : 0,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'one expandable group and all five fonts synchronize with the sheet',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ReaderTypographyScope(
            useSystemFonts: true,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [ReaderTextSettings(), TextScaleControl()],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Памер шрыфту · 100%'), findsNothing);
      await tester.tap(find.text('Тэкст'));
      await tester.pumpAndSettle();
      expect(find.text('Памер шрыфту · 100%'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reader-alignment-justify')));
      await tester.pumpAndSettle();
      expect(
        container.read(settingsProvider).textAlignment,
        ReaderAlignment.justify,
      );
      await tester.ensureVisible(find.byKey(const Key('text-scale-open')));
      await tester.tap(find.byKey(const Key('text-scale-open')));
      await tester.pumpAndSettle();
      final selector = find.descendant(
        of: find.byKey(const Key('sheet-reader-font')),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      for (final font in kAvailableReaderFonts) {
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          selector,
        );
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.descendant(
                  of: find.byKey(const Key('sheet-reader-font')),
                  matching: find.byType(DropdownButton<String>),
                ),
              )
              .items!
              .map((i) => i.value),
          kAvailableReaderFonts.map((f) => f.id),
        );
        dropdown.onChanged!(font.id);
        await tester.pumpAndSettle();
        expect(container.read(settingsProvider).fontFamily, font.id);
      }
      await tester.tap(find.byKey(const Key('reader-alignment-start')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Закрыць'));
      await tester.pumpAndSettle();
      expect(
        container.read(settingsProvider).textAlignment,
        ReaderAlignment.start,
      );
      final settingsFont = tester.widget<DropdownButtonFormField<String>>(
        find.descendant(
          of: find.byKey(const Key('settings-reader-font')),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      expect(settingsFont.initialValue, ReaderFontFamily.system);
      await tester.ensureVisible(find.text('Тэкст'));
      await tester.tap(find.text('Тэкст'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderAlignmentSelector), findsNothing);
    },
  );
}
