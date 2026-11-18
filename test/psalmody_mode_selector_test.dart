import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/liturgical_selector_components.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';
import 'package:mybrev_flutter/widgets/psalmody_settings_section.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  Future<void> setPsalmodyMode(PsalmodyMode mode) async =>
      state = state.copyWith(psalmodyMode: mode);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 360.0, 390.0, 768.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          testWidgets(
            '$platform $brightness $width dp ${scale}x: shared value, safe panel and full labels',
            (tester) async {
              tester.view.physicalSize = Size(width, 740);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final semantics = tester.ensureSemantics();

              final container = ProviderContainer(
                overrides: [settingsProvider.overrideWith(_Settings.new)],
              );
              addTearDown(container.dispose);
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    theme: ThemeData(
                      platform: platform,
                      brightness: brightness,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        padding: const EdgeInsets.only(top: 44, bottom: 34),
                        viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                      ),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const PsalmodySettingsSection(),
                              Builder(
                                builder: (context) => TextButton(
                                  onPressed: () => showTextScalePanel(
                                    context,
                                    showPsalmody: true,
                                  ),
                                  child: const Text('Aa'),
                                ),
                              ),
                              const LiturgicalSelectorHeading(
                                'Тэксты Літургіі гадзінаў апрача ўласных',
                              ),
                              RadioGroup<String>(
                                groupValue: 'dead',
                                onChanged: (_) {},
                                child: const LiturgicalCelebrationChoice(
                                  value: 'dead',
                                  title: 'Афіцый за памерлых',
                                  subtitle:
                                      'Літургічная ступень · Магчымасці цэлебрацыі',
                                  selected: true,
                                  colors: [],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final global = find.byType(PsalmodyModeSelector);
              await tester.tap(
                find.byKey(const ValueKey('psalmody-mode-alternatingStanzas')),
              );
              await tester.pump();
              expect(
                tester.widget<PsalmodyModeSelector>(global).value,
                PsalmodyMode.alternatingStanzas,
              );
              // At large text the button sits below the 740 dp viewport.
              await tester.ensureVisible(find.text('Aa'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Aa'));
              await tester.pumpAndSettle();
              final panel = find.byKey(const Key('text-scale-psalmody-modes'));
              final buttons = [
                for (final mode in PsalmodyMode.values)
                  find.descendant(
                    of: panel,
                    matching: find.byKey(
                      ValueKey('psalmody-mode-${mode.name}'),
                    ),
                  ),
              ];
              Rect? previous;
              for (var i = 0; i < buttons.length; i++) {
                await tester.ensureVisible(buttons[i]);
                await tester.pumpAndSettle();
                final rect = tester.getRect(buttons[i]);
                expect(rect.height, greaterThanOrEqualTo(48));
                expect(rect.width, greaterThanOrEqualTo(44));
                expect(rect.left, greaterThanOrEqualTo(0));
                expect(rect.right, lessThanOrEqualTo(width));
                expect(rect.bottom, lessThanOrEqualTo(740 - 34));
                if (previous != null) {
                  expect(rect.left, closeTo(previous.right, .01));
                  expect(rect.width, closeTo(previous.width, .01));
                }
                previous = rect;
                final node = tester.getSemantics(buttons[i]);
                expect(node.label, PsalmodyMode.values[i].label);
                expect(node.flagsCollection.isButton, isTrue);
                expect(node.flagsCollection.isSelected.toBoolOrNull(), i == 2);
              }
              await tester.tap(buttons[1]);
              await tester.pump();
              expect(
                container.read(settingsProvider).psalmodyMode,
                PsalmodyMode.leftBreakIndent,
              );
              await tester.tap(find.byTooltip('Закрыць'));
              await tester.pumpAndSettle();
              expect(
                tester.widget<PsalmodyModeSelector>(global).value,
                PsalmodyMode.leftBreakIndent,
              );
              expect(tester.takeException(), isNull);
              semantics.dispose();
            },
          );
        }
      }
    }
  }
}
