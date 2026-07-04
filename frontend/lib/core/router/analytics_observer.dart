import 'package:flutter/material.dart';

/// Centralized Analytics Observer for tracking user journeys.
/// This observer is attached to the GoRouter to capture every screen transition.
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      debugPrint('📊 [Analytics] Screen Viewed: ${route.settings.name}');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name != null) {
      debugPrint('📊 [Analytics] Screen Exited: ${route.settings.name}');
    }
  }
}
