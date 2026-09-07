import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// Opens the last read chapter directly, matching the single-page web reader.
class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(settingsProvider).bibleVersionId;
    final books = BibleRepository.getBooks(version);
    if (!_scheduled && books.isNotEmpty) {
      _scheduled = true;
      final raw = HiveService.settingsBox.get('bibleLastLocation:$version');
      final saved = raw is Map ? raw : const <String, dynamic>{};
      final savedBook = BibleRepository.getBook(
        version,
        saved['bookId']?.toString() ?? '',
      );
      final book = savedBook ?? books.first;
      final requested = int.tryParse(saved['chapter']?.toString() ?? '') ?? 1;
      final chapter = requested.clamp(1, book.chapterCount);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/bible/$version/${book.id}/$chapter');
      });
    }
    return const Center(child: CircularProgressIndicator());
  }
}
