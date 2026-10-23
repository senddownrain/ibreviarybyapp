import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Memory-only settings for the isolated real-bundle Chrome acceptance stand.
class DevotionalSmokeSettings extends SettingsNotifier {
  DevotionalSmokeSettings(this.initial);
  final SettingsState initial;
  @override
  SettingsState build() => initial;
  @override
  void setFontSize(double size) =>
      state = state.copyWith(fontSize: normalizeReaderFontSize(size));
  @override
  void setFontFamily(String family) =>
      state = state.copyWith(fontFamily: normalizeReaderFontFamily(family));
  @override
  Future<void> setPsalmVerseLayout(PsalmVerseLayout value) async =>
      state = state.copyWith(psalmVerseLayout: value);
  @override
  Future<void> setPsalmMarkerBreakMode(PsalmMarkerBreakMode value) async =>
      state = state.copyWith(psalmMarkerBreakMode: value);
  @override
  Future<void> toggleFavorite(String id) async => state = state.copyWith(
    favoriteIds: state.favoriteIds.contains(id)
        ? state.favoriteIds.where((v) => v != id).toList()
        : [...state.favoriteIds, id],
  );
}

class _EmptyLocals extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [];
}

/// The production detail screen and ReaderScaffold; no Firebase or Hive setup,
/// no fixture liturgical text, and no production provider can fetch/write data.
class DevotionalOfficeHarness extends StatefulWidget {
  const DevotionalOfficeHarness({
    super.key,
    required this.prayers,
    required this.initialId,
    this.settings = const SettingsState(),
    this.dark = false,
    this.scale = 1,
    this.systemFonts = false,
  });
  final List<Prayer> prayers;
  final String initialId;
  final SettingsState settings;
  final bool dark, systemFonts;
  final double scale;
  @override
  State<DevotionalOfficeHarness> createState() =>
      _DevotionalOfficeHarnessState();
}

class _DevotionalOfficeHarnessState extends State<DevotionalOfficeHarness> {
  late final router = GoRouter(
    overridePlatformDefaultLocation: true,
    initialLocation: '/prayers/prayer/${widget.initialId}',
    routes: [
      GoRoute(
        path: '/prayers/prayer/:id',
        builder: (_, state) =>
            PrayerDetailScreen(prayerId: state.pathParameters['id']!),
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
      settingsProvider.overrideWith(
        () => DevotionalSmokeSettings(widget.settings),
      ),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      allPrayersProvider.overrideWithValue(widget.prayers),
      localPrayersProvider.overrideWith(_EmptyLocals.new),
      prayersContentProvider.overrideWith((ref) async {}),
      protectedPrayerProvider.overrideWith((ref, id) async => null),
    ],
    child: ReaderTypographyScope(
      useSystemFonts: widget.systemFonts,
      child: MaterialApp.router(
        title: 'Devotional offices · Flutter bundled offline',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          brightness: widget.dark ? Brightness.dark : Brightness.light,
          colorScheme: AppPalette.scheme(
            widget.dark ? Brightness.dark : Brightness.light,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(widget.scale)),
          child: child!,
        ),
      ),
    ),
  );
}
