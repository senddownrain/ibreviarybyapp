// Mock transport (docs/analytics-handoff-flutter.md §5). There is no real
// network implementation: sending is disabled until the owner closes the
// privacy decisions (docs/analytics-privacy.md D-01…D-09).
class TransportResponse {
  const TransportResponse(this.status);
  final int status;
}

abstract class AnalyticsTransport {
  Future<TransportResponse> send(Map<String, Object?> packet);
}

/// Default transport: returns 204 without any I/O.
class NoopTransport implements AnalyticsTransport {
  const NoopTransport();

  @override
  Future<TransportResponse> send(Map<String, Object?> packet) async =>
      const TransportResponse(204);
}

/// Test transport: keeps accepted packets in memory and answers with
/// programmable statuses (204/400/410/429/503) or an exception.
class RecordingTransport implements AnalyticsTransport {
  RecordingTransport({List<int>? statuses, this.throwError = false})
    : _statuses = List<int>.of(statuses ?? const []);

  final List<int> _statuses;
  final bool throwError;
  final List<Map<String, Object?>> received = [];

  @override
  Future<TransportResponse> send(Map<String, Object?> packet) async {
    if (throwError) throw StateError('transport failure (test)');
    received.add(packet);
    return TransportResponse(_statuses.isEmpty ? 204 : _statuses.removeAt(0));
  }
}
