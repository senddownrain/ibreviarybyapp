import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/prayer_category_icons.dart';

/// Draws a prayer-category icon from its `iconKey`. Unknown keys get a safe
/// fallback (never an error); the 12 authored symbols are bundled SVG assets
/// recoloured with the surrounding icon colour, so every theme works.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.iconKey, {super.key, this.size = 24, this.color});

  final String? iconKey;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).iconTheme.color;
    final spec = categoryIconSpec(iconKey);
    if (spec == null) {
      return PhosphorIcon(
        PhosphorIconsRegular.folder,
        size: size,
        color: resolved,
      );
    }
    final svg = spec.svgAsset;
    if (svg == null) {
      return PhosphorIcon(spec.phosphor!, size: size, color: resolved);
    }
    return SvgPicture.asset(
      svg,
      key: ValueKey('category-svg-${spec.key}'),
      width: size,
      height: size,
      colorFilter: resolved == null
          ? null
          : ColorFilter.mode(resolved, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
