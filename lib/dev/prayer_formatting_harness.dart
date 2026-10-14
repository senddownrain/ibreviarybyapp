import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayer_form_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/reader.dart';

const formattingSource = '''К. Пане, адкрый вусны мае.
Н. І вусны мае будуць абвяшчаць хвалу Тваю.

С.: Пан з вамі.
Н.: І з духам тваім.

:::rubric
Усе ўстаюць.
:::

> Гэта сапраўдная цытата.
> Н. І з духам тваім.

Н. _Молімся._ **Амэн.**

[Іншая малітва](/prayer/test-id)
[Няма малітвы](/prayer/missing)
[Закрытая малітва](/prayer/restricted)

## Літанія
''';

const parity11Source = '''## MyBrev 1.1

**С.** Пан з вамі.
**Н.:** І з духам тваім.
_К._ Пане, пачуй нас.
**_Д._**: Пане, пачуй нас.

**С.: Словы тлустай рэплікі.**
_Н.: Словы курсіўнага адказу._

**С.: Першы радок,
другі радок.**

К.
Пане, пачуй нас.
Н.
Амэн.

**Усе:** Амэн.
Цэлебрант: Пан з вамі.

_Усе ўстаюць._

Святар кажа:

_Молімся._ _Вітай, Марыя…_

> Н. І з духам тваім.
> **Н.** Аўтарская тлустая метка.
> Усе: Без аўтаматычнай ролі.

**С. Імя:** _Словы апавядання._

[Іншая малітва](/prayer/test-id)
''';
const parity11Prayer = Prayer(
  id: 'local_parity11',
  title: 'MyBrev 1.1 · кантроль',
  body: parity11Source,
  textFormat: 'mybrev-markdown',
  isLocal: true,
);
final formattingPrayer = Prayer(
  id: 'local_formatting',
  title: 'Фарматаванне малітваў',
  isLocal: true,
  body:
      '$formattingSource\n${List.generate(50, (i) => 'Н. Змілуйся над намі. ${i + 1}.').join('\n')}',
  textFormat: 'mybrev-markdown',
);
const linkedPrayer = Prayer(
  id: 'test-id',
  title: 'Іншая малітва',
  body: 'Н. Амэн.',
);
const restrictedPrayer = Prayer(
  id: 'restricted',
  title: 'Недаступная',
  body: 'SECRET',
  priestOnly: true,
);
const legacyPrayer = Prayer(
  id: 'legacy',
  title: 'Спадчынны HTML',
  body:
      '<p><span style="color:red">Усе ўстаюць.</span></p><p><b>Молімся.</b><br>Пан з вамі.</p>'
      '<p><strong>С.:</strong> Пан з вамі.<br><em>Н.: І з духам тваім.</em></p>'
      '<p class="rubric">Усе ўстаюць.</p><p><em>Молімся.</em></p>'
      '<blockquote>Н. І з духам тваім.</blockquote><p><a href="/prayer/test-id">Іншая малітва</a></p>'
      '<script>SECRET_SCRIPT</script><a href="javascript:evil()">Бяспечны тэкст</a>',
);

class FormattingSettings extends SettingsNotifier {
  FormattingSettings({this.size = 16});
  final double size;
  @override
  SettingsState build() => SettingsState(fontSize: size);
  @override
  void setFontSize(double size) =>
      state = state.copyWith(fontSize: normalizeReaderFontSize(size));
  @override
  void setFontFamily(String family) =>
      state = state.copyWith(fontFamily: normalizeReaderFontFamily(family));
  @override
  void setKeepScreenOn(bool value) =>
      state = state.copyWith(keepScreenOn: value);
  @override
  Future<void> toggleFavorite(String id) async => state = state.copyWith(
    favoriteIds: state.favoriteIds.contains(id) ? [] : [id],
  );
}

