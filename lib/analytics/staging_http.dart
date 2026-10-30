// R04: batch-only HTTP sender to the closed QA staging endpoint
// (docs/analytics-staging-flutter.md; server contract: mybrev
// docs/analytics-staging-contract.md).
//
// This is the ONLY analytics file that may open a network channel. It is
// reachable only through the compile-time gate below: both
// `--dart-define=ANALYTICS_LOCAL=true` and `--dart-define=ANALYTICS_STAGING=true`
// are required, plus the endpoint in `--dart-define=ANALYTICS_STAGING_URL=...`.
// No flag, no URL, no code path: a normal build contains no endpoint address
// and never constructs a client. No identifiers, no headers beyond
// Content-Type, no cookies, no secret.
//
// Delivery is AT-MOST-ONCE: the caller removes packets from its persisted
// state BEFORE [send]; there is no retry on any outcome except nothing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mybrev_flutter/analytics/transport.dart';

const bool kAnalyticsStaging = bool.fromEnvironment('ANALYTICS_STAGING');
const String kAnalyticsStagingUrl = String.fromEnvironment(
  'ANALYTICS_STAGING_URL',
);

/// Server limit (`payload_too_large`): bigger packets are never sent.
const int kMaxPacketBytes = 16 * 1024;
const Duration kSendTimeout = Duration(seconds: 10);

/// Reasons the server tells the client to stop sending (kill switch / update).
const Set<int> kHaltStatuses = {426, 503};

/// Only https, or plain http to the loopback address (local R02 server reached
/// through `adb reverse` / the iOS Simulator). Anything else is refused.
Uri? parseStagingUrl(String raw) {
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;
  final loopback =
      uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1';
  if (uri.scheme == 'https' || (uri.scheme == 'http' && loopback)) {
    final base = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: '$base/v2/ingest');
  }
  return null;
}

/// True only in a QA build that asked for staging explicitly.
bool stagingEnabled({
  required bool local,
  required bool staging,
  required String url,
}) => local && staging && parseStagingUrl(url) != null;

/// One POST per packet, never retried. Any exception or non-2xx is a loss.
class HttpStagingTransport implements AnalyticsTransport {
  HttpStagingTransport(this.endpoint, {this.timeout = kSendTimeout});

  final Uri endpoint;
  final Duration timeout;

  /// Body of the last non-204 answer (`{"code": "..."}`), for diagnostics only.
  String? lastErrorCode;

  @override
  Future<TransportResponse> send(Map<String, Object?> packet) async {
    final body = utf8.encode(jsonEncode(packet));
    if (body.length > kMaxPacketBytes) return const TransportResponse(413);
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent =
          null // no User-Agent of our own
      ..idleTimeout = Duration.zero;
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType('application', 'json');
      request.contentLength = body.length;
      request.add(body);
      final response = await request.close().timeout(timeout);
      final text = await utf8.decodeStream(response).timeout(timeout);
      lastErrorCode = null;
      if (response.statusCode != 204 && text.isNotEmpty) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map && decoded['code'] is String) {
            lastErrorCode = decoded['code'] as String;
          }
        } catch (_) {}
      }
      return TransportResponse(response.statusCode);
    } finally {
      client.close(force: true);
    }
  }
}

class StagingFlushResult {
  const StagingFlushResult({this.sent = 0, this.lost = 0, this.halted = false});
  final int sent, lost;
  final bool halted;
}

/// Sends drained packets once. A 503 / 426 answer is the server-side kill
/// switch: the sender halts for the rest of the process and tells the caller
/// to drop what it holds (no queue is kept for a disabled server).
class StagingSender {
  StagingSender(this.transport);

  final AnalyticsTransport transport;
  bool halted = false;
  int sent = 0, lost = 0;
  bool _busy = false;

  Future<StagingFlushResult> sendAll(List<Map<String, Object?>> packets) async {
    if (halted || _busy || packets.isEmpty) {
      return StagingFlushResult(halted: halted);
    }
    _busy = true;
    var s = 0, l = 0;
    try {
      for (final packet in packets) {
        if (halted) {
          l++;
          continue;
        }
        try {
          final response = await transport.send(packet);
          if (response.status == 204) {
            s++;
          } else {
            l++;
            if (kHaltStatuses.contains(response.status)) halted = true;
          }
        } catch (_) {
          l++; // no retry: accepted under-count
        }
      }
    } finally {
      _busy = false;
    }
    sent += s;
    lost += l;
    return StagingFlushResult(sent: s, lost: l, halted: halted);
  }
}
