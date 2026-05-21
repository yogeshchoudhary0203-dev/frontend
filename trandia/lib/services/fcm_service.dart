import 'dart:async';
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Constants ─────────────────────────────────────────────────
const _kChannelId   = 'trandia_v4';
const _kChannelName = 'Trandia';
const _kChannelDesc = 'Trandia notifications';
const _kTokenKey    = 'fcm_token';
const _kJwtKey      = 'auth_token';
const _kBackendUrl  = 'https://web-production-c105c.up.railway.app';

// ── Module-level state ────────────────────────────────────────
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

bool _pluginReady = false;
bool _listenerOn  = false;

String? _pendingTitle;
String? _pendingBody;

/// Callback fired when a user taps a message notification.
typedef ConversationNavigator = void Function(String conversationId);
ConversationNavigator? _onMessageTapped;

// ── iOS notification details (reused) ─────────────────────────
const _kIosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  interruptionLevel: InterruptionLevel.active,
);

class FcmService {

  // ─────────────────────────────────────────────────────────────────────────
  // init()  — call from main() before runApp
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;

    // 1. Initialise flutter_local_notifications plugin
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
        onDidReceiveNotificationResponse: (NotificationResponse r) {
          final payload = r.payload;
          debugPrint('[FCM] notification tapped: $payload');
          if (payload != null && payload.isNotEmpty) {
            _onMessageTapped?.call(payload);
          }
        },
      );
      _pluginReady = true;
      debugPrint('[FCM] ✅ plugin ready');
    } catch (e, st) {
      debugPrint('[FCM] ❌ plugin init error: $e\n$st');
    }

    // 2. Create Android channel with Importance.max (heads-up banners)
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

    // 3. Fetch + cache FCM token eagerly (no permission needed)
    unawaited(_fetchAndCacheToken());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // registerMessageTapHandler()
  // Register a navigator callback so tapping a notification opens the chat.
  // Call from HomeScreen / ChatListScreen.
  // ─────────────────────────────────────────────────────────────────────────
  static void registerMessageTapHandler(ConversationNavigator handler) {
    _onMessageTapped = handler;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // queueWelcome()  — call after login / signup
  // ─────────────────────────────────────────────────────────────────────────
  static void queueWelcome({required String title, required String body}) {
    _pendingTitle = title;
    _pendingBody  = body;
    debugPrint('[FCM] queued welcome: "$title"');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // setupForHomeScreen()  — call from HomeScreen.initState
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> setupForHomeScreen() async {
    if (kIsWeb) return;
    debugPrint('[FCM] setupForHomeScreen()');

    final granted = await _doRequestPermission();
    debugPrint('[FCM] permission granted: $granted');

    if (granted) await showPendingIfAny();

    unawaited(_syncLatestToken());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // showPendingIfAny()
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> showPendingIfAny() async {
    if (_pendingTitle == null) return;
    final title = _pendingTitle!;
    final body  = _pendingBody ?? '';
    _pendingTitle = null;
    _pendingBody  = null;
    await show(title: title, body: body);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // show()  — display a local notification immediately.
  // [conversationId] optional — tapping navigates to that conversation.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> show({
    required String title,
    required String body,
    String? conversationId,
  }) async {
    if (!_pluginReady) {
      await init();
      if (!_pluginReady) {
        debugPrint('[FCM] ❌ plugin not ready — cannot show notification');
        return;
      }
    }

    final int id = DateTime.now().millisecondsSinceEpoch % 100000;

    // Build Android details — non-const when groupKey is dynamic
    final androidDetails = AndroidNotificationDetails(
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
      groupKey: conversationId != null ? 'conv_$conversationId' : null,
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: _kIosDetails,        // ← named parameter 'iOS:' required
        ),
        payload: conversationId,    // ← tapped → onDidReceiveNotificationResponse
      );
      debugPrint('[FCM] ✅ show(): "$title"  conv=$conversationId');
    } catch (e, st) {
      debugPrint('[FCM] ❌ show() error: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // startForegroundListener()
  // Call from main() after Firebase.initializeApp.
  // Handles FCM pushes when app is in foreground.
  // Welcome pushes are suppressed (shown locally via queueWelcome).
  // ─────────────────────────────────────────────────────────────────────────
  static void startForegroundListener() {
    if (_listenerOn) return;
    _listenerOn = true;

    // Foreground FCM message received
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final msgType = msg.data['type'] as String?;
      debugPrint('[FCM] onMessage type=$msgType title="${msg.notification?.title}"');

      if (msgType == 'welcome') return; // shown locally — suppress duplicate

      // Follow notification — show with people icon
      if (msgType == 'follow') {
        final title = msg.data['title'] as String? ?? msg.notification?.title ?? 'New follower';
        final body  = msg.data['body']  as String? ?? msg.notification?.body  ?? 'started following you';
        await show(title: title, body: body);
        return;
      }

      final title = msg.notification?.title
          ?? (msg.data['title'] as String?)
          ?? 'Trandia';
      final body = msg.notification?.body
          ?? (msg.data['body'] as String?)
          ?? '';
      final conversationId = msg.data['conversation_id'] as String?;

      await show(title: title, body: body, conversationId: conversationId);
    });

    // App opened by tapping background notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      final conversationId = msg.data['conversation_id'] as String?;
      debugPrint('[FCM] onMessageOpenedApp conv=$conversationId');
      if (conversationId != null) _onMessageTapped?.call(conversationId);
    });

    debugPrint('[FCM] ✅ foreground listener active');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // listenForTokenRefresh()  — call from main()
  // ─────────────────────────────────────────────────────────────────────────
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
      debugPrint('[FCM] token refreshed');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await _doSyncToken(token, prefs);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getCachedToken()  — returns FCM token from SharedPreferences
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_kTokenKey);
      debugPrint('[FCM] getCachedToken: ${t != null ? "${t.substring(0, 20)}…" : "null"}');
      return t;
    } catch (e) {
      debugPrint('[FCM] getCachedToken error: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PRIVATE
  // ═════════════════════════════════════════════════════════════════════════

  static Future<bool> _doRequestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      // Android 13+ — also request local notifications permission
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final result = await androidImpl.requestNotificationsPermission();
        if (result == true) granted = true;
      }

      return granted;
    } catch (e) {
      debugPrint('[FCM] _doRequestPermission error: $e');
      return false;
    }
  }

  static Future<void> _fetchAndCacheToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      debugPrint('[FCM] ✅ token cached: ${token.substring(0, 20)}…');
    } catch (e) {
      debugPrint('[FCM] _fetchAndCacheToken error: $e');
    }
  }

  static Future<void> _syncLatestToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final old   = prefs.getString(_kTokenKey);
      await prefs.setString(_kTokenKey, token);
      if (old != token) await _doSyncToken(token, prefs);
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
          'Content-Type':  'application/json',
        },
        body: '{"fcm_token": "$token"}',
      ).timeout(const Duration(seconds: 8));
      debugPrint('[FCM] token synced to backend: ${r.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _doSyncToken error: $e');
    }
  }
}
