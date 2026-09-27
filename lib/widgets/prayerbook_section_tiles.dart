import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';

/// Compact 2 × 2 grid of Prayerbook sections.
///
/// Rows size to their content (no fixed height), and both tiles of a row
/// share the taller height. With large system text or a narrow width the
/// grid becomes a single column so titles are never broken mid-word.
class PrayerbookSectionGrid extends StatelessWidget {
  const PrayerbookSectionGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final singleColumn = scale >= 1.6 || constraints.maxWidth < 300;
      if (singleColumn) {
        return Column(
          key: const Key('prayerbook-sections-list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(height: _spacing),
              tiles[i],
            ],
          ],
        );
      }
      return Column(
        key: const Key('prayerbook-sections-grid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row * 2 < tiles.length; row++) ...[
            if (row > 0) const SizedBox(height: _spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[row * 2]),
                  const SizedBox(width: _spacing),
                  Expanded(
                    child: row * 2 + 1 < tiles.length
                        ? tiles[row * 2 + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// One Prayerbook section tile: iOS Glass card or Android tonal surface with
/// the same information structure on both platforms.
class PrayerbookSectionTile extends StatelessWidget {
  const PrayerbookSectionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  static const _radius = BorderRadius.all(Radius.circular(22));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cupertino = usesCupertinoGlass(context);
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.tertiary.withValues(alpha: cupertino ? 0.14 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox.square(
              dimension: 40,
              child: Center(
                child: busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : PhosphorIcon(icon, size: 22, color: accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );

    final ink = InkWell(
      borderRadius: _radius,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: content,
    );

    final Widget surface;
    if (cupertino) {
      surface = GlassSurface(
        seasonColor: cs.tertiary,
        borderRadius: _radius,
        child: Material(type: MaterialType.transparency, child: ink),
      );
    } else {
      surface = Material(
        color: Color.alphaBlend(
          cs.tertiary.withValues(alpha: 0.04),
          cs.surfaceContainerLow,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: _radius,
          side: BorderSide(color: cs.outlineVariant, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: ink,
      );
    }
    return MergeSemantics(child: Semantics(button: true, child: surface));
  }
}
