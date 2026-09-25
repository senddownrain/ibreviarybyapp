import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';

/// Minimal stand-in for Prayerbook sections that are not implemented yet
/// (`/prayers/sacraments`). The route stays stable, so a
/// real module can replace this widget without touching navigation.
class PrayerbookPlaceholderScreen extends StatelessWidget {
  const PrayerbookPlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                120 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Text(
                  title,
                  key: const Key('prayerbook-placeholder-title'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 48),
                PhosphorIcon(icon, size: 48, color: accent),
                const SizedBox(height: 16),
                Text(
                  'Раздзел у распрацоўцы',
                  key: const Key('prayerbook-placeholder-message'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
        ],
      ),
    );
  }
}

class SacramentsPlaceholderScreen extends StatelessWidget {
  const SacramentsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => const PrayerbookPlaceholderScreen(
    title: 'Сакрамэнты',
    icon: PhosphorIconsLight.cross,
  );
}
