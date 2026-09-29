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
class SongChordControl extends StatelessWidget {
  const SongChordControl({
    super.key,
    required this.showChords,
    required this.layout,
    required this.transpose,
    required this.onShowChordsChanged,
    required this.onLayoutChanged,
    required this.onTransposeChanged,
    this.seasonColor,
  });

  final bool showChords;
  final SongChordLayout layout;
  final int transpose;
  final ValueChanged<bool> onShowChordsChanged;
  final ValueChanged<SongChordLayout> onLayoutChanged;
  final ValueChanged<int> onTransposeChanged;
  final Color? seasonColor;

  /// Compact controls keep growing with system text up to this factor; the
  /// whole capsule additionally scales down rather than overflow.
  static const maxTextScale = 1.6;

  static const double _button = 48;

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

    ButtonStyle toggleStyle(bool selected) => IconButton.styleFrom(
      fixedSize: const Size.square(_button),
      foregroundColor: selected ? accent : cs.onSurfaceVariant,
      backgroundColor: selected ? cs.tertiary.withValues(alpha: 0.14) : null,
    );
    const stepStyle = ButtonStyle(
      fixedSize: WidgetStatePropertyAll(Size.square(_button)),
    );

    final capsule = AdaptiveChromeSurface(
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
            label: right ? 'Акорды справа ад тэксту' : 'Акорды над радкамі',
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
              tooltip: right ? 'Акорды справа' : 'Акорды над радкамі',
              style: toggleStyle(false),
              onPressed: showChords
                  ? () => onLayoutChanged(
                      right ? SongChordLayout.above : SongChordLayout.right,
                    )
                  : null,
              icon: PhosphorIcon(
                right
                    ? PhosphorIconsRegular.alignRightSimple
                    : PhosphorIconsRegular.alignTopSimple,
                size: 22,
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: capsule,
          ),
        ),
      ),
    );
  }
}

class _TransposeValue extends StatelessWidget {
  const _TransposeValue({
    required this.value,
    required this.enabled,
    required this.accent,
    required this.onReset,
    required this.semitones,
  });

  final int value;
  final bool enabled;
  final Color accent;
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
    final width = widest.ceilToDouble() + 20;
    final label = SongChordControl.formatTranspose(value);
    final canReset = enabled && shifted;

    return Semantics(
      key: const Key('song-transpose-semantics'),
      liveRegion: true,
      button: canReset,
      label: shifted
          ? 'Танальнасць $label ${semitones(value)}'
          : 'Арыгінальная танальнасць',
      hint: canReset ? 'Вярнуць арыгінальную танальнасць' : null,
      onTap: canReset ? onReset : null,
      excludeSemantics: true,
      child: Tooltip(
        message: canReset ? 'Вярнуць арыгінал' : 'Арыгінальная танальнасць',
        child: InkWell(
          key: const Key('song-transpose-reset'),
          borderRadius: BorderRadius.circular(18),
          onTap: canReset ? onReset : null,
          child: SizedBox(
            key: const Key('song-transpose-value-box'),
            width: width,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: canReset
                      ? cs.tertiary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
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
          ),
        ),
      ),
    );
  }
}
