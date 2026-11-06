import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'feedback_models.dart';

/// Public URL of the shared feedback Worker (no secret): `--dart-define=FEEDBACK_API_URL=...`.
const String kFeedbackApiUrl = String.fromEnvironment('FEEDBACK_API_URL');

enum FeedbackFailure {
  notConfigured,
  network,
  rateLimited,
  unavailable,
  rejected,
}

class FeedbackException implements Exception {
  const FeedbackException(this.failure);
  final FeedbackFailure failure;
  @override
  String toString() => 'FeedbackException($failure)';
}

String feedbackPlatform() {
  if (kIsWeb) return 'web';
  return Platform.isIOS ? 'ios' : 'android';
}

class FeedbackService {
  FeedbackService({
    http.Client? client,
    String? baseUrl,
    String? platform,
    this.appVersion = '1.0.0',
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? kFeedbackApiUrl).trim().replaceAll(
         RegExp(r'/+$'),
         '',
       ),
       _platform = platform;

  final http.Client _client;
  final String _baseUrl;
  final String? _platform;
  final String appVersion;

  bool get configured => _baseUrl.isNotEmpty;

  /// Sends once. Never retries by itself; the caller retries only on a user action.
  /// [requestId] is reused for a retry of the same message so a lost response cannot create a duplicate.
  Future<String> submit({
    required FeedbackCategory category,
    required String body,
    String? email,
    FeedbackContext? context,
    required String requestId,
  }) async {
    if (!configured)
      throw const FeedbackException(FeedbackFailure.notConfigured);
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_baseUrl/api/feedback'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'category': category.code,
              'platform': _platform ?? feedbackPlatform(),
              'sourceApp': 'ibreviary_flutter',
              'appVersion': appVersion,
              'body': body.trim(),
              if (email != null && email.trim().isNotEmpty)
                'email': email.trim(),
              if (context != null) 'context': context.toJson(),
              'requestId': requestId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FeedbackException(FeedbackFailure.network);
    }
    if (res.statusCode == 201) {
      final id = (jsonDecode(res.body) as Map<String, dynamic>)['id'];
      if (id is String) return id;
      throw const FeedbackException(FeedbackFailure.unavailable);
    }
    if (res.statusCode == 429)
      throw const FeedbackException(FeedbackFailure.rateLimited);
    if (res.statusCode >= 500)
      throw const FeedbackException(FeedbackFailure.unavailable);
    throw const FeedbackException(FeedbackFailure.rejected);
  }
}
