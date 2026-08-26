import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

final isOfflineProvider = Provider<bool>((ref) {
  final conn = ref.watch(connectivityProvider);
  return conn.when(
    data: (online) => !online,
    loading: () => false,
    error: (_, __) => false,
  );
});
