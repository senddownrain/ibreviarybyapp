import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mybrev_flutter/models/mass_ritual.dart';

const _kSettingsBox = 'settings';
const _kMassLanguageKey = 'massRitualLanguage';

/// Last chosen Holy Mass language, stored locally and independent of the
/// app UI language.
final massLanguageProvider = NotifierProvider<MassLanguageNotifier, String>(
  MassLanguageNotifier.new,
);

class MassLanguageNotifier extends Notifier<String> {
  @override
  String build() {
    String? stored;
    if (Hive.isBoxOpen(_kSettingsBox)) {
      stored = Hive.box(_kSettingsBox).get(_kMassLanguageKey) as String?;
    }
    return kMassRitual.resolveLanguage(null, stored);
  }

  void select(String language) {
    if (kMassRitual.variant(language) == null || language == state) return;
    state = language;
    if (Hive.isBoxOpen(_kSettingsBox)) {
      Hive.box(_kSettingsBox).put(_kMassLanguageKey, language);
    }
  }
}

/// Bundled fallback text of a Mass variant, read from app assets (offline).
final massBundledTextProvider = FutureProvider.family<String, String>(
  (ref, asset) => rootBundle.loadString(asset),
);
