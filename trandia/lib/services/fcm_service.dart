import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FcmService {
  static const _kTokenKey = 'fcm_token';

  /// Call this ONCE on app startup (in main.dart before runApp).
  /// Requests permission, fetches the FCM token, and caches it.
  /// Silent — never throws.
  static Future<void> initAndCache() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission denied');
        return;
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTokenKey, token);
        debugPrint('[FCM] ✅ Token cached: ${token.substring(0, 25)}...');
      } else {
        debugPrint('[FCM] ⚠️ Token is null — check google-services.json');
      }
    } catch (e) {
      debugPrint('[FCM] initAndCache failed: $e');
    }
  }

  /// Returns cached FCM token — FAST, no network call.
  /// Call this during login/signup.
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kTokenKey);
      debugPrint('[FCM] getCachedToken → ${token != null ? "${token.substring(0, 20)}..." : "null"}');
      return token;
    } catch (e) {
      debugPrint('[FCM] getCachedToken failed: $e');
      return null;
    }
  }

  /// Listen for token refreshes (device reinstall, token rotation).
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTokenKey, newToken);
        debugPrint('[FCM] 🔄 Token refreshed and cached');
      });
    } catch (e) {
      debugPrint('[FCM] listenForTokenRefresh error: $e');
    }
  }
}
