import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kChannelId    = 'trandia_welcome';
const _kChannelName  = 'Trandia Notifications';
const _kChannelDesc  = 'Welcome and activity notifications from Trandia';
const _kTokenKey     = 'fcm_token';
const _kJwtKey       = 'auth_token';
const _kBackendUrl   = 'https://web-production-c105c.up.railway.app';

final _localNotif = FlutterLocalNotificationsPlugin();

const _androidChannel = AndroidNotificationChannel(
  _kChannelId,
  _kChannelName,
  description: _kChannelDesc,
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

class FcmService {
  /// Call ONCE in main() before runApp().
  static Future<void> initAndCache() async {
    if (kIsWeb) return;
    await _setupChannel();
    await _fetchAndCacheToken();
    _listenForeground();
  }

  // ── Android notification channel + local notif init ──────────────────────
  static Future<void> _setupChannel() async {
    try {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      await _localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      debugPrint('[FCM] ✅ Channel ready: $_kChannelId');
    } catch (e) {
      debugPrint('[FCM] _setupChannel error: $e');
    }
  }

  // ── Fetch token + sync with backend if changed ────────────────────────────
  static Future<void> _fetchAndCacheToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS: show notifications even when app is in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission denied');
        return;
      }

      // KEY FIX: Do NOT call deleteToken() on app startup.
      // deleteToken() was called every launch → invalidated current token →
      // backend had dead token → notifications "sent" but never received.
      // Just call getToken() — FCM returns same valid token if unchanged.
      final newToken = await messaging.getToken();
      if (newToken == null || newToken.isEmpty) {
        debugPrint('[FCM] ⚠️ Token null — check google-services.json');
        return;
      }

      final prefs       = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_kTokenKey);

      if (cachedToken == newToken) {
        // Token unchanged — no action needed
        debugPrint('[FCM] ✅ Token valid (unchanged): ${newToken.substring(0, 20)}...');
        return;
      }

      // Token changed (fresh install / FCM rotation) — save + tell backend
      await prefs.setString(_kTokenKey, newToken);
      debugPrint('[FCM] 🔄 New token cached: ${newToken.substring(0, 20)}...');
      await _syncTokenWithBackend(newToken, prefs);
    } catch (e) {
      debugPrint('[FCM] _fetchAndCacheToken error: $e');
    }
  }

  /// If user is already logged in, push the updated FCM token to backend.
  /// This keeps notifications working without requiring a re-login.
  static Future<void> _syncTokenWithBackend(
      String token, SharedPreferences prefs) async {
    try {
      final jwt = prefs.getString(_kJwtKey);
      if (jwt == null) {
        debugPrint('[FCM] Not logged in — token will be sent on next login');
        return;
      }

      final resp = await http
          .put(
            Uri.parse('$_kBackendUrl/users/me/fcm-token'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/json',
            },
            body: '{"fcm_token": "$token"}',
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        debugPrint('[FCM] ✅ Token synced with backend');
      } else {
        debugPrint('[FCM] Backend sync failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] _syncTokenWithBackend error (non-fatal): $e');
    }
  }

  // ── Foreground notification display ──────────────────────────────────────
  // FCM suppresses the system tray when app is open — show manually.
  static void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      debugPrint('[FCM] 📩 Foreground: ${n.title}');

      _localNotif.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId, _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF00C853),
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });
  }

  // ── Token refresh listener ────────────────────────────────────────────────
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTokenKey, newToken);
        debugPrint('[FCM] 🔄 Token refreshed');
        await _syncTokenWithBackend(newToken, prefs);
      });
    } catch (e) {
      debugPrint('[FCM] listenForTokenRefresh error: $e');
    }
  }

  // ── Public helpers ────────────────────────────────────────────────────────
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kTokenKey);
      debugPrint('[FCM] getCachedToken → '
          '${token != null ? "${token.substring(0, 20)}..." : "NULL ⚠️"}');
      return token;
    } catch (e) {
      debugPrint('[FCM] getCachedToken error: $e');
      return null;
    }
  }
}
