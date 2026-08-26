import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const _metaBox = 'meta';
  static const _prayersBoxName = 'prayers';
  static const _daysBoxName = 'days';
  static const _yearOptionsBoxName = 'yearOptions';
  static const _parsedDataBoxName = 'parsedData';
  static const _readingsBoxName = 'readings';
  static const _localPrayersBoxName = 'localPrayers';
  static const _settingsBoxName = 'settings';
  static const _invitatoriumsBoxName = 'invitatoriums';
  static const _completoriumsBoxName = 'completoriums';

  static late Box _meta;
  static late Box _prayers;
  static late Box _days;
  static late Box _yearOptions;
  static late Box _parsedData;
  static late Box _readings;
  static late Box _localPrayers;
  static late Box _settings;
  static late Box _invitatoriums;
  static late Box _completoriums;

  static Box get prayersBox => _prayers;
  static Box get daysBox => _days;
  static Box get yearOptionsBox => _yearOptions;
  static Box get parsedDataBox => _parsedData;
  static Box get readingsBox => _readings;
  static Box get localPrayersBox => _localPrayers;
  static Box get settingsBox => _settings;
  static Box get invitatoriumsBox => _invitatoriums;
  static Box get completoriumsBox => _completoriums;

  static Future<void> init() async {
    await Hive.initFlutter();
    _meta = await Hive.openBox(_metaBox);
    _prayers = await Hive.openBox(_prayersBoxName);
    _days = await Hive.openBox(_daysBoxName);
    _yearOptions = await Hive.openBox(_yearOptionsBoxName);
    _parsedData = await Hive.openBox(_parsedDataBoxName);
    _readings = await Hive.openBox(_readingsBoxName);
    _localPrayers = await Hive.openBox(_localPrayersBoxName);
    _settings = await Hive.openBox(_settingsBoxName);
    _invitatoriums = await Hive.openBox(_invitatoriumsBoxName);
    _completoriums = await Hive.openBox(_completoriumsBoxName);
  }

  static DateTime? getLastSync(String collection) {
    final ts = _meta.get('lastSync_$collection');
    if (ts == null) return null;
    return DateTime.tryParse(ts as String);
  }

  static Future<void> setLastSync(String collection, DateTime time) async {
    await _meta.put('lastSync_$collection', time.toIso8601String());
  }
}
