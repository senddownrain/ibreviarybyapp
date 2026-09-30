import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';

/// Inline chord capsule shown in the Song Detail context header:
///
/// `[♫ chords] [▤ layout] | [−  0  +]`
///
/// One [AdaptiveChromeSurface] (iOS glass, Android tonal) whose children never
/// change: when chords are hidden the layout and transpose parts stay in place
/// but are disabled, and the transpose value has a fixed width measured for the
/// widest label, so toggling, transposing or switching the layout never moves
/// the control. Tapping a non-zero value returns to the original key.
///
/// The layout is one 48 dp toggle rather than a two-segment selector: at
/// 320 dp the capsule already uses the whole header width, and a second
/// segment would shrink every hit target. The icon, tooltip and semantics
/// value name the selected layout instead.
class SongChordControl extends StatelessWidget {
  const SongChordControl({
    super.key,
    required this.showChords,
    required this.layout,
    required this.transpose,
    required this.onShowChordsChanged,
    required this.onLayoutChanged,
    required this.onTransposeChanged,
    this.layoutFallback = false,
    this.seasonColor,
  });

  final bool showChords;
  final SongChordLayout layout;
  final int transpose;
  final ValueChanged<bool> onShowChordsChanged;
  final ValueChanged<SongChordLayout> onLayoutChanged;
  final ValueChanged<int> onTransposeChanged;

  /// [SongChordLayout.right] is preferred but the song currently renders with
  /// chords above because the width is too small. Shown as a quiet dot on the
  /// layout button and spoken in its tooltip and semantics.
  final bool layoutFallback;
  final Color? seasonColor;

  /// Compact controls keep growing with system text up to this factor. On
  /// narrow screens the transpose value gives up its extra width first, so the
  /// buttons stay 48 dp; only below [_minWidth] does the capsule scale down.
  static const maxTextScale = 1.6;

  static const double _button = 48;
  static const double _minValueWidth = 40;

  /// Everything in the capsule except the transpose value: four buttons, the
  /// divider with its margins, the padding and the surface border.
  static const double _fixedWidth = 4 * _button + 9 + 8 + 2;

  static String formatTranspose(int value) => value > 0 ? '+$value' : '$value';

