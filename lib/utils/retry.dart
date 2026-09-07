import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef RetryCallback =
    void Function(Object error, int attempt, int maxAttempts);

/// Retry with exponential backoff (mirrors web `retry.js`).
Future<T> retry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  Duration delay = const Duration(milliseconds: 300),
  double backoff = 2,
  Duration timeout = Duration.zero,
  bool Function(Object error)? shouldRetry,
  RetryCallback? onRetry,
}) async {
  var currentDelay = delay;
  Object? lastError;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      if (timeout > Duration.zero) {
        return await fn().timeout(timeout);
      }
      return await fn();
    } catch (error) {
      lastError = error;
      final retryable = shouldRetry?.call(error) ?? true;
      if (!retryable || attempt == maxAttempts) break;
      onRetry?.call(error, attempt, maxAttempts);
      await Future<void>.delayed(currentDelay);
      currentDelay = Duration(
        milliseconds: (currentDelay.inMilliseconds * backoff).round(),
      );
    }
  }

  throw lastError ?? StateError('retry failed without error');
}

bool _isRetryableFirestoreError(Object error) {
  if (error is FirebaseException) {
    return const {
      'unavailable',
      'deadline-exceeded',
      'resource-exhausted',
      'aborted',
    }.contains(error.code);
  }
  if (error is TimeoutException) return true;
  return false;
}

/// Firestore reads with short per-attempt timeout and backoff.
Future<T> retryFirestore<T>(Future<T> Function() fn, {int maxAttempts = 3}) {
  return retry(
    fn,
    maxAttempts: maxAttempts,
    delay: const Duration(milliseconds: 300),
    backoff: 2,
    timeout: const Duration(seconds: 10),
    shouldRetry: _isRetryableFirestoreError,
  );
}
