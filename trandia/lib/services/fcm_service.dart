import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kChannelId   = 'trandia_ch1';
const _kChannelName = 'Trandia';
const _kChannelDesc = 'Trandia notifications';
const _kTokenKey    = 'fcm_token';
const _kJwtKey      = 'auth_token';
const _kBackendUrl  = 'https://web-production-c105c.up.railway.app';

// Single global instance — must not be recreated
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _initialized    = false;
bool _listenerActive = false;

class FcmService {

  // ── Step 1: Call from main() before runApp ───────────────────────────────
  static Future<void> initAndCache() async {
    if (kIsWeb) return;
    await _initLocalNotifications();
    await _fetchToken();
  }

  // ── Local notifications + Android channel setup ──────────────────────────
  static Future<void> _initLocalNotifications() async {
    if (_initialized) return;
    try {
      // ────────────────────────────────────────────────────────────────────
      // FIX 1: initialize() MUST come first.
      //
      // The old code called createNotificationChannel() BEFORE initialize().
      // resolvePlatformSpecificImplementation() returns null until initialize()
      // has run, so the channel was never created. Android 8+ silently drops
      // notifications for an unknown channel — this was the root cause of
      // "backend sent OK but nothing appears on device".
      // ────────────────────────────────────────────────────────────────────
      final bool? ok = await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse r) {
          debugPrint('[FCM] Notification tapped: ${r.payload}');
        },
      );

      // ────────────────────────────────────────────────────────────────────
      // FIX 2: Don't use strict (ok == true).
      //
      // On some Android versions initialize() returns null even on success.
      // (ok == true) kept _initialized = false forever, causing every
      // showNotification() call to re-init but still work — masking the bug
      // while creating unnecessary overhead. Use (ok != false) instead.
      // ────────────────────────────────────────────────────────────────────
      _initialized = ok != false;
      debugPrint('[FCM] LocalNotifications init: $ok | _initialized=$_initialized');

      // ────────────────────────────────────────────────────────────────────
      // FIX 3: Create channel AFTER initialize().
      //
      // resolvePlatformSpecificImplementation() now returns the real Android
      // plugin object. Also delete the old channel before recreating it —
      // Android permanently caches a channel's importance/sound settings once
      // created. If the previous broken code created it with wrong settings
      // (or it was created as "Miscellaneous" as a fallback), deleting it
      // forces Android to apply the correct Importance.high on next create.
      // ────────────────────────────────────────────────────────────────────
      const channel = AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: _kChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Delete stale channel (no-op if it doesn't exist yet)
        await androidPlugin.deleteNotificationChannel(_kChannelId);
        // Recreate with correct importance:high settings
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('[FCM] ✅ Channel recreated: $_kChannelId');

        // ────────────────────────────────────────────────────────────────
        // FIX 4: Request Android 13+ local notification permission.
        //
        // flutter_local_notifications v14+ manages POST_NOTIFICATIONS state
        // independently from FirebaseMessaging.requestPermission(). Without
        // this explicit call the plugin considers local notifications blocked
        // on Android 13+ even if the FCM permission was already granted.
        // ────────────────────────────────────────────────────────────────
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('[FCM] Android 13+ local notification permission: $granted');
      }
    } catch (e, st) {
      debugPrint('[FCM] ❌ _initLocalNotifications: $e\n$st');
    }
  }

  // ── FCM token fetch + cache ──────────────────────────────────────────────
  static Future<void> _fetchToken() async {
    try {
      final msg = FirebaseMessaging.instance;

      // iOS foreground display
      await msg.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final settings = await msg.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ❌ Permission denied');
        return;
      }

      final token = await msg.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] ⚠️ Token null');
        return;
      }
      debugPrint('[FCM] ✅ Token: ${token.substring(0, 20)}...');

      final prefs = await SharedPreferences.getInstance();
      final old   = prefs.getString(_kTokenKey);
      await prefs.setString(_kTokenKey, token);

      if (old != token) {
        debugPrint('[FCM] 🔄 Token changed — syncing with backend');
        await _syncToken(token, prefs);
      }
    } catch (e, st) {
      debugPrint('[FCM] ❌ _fetchToken: $e\n$st');
    }
  }

  // ── Step 2: Call from HomeScreen.initState() ─────────────────────────────
  // Registers onMessage ONCE. The 3-second delayed notification from backend
  // arrives after navigation completes — this listener catches it.
  static void startForegroundListener() {
    if (_listenerActive) {
      debugPrint('[FCM] Listener already active — skip');
      return;
    }
    _listenerActive = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      debugPrint('[FCM] 📩 onMessage received!');
      debugPrint('[FCM]    notification: ${msg.notification?.title}');
      debugPrint('[FCM]    data: ${msg.data}');

      final title = msg.notification?.title
          ?? msg.data['title'] as String?
          ?? 'Trandia';
      final body  = msg.notification?.body
          ?? msg.data['body'] as String?
          ?? '';

      await showNotification(title: title, body: body);
    });

    debugPrint('[FCM] ✅ onMessage listener registered');
  }

  // ── Show notification (public — can be called from anywhere) ────────────
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 42,
  }) async {
    // Re-init if needed (defensive)
    if (!_initialized) {
      debugPrint('[FCM] Not initialized — re-initializing...');
      await _initLocalNotifications();
    }

    debugPrint('[FCM] Showing notification: "$title"');

    try {
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
      debugPrint('[FCM] ✅ Notification displayed successfully');
    } catch (e, st) {
      debugPrint('[FCM] ❌ show() failed: $e\n$st');
    }
  }

  // ── Token refresh listener ───────────────────────────────────────────────
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint('[FCM] 🔄 Token refreshed');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await _syncToken(token, prefs);
    });
  }

  // ── Sync updated token with backend ─────────────────────────────────────
  static Future<void> _syncToken(String token, SharedPreferences prefs) async {
    try {
      final jwt = prefs.getString(_kJwtKey);
      if (jwt == null) return;
      final r = await http.put(
        Uri.parse('$_kBackendUrl/users/me/fcm-token'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: '{"fcm_token": "$token"}',
      ).timeout(const Duration(seconds: 10));
      debugPrint('[FCM] Backend sync: ${r.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _syncToken error: $e');
    }
  }

  // ── Get cached token (used during login/signup) ──────────────────────────
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_kTokenKey);
      debugPrint('[FCM] getCachedToken: ${t != null ? "${t.substring(0,20)}..." : "NULL"}');
      return t;
    } catch (e) {
      return null;
    }
  }
}
