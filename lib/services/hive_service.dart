import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class HiveService {
  static const _metaBox = 'meta';
  static const _prayersBoxName = 'prayers';
  static const _daysBoxName = 'days';
  static const _yearOptionsBoxName = 'yearOptions';
  static const _readingsBoxName = 'readings';
  static const _readingsIndexBoxName = 'readingsIndex';
  static const _localPrayersBoxName = 'localPrayers';
  static const _settingsBoxName = 'settings';
  static const _invitatoriumsBoxName = 'invitatoriums';
  static const _completoriumsBoxName = 'completoriums';

  static late Box _meta;
  static late Box _prayers;
  static late Box _days;
  static late Box _yearOptions;
  static late Box _readings;
  static late Box _readingsIndex;
  static late Box _localPrayers;
  static Box? _settings;
  static late Box _invitatoriums;
  static late Box _completoriums;

  static bool get isCacheReady =>
      Hive.isBoxOpen(_metaBox) &&
      Hive.isBoxOpen(_daysBoxName) &&
      Hive.isBoxOpen(_readingsBoxName);

  static Box get prayersBox => _prayers;
  static Box get daysBox => _days;
  static Box get yearOptionsBox => _yearOptions;
  static Box get readingsBox => _readings;
  static Box get readingsIndexBox => _readingsIndex;
  static Box get localPrayersBox => _localPrayers;
  static bool get isSettingsReady =>
      (_settings?.isOpen ?? false) || Hive.isBoxOpen(_settingsBoxName);
  static Box get settingsBox => _settings ?? Hive.box(_settingsBoxName);
  static Box get invitatoriumsBox => _invitatoriums;
  static Box get completoriumsBox => _completoriums;

  static Box boxFor(String collection) => Hive.box(collection);

  static final cacheRevision = ValueNotifier<int>(0);
  static int receivedBytes = 0;
  static int receivedDocuments = 0;

  static int cachedBytes(String collection) {
    final value = _meta.get('bytes_$collection');
    if (value is num) return value.toInt();
    final bytes = boxFor(
      collection,
    ).values.fold<int>(0, (sum, value) => sum + payloadBytes(value));
    _meta.put('bytes_$collection', bytes);
    return bytes;
  }

  /// Serialized content size; excludes Firestore/network protocol overhead.
  static int payloadBytes(Object? value) =>
      utf8.encode(jsonEncode(value)).length;

  static final Map<String, Future<void>> _writes = {};

  static Future<void> putCached(String collection, dynamic key, Object data) {
    final next = (_writes[collection] ?? Future<void>.value()).then(
      (_) => _putCached(collection, key, data),
    );
    _writes[collection] = next.catchError((Object _) {});
    return next;
  }

  static Future<void> _putCached(
    String collection,
    dynamic key,
    Object data,
  ) async {
    final box = boxFor(collection);
    final previous = box.get(key);
    final oldTotal = cachedBytes(collection);
    receivedBytes += payloadBytes(data);
    receivedDocuments++;
    final delta =
        payloadBytes(data) - (previous == null ? 0 : payloadBytes(previous));
    await box.put(key, data);
    await _meta.put('bytes_$collection', (oldTotal + delta).clamp(0, 1 << 53));
    cacheRevision.value++;
  }

  static Future<void> removeCached(String collection, dynamic key) async {
    final box = boxFor(collection);
    final old = box.get(key);
    if (old == null) return;
    await box.delete(key);
    await _meta.put(
      'bytes_$collection',
      (cachedBytes(collection) - payloadBytes(old)).clamp(0, 1 << 53),
    );
  }

  static String dateCacheKey(String collection, DateTime date) =>
      'ready_${collection}_${date.year}-${date.month}-${date.day}';

  static bool isDateCached(String collection, DateTime date) =>
      getMetaFlag('fullCache_$collection') == true ||
      getMetaFlag(dateCacheKey(collection, date)) == true;

  static Future<void> markDateCached(String collection, DateTime date) =>
      setMetaFlag(dateCacheKey(collection, date), true);

  static Future<void> init({String? path}) async {
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }
    _meta = await Hive.openBox(_metaBox);
    _prayers = await Hive.openBox(_prayersBoxName);
    _days = await Hive.openBox(_daysBoxName);
    _yearOptions = await Hive.openBox(_yearOptionsBoxName);
    _readings = await Hive.openBox(_readingsBoxName);
    _readingsIndex = await Hive.openBox(_readingsIndexBoxName);
    _localPrayers = await Hive.openBox(_localPrayersBoxName);
    _settings = await Hive.openBox(_settingsBoxName);
    _invitatoriums = await Hive.openBox(_invitatoriumsBoxName);
    _completoriums = await Hive.openBox(_completoriumsBoxName);
    await Hive.openBox('bible_bel');
    await Hive.openBox('bible_bel_charniauski');
    await Hive.openBox('bible_ru');
    await Hive.openBox('prayerCategories');
  }

  static DateTime? getLastSync(String collection) {
    final ts = _meta.get('lastSync_$collection');
    if (ts == null) return null;
    return DateTime.tryParse(ts as String);
  }

  static Future<void> setLastSync(String collection, DateTime time) async {
    await _meta.put('lastSync_$collection', time.toIso8601String());
  }

  static bool? getMetaFlag(String key) => _meta.get(key) as bool?;

  static Future<void> setMetaFlag(String key, bool value) async {
    await _meta.put(key, value);
  }

  static Future<void> setWarmupCoverage(DateTime from, DateTime to) async {
    await _meta.put('warmupFrom', from.toIso8601String());
    await _meta.put('warmupTo', to.toIso8601String());
  }

  static (DateTime, DateTime)? getWarmupCoverage() {
    final from = DateTime.tryParse(_meta.get('warmupFrom')?.toString() ?? '');
    final to = DateTime.tryParse(_meta.get('warmupTo')?.toString() ?? '');
    if (from == null || to == null) return null;
    return (from, to);
  }

  /// True when essential offline data has never been synced.
  static bool needsBootstrap() =>
      yearOptionsBox.isEmpty ||
      prayersBox.isEmpty ||
      invitatoriumsBox.isEmpty ||
      completoriumsBox.isEmpty;
}
