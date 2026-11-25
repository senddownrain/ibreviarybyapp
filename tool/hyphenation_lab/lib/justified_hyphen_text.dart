import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'be_hyphenator.dart';

/// Prototype of an *alternative* paragraph renderer (variant B2).
///
/// Why it exists: on the Flutter versions tested, the standard text engine
/// (a) cannot hyphenate and (b) breaks lines at U+00AD but never draws the
/// hyphen. So quality hyphenation needs one component that owns BOTH line
/// breaking and painting. This widget does that for ONE paragraph:
///
/// * the source text is never modified (no U+00AD, no hard '-\n' inside prose);
///   the visible hyphen is painted, never inserted into the string, so the
///   plain text exposed to copy/semantics is exactly the original;
/// * the whole inline span tree (styles, sentence backgrounds, recognizers)
///   is laid out as ONE paragraph — nothing is split between HTML tags;
/// * lines are chosen by optimal-fit dynamic programming (Knuth–Plass style:
///   squared badness, hyphen penalties, no double hyphens) instead of greedy;
/// * justification spreads the slack over the spaces of each non-final line.
///
/// Known prototype limits (documented in the report): no drag selection, no
/// WidgetSpan, kerning is not applied across fragment joints, fragments of
/// different font sizes share a top-aligned line box.
class HyphenatedJustifiedText extends LeafRenderObjectWidget {
  const HyphenatedJustifiedText({
    super.key,
    required this.text,
    required this.hyphenator,
    this.justify = true,
    this.hyphenate = true,
    this.minRight = 3,
    this.minLeft = 2,
    this.shrink = 0.0,
  });

  final TextSpan text;
  final BelarusianHyphenator? hyphenator;
  final bool justify;
  final bool hyphenate;
  final int minLeft;
  final int minRight;

  /// How much a space may shrink (fraction of its width) before a line is
  /// rejected. 0 = never shrink (safe for sacred text readability).
  final double shrink;

  @override
  RenderHyphenatedJustifiedText createRenderObject(BuildContext context) =>
      RenderHyphenatedJustifiedText(
        text: text,
        hyphenator: hyphenator,
        justify: justify,
        hyphenate: hyphenate,
        minLeft: minLeft,
        minRight: minRight,
        shrink: shrink,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHyphenatedJustifiedText renderObject,
  ) {
    renderObject
      ..text = text
      ..hyphenator = hyphenator
      ..justify = justify
      ..hyphenate = hyphenate
      ..minLeft = minLeft
      ..minRight = minRight
      ..shrink = shrink;
  }
}

/// One laid-out line, exposed for metrics and tests.
class HyphLine {
  HyphLine({
    required this.text,
    required this.naturalWidth,
    required this.spaces,
    required this.spaceWidth,
    required this.width,
    required this.endsWithHyphen,
    required this.isLast,
    required this.pieceCount,
  });

  /// Visible text of the line without the painted hyphen.
  final String text;
  final double naturalWidth;
  final int spaces;
  final double spaceWidth;
  final double width;
  final bool endsWithHyphen;

  /// Last line of its paragraph (ragged, never stretched).
  final bool isLast;
  final int pieceCount;

  /// Extra width added per space when justified, in multiples of a normal space.
  double get stretch => spaces == 0 || isLast
      ? 0
      : (width - naturalWidth) / (spaces * spaceWidth);
}

class _Chunk {
  _Chunk(this.start, this.end, this.style, this.recognizer);
  final int start;
  final int end;
  final TextStyle style;
  final GestureRecognizer? recognizer;
}

class _Seg {
  _Seg(this.text, this.style, this.recognizer, this.painter, this.width);
  final String text;
  final TextStyle style;
  final GestureRecognizer? recognizer;
  final TextPainter painter;
  final double width;
}

class _Piece {
  _Piece(this.segs, this.width, this.endsWord, this.hardHyphen, this.hyphenSeg);
  final List<_Seg> segs;
  final double width;
  final bool endsWord;

  /// The piece already ends with a real '-' (compound): no glyph is added.
  final bool hardHyphen;

  /// Painter for the visible hyphen drawn if a break happens after this piece.
  final _Seg? hyphenSeg;
  String get text => segs.map((s) => s.text).join();
  int firstOfWord = 0;
  bool forcedBreakAfter = false; // paragraph newline follows
}

class _PlacedSeg {
  _PlacedSeg(this.seg, this.x, this.width);
  final _Seg seg;
  final double x;
  final double width;
}

