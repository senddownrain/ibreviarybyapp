import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';

const kAvailableFonts = [
  'Сістэмны',
  'Merriweather',
  'Lora',
  'Playfair Display',
  'Source Serif 4',
];

const kDefaultReaderFontSize = 16.0;
const kMinReaderFontScale = 0.7;
const kMaxReaderFontScale = 1.8;
const kReaderFontScaleStep = 0.1;
const kMinReaderFontSize = kDefaultReaderFontSize * kMinReaderFontScale;
const kMaxReaderFontSize = kDefaultReaderFontSize * kMaxReaderFontScale;
const kStartSections = <String>[
  'last',
  'hours',
  'readings',
  'prayerbook',
  'bible',
];

String startSectionLocation(String preference, String lastSection) {
  final section = preference == 'last' ? lastSection : preference;
  return switch (section) {
    'readings' => '/readings',
    'prayerbook' => '/prayers',
    'bible' => '/bible',
    _ => '/hours',
  };
}

double normalizeReaderFontSize(double size) =>
    size.clamp(kMinReaderFontSize, kMaxReaderFontSize).toDouble();

int readerFontScalePercent(double size) =>
    (normalizeReaderFontSize(size) / kDefaultReaderFontSize * 100).round();

class UserCategory {
  final String id;
  final String name;
  final List<String> tags;

  const UserCategory({
    required this.id,
    required this.name,
    required this.tags,
  });

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'tags': tags};

  factory UserCategory.fromMap(Map<String, dynamic> m) => UserCategory(
    id: m['id'] as String,
    name: m['name'] as String,
    tags: List<String>.from(m['tags'] as List? ?? []),
  );
}

class SettingsState {
  final ThemeMode themeMode;
  final double fontSize;
  final String fontFamily;
  final bool keepScreenOn;
  final List<UserCategory> userCategories;
  final List<String> hiddenGlobalPrayerCategoryIds;
  final List<String> favoriteIds;
  final String bibleVersionId;
  final String startSection;
  final String lastSection;

