// Widgets that connect the shared reader (ReaderScaffold) to the local
// analytics. Both are used only behind `kAnalyticsLocal`, so a normal build
// never creates them. They read facts (character count, scroll metrics) and
// never keep or send the text itself.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart';

/// Number of characters of text rendered below [root] (paragraphs and editable
/// text). Only a count: the text is not stored.
int countRenderedText(RenderObject root) {
  var chars = 0;
  void visit(RenderObject object) {
    if (object is RenderParagraph) {
      chars += object.text.toPlainText(includePlaceholders: false).length;
    } else if (object is RenderEditable) {
      chars += object.text?.toPlainText(includePlaceholders: false).length ?? 0;
    }
    object.visitChildren(visit);
  }

  visit(root);
  return chars;
}

/// Forwards the vertical scroll metrics of the reader's own scroll view (top-level
/// scrollable only). No rebuilds, no state, never consumes a notification.
class AnalyticsReaderScroll extends StatelessWidget {
  const AnalyticsReaderScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        LocalAnalytics.instance?.onScrollMetrics(n.metrics, n.depth);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          LocalAnalytics.instance?.onScrollMetrics(n.metrics, n.depth);
          return false;
        },
        child: child,
      ),
    );
  }
}

/// Wraps the reader's content and reports how much text is rendered: after a
/// frame in which the content changed (throttled), and once more just before
/// the reader is left.
class AnalyticsTextMeter extends StatefulWidget {
  const AnalyticsTextMeter({super.key, required this.child});

  final Widget child;

  @override
  State<AnalyticsTextMeter> createState() => _AnalyticsTextMeterState();
}

class _AnalyticsTextMeterState extends State<AnalyticsTextMeter> {
  static const int _minGapMs = 700;
  final Stopwatch _clock = Stopwatch()..start();
  int _lastMs = -_minGapMs;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    LocalAnalytics.instance?.attachMeter(_measureNow);
    _schedule();
  }

  @override
  void didUpdateWidget(AnalyticsTextMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    LocalAnalytics.instance?.detachMeter(_measureNow);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _clock.elapsedMilliseconds - _lastMs < _minGapMs) return;
      _measureNow();
    });
  }

  void _measureNow() {
    if (!mounted) return;
    _lastMs = _clock.elapsedMilliseconds;
    final object = context.findRenderObject();
    if (object == null || !object.attached) return;
    LocalAnalytics.instance?.reportTextLength(countRenderedText(object));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