class _Line {
  _Line(this.placed, this.height, this.info);
  final List<_PlacedSeg> placed;
  final double height;
  final HyphLine info;
  double y = 0;
  _PlacedSeg? hyphen;
}

class RenderHyphenatedJustifiedText extends RenderBox {
  RenderHyphenatedJustifiedText({
    required TextSpan text,
    required BelarusianHyphenator? hyphenator,
    required bool justify,
    required bool hyphenate,
    required int minLeft,
    required int minRight,
    required double shrink,
  }) : _text = text,
       _hyphenator = hyphenator,
       _justify = justify,
       _hyphenate = hyphenate,
       _minLeft = minLeft,
       _minRight = minRight,
       _shrink = shrink;

  TextSpan _text;
  BelarusianHyphenator? _hyphenator;
  bool _justify;
  bool _hyphenate;
  int _minLeft;
  int _minRight;
  double _shrink;

  set text(TextSpan v) {
    if (_text == v) return;
    _text = v;
    _invalidate();
  }

  set hyphenator(BelarusianHyphenator? v) {
    if (identical(_hyphenator, v)) return;
    _hyphenator = v;
    _invalidate();
  }

  set justify(bool v) {
    if (_justify == v) return;
    _justify = v;
    _invalidate();
  }

  set hyphenate(bool v) {
    if (_hyphenate == v) return;
    _hyphenate = v;
    _invalidate();
  }

  set minLeft(int v) {
    if (_minLeft == v) return;
    _minLeft = v;
    _invalidate();
  }

  set minRight(int v) {
    if (_minRight == v) return;
    _minRight = v;
    _invalidate();
  }

  set shrink(double v) {
    if (_shrink == v) return;
    _shrink = v;
    _invalidate();
  }

  List<_Line> _lines = const [];
  String _plain = '';
  final Map<(String, TextStyle), _Seg> _segCache = {};

  /// The original, unmodified text (what copy/semantics would expose).
  String get plainText => _plain;
  List<HyphLine> get lines => [for (final l in _lines) l.info];

  void _invalidate() {
    _segCache.clear();
    _laidOutWidth = null;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  // ---- flattening -----------------------------------------------------

  List<_Chunk> _flatten(StringBuffer out) {
    final chunks = <_Chunk>[];
    void visit(InlineSpan span, TextStyle parent) {
      if (span is! TextSpan) {
        throw UnsupportedError('WidgetSpan is not supported by the prototype');
      }
      final style = span.style == null ? parent : parent.merge(span.style);
      final t = span.text;
      if (t != null && t.isNotEmpty) {
        final start = out.length;
        out.write(t);
        // Backgrounds are painted by this render object, not by TextPainter.
        chunks.add(_Chunk(start, out.length, style, span.recognizer));
      }
      for (final c in span.children ?? const <InlineSpan>[]) {
        visit(c, style);
      }
    }

    visit(_text, _text.style ?? const TextStyle());
    return chunks;
  }

  _Seg _measure(String text, TextStyle style, GestureRecognizer? rec) {
    final key = (text, style);
    return _segCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(backgroundColor: const Color(0x00000000)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return _Seg(text, style, rec, tp, tp.width);
    });
  }

  // ---- tokenising -----------------------------------------------------

  static final _core = RegExp(r"[А-Яа-яЁёІіЎўЬьЫыЭэ'’ʼ\-]+");

  List<_Piece> _pieces(String plain, List<_Chunk> chunks, double maxWidth) {
    final pieces = <_Piece>[];
    var chunkIdx = 0;

    List<_Seg> segsFor(int from, int to) {
      final segs = <_Seg>[];
      while (chunkIdx > 0 && chunks[chunkIdx].start > from) {
        chunkIdx--;
      }
      for (var i = chunkIdx; i < chunks.length; i++) {
        final c = chunks[i];
        if (c.start >= to) break;
        if (c.end <= from) continue;
        final a = math.max(from, c.start);
        final b = math.min(to, c.end);
        segs.add(_measure(plain.substring(a, b), c.style, c.recognizer));
      }
      return segs;
    }

    _Piece make(int from, int to, {required bool endsWord, bool hard = false}) {
      final segs = segsFor(from, to);
      final w = segs.fold<double>(0, (s, e) => s + e.width);
      final last = segs.isEmpty ? null : segs.last;
      final hy = last == null || endsWord
          ? null
          : _measure('-', last.style, null);
      return _Piece(segs, w, endsWord, hard, hy);
    }

    // Words are separated by ' ' and '\n'. NBSP (U+00A0) glues words.
    final splitter = RegExp(r'[ \n]');
    var pos = 0;
    while (pos <= plain.length) {
      var end = plain.indexOf(splitter, pos);
      if (end < 0) end = plain.length;
      if (end > pos) {
        final newlineFollows = end < plain.length && plain[end] == '\n';
        pieces.addAll(
          _wordPieces(plain, pos, end, make, maxWidth, newlineFollows),
        );
      } else if (end < plain.length && plain[end] == '\n') {
        // Empty line: represent with a forced-break empty piece.
        final p = _Piece([], 0, true, false, null)..forcedBreakAfter = true;
        pieces.add(p);
      }
      if (end >= plain.length) break;
      pos = end + 1;
    }
    return pieces;
  }

