// Actual production Office renderer + final public bundle; no Firebase setup.
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/utils/devotional_office.dart';
import 'package:mybrev_flutter/widgets/devotional_office_reader.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart' show officeDocument;
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

@JS('officeSmokeConfigure')
external set configureOfficeSmoke(JSFunction value);
@JS('officeSmokeState')
external set officeSmokeState(JSString value);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await HiveService.init();
  await ContentStore.instance.ensureLoaded(['days', 'prayers']);
  await HiveService.settingsBox.put(
    'textAlignment',
    Uri.base.queryParameters['align'] ?? 'justify',
  );
  SemanticsBinding.instance.ensureSemantics();
  runApp(const ProviderScope(child: OfficeVisualApp()));
}

class OfficeVisualApp extends StatefulWidget {
  const OfficeVisualApp({super.key});
  @override
  State<OfficeVisualApp> createState() => _OfficeVisualAppState();
}

class _OfficeVisualAppState extends State<OfficeVisualApp> {
  late AppThemePreference preference;
  late double scale;
  late String selected;
  @override
  void initState() {
    super.initState();
    preference = AppThemePreference.fromStorage(
      Uri.base.queryParameters['theme'] ?? 'light',
    );
    scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;
    selected = Uri.base.queryParameters['case'] ?? 'citation1';
    configureOfficeSmoke =
        ((JSString nextCase, JSString nextTheme, JSNumber nextScale) {
          setState(() {
            selected = nextCase.toDart;
            preference = AppThemePreference.fromStorage(nextTheme.toDart);
            scale = nextScale.toDartDouble;
          });
          _markFrame();
        }).toJS;
    _markFrame();
  }

  void _markFrame() => WidgetsBinding.instance.addPostFrameCallback((_) {
    officeSmokeState =
        '$selected|${preference.name}|${scale.toStringAsFixed(1)}'.toJS;
  });
  @override
  Widget build(BuildContext context) {
    final schemes = AppPalette.schemesFor(preference),
        colors = AppPalette.colorsFor(preference, schemes.theme.brightness);
    final day = Map<String, dynamic>.from(
      ContentStore.instance.collection('days').get('ordinary-w5-d1') as Map,
    );
    final actual = <String, String>{
      'laudes': 'laudesR',
      'vesper': 'vesperR',
      'sext': 'sext2R',
      'first': 'officeOfReadingsR1',
      'second': 'officeOfReadingsR2',
    };
    final isLong = selected == 'first' || selected == 'second';
    final label = selected == 'first' ? 'Першае чытанне' : 'Другое чытанне';
    final reference = selected == 'citation2'
        ? '1 Ян 3, 1а–2'
        : 'Рым 13, 11б. 12–13а';
    final legacy = selected == 'div'
        ? '<div>К. Доўгі адказ з натуральным пераносам * і нязменным тэкстам.</div><div>Н. Другі адказ.</div>'
        : '<p>К. Доўгі адказ з натуральным пераносам * і нязменным тэкстам.<br>Н. Другі адказ.<br>К. Хвала Айцу і Сыну, і Духу Святому.<br>Н. Амэн.</p>';
    var html = actual.containsKey(selected)
        ? day[actual[selected]] as String
        : '<p><span style="color:red">КАРОТКАЕ ЧЫТАННЕ $reference</span></p><p>З Першага паслання святога Яна.</p><p>Нязменены тэкст чытання.</p><p>КАРОТКІ РЭСПАНСОРЫЙ</p>$legacy';
    final header = isLong
        ? extractOfficeReadingReference(stripLeadingReadingHeading(html, label))
        : (reference: null, bodyHtml: html);
    html = header.bodyHtml;
    return ReaderTypographyScope(
      useSystemFonts: Uri.base.queryParameters['family'] == 'system',
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: schemes.theme,
          extensions: [colors],
          scaffoldBackgroundColor: colors.reader,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: Text(
              '$selected · ${preference.name} · ${(scale * 100).round()}%',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              IconButton(
                tooltip: 'Theme',
                onPressed: () => setState(
                  () => preference = preference == AppThemePreference.light
                      ? AppThemePreference.dark
                      : preference == AppThemePreference.dark
                      ? AppThemePreference.marian
                      : AppThemePreference.light,
                ),
                icon: const Icon(Icons.brightness_6),
              ),
              IconButton(
                tooltip: 'Aa',
                onPressed: () => setState(() => scale = scale == 1 ? 2 : 1),
                icon: const Icon(Icons.text_fields),
              ),
              IconButton(
                tooltip: 'Next hour',
                onPressed: () => setState(
                  () => selected = actual.keys.elementAt(
                    (actual.keys.toList().indexOf(selected) + 1) %
                        actual.length,
                  ),
                ),
                icon: const Icon(Icons.navigate_next),
              ),
            ],
          ),
          body: MediaQuery(
            data: MediaQueryData.fromView(
              View.of(context),
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                final reader = ReaderTheme.of(context),
                    body = reader.body(
                      16,
                      family: Uri.base.queryParameters['family'],
                    );
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selected == 'headings')
                              for (final title in [
                                'Гімн',
                                'Псальмодыя',
                                'Першае чытанне',
                                'Другое чытанне',
                                'Кароткае чытанне',
                                'Рэспансорый',
                                'Кароткі рэспансорый',
                                'Песня Захарыі',
                                'Песня Марыі',
                                'Просьбы',
                                'Малітва',
                              ])
                                LiturgicalSectionHeading(
                                  title: title,
                                  bodySize: 16,
                                ),
                            if (isLong)
                              LiturgicalHeadingReferenceRow(
                                title: label,
                                reference: header.reference,
                                bodySize: 16,
                              ),
                            if (selected == 'gadzinki')
                              DevotionalOfficeReader(
                                document: parseDevotionalOffice(
                                  Prayer.fromMap(
                                    Map<String, dynamic>.from(
                                      ContentStore.instance
                                              .collection('prayers')
                                              .get(
                                                'catholicby-yearcycle-100116',
                                              )
                                          as Map,
                                    ),
                                    'catholicby-yearcycle-100116',
                                  ),
                                )!,
                                textStyle: body,
                              )
                            else
                              officeDocument(
                                html: html,
                                body: body,
                                kind: isLong ? 'office-reading' : 'reading',
                              ),
                            const SizedBox(height: 24),
                            const Text(
                              'Канец праверкі',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
