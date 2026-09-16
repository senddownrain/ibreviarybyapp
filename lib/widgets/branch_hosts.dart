import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/navigation/bible_navigation.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/providers/bible_data_provider.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/screens/bible_chapter_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/horizontal_swipe_navigation.dart';

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
    final date = DateUtils.dateOnly(widget.date);
    // initState/didUpdateWidget run while the widget tree is building; writing
    // the provider here would notify sync listeners mid-build.
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      ref.read(selectedDateProvider.notifier).state = date;
    } else {
      binding.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedDateProvider.notifier).state = date;
      });
    }
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
      ref
          .read(liturgicalNavigationControllerProvider)
          .openDate(widget.date!, dayId: widget.dayId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invalidContext case final message?) {
      return _BranchError(message: message);
    }
    final state = ref.watch(readingsBranchStateProvider);
    final sharedDate = DateUtils.dateOnly(ref.watch(selectedDateProvider));
    final sharedDayId = ref.watch(hoursLiturgicalSelectionProvider).dayId;
    final direction = ref.watch(homeNavDirectionProvider);
    final content = state.liturgicalKey != null
        ? ReadingsScreen(
            key: ValueKey('readings-liturgical-${state.liturgicalKey}'),
            liturgicalKey: state.liturgicalKey,
            dayId: state.dayId,
          )
        : ReadingsScreen(
            key: ValueKey(
              'readings-${sharedDate.toIso8601String()}-${sharedDayId ?? ''}',
            ),
            dateStr: _dateKey(sharedDate),
            dayId: sharedDayId,
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
          child: state.liturgicalKey == null
              ? LiturgicalDayTransition(direction: direction, child: child!)
              : child!,
        );
      },
    );
  }
}

class BibleBranchHost extends ConsumerStatefulWidget {
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
  ConsumerState<BibleBranchHost> createState() => _BibleBranchHostState();
}

class _BibleBranchHostState extends ConsumerState<BibleBranchHost> {
  bool _retrying = false;
  String? _retryError;
  BibleLocation? _lastLocation;
  int _navigationDirection = 0;

  int _locationIndex(BibleLocation location) {
    final books = BibleRepository.getBooks(location.versionId);
    var index = 0;
    for (final book in books) {
      if (book.id == location.bookId) return index + location.chapter;
      index += book.chapterCount;
    }
    return index;
  }

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      await BibleRepository.reloadBundled();
    } catch (error) {
      _retryError = error.toString();
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(bibleDataProvider);
    if (data.isLoading &&
        BibleRepository.getBooks(widget.version ?? 'bel').isEmpty) {
      return const Scaffold(
        body: Center(
          child: DataLoadingNotice(
            label: 'Адкрываем пераклад Бібліі з лакальных даных',
            collections: ['bible_bel', 'bible_ru'],
          ),
        ),
      );
    }

    if (widget.invalidContext case final message?) {
      return _BranchError(message: message);
    }

    final resolvedVersion =
        widget.version ?? ref.watch(settingsProvider).bibleVersionId;
    final books = BibleRepository.getBooks(resolvedVersion);
    if (books.isEmpty) {
      if (widget.version != null) {
        return const _BranchError(message: 'Невядомы пераклад Бібліі.');
      }
      return _BranchError(
        message: _retryError == null
            ? 'Тэкст Бібліі недаступны на гэтай прыладзе.'
            : 'Не ўдалося аднавіць тэкст Бібліі. $_retryError',
        actionLabel: _retrying ? 'Загрузка…' : 'Паўтарыць',
        onAction: _retrying ? null : _retry,
      );
    }
    final savedRaw = HiveService.settingsBox.get(
      BibleNavigation.lastLocationKey(resolvedVersion),
    );
    final saved = savedRaw is Map ? savedRaw : const <String, dynamic>{};
    final location = BibleNavigation.resolve(
      versionId: resolvedVersion,
      requestedBookId: widget.book,
      requestedChapter: widget.chapter,
      saved: saved,
    );
    if (location == null) {
      return const _BranchError(message: 'Даныя Бібліі недаступныя.');
    }

    final previousLocation = _lastLocation;
    if (previousLocation != null &&
        previousLocation.documentKey != location.documentKey) {
      _navigationDirection = previousLocation.versionId == location.versionId
          ? (_locationIndex(location) > _locationIndex(previousLocation)
                ? 1
                : -1)
          : 0;
    }
    _lastLocation = location;

    return LiturgicalDayTransition(
      direction: _navigationDirection,
      child: BibleChapterScreen(
        key: ValueKey('bible-${location.documentKey}'),
        versionId: location.versionId,
        bookId: location.bookId,
        chapter: location.chapter,
      ),
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
  const _BranchError({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
