import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/utils/prayer_legacy_html.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';

void main() {
  test('legacy semantic conversion drops executable content and unsafe links', () {
    const source =
        '<p onclick="evil()"><strong>С.:</strong> Пан з вамі.</p>'
        '<p class="rubric"><em>Усе ўстаюць.</em></p><p><em>Молімся.</em></p>'
        '<script>SECRET_SCRIPT</script><style>SECRET_STYLE</style>'
        '<iframe>SECRET_FRAME</iframe><svg><text>SECRET_SVG</text></svg>'
        '<a href="java&#10;script:evil()">Словы</a>'
        '<a href="//evil.test">Словы</a><a href="data:text/html,bad">Словы</a>'
        '<a href="/prayer/id" title="Назва">Іншая</a><img src=x onerror="evil()" alt="Вобраз">';
    final doc = parseFragment(
      prayerMarkdownToHtml(prayerLegacyHtmlToMarkdown(source)),
    );
    expect(doc.text, isNot(contains('SECRET')));
    expect(
      doc.querySelectorAll('script,style,iframe,svg,img,[onclick],[onerror]'),
      isEmpty,
    );
    expect(doc.querySelectorAll('a[href]').map((n) => n.attributes['href']), [
      '/prayer/id',
    ]);
    expect(doc.querySelector('a')!.attributes['title'], 'Назва');
    expect(doc.querySelector('.prayer-speaker')!.text, 'С.:');
    expect(doc.querySelectorAll('.prayer-rubric'), hasLength(1));
    expect(doc.querySelectorAll('em').last.text, 'Молімся.');
    expect(doc.text, contains('Вобраз'));
  });
  test('Mass opt-out includes all 1.1 compatibility projection', () {
    final html = prayerMarkdownToHtml(
      '**С.** Пан з вамі.\nУсе: Амэн.\n\n_Усе ўстаюць._',
      recognizeSpeakers: false,
    );
    expect(html, isNot(contains('prayer-speaker')));
    expect(html, isNot(contains('prayer-rubric')));
    expect(parseFragment(html).querySelector('strong')!.text, 'С.');
  });
  for (final brightness in Brightness.values) {
    for (final legacy in [false, true]) {
      testWidgets(
        '1.1 words and labels keep independent styles at $brightness legacy=$legacy',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final source = legacy
              ? '<p><em>К.</em> Пане, пачуй нас.</p><p><em>Н.: Словы адказу.</em></p><p><em>Молімся.</em></p><blockquote>Н. І з духам тваім.</blockquote><p class="rubric"><em>Усе ўстаюць.</em></p>'
              : '_К._ Пане, пачуй нас.\n\n_Н.: Словы адказу._\n\n_Молімся._\n\n> Н. І з духам тваім.\n\n_Усе ўстаюць._';
          final prayer = Prayer(
            id: 'fixture',
            title: '',
            body: source,
            textFormat: legacy ? 'html' : 'mybrev-markdown',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [settingsProvider.overrideWith(_Settings.new)],
              child: ReaderTypographyScope(
                useSystemFonts: true,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: PrayerContent(
                        prayer: prayer,
                        textStyle: const TextStyle(fontSize: 28.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final html = tester.widget<Html>(find.byType(Html));
          final spans = <TextSpan>[];
          void visit(InlineSpan span) {
            if (span is TextSpan) {
              spans.add(span);
              for (final child in span.children ?? <InlineSpan>[]) {
                visit(child);
              }
            }
          }

          for (final rich in tester.widgetList<RichText>(
            find.byType(RichText),
          )) {
            visit(rich.text);
          }
          for (final label in ['К.', 'Н.:', 'Н.']) {
            final span = spans.firstWhere((s) => s.text == label);
            expect(span.style!.color, html.style['.prayer-speaker']!.color);
            expect(span.style!.fontWeight, FontWeight.w700);
            expect(span.style!.fontStyle, FontStyle.normal);
            expect(span.style!.fontSize, 28.8);
          }
          final spoken = spans.firstWhere(
            (s) => s.text?.contains('Словы адказу.') ?? false,
          );
          expect(spoken.style!.fontStyle, FontStyle.italic);
          expect(spoken.style!.color, html.style['body']!.color);
          final formula = spans.firstWhere((s) => s.text == 'Молімся.');
          expect(formula.style!.fontStyle, FontStyle.italic);
          expect(formula.style!.color, html.style['body']!.color);
          final rubric = spans.firstWhere((s) => s.text == 'Усе ўстаюць.');
          expect(rubric.style!.fontStyle, FontStyle.italic);
          expect(rubric.style!.color, html.style['.prayer-rubric']!.color);
          expect(prayer.toMap()['text'], source);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}
