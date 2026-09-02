import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped whenever Hive day/reading cache changes so UI providers rebuild.
final cacheEpochProvider = StateProvider<int>((ref) => 0);