class FormattingLocals extends LocalPrayersNotifier {
  int _sequence = 0;
  @override
  List<Prayer> build() => [formattingPrayer, parity11Prayer];
  @override
  Future<Prayer> create({
    required String title,
    String? body,
    List<String> tags = const [],
    String? textFormat = localPrayerTextFormat,
  }) async {
    final prayer = Prayer(
      id: 'local_smoke_${_sequence++}',
      title: title,
      body: body,
      tags: tags,
      textFormat: textFormat,
      isLocal: true,
    );
    state = [...state, prayer];
    return prayer;
  }

  @override
  Future<void> update(Prayer prayer) async => state = [
    for (final current in state) current.id == prayer.id ? prayer : current,
  ];
  @override
  Future<void> delete(String id) async =>
      state = state.where((prayer) => prayer.id != id).toList();
}

/// Uses the real screens with memory-only providers. No Firebase or Hive setup.
class PrayerFormattingHarness extends StatefulWidget {
  const PrayerFormattingHarness({
    super.key,
    this.realPrayers = const [],
    this.systemFonts = false,
  });
  final List<Prayer> realPrayers;
  final bool systemFonts;
  @override
  State<PrayerFormattingHarness> createState() => _HarnessState();
}

class _HarnessState extends State<PrayerFormattingHarness> {
  bool dark = false;
  bool narrow = false;
  late final router = GoRouter(
    initialLocation: '/prayers/prayer/local_formatting',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _frame(context, child),
        routes: [
          GoRoute(
            path: '/prayers/prayer/:id',
            builder: (_, state) =>
                PrayerDetailScreen(prayerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, state) => PrayerFormScreen(
              prayerId:
                  state.uri.queryParameters['prayerId'] ?? 'local_formatting',
            ),
          ),
        ],
      ),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith(FormattingSettings.new),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      allPrayersProvider.overrideWithValue([
        linkedPrayer,
        legacyPrayer,
        restrictedPrayer,
        ...widget.realPrayers,
      ]),
      localPrayersProvider.overrideWith(FormattingLocals.new),
      prayersContentProvider.overrideWith((ref) async {}),
      protectedPrayerProvider.overrideWith((ref, id) async => null),
    ],
    child: ReaderTypographyScope(
      useSystemFonts: widget.systemFonts,
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          colorScheme: AppPalette.scheme(
            dark ? Brightness.dark : Brightness.light,
          ),
        ),
      ),
    ),
  );
  Widget _frame(BuildContext context, Widget child) => StatefulBuilder(
    builder: (context, setFrameState) => Scaffold(
      appBar: AppBar(
        title: const Text('Prayer formatting · isolated offline smoke'),
        actions: [
          IconButton(
            tooltip: 'Theme',
            onPressed: () => setState(() => dark = !dark),
            icon: const Icon(Icons.brightness_6),
          ),
          IconButton(
            tooltip: '320px',
            onPressed: () => setFrameState(() => narrow = !narrow),
            icon: const Icon(Icons.smartphone),
          ),
          IconButton(
            tooltip: 'Reader',
            onPressed: () => router.go('/prayers/prayer/local_formatting'),
            icon: const Icon(Icons.book),
          ),
          IconButton(
            tooltip: 'Preview',
            onPressed: () => router.push(
              router.routeInformationProvider.value.uri.path.endsWith(
                    '/local_parity11',
                  )
                  ? '/edit?prayerId=local_parity11'
                  : '/edit',
            ),
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: 'Legacy',
            onPressed: () => router.go('/prayers/prayer/legacy'),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.realPrayers.isNotEmpty)
            DropdownButton<String>(
              hint: const Text('Bundled public prayer'),
              isExpanded: true,
              items: [
                for (final prayer in [parity11Prayer, ...widget.realPrayers])
                  DropdownMenuItem(
                    value: prayer.id,
                    child: Text(
                      prayer.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) router.go('/prayers/prayer/$id');
              },
            ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: narrow ? 320 : double.infinity,
                child: child,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
