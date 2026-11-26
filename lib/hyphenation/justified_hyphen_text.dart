import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:mybrev_flutter/hyphenation/be_hyphenator.dart';

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
    this.textScaler = TextScaler.noScaling,
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

  /// System/reader text scale (pass `MediaQuery.textScalerOf(context)`).
  final TextScaler textScaler;

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
          textScaler: textScaler,
        )
        ..registrar = SelectionContainer.maybeOf(context)
        ..selectionColor = DefaultSelectionStyle.of(context).selectionColor;

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
      ..shrink = shrink
      ..textScaler = textScaler
      ..registrar = SelectionContainer.maybeOf(context)
      ..selectionColor = DefaultSelectionStyle.of(context).selectionColor;
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

class _Metric {
  _Metric(this.painter, this.width, this.baseline, this.height);
  final TextPainter painter;
  final double width;
  final double baseline;
  final double height;
}

class _Seg {
  _Seg(this.start, this.text, this.style, this.recognizer, this.metric);

  /// Offset of this segment's first character in the paragraph's plain text
  /// (-1 for the painted hyphen, which is not part of the text).
  final int start;
  final String text;
  final TextStyle style;
  final GestureRecognizer? recognizer;
  final _Metric metric;
  TextPainter get painter => metric.painter;
  double get width => metric.width;
  double get baseline => metric.baseline;
  double get height => metric.height;
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

  /// The space after this piece may not become a line break (one-letter
  /// prepositions, abbreviations, "Мц 5"-style references, a following dash).
  bool glue = false;

  /// Kerning between this piece and the next piece of the same word (applies
  /// only when the word is NOT broken there), so an unbroken word keeps the
  /// exact width and shape the stock engine gives it.
  double joint = 0;
}

class _PlacedSeg {
  _PlacedSeg(this.seg, this.x, this.width, [this.dy = 0]);
  final _Seg seg;
  final double x;
  final double width;

  /// Vertical shift that puts every segment's baseline on the line baseline.
  double dy;
}

class _Line {
  _Line(this.placed, this.height, this.info);
  final List<_PlacedSeg> placed;
  final double height;
  final HyphLine info;
  double y = 0;
  _PlacedSeg? hyphen;
  double baseline = 0;

  /// Source-text range covered by this line (without the painted hyphen).
  int get start => placed.isEmpty ? 0 : placed.first.seg.start;
  int get end =>
      placed.isEmpty ? 0 : placed.last.seg.start + placed.last.seg.text.length;
}

