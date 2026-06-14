import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin, crash-safe wrapper around Firebase Analytics.
///
/// Design rules (intentional):
///  * Every call is wrapped in try/catch — analytics must NEVER crash the app
///    or break a user flow, even if Firebase is mis-initialised.
///  * Nothing here is `await`ed at a call site that blocks the UI. All methods
///    return quickly; the underlying SDK batches and uploads in the background,
///    so there is zero added latency / lag on screen transitions.
///  * No PII is sent. We only set an opaque user id (the JWT `sub`) so DAU/MAU
///    and per-user funnels work; we never log emails, names, message text, etc.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  /// Raw instance — exposed only so `main.dart` can build the navigator
  /// observer. Prefer the helpers below everywhere else.
  static FirebaseAnalytics get instance => _fa;

  /// Navigator observer that auto-captures `screen_view` for any named route.
  /// Coexists with the app's existing [appRouteObserver] without interfering.
  static FirebaseAnalyticsObserver navigatorObserver() =>
      FirebaseAnalyticsObserver(analytics: _fa);

  /// Enable/disable collection (e.g. honour a future privacy toggle).
  static Future<void> setEnabled(bool enabled) async {
    try {
      await _fa.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      _warn('setEnabled', e);
    }
  }

  /// Identify the signed-in user so user counts and funnels are accurate.
  /// Pass `null` on logout to detach the id from future events.
  static Future<void> setUser(String? userId) async {
    try {
      await _fa.setUserId(id: userId);
    } catch (e) {
      _warn('setUser', e);
    }
  }

  /// Log a screen view. Firebase derives "engagement time per screen"
  /// automatically from the gaps between consecutive screen_view events.
  static void logScreen(String screenName) {
    // Fire-and-forget — never block the build/initState path.
    _fa.logScreenView(screenName: screenName).catchError((e) {
      _warn('logScreen', e);
    });
  }

  /// Log an arbitrary feature-usage event. Param values must be String/num.
  static void logEvent(String name, [Map<String, Object>? params]) {
    _fa.logEvent(name: name, parameters: params).catchError((e) {
      _warn('logEvent', e);
    });
  }

  static void _warn(String where, Object e) {
    if (kDebugMode) debugPrint('[Analytics] $where failed: $e');
  }
}
