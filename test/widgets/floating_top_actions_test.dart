import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/widgets/floating_top_actions.dart';

Widget _app(Widget child, TargetPlatform platform) => ProviderScope(
  child: MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(body: Stack(children: [child])),
  ),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('single floating action icon is centred in its circle '
        '(${platform.name})', (tester) async {
      await tester.pumpWidget(
        _app(
          FloatingTopActions(
            seasonColor: Colors.indigo,
            actions: [
              IconButton(
                key: const Key('probe-action'),
                onPressed: () {},
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 22,
                ),
              ),
            ],
          ),
          platform,
        ),
      );
      final surface = tester.getRect(
        find.byKey(const Key('floating-top-actions-surface')),
      );
      final icon = tester.getRect(find.byType(PhosphorIcon));
      final button = tester.getRect(find.byKey(const Key('probe-action')));
      expect(icon.center.dx, closeTo(surface.center.dx, 0.01));
      expect(icon.center.dy, closeTo(surface.center.dy, 0.01));
      // The whole circle stays tappable.
      expect(button.width, greaterThanOrEqualTo(48));
    });
  }
}
