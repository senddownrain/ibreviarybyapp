import 'package:flutter/material.dart';

import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';

/// Renders song lyrics with an optional, display-only transposed chord column.
///
/// With [SongChordLayout.left] chords sit in a narrow column beside each line.
/// When the available width is too small for the effective text size (narrow
/// phones, large system or reader text), it falls back to chords above lines
/// so lyrics never become unreadably narrow.
class SongText extends StatelessWidget {
  const SongText({
    super.key,
    required this.song,
    required this.textStyle,
    this.showChords = false,
    this.layout = SongChordLayout.above,
    this.transpose = 0,
  });

  final Song song;
  final TextStyle textStyle;
  final bool showChords;
  final SongChordLayout layout;
  final int transpose;

  /// Minimum content width, in effective em, for the side-by-side layout.
  static const leftLayoutMinEm = 18.0;

  static bool fitsLeftLayout({
    required double width,
    required double fontSize,
    required TextScaler textScaler,
  }) => width >= textScaler.scale(fontSize) * leftLayoutMinEm;

  @override
  Widget build(BuildContext context) {
    final chordsVisible = showChords && song.hasChords;
    // Hidden chords must not add trailing blank rows from overflow chords.
    final lines = songLines(
      text: song.text,
      chord: chordsVisible ? song.chord : '',
    );
    final fontSize = textStyle.fontSize ?? 16;
    final chordStyle = textStyle.copyWith(
      fontSize: fontSize * 0.85,
      fontWeight: FontWeight.w700,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Roboto Mono', 'Courier'],
      color: ReaderTheme.of(context).rubric,
      height: 1.35,
    );
    String chordText(String chord) => transposeChordLine(chord, transpose);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            chordsVisible &&
            layout == SongChordLayout.left &&
            fitsLeftLayout(
              width: constraints.maxWidth,
              fontSize: fontSize,
              textScaler: MediaQuery.textScalerOf(context),
            );
        return Column(
          key: Key(side ? 'song-text-left' : 'song-text-above'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              if (side)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 36,
                      child: Padding(
                        padding: EdgeInsets.only(top: fontSize * 0.18),
                        child: Text(
                          line.chord.isEmpty ? '' : chordText(line.chord),
                          style: chordStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 64,
                      child: Text(
                        line.text.isEmpty ? ' ' : line.text,
                        style: textStyle,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (chordsVisible && line.chord.isNotEmpty)
                      Text(chordText(line.chord), style: chordStyle),
                    Text(line.text.isEmpty ? ' ' : line.text, style: textStyle),
                  ],
                ),
          ],
        );
      },
    );
  }
}
