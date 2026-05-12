import 'dart:async';
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Channel v4 — fresh channel, Importance.max guaranteed
const _kChannelId   = 'trandia_v4';
const _kChannelName = 'Trandia';
const _kChannelDesc = 'Trandia notifications';
const _kTokenKey    = 'fcm_token';
const _kJwtKey      = 'auth_token';
const _kBackendUrl  = 'https://web-production-c105c.up.railway.app';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _pluginReady = false;
bool _listenerOn  = false;

// Pending welcome notification — set at login, shown after permission granted
String? _pendingTitle;
String? _pendingBody;

class FcmService {

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — init()  (called from main() before runApp)
  //
  // Does NOT request permission. Only:
  //   a) initializes flutter_local_notifications plugin
  //   b) creates Android notification channel with Importance.max
  //   c) fetches + caches FCM token eagerly — no permission needed for
  //      getToken(). This ensures login/signup always sends a valid token
  //      to the backend, even on first ever install.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;

    // a) Plugin init
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) =>
            debugPrint('[FCM] notification tapped: ${r.payload}'),
      );
      _pluginReady = true;
      debugPrint('[FCM] ✅ plugin ready');
    } catch (e, st) {
      debugPrint('[FCM] ❌ plugin init error: $e\n$st');
    }

    // b) Android channel
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            description: _kChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color(0xFF00C853),
            showBadge: true,
          ),
        );
        debugPrint('[FCM] ✅ channel ready: $_kChannelId');
      } catch (e) {
        debugPrint('[FCM] ❌ channel create error: $e');
      }
    }

    // c) Fetch token eagerly — fire and forget (does not block app start)
    unawaited(_fetchAndCacheToken());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — queueWelcome()  (called from AuthService after login/signup)
  //
  // Stores notification data. Does NOT show yet.
  // HomeScreen shows it after permission is confirmed.
  // ─────────────────────────────────────────────────────────────────────────
  static void queueWelcome({required String title, required String body}) {
    _pendingTitle = title;
    _pendingBody  = body;
    debugPrint('[FCM] queued: "$title"');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — setupForHomeScreen()  (called from HomeScreen.initState)
  //
  // Single clean path — no branching on whether permission was already
  // granted or not. requestPermission() is instant (~1ms) if already
  // granted, and shows dialog only on first-ever launch.
  //
  //   1. requestPermission()   — ask (or confirm) OS permission
  //   2. showPendingIfAny()    — show queued notification (AFTER permission)
  //   3. _syncLatestToken()    — keep backend token fresh (background)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> setupForHomeScreen() async {
    if (kIsWeb) return;
    debugPrint('[FCM] setupForHomeScreen()');

    final granted = await _doRequestPermission();
    debugPrint('[FCM] permission: $granted');

    if (granted) {
      await showPendingIfAny();
    } else {
      debugPrint('[FCM] permission denied — notification skipped');
    }

    // Token sync runs in background — does not delay notification
    unawaited(_syncLatestToken());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // showPendingIfAny()
  // Shows queued notification if one exists, then clears the queue.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> showPendingIfAny() async {
    if (_pendingTitle == null) {
      debugPrint('[FCM] showPendingIfAny: nothing queued');
      return;
    }
    final title = _pendingTitle!;
    final body  = _pendingBody ?? '';
    _pendingTitle = null;
    _pendingBody  = null;
    debugPrint('[FCM] showPendingIfAny: showing "$title"');
    await show(title: title, body: body);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // show()
  // Shows a local notification immediately.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> show({required String title, required String body}) async {
    if (!_pluginReady) {
      debugPrint('[FCM] ⚠️ plugin not ready on show() — retrying init');
      await init();
      if (!_pluginReady) {
        debugPrint('[FCM] ❌ plugin still not ready — cannot show notification');
        return;
      }
    }

    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    debugPrint('[FCM] show() id=$id  title="$title"');

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/launcher_icon',
            playSound: true,
            enableVibration: true,
            autoCancel: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.message,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
      debugPrint('[FCM] ✅ show() done: "$title"');
    } catch (e, st) {
      debugPrint('[FCM] ❌ show() exception: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // startForegroundListener()  (called from main + HomeScreen)
  // Handles incoming FCM messages when app is in foreground.
  // Welcome messages are ignored — they are shown locally by showPendingIfAny.
  // ─────────────────────────────────────────────────────────────────────────
  static void startForegroundListener() {
    if (_listenerOn) return;
    _listenerOn = true;

    FirebaseMessaging.onMessage.listen((msg) async {
      debugPrint('[FCM] onMessage: "${msg.notification?.title}" type=${msg.data["type"]}');
      if (msg.data['type'] == 'welcome') {
        debugPrint('[FCM] welcome push ignored (shown locally)');
        return;
      }
      final title = msg.notification?.title ?? msg.data['title'] as String? ?? 'Trandia';
      final body  = msg.notification?.body  ?? msg.data['body']  as String? ?? '';
      await show(title: title, body: body);
    });

    debugPrint('[FCM] ✅ foreground listener active');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // listenForTokenRefresh()  (called from main)
  // ─────────────────────────────────────────────────────────────────────────
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint('[FCM] token refreshed by Firebase');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await _doSyncToken(token, prefs);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getCachedToken()
  // Returns the FCM token cached by init() or a previous session.
  // Always returns a real token after init() has run (guaranteed by eager
  // fetch in init). Used by AuthService during login/signup.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_kTokenKey);
      debugPrint('[FCM] getCachedToken: ${t != null ? "${t.substring(0, 20)}..." : "null — token not yet cached"}');
      return t;
    } catch (e) {
      debugPrint('[FCM] getCachedToken error: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PRIVATE
  // ═════════════════════════════════════════════════════════════════════════

  /// Request notification permission from OS.
  /// Returns true if granted. Fast (< 1ms) if already granted.
  static Future<bool> _doRequestPermission() async {
    try {
      final s = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      bool granted =
          s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;

      // Android 13+: also request local notifications permission
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final result = await android.requestNotificationsPermission();
        if (result == true) {
          granted = true;
        }
      }

      return granted;
    } catch (e) {
      debugPrint('[FCM] _doRequestPermission error: $e');
      return false;
    }
  }

  /// Fetch FCM token from Firebase and cache to SharedPreferences.
  /// Called from init() — no permission needed.
  static Future<void> _fetchAndCacheToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken() returned null');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      debugPrint('[FCM] ✅ token cached on init: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] _fetchAndCacheToken error: $e');
    }
  }

  /// Get latest token from Firebase and sync to backend if it changed.
  static Future<void> _syncLatestToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final old   = prefs.getString(_kTokenKey);
      await prefs.setString(_kTokenKey, token);
      if (old != token) {
        debugPrint('[FCM] token changed — syncing to backend');
        await _doSyncToken(token, prefs);
      }
    } catch (e) {
      debugPrint('[FCM] _syncLatestToken error: $e');
    }
  }

  static Future<void> _doSyncToken(String token, SharedPreferences prefs) async {
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
      ).timeout(const Duration(seconds: 8));
      debugPrint('[FCM] backend sync: ${r.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _doSyncToken error: $e');
    }
  }
}
