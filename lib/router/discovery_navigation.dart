import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The real route opener for discovery hints: a section tab is switched with
/// `go`, a screen inside the Prayer book is pushed so Back returns to it.
void openDiscoveryRoute(
  BuildContext context,
  String path, {
  bool switchBranch = false,
}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  switchBranch ? router.go(path) : router.push(path);
}
