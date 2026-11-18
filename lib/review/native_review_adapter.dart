import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// The only place that touches the store plugin, so tests never need a
/// platform channel.
abstract class NativeReviewAdapter {
  /// Asks the OS to show its review sheet. The OS may silently decline (quota);
  /// the result says only whether the call was made.
  Future<bool> requestReview();

  /// Opens the app's store page. Never the system sheet.
  Future<bool> openStoreListing();
}

/// Numeric App Store id, supplied at build time once the app has a store page
/// (`--dart-define=APP_STORE_ID=123456789`). Empty means "not known yet".
const String kAppStoreId = String.fromEnvironment('APP_STORE_ID');

class InAppReviewAdapter implements NativeReviewAdapter {
  InAppReviewAdapter({InAppReview? plugin, String appStoreId = kAppStoreId})
    : _plugin = plugin ?? InAppReview.instance,
      _appStoreId = appStoreId;

  final InAppReview _plugin;
  final String _appStoreId;

  @override
  Future<bool> requestReview() async {
    try {
      if (!await _plugin.isAvailable()) return false;
      await _plugin.requestReview();
      return true;
    } catch (error) {
      debugPrint('[Review] native request failed: $error');
      return false;
    }
  }

  @override
  Future<bool> openStoreListing() async {
    try {
      // iOS needs the numeric id; without it there is nothing correct to open.
      if (defaultTargetPlatform == TargetPlatform.iOS && _appStoreId.isEmpty) {
        return false;
      }
      await _plugin.openStoreListing(appStoreId: _appStoreId);
      return true;
    } catch (error) {
      debugPrint('[Review] store listing failed: $error');
      return false;
    }
  }
}
