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
  // Initialises the local-notification plugin and fetches + caches the FCM
  // token.  Does NOT request Android 13+ permission here — that must happen
  // via requestPermissionIfNeeded() once the Activity is fully resumed (i.e.
  // from HomeScreen.initState).
  static Future<void> initAndCache() async {
    if (kIsWeb) return;
    await _initLocalNotifications();
    await _fetchToken();
  }

  // ── Local notifications + Android channel setup ──────────────────────────
  static Future<void> _initLocalNotifications() async {
    if (_initialized) return;
    try {
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

      // ok can be null on some Android versions even when init succeeded.
      _initialized = ok != false;
      debugPrint('[FCM] LocalNotifications init: $ok | _initialized=$_initialized');

      // ── Channel creation AFTER initialize() ─────────────────────────────
      // resolvePlatformSpecificImplementation() returns null until initialize()
      // runs. We also delete the old channel first so Android applies the new
      // Importance.high settings — Android permanently caches channel settings
      // once a channel is created.
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
        await androidPlugin.deleteNotificationChannel(_kChannelId);
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('[FCM] ✅ Channel created: $_kChannelId');
        // NOTE: requestNotificationsPermission() is intentionally NOT called
        // here.  Before runApp() the Android Activity is not yet in its
        // RESUMED state, so the POST_NOTIFICATIONS dialog silently fails on
        // Android 13+ (API 33).  The permission is requested from
        // HomeScreen.initState() via requestPermissionIfNeeded() instead.
      }
    } catch (e, st) {
      debugPrint('[FCM] ❌ _initLocalNotifications: $e\n$st');
    }
  }

  // ── BUG FIX #2 — Android 13+ local-notification permission ──────────────
  // Call this from HomeScreen.initState() (or any widget that is definitely
  // visible on screen with a resumed Activity).  Calling it from main()
  // before runApp() caused the dialog to silently fail on Android 13+,
  // leaving local-notification permission permanently denied and preventing
  // foreground notification display.
  static Future<void> requestPermissionIfNeeded() async {
    if (kIsWeb) return;
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? granted =
            await androidPlugin.requestNotificationsPermission();
        debugPrint('[FCM] Android 13+ local notification permission: $granted');
      }
    } catch (e) {
      debugPrint('[FCM] requestPermissionIfNeeded error: $e');
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

  // ── BUG FIX #3 — Foreground listener now registered in main() ────────────
  // Previously this was only called from HomeScreen.initState().  If the
  // 3-second delayed notification from the backend arrived during the brief
  // navigation transition (before HomeScreen was fully initialised), onMessage
  // fired with no subscriber and the message was silently dropped — the
  // notification never appeared even though Railway logs showed a successful
  // FCM send.
  //
  // Now called from main() right after FcmService.initAndCache() so the
  // listener is ALWAYS active from the moment Firebase is ready.  The
  // _listenerActive guard prevents double-registration if HomeScreen also
  // calls this method.
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
      debugPrint('[FCM] getCachedToken: ${t != null ? "${t.substring(0, 20)}..." : "NULL"}');
      return t;
    } catch (e) {
      return null;
    }
  }
}
