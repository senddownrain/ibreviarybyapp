import 'package:hive/hive.dart';

/// Holds the encoded `AppReviewState`. Its own Hive box, so settings,
/// favourites and the discovery box are never touched.
abstract class AppReviewStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class MemoryAppReviewStorage implements AppReviewStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> clear() async => value = null;
}

class HiveAppReviewStorage implements AppReviewStorage {
  HiveAppReviewStorage({this.boxName = defaultBoxName});

  static const defaultBoxName = 'app_review_v1';
  static const stateKey = 'review.v1.state';

  final String boxName;
  Box<String>? _box;

  /// `main()` opens the box before `runApp`. Never open it lazily here: with
  /// Hive uninitialised (tests, a failed start) that would raise an error
  /// Hive also reports to the zone, which no `try` can catch.
  Future<Box<String>> _open() async {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('Review box "$boxName" is not open');
    }
    return _box ??= Hive.box<String>(boxName);
  }

  @override
  Future<String?> read() async => (await _open()).get(stateKey);

  @override
  Future<void> write(String value) async =>
      (await _open()).put(stateKey, value);

  @override
  Future<void> clear() async => (await _open()).delete(stateKey);
}
