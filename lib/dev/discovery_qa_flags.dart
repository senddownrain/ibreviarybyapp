import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/discovery/hint_eligibility.dart';

/// Test-profile switches for demos on a device:
/// `--dart-define=DISCOVERY_QA=true` removes the waiting times and quotas;
/// a file named `DISCOVERY_QA_RESET` next to the `discovery_v1` box (or the
/// environment variable `DISCOVERY_QA_RESET=1`) makes the next launch forget
/// the hint history of this profile (that box only) and removes the file.
/// All of it is inert in release builds: the `!kReleaseMode` test is a
/// compile-time constant.
const bool kDiscoveryQa = !kReleaseMode && bool.fromEnvironment('DISCOVERY_QA');

/// [boxPath] is the file of the open `discovery_v1` box, if known.
bool discoveryQaResetRequested([String? boxPath]) {
  if (!kDiscoveryQa || kIsWeb) return false;
  try {
    if (Platform.environment['DISCOVERY_QA_RESET'] == '1') return true;
    if (boxPath == null) return false;
    final marker = File('${File(boxPath).parent.path}/DISCOVERY_QA_RESET');
    if (!marker.existsSync()) return false;
    marker.deleteSync();
    return true;
  } catch (_) {
    return false;
  }
}

/// Production numbers, or the QA profile without gaps and quotas.
DiscoveryPolicyConfig discoveryPolicyForBuild() => kDiscoveryQa
    ? const DiscoveryPolicyConfig(
        minInterval: Duration.zero,
        p2MinInterval: Duration.zero,
        firstSessionLimit: 99,
        rollingLimit: 99,
      )
    : const DiscoveryPolicyConfig();