  /// Prayer ID mapped to a set of category IDs.
  final Map<String, Set<String>> prayerCategoryMap;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.fontSize = kDefaultReaderFontSize,
    this.fontFamily = 'Сістэмны',
    this.keepScreenOn = false,
    this.userCategories = const [],
    this.hiddenGlobalPrayerCategoryIds = const [],
    this.favoriteIds = const [],
    this.bibleVersionId = 'bel',
    this.startSection = 'hours',
    this.lastSection = 'hours',
    this.prayerCategoryMap = const {},
  });

  /// null means use system font
  String? get resolvedFontFamily =>
      fontFamily == 'Сістэмны' ? null : fontFamily;

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    String? fontFamily,
    bool? keepScreenOn,
    List<UserCategory>? userCategories,
    List<String>? hiddenGlobalPrayerCategoryIds,
    List<String>? favoriteIds,
    String? bibleVersionId,
    String? startSection,
    String? lastSection,
    Map<String, Set<String>>? prayerCategoryMap,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    userCategories: userCategories ?? this.userCategories,
    hiddenGlobalPrayerCategoryIds:
        hiddenGlobalPrayerCategoryIds ?? this.hiddenGlobalPrayerCategoryIds,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    bibleVersionId: bibleVersionId ?? this.bibleVersionId,
    startSection: startSection ?? this.startSection,
    lastSection: lastSection ?? this.lastSection,
    prayerCategoryMap: prayerCategoryMap ?? this.prayerCategoryMap,
  );
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _boxName = 'settings';
  late Box _box;

  @override
  SettingsState build() {
    _box = Hive.box(_boxName);
    final loaded = _load();
    setActiveThemeMode(loaded.themeMode);
    return loaded;
  }

  SettingsState _load() {
    final mode = _box.get('themeMode', defaultValue: 'system') as String;
    final cats = (_box.get('userCategories', defaultValue: '[]') as String);
    final favs = (_box.get('favoriteIds', defaultValue: '[]') as String);
    final hiddenCategories =
        (_box.get('hiddenGlobalPrayerCategoryIds', defaultValue: '[]')
            as String);
    final pcm = (_box.get('prayerCategoryMap', defaultValue: '{}') as String);
    final pcmRaw = jsonDecode(pcm) as Map;
    final prayerCategoryMap = {
      for (final e in pcmRaw.entries)
        e.key as String: Set<String>.from(e.value as List),
    };
    return SettingsState(
      themeMode: _parseTheme(mode),
      fontSize: normalizeReaderFontSize(
        (_box.get('fontSize', defaultValue: kDefaultReaderFontSize) as num)
            .toDouble(),
      ),
      fontFamily: _box.get('fontFamily', defaultValue: 'Сістэмны') as String,
      keepScreenOn: _box.get('keepScreenOn', defaultValue: false) as bool,
      userCategories: (jsonDecode(cats) as List)
          .map((e) => UserCategory.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      hiddenGlobalPrayerCategoryIds: List<String>.from(
        jsonDecode(hiddenCategories) as List,
      ),
      favoriteIds: List<String>.from(jsonDecode(favs) as List),
      bibleVersionId: _box.get('bibleVersionId', defaultValue: 'bel') as String,
      startSection: _validStartSection(
        _box.get('startSection', defaultValue: 'hours') as String,
      ),
      lastSection: _validLastSection(
        _box.get('lastSection', defaultValue: 'hours') as String,
      ),
      prayerCategoryMap: prayerCategoryMap,
    );
  }

  Future<void> _save() async {
    await _box.put('themeMode', _themeName(state.themeMode));
    await _box.put('fontSize', state.fontSize);
    await _box.put('fontFamily', state.fontFamily);
    await _box.put('keepScreenOn', state.keepScreenOn);
    await _box.put(
      'userCategories',
      jsonEncode(state.userCategories.map((c) => c.toMap()).toList()),
    );
    await _box.put(
      'hiddenGlobalPrayerCategoryIds',
      jsonEncode(state.hiddenGlobalPrayerCategoryIds),
    );
    await _box.put('favoriteIds', jsonEncode(state.favoriteIds));
    await _box.put('bibleVersionId', state.bibleVersionId);
    await _box.put('startSection', state.startSection);
    await _box.put('lastSection', state.lastSection);
    await _box.put(
      'prayerCategoryMap',
      jsonEncode({
        for (final e in state.prayerCategoryMap.entries)
          e.key: e.value.toList(),
      }),
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    setActiveThemeMode(mode);
    _save();
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: normalizeReaderFontSize(size));
    _save();
  }

  void increaseFontSize() => _stepFontSize(1);

  void decreaseFontSize() => _stepFontSize(-1);

  void _stepFontSize(int direction) {
    final currentStep =
        (state.fontSize / kDefaultReaderFontSize / kReaderFontScaleStep)
            .round();
    final minStep = (kMinReaderFontScale / kReaderFontScaleStep).round();
    final maxStep = (kMaxReaderFontScale / kReaderFontScaleStep).round();
    final nextStep = (currentStep + direction).clamp(minStep, maxStep);
    setFontSize(kDefaultReaderFontSize * nextStep * kReaderFontScaleStep);
  }

  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _save();
  }

  void setKeepScreenOn(bool value) {
    state = state.copyWith(keepScreenOn: value);
    _save();
  }

  Future<void> toggleFavorite(String id) {
    final favs = List<String>.from(state.favoriteIds);
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    state = state.copyWith(favoriteIds: favs);
    return _save();
  }

  String addCategory(String name, List<String> tags) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final cats = [
      ...state.userCategories,
      UserCategory(id: id, name: name, tags: tags),
    ];
    state = state.copyWith(userCategories: cats);
    _save();
    return id;
  }

  void updateCategory(String id, String name, List<String> tags) {
    final cats = state.userCategories
        .map(
          (c) => c.id == id ? UserCategory(id: id, name: name, tags: tags) : c,
        )
        .toList();
    state = state.copyWith(userCategories: cats);
    _save();
  }

  void deleteCategory(String id) {
    final cats = state.userCategories.where((c) => c.id != id).toList();
    final memberships = <String, Set<String>>{
      for (final entry in state.prayerCategoryMap.entries)
        if (entry.value.where((categoryId) => categoryId != id).isNotEmpty)
          entry.key: entry.value
              .where((categoryId) => categoryId != id)
              .toSet(),
    };
    state = state.copyWith(
      userCategories: cats,
      prayerCategoryMap: memberships,
    );
    _save();
  }

  void hideGlobalPrayerCategory(String id) {
    final hidden = {...state.hiddenGlobalPrayerCategoryIds, id}.toList();
    state = state.copyWith(hiddenGlobalPrayerCategoryIds: hidden);
    _save();
  }

  void showGlobalPrayerCategory(String id) {
    final hidden = state.hiddenGlobalPrayerCategoryIds
        .where((categoryId) => categoryId != id)
        .toList();
    state = state.copyWith(hiddenGlobalPrayerCategoryIds: hidden);
    _save();
  }

  void clearPrayerReferences(String prayerId) {
    final favorites = state.favoriteIds
        .where((favoriteId) => favoriteId != prayerId)
        .toList();
    final memberships = Map<String, Set<String>>.from(state.prayerCategoryMap)
      ..remove(prayerId);
    state = state.copyWith(
      favoriteIds: favorites,
      prayerCategoryMap: memberships,
    );
    _save();
  }

  void setBibleVersion(String versionId) {
    state = state.copyWith(bibleVersionId: versionId);
    _save();
  }

  void setStartSection(String section) {
    state = state.copyWith(startSection: _validStartSection(section));
    _save();
  }

  void rememberLastSection(String section) {
    final valid = _validLastSection(section);
    if (state.lastSection == valid) return;
    state = state.copyWith(lastSection: valid);
    _save();
  }

  void setPrayerCategory(String prayerId, String categoryId, bool selected) {
    final map = Map<String, Set<String>>.from(
      state.prayerCategoryMap.map((k, v) => MapEntry(k, Set<String>.from(v))),
    );
    final set = map[prayerId] ?? <String>{};
    if (selected) {
      set.add(categoryId);
    } else {
      set.remove(categoryId);
    }
    if (set.isEmpty) {
      map.remove(prayerId);
    } else {
      map[prayerId] = set;
    }
    state = state.copyWith(prayerCategoryMap: map);
    _save();
  }

  void resetDefaultCategories() {
    state = state.copyWith(hiddenGlobalPrayerCategoryIds: const []);
    _save();
  }

  ThemeMode _parseTheme(String s) => switch (s) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  String _themeName(ThemeMode m) => switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    _ => 'system',
  };

  String _validStartSection(String value) =>
      kStartSections.contains(value) ? value : 'hours';

  String _validLastSection(String value) =>
      const {'hours', 'readings', 'prayerbook', 'bible'}.contains(value)
      ? value
      : 'hours';
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