  static String _semitones(int value) {
    final n = value.abs();
    if (n % 10 == 1 && n % 100 != 11) return 'паўтон';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)) {
      return 'паўтоны';
    }
    return 'паўтонаў';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    final right = layout == SongChordLayout.right;
    final fallback = showChords && right && layoutFallback;

    ButtonStyle toggleStyle(bool selected) => IconButton.styleFrom(
      fixedSize: const Size.square(_button),
      foregroundColor: selected ? accent : cs.onSurfaceVariant,
      backgroundColor: selected ? cs.tertiary.withValues(alpha: 0.14) : null,
    );
    const stepStyle = ButtonStyle(
      fixedSize: WidgetStatePropertyAll(Size.square(_button)),
    );

    Widget capsule(double maxValueWidth) => AdaptiveChromeSurface(
      key: const Key('song-chord-control'),
      role: ChromeSurfaceRole.group,
      seasonColor: seasonColor,
      borderRadius: BorderRadius.circular(_button / 2 + 4),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('song-chords-toggle'),
            tooltip: showChords ? 'Схаваць акорды' : 'Паказаць акорды',
            isSelected: showChords,
            style: toggleStyle(showChords),
            onPressed: () => onShowChordsChanged(!showChords),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.musicNotesSimple,
              size: 22,
            ),
            selectedIcon: const PhosphorIcon(
              PhosphorIconsFill.musicNotesSimple,
              size: 22,
            ),
          ),
          Semantics(
            key: const Key('song-chord-layout-semantics'),
            container: true,
            label: 'Размяшчэнне акордаў',
            value: fallback
                ? '${layout.label}. Цяпер над радкамі: не хапае шырыні'
                : layout.label,
            hint: right
                ? 'Паставіць акорды над радкамі'
                : 'Паставіць акорды справа, калі хапае шырыні',
            button: true,
            enabled: showChords,
            excludeSemantics: true,
            onTap: showChords
                ? () => onLayoutChanged(
                    right ? SongChordLayout.above : SongChordLayout.right,
                  )
                : null,
            child: IconButton(
              key: const Key('song-chord-layout-toggle'),
              tooltip: fallback
                  ? 'Акорды справа: не хапае шырыні, паказаны над радкамі'
                  : right
                  ? 'Акорды справа ад тэксту'
                  : 'Акорды над радкамі',
              style: toggleStyle(false),
              onPressed: showChords
                  ? () => onLayoutChanged(
                      right ? SongChordLayout.above : SongChordLayout.right,
                    )
                  : null,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Dimmed while `right` cannot be shown at this width.
                  AnimatedOpacity(
                    opacity: fallback ? 0.45 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: ChordLayoutGlyph(layout: layout),
                  ),
                  // Always in the tree, so the fallback never moves anything.
                  PositionedDirectional(
                    top: -3,
                    end: -5,
                    child: AnimatedOpacity(
                      key: const Key('song-chord-layout-fallback'),
                      opacity: fallback ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: cs.outlineVariant.withValues(alpha: 0.7),
          ),
          IconButton(
            key: const Key('song-transpose-down'),
            tooltip: 'Панізіць на паўтон',
            style: stepStyle,
            onPressed: showChords && transpose > kMinTranspose
                ? () => onTransposeChanged(transpose - 1)
                : null,
            icon: const PhosphorIcon(PhosphorIconsBold.minus, size: 18),
          ),
          _TransposeValue(
            value: transpose,
            enabled: showChords,
            accent: accent,
            maxWidth: maxValueWidth,
            onReset: () => onTransposeChanged(0),
            semitones: _semitones,
          ),
          IconButton(
            key: const Key('song-transpose-up'),
            tooltip: 'Павысіць на паўтон',
            style: stepStyle,
            onPressed: showChords && transpose < kMaxTranspose
                ? () => onTransposeChanged(transpose + 1)
                : null,
            icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 18),
          ),
        ],
      ),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: Semantics(
        container: true,
        label: 'Акорды',
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: capsule(
                math.max(_minValueWidth, constraints.maxWidth - _fixedWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two lyric lines with their chord marks above each line or beside it.
///
/// A purpose-drawn glyph: the generic Phosphor alignment icons read as
/// unrelated actions at this size. Painted in the ambient icon colour with
/// Phosphor-like rounded strokes.
class ChordLayoutGlyph extends StatelessWidget {
  const ChordLayoutGlyph({super.key, required this.layout, this.size = 22});

  final SongChordLayout layout;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: Key('song-chord-layout-glyph-${layout.storageValue}'),
    size: Size.square(size),
    painter: _ChordLayoutGlyphPainter(
      layout: layout,
      color: IconTheme.of(context).color ?? const Color(0xFF000000),
      rtl: Directionality.of(context) == TextDirection.rtl,
    ),
  );
}

class _ChordLayoutGlyphPainter extends CustomPainter {
  const _ChordLayoutGlyphPainter({
    required this.layout,
    required this.color,
    required this.rtl,
  });

  final SongChordLayout layout;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // Designed on a 22 × 22 grid.
    canvas.scale(size.width / 22, size.height / 22);
    if (rtl) {
      canvas
        ..translate(22, 0)
        ..scale(-1, 1);
    }
    final lyric = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final chord = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    void mark(double x, double y) =>
        canvas.drawLine(Offset(x, y), Offset(x + 0.01, y), chord);
    if (layout == SongChordLayout.above) {
      for (final top in const [3.5, 13.5]) {
        mark(5, top);
        mark(12, top);
        canvas.drawLine(Offset(3, top + 5), Offset(19, top + 5), lyric);
      }
    } else {
      for (final y in const [7.0, 15.0]) {
        canvas.drawLine(Offset(3, y), Offset(12, y), lyric);
        mark(17.5, y);
      }
    }
  }

  @override
  bool shouldRepaint(_ChordLayoutGlyphPainter old) =>
      old.layout != layout || old.color != color || old.rtl != rtl;
}

class _TransposeValue extends StatelessWidget {
  const _TransposeValue({
    required this.value,
    required this.enabled,
    required this.accent,
    required this.maxWidth,
    required this.onReset,
    required this.semitones,
  });

  final int value;
  final bool enabled;
  final Color accent;

  /// Width left for the value once the 48 dp buttons are placed.
  final double maxWidth;
  final VoidCallback onReset;
  final String Function(int) semitones;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shifted = value != 0;
    final style = Theme.of(context).textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: !enabled
          ? cs.onSurface.withValues(alpha: 0.38)
          : shifted
          ? accent
          : cs.onSurfaceVariant,
    );
    // Width of the widest label, so -12 … +12 never shift the neighbours.
    final textScaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final sample in const ['+12', '-12', '0']) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final width = math.min(widest.ceilToDouble() + 20, maxWidth);
    final label = SongChordControl.formatTranspose(value);
    final canReset = enabled && shifted;

    return Semantics(
      key: const Key('song-transpose-semantics'),
      container: true,
      liveRegion: true,
      button: canReset,
      label: shifted
          ? 'Танальнасць $label ${semitones(value)}'
          : 'Арыгінальная танальнасць',
      hint: canReset ? 'Вярнуць арыгінальную танальнасць' : null,
      onTap: canReset ? onReset : null,
      excludeSemantics: true,
      child: Tooltip(
        message: canReset
            ? 'Націсніце, каб вярнуць арыгінальную танальнасць'
            : 'Арыгінальная танальнасць',
        child: InkWell(
          key: const Key('song-transpose-reset'),
          borderRadius: BorderRadius.circular(18),
          onTap: canReset ? onReset : null,
          child: SizedBox(
            key: const Key('song-transpose-value-box'),
            width: width,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: width,
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 3,
                  ),
                  decoration: BoxDecoration(
                    color: canReset
                        ? cs.tertiary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      key: const Key('song-transpose-value'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                  ),
                ),
                // Reset affordance: a small "return" glyph on the corner of a
                // shifted value. Overlaid, so it never changes the geometry.
                PositionedDirectional(
                  top: 1,
                  end: 0,
                  child: AnimatedOpacity(
                    key: const Key('song-transpose-reset-hint'),
                    opacity: canReset ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: PhosphorIcon(
                      PhosphorIconsBold.arrowCounterClockwise,
                      size: 12,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
