import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';

/// Renders song lyrics with optional, display-only transposed chords.
///
/// [SongChordLayout.above] puts each chord line over its lyric line.
/// [SongChordLayout.right] keeps lyrics as the primary, left column and puts
/// the chords of each line in a secondary column on the right, aligned to the
/// first baseline of the line. The side layout is used only when the actual
/// constraints leave the lyrics enough room ([resolveLayout]); otherwise the
/// song temporarily renders with chords above, without touching the stored
/// preference. The decision and the chord column width are measured over
/// every transposition, so stepping the key never switches the layout.
class SongText extends StatelessWidget {
  const SongText({
    super.key,
    required this.song,
    required this.textStyle,
    this.showChords = false,
    this.layout = SongChordLayout.above,
    this.transpose = 0,
    this.onRightFallbackChanged,
  });

  final Song song;
  final TextStyle textStyle;
  final bool showChords;
  final SongChordLayout layout;
  final int transpose;

  /// Reports, on every layout, whether the preferred
  /// [SongChordLayout.right] is currently rendered as `above` because the
  /// width is too small. Called during layout: defer any state change.
  final ValueChanged<bool>? onRightFallbackChanged;

  /// Minimum lyric column width, in effective em of the lyric text. Lyric
  /// lines may wrap in the column, but it never gets narrower than this
  /// (about 20 characters), which keeps `right` usable on 360–430 dp phones.
  static const rightLayoutMinLyricsEm = 10.0;

  /// The chord column may take at most this share of the available width.
  static const rightLayoutMaxChordShare = 0.45;

  /// Gap between the lyric and the chord column, in effective em.
  static const rightLayoutGapEm = 1.0;

  /// Chord text relative to the lyric text size.
  static const chordScale = 0.85;

  /// Layout actually rendered for [preferred] at [width].
  ///
  /// `right` needs room for the widest chord line and at least
  /// [rightLayoutMinLyricsEm] of lyrics, and the chord column must stay
  /// secondary. Otherwise `above` is returned.
  static SongChordLayout resolveLayout({
    required SongChordLayout preferred,
    required double width,
    required double fontSize,
    required TextScaler textScaler,
    required double chordColumnWidth,
  }) {
    if (preferred != SongChordLayout.right) return SongChordLayout.above;
    if (!width.isFinite) return SongChordLayout.right;
    final em = textScaler.scale(fontSize);
    final lyrics = width - chordColumnWidth - em * rightLayoutGapEm;
    final fits =
        chordColumnWidth <= width * rightLayoutMaxChordShare &&
        lyrics >= em * rightLayoutMinLyricsEm;
    return fits ? SongChordLayout.right : SongChordLayout.above;
  }

  /// Last song's candidates: transposing rebuilds the text on every step.
  static String? _candidatesSource;
  static Set<String> _candidates = const {};

  /// The longest chord line of [chord] in each key of the transpose range.
  static Set<String> _widestChordLines(String chord) {
    if (_candidatesSource == chord) return _candidates;
    final rows = [
      for (final row in chord.split('\n'))
        if (row.trim().isNotEmpty) row,
    ];
    final result = <String>{};
    for (var shift = kMinTranspose; shift <= kMaxTranspose; shift++) {
      var longest = '';
      for (final row in rows) {
        final value = transposeChordLine(row, shift);
        if (value.length > longest.length) longest = value;
      }
      if (longest.isNotEmpty) result.add(longest);
    }
    _candidatesSource = chord;
    return _candidates = result;
  }

  static TextStyle chordStyleFor(BuildContext context, TextStyle textStyle) =>
      textStyle.copyWith(
        fontSize: (textStyle.fontSize ?? 16) * chordScale,
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Roboto Mono', 'Courier'],
        color: ReaderTheme.of(context).rubric,
        height: 1.35,
      );

  @override
  Widget build(BuildContext context) {
    final chordsVisible = showChords && song.hasChords;
    // Hidden chords must not add trailing blank rows from overflow chords.
    final lines = songLines(
      text: song.text,
      chord: chordsVisible ? song.chord : '',
    );
    final chords = [
      for (final line in lines)
        line.chord.isEmpty ? '' : transposeChordLine(line.chord, transpose),
    ];
    final fontSize = textStyle.fontSize ?? 16;
    final chordStyle = chordStyleFor(context, textStyle);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    // Widest chord line over every transposition (sharps make some keys
    // wider), so the column and the right/above decision do not depend on the
    // current key. Only the longest line of each key is measured.
    double measureChordColumn() {
      final candidates = _widestChordLines(song.chord);
      var widest = 0.0;
      for (final chord in candidates) {
        final painter = TextPainter(
          text: TextSpan(text: chord, style: chordStyle),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest.ceilToDouble() + 1;
    }

    Widget lyric(String text) =>
        Text(text.isEmpty ? ' ' : text, style: textStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wantsSide = chordsVisible && layout == SongChordLayout.right;
        final chordWidth = wantsSide ? measureChordColumn() : 0.0;
        final side =
            wantsSide &&
            resolveLayout(
                  preferred: layout,
                  width: constraints.maxWidth,
                  fontSize: fontSize,
                  textScaler: textScaler,
                  chordColumnWidth: chordWidth,
                ) ==
                SongChordLayout.right;
        final gap = textScaler.scale(fontSize) * rightLayoutGapEm;
        onRightFallbackChanged?.call(wantsSide && !side);

        return Column(
          key: Key(side ? 'song-text-right' : 'song-text-above'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lines.length; i++)
              if (side)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: lyric(lines[i].text)),
                    SizedBox(width: gap),
                    SizedBox(
                      width: chordWidth,
                      child: Text(
                        chords[i],
                        style: chordStyle,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (chords[i].isNotEmpty)
                      Text(chords[i], style: chordStyle),
                    lyric(lines[i].text),
                  ],
                ),
          ],
        );
      },
    );
  }
}
