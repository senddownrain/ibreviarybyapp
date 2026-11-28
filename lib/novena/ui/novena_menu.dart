import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';

/// What the shared overflow menu needs to know. Menus built without a
/// provider scope (isolated hosts) have no novenas.
bool novenaMenuHasActive(BuildContext context) {
  final scope = context
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
  if (scope == null) return false;
  final container = (scope.widget as UncontrolledProviderScope).container;
  return container.read(novenaBoxProvider) != null &&
      container.read(novenaProvider).active.isNotEmpty;
}

/// The quiet indicator on the menu button: novenas awaiting today. It sits
/// inside the button, so it covers no text and hides with the chrome.
class NovenaMenuBadge extends StatelessWidget {
  const NovenaMenuBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context
            .getElementForInheritedWidgetOfExactType<
              UncontrolledProviderScope
            >() ==
        null) {
      return child;
    }
    return Stack(
      children: [
        child,
        Positioned(
          top: 3,
          right: 3,
          child: Consumer(
            builder: (context, ref, _) {
              if (ref.watch(novenaBoxProvider) == null) {
                return const SizedBox.shrink();
              }
              final state = ref.watch(novenaProvider);
              if (state.active.isEmpty) return const SizedBox.shrink();
              final count = state.needingAction(ref.watch(novenaTodayProvider));
              if (count == 0) return const SizedBox.shrink();
              final cs = Theme.of(context).colorScheme;
              return IgnorePointer(
                child: Semantics(
                  label: 'Навэнны на сёння: $count',
                  excludeSemantics: true,
                  child: Container(
                    key: const Key('novena-badge'),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.tertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: cs.onTertiary,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