  List<_Piece> _wordPieces(
    String plain,
    int start,
    int end,
    _Piece Function(int, int, {required bool endsWord, bool hard}) make,
    double maxWidth,
    bool newlineFollows,
  ) {
    final word = plain.substring(start, end);
    final cuts = <int>[]; // absolute offsets where a break is legal
    final hard = <int>{};
    final h = _hyphenator;
    if (_hyphenate && h != null) {
      // Hyphenate only the pure-letter core, leaving punctuation outside.
      final m = _core.firstMatch(word);
      if (m != null && m.group(0)!.length >= 6) {
        // The whole token must be "core + punctuation" with a single core run.
        final rest = word.substring(0, m.start) + word.substring(m.end);
        if (!RegExp(r'[А-Яа-яЁёІіЎў0-9A-Za-z]').hasMatch(rest)) {
          final pts = h.hyphenationPoints(
            m.group(0)!,
            minLeft: _minLeft,
            minRight: _minRight,
          );
          for (final p in pts) {
            final abs = start + m.start + p;
            cuts.add(abs);
            if (plain[abs - 1] == '-') hard.add(abs);
          }
        }
      }
    }
    final bounds = [start, ...cuts, end];
    final out = <_Piece>[];
    for (var i = 0; i < bounds.length - 1; i++) {
      final last = i == bounds.length - 2;
      final isHard = !last && hard.contains(bounds[i + 1]);
      final piece = make(
        bounds[i],
        bounds[i + 1],
        endsWord: last,
        hard: isHard,
      );
      piece.firstOfWord = i;
      if (last && newlineFollows) piece.forcedBreakAfter = true;
      out.add(piece);
    }
    // Emergency: a single piece wider than the box is split by characters so
    // nothing is ever clipped (visible hyphen after each cut).
    final fixed = <_Piece>[];
    for (final p in out) {
      if (p.width <= maxWidth || p.text.length < 2) {
        fixed.add(p);
        continue;
      }
      final text = p.text;
      final offset = plain.indexOf(text, start);
      var from = offset < 0 ? start : offset;
      final to = from + text.length;
      while (from < to) {
        var cut = to;
        while (cut - from > 1) {
          final cand = make(from, cut, endsWord: false);
          if (cand.width + (cand.hyphenSeg?.width ?? 0) <= maxWidth) break;
          cut--;
        }
        final isEnd = cut == to;
        final piece = make(from, cut, endsWord: isEnd && p.endsWord);
        piece.forcedBreakAfter = isEnd && p.forcedBreakAfter;
        fixed.add(piece);
        from = cut;
      }
    }
    return fixed;
  }

  // ---- breaking -------------------------------------------------------

  double _spaceWidth = 0;

  double? _laidOutWidth;
  double _height = 0;

  void _ensureLayout(double maxWidth) {
    if (_laidOutWidth == maxWidth) return;
    final buf = StringBuffer();
    final chunks = _flatten(buf);
    _plain = buf.toString();
    _laidOutWidth = maxWidth;
    if (chunks.isEmpty) {
      _lines = const [];
      _height = 0;
      return;
    }
    _spaceWidth = _measure(' ', chunks.first.style, null).width;
    final pieces = _pieces(_plain, chunks, maxWidth);
    _lines = _breakParagraphs(pieces, maxWidth);
    var y = 0.0;
    for (final l in _lines) {
      l.y = y;
      y += l.height;
    }
    _height = y;
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth;
    assert(maxWidth.isFinite, 'HyphenatedJustifiedText needs a bounded width');
    _ensureLayout(maxWidth);
    size = constraints.constrain(Size(maxWidth, _height));
  }

