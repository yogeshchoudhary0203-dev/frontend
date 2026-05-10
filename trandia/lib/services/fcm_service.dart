import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kChannelId  = 'trandia_welcome';
const _kChannelName = 'Trandia Notifications';
const _kChannelDesc = 'Welcome and activity notifications from Trandia';
const _kTokenKey   = 'fcm_token';
const _kJwtKey     = 'auth_token';
const _kBackendUrl = 'https://web-production-c105c.up.railway.app';

final localNotif = FlutterLocalNotificationsPlugin();

const androidChannel = AndroidNotificationChannel(
  _kChannelId,
  _kChannelName,
  description: _kChannelDesc,
  importance: Importance.max,   // MAX so it shows as heads-up popup
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

class FcmService {

  static Future<void> initAndCache() async {
    if (kIsWeb) return;
    await _setupChannel();
    await _fetchAndCacheToken();
    // NOTE: foreground listener is now started from HomeScreen via
    // FcmService.startForegroundListener() so it runs AFTER navigation completes.
  }

  static Future<void> _setupChannel() async {
    try {
      await localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      await localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      debugPrint('[FCM] ✅ Channel ready (Importance.max): $_kChannelId');
    } catch (e) {
      debugPrint('[FCM] _setupChannel error: $e');
    }
  }

  static Future<void> _fetchAndCacheToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ❌ Permission denied');
        return;
      }

      // Do NOT call deleteToken() — it invalidates the token every launch
      // causing backend to have a dead token and notifications never arrive.
      final newToken = await messaging.getToken();
      if (newToken == null || newToken.isEmpty) {
        debugPrint('[FCM] ⚠️ Token null — check google-services.json');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_kTokenKey);

      if (cachedToken == newToken) {
        debugPrint('[FCM] ✅ Token unchanged: ${newToken.substring(0, 20)}...');
        return;
      }

      await prefs.setString(_kTokenKey, newToken);
      debugPrint('[FCM] 🆕 New token: ${newToken.substring(0, 20)}...');
      await _syncTokenWithBackend(newToken, prefs);
    } catch (e) {
      debugPrint('[FCM] _fetchAndCacheToken error: $e');
    }
  }

  /// Start listening for foreground messages.
  /// Call this from HomeScreen.initState() — AFTER navigation is complete.
  /// This way the 3-second delayed notification from backend lands here
  /// instead of during the login→home navigation transition.
  static void startForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] 📩 onMessage fired: ${message.notification?.title}');
      _showLocalNotification(message);
    });
    debugPrint('[FCM] ✅ Foreground listener active');
  }

  static void _showLocalNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null) {
      debugPrint('[FCM] ⚠️ message.notification is null — data-only message');
      return;
    }

    final title = n.title ?? 'Trandia';
    final body  = n.body  ?? '';

    debugPrint('[FCM] Showing local notification: $title');

    localNotif.show(
      // Use a fixed ID so duplicate notifications replace each other
      title.hashCode.abs() % 10000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF00C853),
          playSound: true,
          enableVibration: true,
          // Heads-up notification (shows over other apps)
          fullScreenIntent: false,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  static Future<void> _syncTokenWithBackend(
      String token, SharedPreferences prefs) async {
    try {
      final jwt = prefs.getString(_kJwtKey);
      if (jwt == null) {
        debugPrint('[FCM] Not logged in — token will be sent on next login');
        return;
      }
      final resp = await http.put(
        Uri.parse('$_kBackendUrl/users/me/fcm-token'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: '{"fcm_token": "$token"}',
      ).timeout(const Duration(seconds: 10));

      debugPrint('[FCM] Backend sync: ${resp.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _syncTokenWithBackend error: $e');
    }
  }

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
