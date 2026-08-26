import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

const _kLocalPrefix = 'local_';

class LocalPrayersNotifier extends Notifier<List<Prayer>> {
  @override
  List<Prayer> build() => _loadAll();

  /// Returns true if the given prayer id belongs to a local (user-created) prayer.
  static bool isLocal(String id) => id.startsWith(_kLocalPrefix);

  List<Prayer> _loadAll() {
    final box = HiveService.localPrayersBox;
    final prayers = <Prayer>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        prayers.add(Prayer.fromMap(
            Map<String, dynamic>.from(raw), key as String));
      } catch (_) {}
    }
    prayers.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
    return prayers;
  }

  Future<Prayer> create({
    required String title,
    String? body,
    List<String> tags = const [],
  }) async {
    final id = '$_kLocalPrefix${DateTime.now().millisecondsSinceEpoch}';
    final prayer = Prayer(
      id: id,
      title: title,
      body: body,
      tags: tags,
      isLocal: true,
    );
    await HiveService.localPrayersBox.put(id, prayer.toMap());
    state = _loadAll();
    return prayer;
  }

  Future<void> update(Prayer prayer) async {
    await HiveService.localPrayersBox.put(prayer.id, prayer.toMap());
    state = _loadAll();
  }

  Future<void> delete(String id) async {
    await HiveService.localPrayersBox.delete(id);
    state = _loadAll();
  }
}

final localPrayersProvider =
    NotifierProvider<LocalPrayersNotifier, List<Prayer>>(
        LocalPrayersNotifier.new);
