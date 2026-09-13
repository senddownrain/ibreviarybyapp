import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';

final bibleDataProvider = FutureProvider<void>((ref) async {
  ref.watch(cacheEpochProvider);
  await BibleRepository.preload();
});
