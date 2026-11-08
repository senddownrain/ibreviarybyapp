import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cadence segments preserve marks, emphasis, source breaks and non-psalm text',
    () {
      final formatted = formatPsalmHtml(
        '<p><em>Пачатак<br>слова † працяг *</em> канец</p>',
      );
      final output = preparePsalmChoirHtml(
        '$formatted<p class="ora-ant">Ант. *</p>',
        selectedChoir: 1,
        mode: PsalmodyMode.leftBreakIndent,
      );
      final root = parseFragment(output);
      final lines = root.querySelectorAll('.psalm-line');
      expect(lines, hasLength(3));
      expect(lines[0].text.trim(), 'Пачатакслова †');
      expect(lines[1].text.trim(), 'працяг *');
      expect(lines[1].querySelector('em'), isNotNull);
      expect(lines[0].querySelector('br'), isNotNull);
      expect(
        root.querySelector('.ora-ant')!.outerHtml,
        '<p class="ora-ant">Ант. *</p>',
      );
      expect(root.querySelectorAll('.psalm-continuation'), hasLength(2));
      expect(root.querySelector('p')!.attributes['data-psalm-choir'], '1');
    },
  );

  test('next hour skips unavailable entries and ends at Compline', () {
    final day = LiturgicalDay.fromMap({
      'id': 'variant',
      'title': 'Дзень',
      'laudesAnt1': 'антыфона',
      'vesperAnt1': 'антыфона',
    });
    expect(
      nextAvailableHour(day, 'laudes', completoriumAvailable: true)?.type,
      'vespers',
    );
    expect(
      nextAvailableHour(day, 'vespers', completoriumAvailable: true)?.type,
      'completorium',
    );
    expect(
      nextAvailableHour(day, 'vespers', completoriumAvailable: false),
      isNull,
    );
    expect(
      nextAvailableHour(day, 'completorium', completoriumAvailable: true),
      isNull,
    );
  });

  testWidgets(
    'one selection dims matching sides of psalms and gospel canticles in all layouts',
    (tester) async {
      final controller = ValueNotifier<int?>(null);
      addTearDown(controller.dispose);
      for (final mode in PsalmodyMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: PsalmodyScope(
              controller: controller,
              mode: mode,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final name in [
                        'Псальм',
                        'Benedictus',
                        'Magnificat',
                        'Nunc dimittis',
                      ])
                        PsalmChoirHtml(
                          html: formatPsalmHtml(
                            '<p>$name A * працяг</p><p>$name B * працяг</p>',
                          ),
                          style: {'body': Style(fontSize: FontSize(20))},
                          textColor: Colors.black,
                          rubricColor: Colors.red,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        void select(int side) => tester
            .widgetList<Html>(find.byType(Html))
            .first
            .onLinkTap!('psalm-choir:$side', {}, null);
        select(1);
        await tester.pump();
        expect(controller.value, 1);
        for (final html in tester.widgetList<Html>(find.byType(Html))) {
          final root = parseFragment(html.data!);
          expect(
            root
                .querySelectorAll('a.psalm-choir-muted')
                .every((a) => a.attributes['href'] == 'psalm-choir:1'),
            isTrue,
          );
          expect(root.querySelectorAll('a.psalm-choir-muted'), isNotEmpty);
          expect(
            root.querySelectorAll('.psalm-continuation').isNotEmpty,
            mode != PsalmodyMode.alternatingStanzas,
          );
        }
        select(2);
        await tester.pump();
        expect(controller.value, 2);
        select(2);
        await tester.pump();
        expect(controller.value, isNull);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'cadence continuation has typographic inset in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final selection = ValueNotifier<int?>(1);
        addTearDown(selection.dispose);
        for (final size in [16.0, 24.0]) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('psalmody-capture'),
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: PsalmodyScope(
                  controller: selection,
                  mode: PsalmodyMode.leftBreakIndent,
                  child: Scaffold(
                    body: Builder(
                      builder: (context) {
                        final reader = ReaderTheme.of(context);
                        final body = reader.body(size);
                        return ColoredBox(
                          color: reader.surface,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Псальмодыя',
                                    style: reader.serviceHeading(size),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Ант. Пан — маё святло і маё збаўленне.',
                                    style: body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  PsalmChoirHtml(
                                    html: formatPsalmHtml(
                                      '<p>Божа, † працяг * канец.</p><p>Цябе шукаю * усёй душой.</p>',
                                    ),
                                    style: {
                                      ...liturgicalDocumentStyles(
                                        reader: reader,
                                        body: body,
                                      ),
                                      '.psalm-strophe': Style(
                                        margin: Margins.only(bottom: 8),
                                      ),
                                    },
                                    textColor: reader.ink,
                                    rubricColor: reader.rubric,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Finder line(String text) => find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText().trim() == text,
          );
          expect(line('Божа, †'), findsOneWidget);
          expect(line('працяг *'), findsOneWidget);
          expect(
            tester.getTopLeft(line('працяг *')).dy,
            greaterThan(tester.getTopLeft(line('Божа, †')).dy),
          );
          expect(
            tester.getTopLeft(line('працяг *')).dx -
                tester.getTopLeft(line('Божа, †')).dx,
            closeTo(size * .75, .01),
          );
          expect(tester.takeException(), isNull);
          if (Platform.environment['LITURGY_PSALMODY_IMAGES'] == '1') {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('psalmody-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('build/psalmody-preview')
                ..createSync(recursive: true);
              File(
                '${directory.path}/${brightness.name}-$size.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      },
    );

    testWidgets(
      'floating controls fit 320 px with Android dock and large text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        final anchor = GlobalKey();
        addTearDown(scroll.dispose);
        var pickerCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              platform: TargetPlatform.android,
            ),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                padding: EdgeInsets.only(top: 24, bottom: 104),
                viewPadding: EdgeInsets.only(top: 24, bottom: 24),
                textScaler: TextScaler.linear(2),
              ),
              child: ReaderScaffold(
                scrollController: scroll,
                showScrollToTop: true,
                hourTitle: 'Малітва перад поўднем',
                hourTitleAnchor: anchor,
                onChangeHour: () => pickerCalls++,
                contextHeader: ReaderContextHeader(
                  title: 'Малітва перад поўднем',
                  titleAnchorKey: anchor,
                  onTitleTap: () => pickerCalls++,
                  subtitle: 'Доўгая назва літургічнага дня',
                ),
                content: Column(
                  children: [for (var i = 0; i < 90; i++) Text('Радок $i')],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reader-scroll-to-top')), findsNothing);
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const Key('hour-switcher-opacity')),
              )
              .opacity,
          0,
        );
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const Key('hour-switcher-opacity')),
              )
              .opacity,
          1,
        );
        final pill = find.byKey(const Key('hour-switcher-pill'));
        final button = find.byKey(const Key('reader-scroll-to-top'));
        expect(button, findsOneWidget);
        expect(tester.getRect(button).bottom, lessThan(640 - 104));
        expect(tester.getRect(button).overlaps(tester.getRect(pill)), isFalse);
        await tester.tap(pill);
        expect(pickerCalls, 1);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(scroll.offset, 0);
        expect(button, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Office font panel includes families and fits a small screen at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_Settings.new)],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('text-scale-open'),
                    onPressed: () =>
                        showTextScalePanel(context, showPsalmody: true),
                    child: const Text('Aa'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('text-scale-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-font-literata')), findsOneWidget);
      expect(
        find.byKey(const Key('text-scale-psalmody-modes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reader-alignment-justify')),
        findsNothing,
      );
      expect(find.byKey(const Key('psalm-marker-break')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}
