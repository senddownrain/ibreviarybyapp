import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/discovery/discovery_qa_mode.dart';

/// Test-profile reset for demos on a device. The one QA switch is
/// [discoveryQaActive] (see discovery_qa_mode.dart): it is a debug/profile
/// build with the QA define, with its own box, no waiting times and no quotas.
/// A file named `DISCOVERY_QA_RESET` next to the `discovery_v1` box (or the
/// environment variable `DISCOVERY_QA_RESET=1`) makes the next launch forget
/// the hint history of this profile (that box only) and removes the file.
/// Inert in release builds and without the QA switch.

/// [boxPath] is the file of the open `discovery_v1` box, if known.
bool discoveryQaResetRequested([String? boxPath]) {
  if (!discoveryQaActive || kIsWeb) return false;
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
