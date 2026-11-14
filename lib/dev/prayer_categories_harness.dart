import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/admin_songbook_access_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Real Flutter screens and membership providers; synthetic, memory-only data.
/// No Firebase initialization, credentials, production content or disk cache.
class PrayerCategoriesHarness extends StatefulWidget {
  const PrayerCategoriesHarness({
    super.key,
    required this.content,
    this.scheme = 'light',
    this.scale = 1,
    this.platform = TargetPlatform.android,
  });
  final PrayerAccessContent content;
  final String scheme;
  final double scale;
  final TargetPlatform platform;
  @override
  State<PrayerCategoriesHarness> createState() => _HarnessState();
}

class _HarnessState extends State<PrayerCategoriesHarness> {
  late String scheme = widget.scheme;
  late double scale = widget.scale;
  late final access = CategorySmokeAccess(widget.content);
  late final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          appBar: AppBar(
            title: const Text('Катэгорыі · synthetic', maxLines: 1),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Theme',
                onSelected: (value) => setState(() => scheme = value),
                itemBuilder: (_) => [
                  for (final value in ['light', 'dark', 'marian'])
                    PopupMenuItem(value: value, child: Text(value)),
                ],
              ),
              IconButton(
                tooltip: 'Text size',
                onPressed: () => setState(() => scale = scale == 1 ? 2 : 1),
                icon: const Icon(Icons.text_fields),
              ),
              IconButton(
                tooltip: 'Grant',
                onPressed: () => access.setGranted(!access.granted),
                icon: const Icon(Icons.key),
              ),
            ],
          ),
          body: child,
        ),
        routes: [
          GoRoute(
            path: '/prayers',
            builder: (_, _) => const PrayersScreen(),
            routes: [
              GoRoute(
                path: 'category/:id',
                builder: (_, state) => PrayerCategoryScreen(
                  categoryId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'prayer/:id',
                builder: (_, state) =>
                    PrayerDetailScreen(prayerId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'all',
                builder: (_, _) => const PrayerCatalogScreen(),
              ),
              GoRoute(
                path: 'search',
                builder: (_, _) =>
                    const PrayerCatalogScreen(searchInitially: true),
              ),
              GoRoute(
                path: 'categories',
                builder: (_, _) => const PrayerCategoriesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    initialLocation: '/prayers',
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith(CategorySmokeSettings.new),
      priestAccessProvider.overrideWith((ref) => access),
      adminSongbookAccessProvider.overrideWith((ref) => Stream.value(false)),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      prayersContentProvider.overrideWith((ref) async {}),
      localPrayersProvider.overrideWith(_SmokeLocals.new),
      globalPrayerCategoriesProvider.overrideWith((ref) {
        final current = ref.watch(priestAccessProvider);
        final source = current.content ?? current.publicContent!;
        final policy = PriestAccessPolicy(source.categories);
        return Stream.value([
          for (final e in source.categories.entries)
            if (policy.categoryValid(e.key) &&
                (current.content != null || !policy.categoryRestricted(e.key)))
              PrayerMenuCategory.global(e.key, {
                ...e.value,
                'effectivePriestOnly': policy.categoryRestricted(e.key),
              }),
        ]);
      }),
      protectedPrayerProvider.overrideWith(
        (ref, id) async => ref.watch(priestAccessProvider).content?.prayers[id],
      ),
    ],
    child: ReaderTypographyScope(
      useSystemFonts: false,
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          platform: widget.platform,
          colorScheme: scheme == 'marian'
              ? AppPalette.marianScheme
              : AppPalette.scheme(
                  scheme == 'dark' ? Brightness.dark : Brightness.light,
                ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
}

class CategorySmokeSettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(
    userCategories: [
      UserCategory(id: 'mine', name: 'Асабісты раздзел', tags: ['root-tag']),
    ],
  );
  @override
  Future<void> toggleFavorite(String id) async {
    final ids = [...state.favoriteIds];
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    state = state.copyWith(favoriteIds: ids);
  }

  @override
  void hideGlobalPrayerCategory(String id) => state = state.copyWith(
    hiddenGlobalPrayerCategoryIds: [...state.hiddenGlobalPrayerCategoryIds, id],
  );
  @override
  void showGlobalPrayerCategory(String id) => state = state.copyWith(
    hiddenGlobalPrayerCategoryIds: state.hiddenGlobalPrayerCategoryIds
        .where((value) => value != id)
        .toList(),
  );
}

class _SmokeLocals extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [];
}

class CategorySmokeAccess extends PriestAccessController {
  CategorySmokeAccess(this.fixture) : super(_NoGateway(), _MemoryStorage()) {
    setGranted(false);
  }
  final PrayerAccessContent fixture;
  bool get granted => state.content != null;
  void setGranted(bool value) => state = PriestAccessState(
    publicContent: fixture.publicOnly,
    content: value ? fixture : null,
  );
}

class _NoGateway implements PriestAccessGateway {
  @override
  Future<void> clearProtectedMemory() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Network is disabled in this synthetic harness');
}

class _MemoryStorage implements PriestAccessStorage {
  @override
  Future<Map<String, dynamic>> read() async => {};
  @override
  Future<void> write(Map<String, dynamic> data) async {}
}