class RenderHyphenatedJustifiedText extends RenderBox
    with Selectable, SelectionRegistrant {
  RenderHyphenatedJustifiedText({
    required TextSpan text,
    required BelarusianHyphenator? hyphenator,
    required bool justify,
    required bool hyphenate,
    required int minLeft,
    required int minRight,
    required double shrink,
    TextScaler textScaler = TextScaler.noScaling,
  }) : _text = text,
       _hyphenator = hyphenator,
       _justify = justify,
       _hyphenate = hyphenate,
       _minLeft = minLeft,
       _minRight = minRight,
       _shrink = shrink,
       _textScaler = textScaler;

  TextSpan _text;
  BelarusianHyphenator? _hyphenator;
  bool _justify;
  bool _hyphenate;
  int _minLeft;
  int _minRight;
  double _shrink;
  TextScaler _textScaler;

  set textScaler(TextScaler v) {
    if (_textScaler == v) {
      return;
    }
    _textScaler = v;
    _invalidate();
  }

  set text(TextSpan v) {
    if (_text == v) {
      return;
    }
    _text = v;
    _invalidate();
  }

  set hyphenator(BelarusianHyphenator? v) {
    if (identical(_hyphenator, v)) {
      return;
    }
    _hyphenator = v;
    _invalidate();
  }

  set justify(bool v) {
    if (_justify == v) {
      return;
    }
    _justify = v;
    _invalidate();
  }

  set hyphenate(bool v) {
    if (_hyphenate == v) {
      return;
    }
    _hyphenate = v;
    _invalidate();
  }

  set minLeft(int v) {
    if (_minLeft == v) {
      return;
    }
    _minLeft = v;
    _invalidate();
  }

  set minRight(int v) {
    if (_minRight == v) {
      return;
    }
    _minRight = v;
    _invalidate();
  }

  set shrink(double v) {
    if (_shrink == v) {
      return;
    }
    _shrink = v;
    _invalidate();
  }

  List<_Line> _lines = const [];
  String _plain = '';

  /// True for B2 (justified), false for D (ragged right).
  bool get justify => _justify;

  /// The original, unmodified text (what copy/semantics would expose).
  String get plainText => _plain;
  List<HyphLine> get lines => [for (final l in _lines) l.info];

  void _invalidate() {
    _metricCache.clear();
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

  final Map<(String, TextStyle), _Metric> _metricCache = {};

  _Seg _measure(
    String text,
    TextStyle style,
    GestureRecognizer? rec, [
    int start = -1,
  ]) {
    final m = _metricCache.putIfAbsent((text, style), () {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          // Backgrounds and underlines are drawn by this render object (so
          // that they also cover the stretched gaps between words).
          style: style.copyWith(
            backgroundColor: const Color(0x00000000),
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: _textScaler,
      )..layout();
      return _Metric(
        tp,
        tp.width,
        tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        tp.height,
      );
    });
    return _Seg(start, text, style, rec, m);
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
        if (c.start >= to) {
          break;
        }
        if (c.end <= from) {
          continue;
        }
        final a = math.max(from, c.start);
        final b = math.min(to, c.end);
        segs.add(_measure(plain.substring(a, b), c.style, c.recognizer, a));
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
    final tokens = <(int, int, bool)>[];
    var pos = 0;
    while (pos <= plain.length) {
      var end = plain.indexOf(splitter, pos);
      if (end < 0) end = plain.length;
      final newline = end < plain.length && plain[end] == '\n';
      if (end > pos) {
        tokens.add((pos, end, newline));
      } else if (newline) {
        tokens.add((pos, pos, true)); // empty line
      }
      if (end >= plain.length) {
        break;
      }
      pos = end + 1;
    }
    for (var t = 0; t < tokens.length; t++) {
      final (a, b, newline) = tokens[t];
      if (b == a) {
        pieces.add(_Piece([], 0, true, false, null)..forcedBreakAfter = true);
        continue;
      }
      final wp = _wordPieces(plain, a, b, make, maxWidth, newline);
      if (wp.isNotEmpty && !newline && t + 1 < tokens.length) {
        final (na, nb, _) = tokens[t + 1];
        if (nb > na &&
            glueAfter(plain.substring(a, b), plain.substring(na, nb))) {
          wp.last.glue = true;
        }
      }
      pieces.addAll(wp);
    }
    return pieces;
  }

  static final _abbreviation = RegExp(
    r'^(гл|ст|с|пар|рыс|напр|тт|т|тыс|гг|г|н|п|ч|пр|тзв|гэт|англ|рус|лац)\.$',
    caseSensitive: false,
  );

  /// Typographic "no line break after this word" rules (Belarusian prose):
  /// a one-letter word (ў, у, і, а, з, к…) is never left at the end of a line;
  /// an abbreviation with a dot stays with what it abbreviates; a word before a
  /// number stays with it ("Мц 5, 3–12"); a lone dash or a rubric marker
  /// (`*`, `†`) never starts a line.
  static bool glueAfter(String word, String next) {
    final core = word.replaceAll(
      RegExp(r'^[^А-Яа-яЁёІіЎў0-9]+|[^А-Яа-яЁёІіЎў0-9]+$'),
      '',
    );
    if (core.length == 1 && RegExp(r'[А-Яа-яЁёІіЎў]').hasMatch(core))
      return true;
    if (_abbreviation.hasMatch(word)) {
      return true;
    }
    if (RegExp(r'^[0-9]').hasMatch(next)) {
      return true;
    }
    if (RegExp(r'^[—–*†]$').hasMatch(next)) {
      return true;
    }
    return false;
  }

  static bool _isSentenceStart(String plain, int start) {
    var i = start - 1;
    while (i >= 0 && ' «“"(\u00A0'.contains(plain[i])) {
      i--;
    }
    return i < 0 || '.!?…:\n'.contains(plain[i]);
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
      // Proper names (capitalised words inside a sentence) are never split.
      final properName =
          m != null &&
          m.group(0)![0] != m.group(0)![0].toLowerCase() &&
          !_isSentenceStart(plain, start);
      if (m != null && !properName && m.group(0)!.length >= 6) {
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
    for (var i = 0; i < out.length - 1; i++) {
      final a = out[i], b = out[i + 1];
      if (a.segs.length == 1 &&
          b.segs.length == 1 &&
          a.segs.first.style == b.segs.first.style) {
        final both = _measure(a.text + b.text, a.segs.first.style, null);
        a.joint = both.width - a.width - b.width;
      }
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
          if (cand.width + (cand.hyphenSeg?.width ?? 0) <= maxWidth) {
            break;
          }
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
    if (_laidOutWidth == maxWidth) {
      return;
    }
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
    final changed = _laidOutWidth != maxWidth;
    _ensureLayout(maxWidth);
    size = constraints.constrain(Size(maxWidth, _height));
    if (changed && _hasSelection) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) _publishSelection();
      });
    }
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

  List<_Line> _breakParagraph(
    List<_Piece> items,
    double w, {
    bool honorGlue = true,
  }) {
    final n = items.length;
    if (n == 0 || (n == 1 && items[0].segs.isEmpty)) {
      final lh = _measure('Ay', _text.style ?? const TextStyle(), null).height;
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
        if (base == inf) {
          continue;
        }
        var natural = 0.0;
        var spaces = 0;
        for (var j = i; j < n; j++) {
          // line = items[i..j]
          if (j > i && items[j - 1].endsWord) {
            spaces++;
            natural += _spaceWidth;
          }
          if (j > i && !items[j - 1].endsWord) natural += items[j - 1].joint;
          natural += items[j].width;
          final isEndOfPara = j == n - 1;
          final hyphenBreak = !items[j].endsWord;
          final hyphenW = hyphenBreak && !items[j].hardHyphen
              ? (items[j].hyphenSeg?.width ?? 0)
              : 0.0;
          final lineW = natural + hyphenW;
          // Never leave a hyphen break at paragraph end.
          if (isEndOfPara && hyphenBreak) {
            continue;
          }

          double demerits;
          if (isEndOfPara) {
            if (lineW > w + 0.01) {
              break;
            }
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
              badness =
                  100 * math.pow(((w - lineW) / w * 4).clamp(0.0, 4.0), 3)
                      as double;
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
          if (hyphenBreak && ph >= 3) {
            continue;
          }
          // Breaking at a glued space is allowed only when unavoidable.
          if (honorGlue && items[j].glue && !isEndOfPara) demerits += 5e8;
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
      // Glue made the paragraph unbreakable: retry without it; never throw.
      if (honorGlue) {
        return _breakParagraph(items, w, honorGlue: false);
      }
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
      if (j > a && !items[j - 1].endsWord) natural += items[j - 1].joint;
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
    final text = StringBuffer();
    // Common baseline: segments of different sizes/styles (italic, rubric,
    // smaller reference text) sit on one line like in the stock renderer.
    var maxBase = 0.0;
    for (var j = a; j < b; j++) {
      for (final s in items[j].segs) {
        maxBase = math.max(maxBase, s.baseline);
      }
    }
    if (showHyphen && lastPiece.hyphenSeg != null) {
      maxBase = math.max(maxBase, lastPiece.hyphenSeg!.baseline);
    }
    var height = 0.0;
    for (var j = a; j < b; j++) {
      if (j > a && items[j - 1].endsWord) {
        x += _spaceWidth + extra;
        text.write(' ');
      } else if (j > a) {
        x += items[j - 1].joint;
      }
      for (final s in items[j].segs) {
        final dy = maxBase - s.baseline;
        placed.add(_PlacedSeg(s, x, s.width, dy));
        x += s.width;
        height = math.max(height, dy + s.height);
      }
      text.write(items[j].text);
    }
    if (height == 0) {
      height = lastPiece.segs.isEmpty ? 0 : lastPiece.segs.last.height;
    }
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
    final line = _Line(placed, height, info)..baseline = maxBase;
    if (showHyphen) {
      final hs = lastPiece.hyphenSeg!;
      line.hyphen = _PlacedSeg(hs, x, hs.width, maxBase - hs.baseline);
    }
    return line;
  }

  // ---- paint / input --------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintSelectionHighlight(context.canvas, offset);
    final canvas = context.canvas;
    for (final line in _lines) {
      final y = offset.dy + line.y;
      // Backgrounds and underlines first; consecutive segments with the same
      // style are joined so they also cover the stretched gap between words.
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
        final deco = p.seg.style.decoration;
        if (deco != null && deco.contains(TextDecoration.underline)) {
          var left = offset.dx + p.x;
          final prevDeco = prev?.seg.style.decoration;
          if (prev != null &&
              prevDeco != null &&
              prevDeco.contains(TextDecoration.underline) &&
              prev.seg.style.decorationColor == p.seg.style.decorationColor) {
            left = offset.dx + prev.x + prev.width;
          }
          final size = p.seg.style.fontSize ?? 14;
          final thickness =
              (p.seg.style.decorationThickness ?? 1.0) *
              math.max(1.0, size / 14);
          final ly = y + line.baseline + size * 0.12 + thickness / 2;
          canvas.drawLine(
            Offset(left, ly),
            Offset(offset.dx + p.x + p.width, ly),
            Paint()
              ..color =
                  p.seg.style.decorationColor ??
                  p.seg.style.color ??
                  const Color(0xFF000000)
              ..strokeWidth = thickness,
          );
        }
        prev = p;
      }
      for (final p in line.placed) {
        p.seg.painter.paint(canvas, Offset(offset.dx + p.x, y + p.dy));
      }
      final hy = line.hyphen;
      if (hy != null) {
        hy.seg.painter.paint(canvas, Offset(offset.dx + hy.x, y + hy.dy));
      }
    }
    _pushHandleAnchors(context, offset);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) {
      return;
    }
    final pos = entry.localPosition;
    for (final line in _lines) {
      if (pos.dy < line.y || pos.dy >= line.y + line.height) {
        continue;
      }
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

  // ---- selection / copy -----------------------------------------------
  //
  // Selection works on the ORIGINAL text offsets, so copying yields exactly the
  // source string: no painted hyphen, no line breaks that were not in the
  // source, original hyphens and paragraph breaks preserved.

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  int? _selStart; // text offsets of the two selection edges
  int? _selEnd;
  LayerLink? _startHandle;
  LayerLink? _endHandle;
  Color? selectionColor;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  SelectionGeometry _value = const SelectionGeometry(
    status: SelectionStatus.none,
    hasContent: true,
  );

  @override
  SelectionGeometry get value => _value;

  set _geometry(SelectionGeometry v) {
    if (v == _value) {
      return;
    }
    _value = v;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  int get contentLength => _plain.length;

  @override
  List<Rect> get boundingBoxes => [Offset.zero & size];

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    if (_startHandle == startHandle && _endHandle == endHandle) {
      return;
    }
    _startHandle = startHandle;
    _endHandle = endHandle;
    // Called while the selection container removes a disposed selectable.
    if (attached) markNeedsPaint();
  }

  int get _lo => math.min(_selStart ?? 0, _selEnd ?? 0);
  int get _hi => math.max(_selStart ?? 0, _selEnd ?? 0);
  bool get _hasSelection => _selStart != null && _selEnd != null;

  @override
  SelectedContent? getSelectedContent() {
    if (!_hasSelection || _lo == _hi) {
      return null;
    }
    return SelectedContent(plainText: _plain.substring(_lo, _hi));
  }

  @override
  SelectedContentRange? getSelection() {
    if (!_hasSelection) {
      return null;
    }
    return SelectedContentRange(startOffset: _selStart!, endOffset: _selEnd!);
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    switch (event.type) {
      case SelectionEventType.selectAll:
        _selStart = 0;
        _selEnd = _plain.length;
        _publishSelection();
        return SelectionResult.none;
      case SelectionEventType.clear:
        _selStart = _selEnd = null;
        _publishSelection();
        return SelectionResult.none;
      case SelectionEventType.selectWord:
        final e = event as SelectWordSelectionEvent;
        final at = _indexAt(globalToLocal(e.globalPosition));
        final word = _wordAt(at);
        _selStart = word.$1;
        _selEnd = word.$2;
        _publishSelection();
        return SelectionResult.end;
      case SelectionEventType.selectParagraph:
        final e = event as SelectParagraphSelectionEvent;
        final at = _indexAt(globalToLocal(e.globalPosition));
        var a = _plain.lastIndexOf('\n', math.max(0, at - 1));
        a = a < 0 ? 0 : a + 1;
        var b = _plain.indexOf('\n', at);
        if (b < 0) b = _plain.length;
        _selStart = a;
        _selEnd = b;
        _publishSelection();
        return SelectionResult.end;
      case SelectionEventType.startEdgeUpdate:
      case SelectionEventType.endEdgeUpdate:
        final e = event as SelectionEdgeUpdateEvent;
        final local = globalToLocal(e.globalPosition);
        final result = SelectionUtils.getResultBasedOnRect(
          Offset.zero & size,
          local,
        );
        var idx = _indexAt(local);
        if (result == SelectionResult.previous) idx = 0;
        if (result == SelectionResult.next) idx = _plain.length;
        if (event.type == SelectionEventType.startEdgeUpdate) {
          _selStart = idx;
          _selEnd ??= idx;
        } else {
          _selEnd = idx;
          _selStart ??= idx;
        }
        _publishSelection();
        return result;
      case SelectionEventType.granularlyExtendSelection:
      case SelectionEventType.directionallyExtendSelection:
        // Keyboard extension is not part of the prototype.
        return SelectionResult.end;
    }
  }

  (int, int) _wordAt(int at) {
    final isWord = RegExp(r"[\p{L}\p{N}'’ʼ\-]", unicode: true);
    var a = at.clamp(0, _plain.length);
    var b = a;
    while (a > 0 && isWord.hasMatch(_plain[a - 1])) {
      a--;
    }
    while (b < _plain.length && isWord.hasMatch(_plain[b])) {
      b++;
    }
    return (a, b);
  }

  _Line? _lineAtY(double y) {
    if (_lines.isEmpty) {
      return null;
    }
    for (final l in _lines) {
      if (y < l.y + l.height) {
        return l;
      }
    }
    return _lines.last;
  }

  int _indexAt(Offset p) {
    final line = _lineAtY(p.dy);
    if (line == null || line.placed.isEmpty) {
      return line?.start ?? 0;
    }
    final first = line.placed.first;
    final last = line.placed.last;
    if (p.dx <= first.x) {
      return line.start;
    }
    if (p.dx >= last.x + last.width) {
      return line.end;
    }
    for (var k = 0; k < line.placed.length; k++) {
      final pl = line.placed[k];
      if (p.dx >= pl.x && p.dx <= pl.x + pl.width) {
        final pos = pl.seg.painter.getPositionForOffset(
          Offset(p.dx - pl.x, pl.seg.height / 2),
        );
        return pl.seg.start + pos.offset;
      }
      if (k + 1 < line.placed.length) {
        final next = line.placed[k + 1];
        if (p.dx > pl.x + pl.width && p.dx < next.x) {
          final prevEnd = pl.seg.start + pl.seg.text.length;
          return (p.dx - (pl.x + pl.width)) < (next.x - p.dx)
              ? prevEnd
              : next.seg.start;
        }
      }
    }
    return line.end;
  }

  /// X of the caret before text offset [i] on [l] (gaps between words
  /// included: the space belongs to the gap, so highlights stay continuous).
  double _xAt(_Line l, int i) {
    if (l.placed.isEmpty) {
      return 0;
    }
    if (i <= l.start) {
      return l.placed.first.x;
    }
    if (i >= l.end) {
      final last = l.placed.last;
      return last.x + last.width;
    }
    for (var k = 0; k < l.placed.length; k++) {
      final p = l.placed[k];
      final s = p.seg;
      final end = s.start + s.text.length;
      if (i >= s.start && i <= end) {
        return p.x +
            s.painter
                .getOffsetForCaret(TextPosition(offset: i - s.start), Rect.zero)
                .dx;
      }
      if (k + 1 < l.placed.length) {
        final n = l.placed[k + 1];
        if (i > end && i <= n.seg.start) {
          return i == n.seg.start ? n.x : p.x + p.width;
        }
      }
    }
    final last = l.placed.last;
    return last.x + last.width;
  }

  List<Rect> _selectionRects() {
    if (!_hasSelection || _lo == _hi) {
      return const [];
    }
    final rects = <Rect>[];
    for (final l in _lines) {
      final a = math.max(_lo, l.start);
      final b = math.min(_hi, l.end);
      // A selection that continues past the line end also covers the gap to
      // the right edge only when the line is justified; keep it to the text.
      if (b <= a && !(_lo < l.start && _hi > l.end)) {
        continue;
      }
      final x1 = _xAt(l, a);
      final x2 = _xAt(l, b);
      if (x2 > x1) rects.add(Rect.fromLTRB(x1, l.y, x2, l.y + l.height));
    }
    return rects;
  }

  void _publishSelection() {
    if (attached) markNeedsPaint();
    if (!_hasSelection) {
      _geometry = const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: true,
      );
      return;
    }
    final lo = _lo, hi = _hi;
    final startLine = _lineAtLeft(lo);
    final endLine = _lineAtRight(hi);
    if (startLine == null || endLine == null) {
      return;
    }
    _geometry = SelectionGeometry(
      status: lo == hi
          ? SelectionStatus.collapsed
          : SelectionStatus.uncollapsed,
      hasContent: true,
      startSelectionPoint: SelectionPoint(
        localPosition: Offset(
          _xAt(startLine, lo),
          startLine.y + startLine.height,
        ),
        lineHeight: startLine.height,
        handleType: TextSelectionHandleType.left,
      ),
      endSelectionPoint: SelectionPoint(
        localPosition: Offset(_xAt(endLine, hi), endLine.y + endLine.height),
        lineHeight: endLine.height,
        handleType: TextSelectionHandleType.right,
      ),
      selectionRects: _selectionRects(),
    );
  }

  _Line? _lineAtLeft(int i) {
    for (final l in _lines) {
      if (i < l.end || (i == l.end && l == _lines.last)) {
        return l;
      }
    }
    return _lines.isEmpty ? null : _lines.last;
  }

  _Line? _lineAtRight(int i) {
    for (final l in _lines) {
      if (i <= l.end) {
        return l;
      }
    }
    return _lines.isEmpty ? null : _lines.last;
  }

  void _paintSelectionHighlight(Canvas canvas, Offset offset) {
    if (!_hasSelection || _lo == _hi) {
      return;
    }
    final color = selectionColor ?? const Color(0x663F6E8C);
    for (final r in _selectionRects()) {
      canvas.drawRect(r.shift(offset), Paint()..color = color);
    }
  }

  /// Anchors for the touch selection handles. Pushing a layer ends the current
  /// canvas recording, so this MUST run after all text has been painted.
  void _pushHandleAnchors(PaintingContext context, Offset offset) {
    if (!_hasSelection || _lo == _hi) {
      return;
    }
    final sp = _value.startSelectionPoint;
    final ep = _value.endSelectionPoint;
    if (_startHandle != null && sp != null) {
      context.pushLayer(
        LeaderLayer(link: _startHandle!, offset: offset + sp.localPosition),
        (_, _) {},
        Offset.zero,
      );
    }
    if (_endHandle != null && ep != null) {
      context.pushLayer(
        LeaderLayer(link: _endHandle!, offset: offset + ep.localPosition),
        (_, _) {},
        Offset.zero,
      );
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
