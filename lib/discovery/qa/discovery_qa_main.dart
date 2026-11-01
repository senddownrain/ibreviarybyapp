import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/discovery/qa/discovery_qa_harness.dart';

/// Debug/profile only entrypoint:
/// `flutter run -t lib/discovery/qa/discovery_qa_main.dart`.
/// It uses its own Hive directory, so the app's data is never read or erased.
Future<void> main() async {
  if (kReleaseMode) {
    throw StateError('The discovery QA harness is not available in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('discovery_qa');
  runApp(
    DiscoveryQaApp(storage: HiveDiscoveryStorage(boxName: 'discovery_qa_v1')),
  );
}
