import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared liquid-glass / ambient tokens for the liturgical UI.
class GlassTokens {
  const GlassTokens._(this.isDark);

  factory GlassTokens.of(BuildContext context) =>
      GlassTokens._(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;

  // Blur strengths
  double get pillBlur => 20;
  double get cardBlur => 14;
  double get softBlur => 10;

  // Ambient wash (full / soft page tints)
  double get ambientStrong => isDark ? 0.22 : 0.14;
  double get ambientMid => isDark ? 0.10 : 0.06;
  double get ambientSoft => isDark ? 0.12 : 0.07;
  double get ambientPill => isDark ? 0.12 : 0.08;
  double get ambientCard => isDark ? 0.10 : 0.06;

  // Glass fills
  Color get cardFill =>
      isDark ? const Color(0xF0171512) : const Color(0xF0FFFBF3);
  Color get softFill =>
      isDark ? const Color(0xD9171512) : const Color(0xD9FFFBF3);
  Color get pillFill =>
      isDark ? const Color(0xF7171512) : const Color(0xF7FFFBF3);

  Color get border =>
      isDark ? const Color(0x21F4EDE1) : const Color(0x1A372F26);
  Color get softBorder =>
      isDark ? const Color(0x21F4EDE1) : const Color(0x1A372F26);
  Color get pillBorder =>
      isDark ? const Color(0x21F4EDE1) : const Color(0x1A372F26);
  Color get specular => isDark
      ? Colors.white.withValues(alpha: 0.045)
      : Colors.white.withValues(alpha: 0.28);

  Color get ambientBase =>
      isDark ? const Color(0xFF4A3A2D) : const Color(0xFFB49B71);

  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
      blurRadius: 14,
      spreadRadius: -1,
      offset: const Offset(0, 3),
    ),
  ];

  List<BoxShadow> get pillShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
      blurRadius: 30,
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

/// Warm neutral application material used below contextual liturgical washes.
class AmbientBackdrop extends StatelessWidget {
  final Widget child;

  const AmbientBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final background = Theme.of(context).colorScheme.surfaceContainerLowest;
    final strength = tokens.isDark ? 0.18 : 0.13;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        gradient: RadialGradient(
          center: const Alignment(0, -1.12),
          radius: 1.22,
          colors: [
            Color.alphaBlend(
              tokens.ambientBase.withValues(alpha: strength),
              background,
            ),
            background,
          ],
          stops: const [0, 0.78],
        ),
      ),
      child: child,
    );
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
  }) : intensity = AmbientWashIntensity.hero,
       height = double.infinity;

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final wash = IgnorePointer(
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeInOut,
        height: intensity == AmbientWashIntensity.hero ? 430 : height,
        decoration: BoxDecoration(gradient: _gradient(tokens)),
      ),
    );

    if (child == null) {
      if (intensity == AmbientWashIntensity.hero) {
        return Positioned(top: -72, left: -72, right: -72, child: wash);
      }
      return wash;
    }

    return Stack(
      children: [
        if (intensity == AmbientWashIntensity.hero)
          Positioned(top: -72, left: -72, right: -72, child: wash)
        else
          Positioned(top: 0, left: 0, right: 0, child: wash),
        child!,
      ],
    );
  }

  Gradient _gradient(GlassTokens tokens) {
    switch (intensity) {
      case AmbientWashIntensity.hero:
        return RadialGradient(
          center: const Alignment(0.62, -0.48),
          radius: 0.92,
          colors: [
            seasonColor.withValues(alpha: tokens.ambientStrong),
            seasonColor.withValues(alpha: tokens.ambientMid),
            seasonColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.46, 1.0],
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

enum GlassStyle { card, soft, pill }

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
    final radius =
        borderRadius ??
        BorderRadius.circular(switch (style) {
          GlassStyle.pill => 32,
          GlassStyle.card => 22,
          GlassStyle.soft => 20,
        });

    final base = switch (style) {
      GlassStyle.card => tokens.cardFill,
      GlassStyle.soft => tokens.softFill,
      GlassStyle.pill => tokens.pillFill,
    };
    final tintStrength = switch (style) {
      GlassStyle.card => tokens.ambientCard,
      GlassStyle.soft => tokens.ambientCard,
      GlassStyle.pill => tokens.ambientPill,
    };
    final fill = seasonColor != null
        ? tokens.tinted(base, seasonColor!, tintStrength)
        : base;
    final borderColor = switch (style) {
      GlassStyle.pill => tokens.pillBorder,
      GlassStyle.soft => tokens.softBorder,
      GlassStyle.card => tokens.border,
    };
    final blurSigma = switch (style) {
      GlassStyle.pill => tokens.pillBlur,
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
                colors: [Color.alphaBlend(tokens.specular, fill), fill],
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
