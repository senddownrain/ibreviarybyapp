import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/screens/bible_chapter_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class HoursDateContext extends ConsumerStatefulWidget {
  const HoursDateContext({super.key, required this.date, required this.child});

  final DateTime date;
  final Widget child;

  @override
  ConsumerState<HoursDateContext> createState() => _HoursDateContextState();
}

class _HoursDateContextState extends ConsumerState<HoursDateContext> {
  @override
  void initState() {
    super.initState();
    _applyDate();
  }

  @override
  void didUpdateWidget(covariant HoursDateContext oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.date, widget.date)) _applyDate();
  }

  void _applyDate() {
    ref.read(selectedDateProvider.notifier).state = DateUtils.dateOnly(
      widget.date,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ReadingsBranchHost extends ConsumerStatefulWidget {
  const ReadingsBranchHost({
    super.key,
    this.date,
    this.dayId,
    this.liturgicalKey,
    this.invalidContext,
  });

  final DateTime? date;
  final String? dayId;
  final String? liturgicalKey;
  final String? invalidContext;

  @override
  ConsumerState<ReadingsBranchHost> createState() => _ReadingsBranchHostState();
}

class _ReadingsBranchHostState extends ConsumerState<ReadingsBranchHost> {
  @override
  void initState() {
    super.initState();
    _applyExplicitContext();
  }

  @override
  void didUpdateWidget(covariant ReadingsBranchHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        oldWidget.dayId != widget.dayId ||
        oldWidget.liturgicalKey != widget.liturgicalKey) {
      _applyExplicitContext();
    }
  }

  void _applyExplicitContext() {
    if (widget.invalidContext != null) return;
    final current = ref.read(readingsBranchStateProvider);
    if (widget.liturgicalKey != null) {
      ref.read(readingsBranchStateProvider.notifier).state = current.copyWith(
        liturgicalKey: widget.liturgicalKey,
        dayId: widget.dayId,
        clearDayId: widget.dayId == null,
      );
      return;
    }
    if (widget.date != null) {
      ref.read(readingsBranchStateProvider.notifier).state = current.copyWith(
        date: widget.date,
        dayId: widget.dayId,
        clearLiturgicalKey: true,
        clearDayId: widget.dayId == null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invalidContext case final message?) {
      return _BranchError(message: message);
    }
    final state = ref.watch(readingsBranchStateProvider);
    final content = state.liturgicalKey != null
        ? ReadingsScreen(
            key: ValueKey('readings-liturgical-${state.liturgicalKey}'),
            liturgicalKey: state.liturgicalKey,
            dayId: state.dayId,
          )
        : ReadingsScreen(
            key: ValueKey(
              'readings-${state.date.toIso8601String()}-${state.dayId ?? ''}',
            ),
            dateStr: _dateKey(state.date),
            dayId: state.dayId,
          );

    final navigation = AppNavigationScope.of(context);
    final chrome = ReaderChromeModeScope.maybeControllerOf(context)!;
    return AnimatedBuilder(
      animation: Listenable.merge([navigation.shellState, chrome]),
      child: content,
      builder: (context, child) {
        final hasOraReturn = navigation.shellState.canReturnToOra();
        final focusIsHidden = chrome.value == ReaderChromeMode.hidden;
        return PopScope<void>(
          canPop: !hasOraReturn,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && hasOraReturn && !focusIsHidden) {
              navigation.returnToOra();
            }
          },
          child: child!,
        );
      },
    );
  }
}

class BibleBranchHost extends ConsumerWidget {
  const BibleBranchHost({
    super.key,
    this.version,
    this.book,
    this.chapter,
    this.invalidContext,
  });

  final String? version;
  final String? book;
  final int? chapter;
  final String? invalidContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invalidContext case final message?) {
      return _BranchError(message: message);
    }

    final resolvedVersion =
        version ?? ref.watch(settingsProvider).bibleVersionId;
    final books = BibleRepository.getBooks(resolvedVersion);
    if (books.isEmpty) {
      if (version != null) {
        return const _BranchError(message: 'Невядомы пераклад Бібліі.');
      }
      return const Center(child: CircularProgressIndicator());
    }
    final savedRaw = HiveService.settingsBox.get(
      'bibleLastLocation:$resolvedVersion',
    );
    final saved = savedRaw is Map ? savedRaw : const <String, dynamic>{};
    final resolvedBook = book ?? saved['bookId']?.toString() ?? books.first.id;
    final requestedChapter =
        chapter ?? int.tryParse(saved['chapter']?.toString() ?? '') ?? 1;

    return BibleChapterScreen(
      key: ValueKey('bible-$resolvedVersion-$resolvedBook-$requestedChapter'),
      versionId: resolvedVersion,
      bookId: resolvedBook,
      chapter: requestedChapter,
    );
  }
}

class SecondaryPageScaffold extends StatelessWidget {
  const SecondaryPageScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    void close() {
      if (canPop) {
        Navigator.pop(context);
      } else {
        context.go('/hours');
      }
    }

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Закрыць',
            onPressed: close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: child,
      ),
    );
  }
}

class _BranchError extends StatelessWidget {
  const _BranchError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