  List<_Line> _breakParagraphs(List<_Piece> all, double w) {
    final result = <_Line>[];
    var start = 0;
    for (var i = 0; i < all.length; i++) {
      if (all[i].forcedBreakAfter) {
        result.addAll(_breakParagraph(all.sublist(start, i + 1), w));
        start = i + 1;
      }
    }
    if (start < all.length) {
      result.addAll(_breakParagraph(all.sublist(start), w));
    }
    return result;
  }

  List<_Line> _breakParagraph(List<_Piece> items, double w) {
    final n = items.length;
    if (n == 0 || (n == 1 && items[0].segs.isEmpty)) {
      final lh = _measure(
        'Ay',
        _text.style ?? const TextStyle(),
        null,
      ).painter.height;
      return [
        _Line(
          [],
          lh,
          HyphLine(
            text: '',
            naturalWidth: 0,
            spaces: 0,
            spaceWidth: _spaceWidth,
            width: w,
            endsWithHyphen: false,
            isLast: true,
            pieceCount: 0,
          ),
        ),
      ];
    }
    const inf = double.infinity;
    // best[k][hyph]: minimal demerits to have a break after item k-1
    // (k = 0 is the start), hyph = that break was a hyphen break.
    final best = List.generate(n + 1, (_) => [inf, inf, inf, inf]);
    final from = List.generate(n + 1, (_) => [-1, -1, -1, -1]);
    final fromH = List.generate(n + 1, (_) => [0, 0, 0, 0]);
    best[0][0] = 0;

    for (var i = 0; i < n; i++) {
      for (var ph = 0; ph < 4; ph++) {
        final base = best[i][ph];
        if (base == inf) continue;
        var natural = 0.0;
        var spaces = 0;
        for (var j = i; j < n; j++) {
          // line = items[i..j]
          if (j > i && items[j - 1].endsWord) {
            spaces++;
            natural += _spaceWidth;
          }
          natural += items[j].width;
          final isEndOfPara = j == n - 1;
          final hyphenBreak = !items[j].endsWord;
          final hyphenW = hyphenBreak && !items[j].hardHyphen
              ? (items[j].hyphenSeg?.width ?? 0)
              : 0.0;
          final lineW = natural + hyphenW;
          // Never leave a hyphen break at paragraph end.
          if (isEndOfPara && hyphenBreak) continue;

          double demerits;
          if (isEndOfPara) {
            if (lineW > w + 0.01) break;
            demerits = 100.0; // (10)^2 — ragged last line is free
            final p = items[j];
            if (i == j && !p.endsWord) demerits += 0;
            // Penalise a last line that is only a short word-tail.
            if (i == j &&
                items[j].firstOfWord > 0 &&
                items[j].text.length < 4) {
              demerits += 2500;
            }
          } else {
            if (lineW > w + 0.01) {
              if (spaces == 0 || (lineW - w) > spaces * _spaceWidth * _shrink) {
                break;
              }
            }
            double badness;
            if (!_justify) {
              // Ragged right: only the slack at the end of the line matters.
              badness = 100 * math.pow(((w - lineW) / w * 4).clamp(0.0, 4.0), 3) as double;
            } else if (spaces == 0) {
              // A one-word line cannot be justified: always at least as bad
              // as the worst stretched line (cap 10000), worse the shorter it is.
              badness = 10000 + 10000 * ((w - lineW) / w).clamp(0.0, 1.0);
              if (lineW >= w - 0.5) badness = 0;
            } else {
              final r = (w - lineW) / (spaces * _spaceWidth);
              badness = r < 0
                  ? 100 * math.pow(-r / math.max(_shrink, 0.01), 3) as double
                  : 100 * math.pow(r, 3) as double;
              if (badness > 10000) badness = 10000;
            }
            demerits = math.pow(10 + badness, 2) as double;
            if (hyphenBreak) {
              // Scale matches (10+badness)²: ~ a line stretched r≈1.5.
              demerits += 120000;
              if (ph >= 1) demerits += 3000000 * ph; // consecutive hyphen lines
            }
          }
          // At most 3 hyphenated lines in a row (state 3 = three already).
          if (hyphenBreak && ph >= 3) continue;
          final h = hyphenBreak ? ph + 1 : 0;
          final total = base + demerits;
          if (total < best[j + 1][h]) {
            best[j + 1][h] = total;
            from[j + 1][h] = i;
            fromH[j + 1][h] = ph;
          }
        }
      }
    }

    var h = 0;
    for (var q = 1; q < 4; q++) {
      if (best[n][q] < best[n][h]) h = q;
    }
    if (best[n][h] == inf) {
      // Cannot happen after the emergency split, but never throw in layout.
      return [_greedy(items, 0, n, w, true)];
    }
    final ranges = <(int, int)>[];
    var k = n;
    while (k > 0) {
      final i = from[k][h];
      ranges.add((i, k));
      final ph = fromH[k][h];
      k = i;
      h = ph;
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final r in ranges) _greedy(items, r.$1, r.$2, w, r.$2 == n)];
  }

  /// Builds a placed line for items[a..b) (justified if not the last).
  _Line _greedy(List<_Piece> items, int a, int b, double w, bool isLast) {
    final placed = <_PlacedSeg>[];
    var natural = 0.0;
    var spaces = 0;
    for (var j = a; j < b; j++) {
      if (j > a && items[j - 1].endsWord) {
        spaces++;
        natural += _spaceWidth;
      }
      natural += items[j].width;
    }
    final lastPiece = items[b - 1];
    final hyphenBreak = !lastPiece.endsWord && !isLast;
    final showHyphen = hyphenBreak && !lastPiece.hardHyphen;
    final hyphenW = showHyphen ? (lastPiece.hyphenSeg?.width ?? 0) : 0.0;
    final lineNatural = natural + hyphenW;
    final extra = _justify && !isLast && spaces > 0
        ? math.max(w - lineNatural, -spaces * _spaceWidth * _shrink) / spaces
        : 0.0;
    var x = 0.0;
    var height = 0.0;
    final text = StringBuffer();
    for (var j = a; j < b; j++) {
      if (j > a && items[j - 1].endsWord) {
        x += _spaceWidth + extra;
        text.write(' ');
      }
      for (final s in items[j].segs) {
        placed.add(_PlacedSeg(s, x, s.width));
        x += s.width;
        height = math.max(height, s.painter.height);
      }
      text.write(items[j].text);
    }
    if (height == 0)
      height = lastPiece.segs.isEmpty ? 0 : lastPiece.segs.last.painter.height;
    final info = HyphLine(
      text: text.toString(),
      naturalWidth: lineNatural,
      spaces: spaces,
      spaceWidth: _spaceWidth,
      width: w,
      endsWithHyphen: showHyphen,
      isLast: isLast,
      pieceCount: b - a,
    );
    final line = _Line(placed, height, info);
    if (showHyphen) {
      final hs = lastPiece.hyphenSeg!;
      line.hyphen = _PlacedSeg(hs, x, hs.width);
    }
    return line;
  }

  // ---- paint / input --------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    for (final line in _lines) {
      final y = offset.dy + line.y;
      // Backgrounds first, joining consecutive same-colour segments.
      _PlacedSeg? prev;
      for (final p in line.placed) {
        final bg = p.seg.style.backgroundColor;
        if (bg != null && bg.a > 0) {
          var left = offset.dx + p.x;
          if (prev != null && prev.seg.style.backgroundColor == bg) {
            left = offset.dx + prev.x + prev.width;
          }
          canvas.drawRect(
            Rect.fromLTWH(
              left,
              y,
              offset.dx + p.x + p.width - left,
              line.height,
            ),
            Paint()..color = bg,
          );
        }
        prev = p;
      }
      for (final p in line.placed) {
        p.seg.painter.paint(canvas, Offset(offset.dx + p.x, y));
      }
      final hy = line.hyphen;
      if (hy != null) {
        hy.seg.painter.paint(canvas, Offset(offset.dx + hy.x, y));
      }
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) return;
    final pos = entry.localPosition;
    for (final line in _lines) {
      if (pos.dy < line.y || pos.dy >= line.y + line.height) continue;
      for (final p in line.placed) {
        if (pos.dx >= p.x && pos.dx <= p.x + p.width) {
          p.seg.recognizer?.addPointer(event);
          return;
        }
      }
      // Gap between words: nearest segment to the left.
      _PlacedSeg? best;
      for (final p in line.placed) {
        if (p.x <= pos.dx) best = p;
      }
      best?.seg.recognizer?.addPointer(event);
      return;
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = false
      ..label = _plain
      ..textDirection = TextDirection.ltr;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _ensureLayout(constraints.maxWidth);
    return constraints.constrain(Size(constraints.maxWidth, _height));
  }
}
