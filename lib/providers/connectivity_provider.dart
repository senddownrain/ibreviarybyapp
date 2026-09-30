import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _connectionProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

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
    error: (_, _) => false,
  );
});

/// True only when the device is known to be on a metered mobile connection
/// without Wi-Fi or Ethernet. Unknown connectivity is not treated as mobile.
final isOnMobileDataProvider = Provider<bool>((ref) {
  final results = ref.watch(_connectionProvider).valueOrNull;
  if (results == null) return false;
  final unmetered = results.any(
    (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
  );
  return !unmetered && results.contains(ConnectivityResult.mobile);
});
