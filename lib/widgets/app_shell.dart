import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/bottom_nav.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: cs.surface,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.list, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsLight.cross,
              size: 16,
              color: cs.primary.withOpacity(0.7),
            ),
            const SizedBox(width: 7),
            const Text(
              'Малітоўнік',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      drawer: const AppNavigationDrawer(),
      body: child,
      bottomNavigationBar: AppBottomNav(
        currentLocation: GoRouterState.of(context).uri.toString(),
      ),
    );
  }
}
