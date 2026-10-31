import 'package:hive/hive.dart';

/// Where the encoded `DiscoveryState` lives. Implementations hold only the
/// discovery key; they never read or write anything else.
abstract class DiscoveryStorage {
  Future<String?> read();

  Future<void> write(String value);

  /// Removes the discovery payload only.
  Future<void> clear();
}

/// Isolated test double and the fallback when Hive is unavailable.
class MemoryDiscoveryStorage implements DiscoveryStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> clear() async => value = null;
}

/// Own Hive box, so the user's `settings`, favourites, prayers and caches are
/// never touched. The schema version is part of the box name and key.
class HiveDiscoveryStorage implements DiscoveryStorage {
  HiveDiscoveryStorage({this.boxName = defaultBoxName});

  static const defaultBoxName = 'discovery_v1';
  static const stateKey = 'discovery.v1.state';

  final String boxName;
  Box<String>? _box;

  Future<Box<String>> _open() async => _box ??= Hive.isBoxOpen(boxName)
      ? Hive.box<String>(boxName)
      : await Hive.openBox<String>(boxName);

  @override
  Future<String?> read() async => (await _open()).get(stateKey);

  @override
  Future<void> write(String value) async =>
      (await _open()).put(stateKey, value);

  @override
  Future<void> clear() async => (await _open()).delete(stateKey);
}
