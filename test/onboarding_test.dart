import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('onboarding');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  /// One app launch on the same storage.
  Future<void> launch() async {
    await Hive.close();
    await HiveService.init(
      path: directory.path,
      loadBundle: false,
      detectFirstLaunch: true,
    );
  }

  SettingsNotifier settings(ProviderContainer container) =>
      container.read(settingsProvider.notifier);

  ProviderContainer container() {
    final result = ProviderContainer();
    addTearDown(result.dispose);
    return result;
  }

  test('a clean install waits for the choice, also after a restart', () async {
    await launch();
    expect(HiveService.needsOnboarding, isTrue);
    await launch();
    expect(HiveService.needsOnboarding, isTrue);
  });

  test('an older install without any changed setting is not asked', () async {
    Hive.init(directory.path);
    await Hive.openBox('meta');
    await Hive.openBox('settings');
    await launch();
    expect(HiveService.needsOnboarding, isFalse);
    expect(HiveService.settingsBox.get(HiveService.onboardingKey), isNull);
  });

  test('an older install keeps its settings', () async {
    Hive.init(directory.path);
    await Hive.openBox('meta');
    final old = await Hive.openBox('settings');
    await old.putAll({
      'startSection': 'last',
      'lastSection': 'bible',
      'themeMode': 'dark',
    });
    await launch();
    expect(HiveService.needsOnboarding, isFalse);
    expect(HiveService.settingsBox.get('startSection'), 'last');
    expect(HiveService.settingsBox.get('lastSection'), 'bible');
    expect(HiveService.settingsBox.get('themeMode'), 'dark');
  });

  for (final (section, location) in const [
    ('hours', '/hours'),
    ('readings', '/readings'),
    ('prayerbook', '/prayers'),
    ('bible', '/bible'),
  ]) {
    test('choosing $section is stored and used on later launches', () async {
      await launch();
      final before = Map.of(HiveService.settingsBox.toMap());
      await settings(container()).completeOnboarding(section);
      expect(startSectionLocation(section, section), location);
      await launch();
      expect(HiveService.needsOnboarding, isFalse);
      expect(Map.of(HiveService.settingsBox.toMap()), {
        ...before,
        'startSection': section,
        HiveService.onboardingKey: HiveService.onboardingDone,
      });
      expect(onboardingRedirect(welcomeRoute, pending: false), location);
    });
  }

  test('a failed write does not complete the setup', () async {
    await launch();
    final notifier = settings(container());
    await HiveService.settingsBox.close();
    await expectLater(
      notifier.completeOnboarding('bible'),
      throwsA(isA<HiveError>()),
    );
    await launch();
    expect(HiveService.needsOnboarding, isTrue);
    expect(HiveService.settingsBox.get('startSection'), isNull);
  });

  test('changing the start page later does not ask again', () async {
    await launch();
    final first = settings(container());
    await first.completeOnboarding('hours');
    first.setStartSection('readings');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await launch();
    expect(HiveService.needsOnboarding, isFalse);
    expect(HiveService.settingsBox.get('startSection'), 'readings');
  });

  test('every location leads to the welcome screen while pending', () {
    for (final path in ['/', '/hours', '/bible', '/settings', '/about']) {
      expect(onboardingRedirect(path, pending: true), welcomeRoute);
      expect(onboardingRedirect(path, pending: false), isNull);
    }
    expect(onboardingRedirect(welcomeRoute, pending: true), isNull);
  });
}
