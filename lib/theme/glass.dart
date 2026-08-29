import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared liquid-glass / ambient tokens for the liturgical UI.
class GlassTokens {
  const GlassTokens._(this.isDark);

  factory GlassTokens.of(BuildContext context) =>
      GlassTokens._(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;

  // Blur strengths
  double get barBlur => 24;
  double get pillBlur => 18;
  double get cardBlur => 14;
  double get softBlur => 10;

  // Ambient wash (full / soft page tints)
  double get ambientStrong => isDark ? 0.35 : 0.22;
  double get ambientMid => isDark ? 0.12 : 0.08;
  double get ambientSoft => isDark ? 0.14 : 0.08;
  double get ambientBar => isDark ? 0.12 : 0.07;
  double get ambientPill => isDark ? 0.12 : 0.08;
  double get ambientCard => isDark ? 0.10 : 0.06;

  // Glass fills
  Color get cardFill => isDark
      ? Colors.black.withValues(alpha: 0.38)
      : Colors.white.withValues(alpha: 0.72);
  Color get softFill => isDark
      ? Colors.black.withValues(alpha: 0.28)
      : Colors.white.withValues(alpha: 0.62);
  Color get barFill => isDark
      ? Colors.black.withValues(alpha: 0.48)
      : Colors.white.withValues(alpha: 0.62);
  Color get pillFill => isDark
      ? Colors.black.withValues(alpha: 0.52)
      : Colors.white.withValues(alpha: 0.80);

  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.92);
  Color get softBorder => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.06);
  Color get pillBorder => isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.white;
  Color get specular => isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.92);

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
          blurRadius: 18,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];

  List<BoxShadow> get pillShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
          blurRadius: 32,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
          blurRadius: 8,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ];

  Color tinted(Color base, Color season, double strength) =>
      Color.alphaBlend(season.withValues(alpha: strength), base);

  /// Lift dark liturgical accents for readable icons/labels on dark glass.
  Color accentOnSurface(Color accent) {
    if (!isDark) return accent;
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness >= 0.55) return accent;
    return hsl.withLightness(0.62).toColor();
  }
}

/// Soft season-colored wash behind page content.
class AmbientWash extends StatelessWidget {
  final Color seasonColor;
  final AmbientWashIntensity intensity;
  final double height;
  final Duration duration;
  final Widget? child;

  const AmbientWash({
    super.key,
    required this.seasonColor,
    this.intensity = AmbientWashIntensity.soft,
    this.height = 160,
    this.duration = const Duration(milliseconds: 700),
    this.child,
  });

  /// Full-bleed vertical wash (home hero).
  const AmbientWash.hero({
    super.key,
    required this.seasonColor,
    this.duration = const Duration(milliseconds: 700),
    this.child,
  })  : intensity = AmbientWashIntensity.hero,
        height = double.infinity;

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final wash = IgnorePointer(
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeInOut,
        height: intensity == AmbientWashIntensity.hero ? null : height,
        decoration: BoxDecoration(gradient: _gradient(tokens)),
      ),
    );

    if (child == null) {
      if (intensity == AmbientWashIntensity.hero) {
        return Positioned.fill(child: wash);
      }
      return wash;
    }

    return Stack(
      children: [
        if (intensity == AmbientWashIntensity.hero)
          Positioned.fill(child: wash)
        else
          Positioned(top: 0, left: 0, right: 0, child: wash),
        child!,
      ],
    );
  }

  LinearGradient _gradient(GlassTokens tokens) {
    switch (intensity) {
      case AmbientWashIntensity.hero:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            seasonColor.withValues(alpha: tokens.ambientStrong),
            seasonColor.withValues(alpha: tokens.ambientMid),
            seasonColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.42, 0.88],
        );
      case AmbientWashIntensity.soft:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            seasonColor.withValues(alpha: tokens.ambientSoft),
            seasonColor.withValues(alpha: 0),
          ],
        );
    }
  }
}

enum AmbientWashIntensity { hero, soft }

enum GlassStyle { card, soft, bar, pill }

/// Frosted / liquid-glass surface with optional season tint.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final Color? seasonColor;
  final GlassStyle style;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool blur;
  final Color? accentBar;
  final double accentBarWidth;

  const GlassSurface({
    super.key,
    required this.child,
    this.seasonColor,
    this.style = GlassStyle.card,
    this.borderRadius,
    this.padding,
    this.blur = true,
    this.accentBar,
    this.accentBarWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final radius = borderRadius ??
        BorderRadius.circular(style == GlassStyle.pill ? 32 : 14);

    final base = switch (style) {
      GlassStyle.card => tokens.cardFill,
      GlassStyle.soft => tokens.softFill,
      GlassStyle.bar => tokens.barFill,
      GlassStyle.pill => tokens.pillFill,
    };
    final tintStrength = switch (style) {
      GlassStyle.card => tokens.ambientCard,
      GlassStyle.soft => tokens.ambientCard,
      GlassStyle.bar => tokens.ambientBar,
      GlassStyle.pill => tokens.ambientPill,
    };
    final fill = seasonColor != null
        ? tokens.tinted(base, seasonColor!, tintStrength)
        : base;
    final borderColor = switch (style) {
      GlassStyle.pill => tokens.pillBorder,
      GlassStyle.bar || GlassStyle.soft => tokens.softBorder,
      GlassStyle.card => tokens.border,
    };
    final blurSigma = switch (style) {
      GlassStyle.pill => tokens.pillBlur,
      GlassStyle.bar => tokens.barBlur,
      GlassStyle.soft => tokens.softBlur,
      GlassStyle.card => tokens.cardBlur,
    };

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (accentBar != null) {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: accentBarWidth,
              decoration: BoxDecoration(
                color: accentBar,
                borderRadius: BorderRadius.only(
                  topLeft: radius.topLeft,
                  bottomLeft: radius.bottomLeft,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    final decorated = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: style == GlassStyle.pill
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.specular, fill],
                stops: const [0.0, 0.38],
              )
            : null,
        color: style == GlassStyle.pill ? null : fill,
        border: Border.all(
          color: borderColor,
          width: style == GlassStyle.pill ? 1.0 : 0.7,
        ),
      ),
      child: content,
    );

    final clipped = ClipRRect(
      borderRadius: radius,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: decorated,
            )
          : decorated,
    );

    final shadows = switch (style) {
      GlassStyle.pill => tokens.pillShadow,
      GlassStyle.card => tokens.cardShadow,
      _ => null,
    };

    if (shadows == null) return clipped;

    // Shadow outside ClipRRect so it is not clipped away.
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: clipped,
    );
  }
}

/// Full-width frosted bar (app bars).
class GlassBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  final Color? seasonColor;
  final double height;

  const GlassBar({
    super.key,
    required this.child,
    this.seasonColor,
    this.height = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final base = tokens.barFill;
    final fill = seasonColor != null
        ? tokens.tinted(base, seasonColor!, tokens.ambientBar)
        : base;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.barBlur,
          sigmaY: tokens.barBlur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              bottom: BorderSide(color: tokens.softBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(height: height, child: child),
          ),
        ),
      ),
    );
  }
}
