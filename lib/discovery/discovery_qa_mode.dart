import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/discovery/hint_eligibility.dart';

/// Local test builds only: `--dart-define=DISCOVERY_QA=true` on a debug or
/// profile build. It never exists in release (`kReleaseMode` wins), uses its
/// own Hive box and relaxes only the frequency quotas, so every hint can be
/// shown again and again on a test profile. Content, dates and rules are the
/// production ones.
const bool kDiscoveryQaDefine = bool.fromEnvironment('DISCOVERY_QA');

bool get discoveryQaActive => kDiscoveryQaDefine && !kReleaseMode;

const String kDiscoveryQaBox = 'discovery_qa_v1';

DiscoveryStorage qaDiscoveryStorage() =>
    HiveDiscoveryStorage(boxName: kDiscoveryQaBox);

const DiscoveryPolicyConfig qaDiscoveryPolicy = DiscoveryPolicyConfig(
  minInterval: Duration.zero,
  p2MinInterval: Duration.zero,
  firstSessionLimit: 999,
  rollingLimit: 999,
);
