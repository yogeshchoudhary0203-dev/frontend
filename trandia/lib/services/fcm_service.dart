import 'dart:async';
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Channel ID bumped to v3 — forces a fresh channel with correct settings ──
const _kChannelId   = 'trandia_ch3';
const _kChannelName = 'Trandia';
const _kChannelDesc = 'Trandia notifications';
const _kTokenKey    = 'fcm_token';
const _kJwtKey      = 'auth_token';
const _kBackendUrl  = 'https://web-production-c105c.up.railway.app';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _pluginReady  = false;
bool _listenerOn   = false;

// Queued welcome notification (set at login, shown after permission confirmed)
String? _pendingTitle;
String? _pendingBody;

class FcmService {

  // ── init() — called once from main() before runApp() ─────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;

    // 1. Init plugin
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) =>
            debugPrint('[FCM] tapped payload=${r.payload}'),
      );
      _pluginReady = true;
      debugPrint('[FCM] ✅ Plugin ready');
    } catch (e) {
      debugPrint('[FCM] ❌ Plugin init failed: $e');
      return;
    }

    // 2. Create notification channel (Android only)
    //    We do NOT delete first — deleting corrupts the channel for some
    //    devices. Instead we use a new channel ID (v3) so Android always
    //    creates it fresh with Importance.max.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: _kChannelDesc,
        importance: Importance.max,   // heads-up banner
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF00C853),
        showBadge: true,
      ));
      debugPrint('[FCM] ✅ Channel $_kChannelId created');
    }
  }

  // ── Queue a welcome notification at login / signup ────────────────────────
  // Does NOT show yet. HomeScreen will call showPendingIfAny() after
  // confirming permission — zero race condition.
  static void queueWelcome({required String title, required String body}) {
    _pendingTitle = title;
    _pendingBody  = body;
    debugPrint('[FCM] Queued: "$title"');
  }

  // ── Check permission WITHOUT showing a dialog ─────────────────────────────
  // Returns true if already granted (instant, no network, no dialog).
  static Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
             s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  // ── Request permission + sync token ──────────────────────────────────────
  // Call from HomeScreen AFTER Activity is RESUMED (addPostFrameCallback).
  // Returns true if granted.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final msg = FirebaseMessaging.instance;

      final settings = await msg.requestPermission(
        alert: true, badge: true, sound: true,
      );
      await msg.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('[FCM] requestPermission → $granted (${settings.authorizationStatus})');

      // Also request Android 13+ local notification permission
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }

      if (granted) await _fetchAndSyncToken();
      return granted;
    } catch (e) {
      debugPrint('[FCM] ❌ requestPermission error: $e');
      return false;
    }
  }

  // ── Show pending notification if any ─────────────────────────────────────
  // Call AFTER permission is confirmed.
  static Future<void> showPendingIfAny() async {
    if (_pendingTitle == null) return;
    final title = _pendingTitle!;
    final body  = _pendingBody ?? '';
    _pendingTitle = null;
    _pendingBody  = null;
    await show(title: title, body: body);
  }

  // ── Show a notification immediately ──────────────────────────────────────
  static Future<void> show({required String title, required String body}) async {
    if (!_pluginReady) {
      debugPrint('[FCM] Plugin not ready — skipping');
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    try {
      await _plugin.show(
        id, title, body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId, _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
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
      debugPrint('[FCM] ✅ Notification shown: "$title"');
    } catch (e) {
      debugPrint('[FCM] ❌ show() error: $e');
    }
  }

  // ── Foreground message listener ───────────────────────────────────────────
  static void startForegroundListener() {
    if (_listenerOn) return;
    _listenerOn = true;

    FirebaseMessaging.onMessage.listen((msg) async {
      debugPrint('[FCM] onMessage: ${msg.notification?.title} | type=${msg.data['type']}');

      // Welcome notifications are already shown locally via showPendingIfAny().
      // Do NOT show again to avoid duplicate. All other types show normally.
      if (msg.data['type'] == 'welcome') {
        debugPrint('[FCM] Welcome push ignored (already shown locally)');
        return;
      }

      final title = msg.notification?.title ?? msg.data['title'] as String? ?? 'Trandia';
      final body  = msg.notification?.body  ?? msg.data['body']  as String? ?? '';
      await show(title: title, body: body);
    });

    debugPrint('[FCM] ✅ Foreground listener ON');
  }

  // ── Token refresh listener ────────────────────────────────────────────────
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint('[FCM] Token refreshed');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await _syncTokenToBackend(token, prefs);
    });
  }

  // ── Get cached token for login/signup body ────────────────────────────────
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kTokenKey);
    } catch (_) {
      return null;
    }
  }

  // ── Internal: fetch fresh token + sync ───────────────────────────────────
  static Future<void> _fetchAndSyncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final old   = prefs.getString(_kTokenKey);
      await prefs.setString(_kTokenKey, token);
      if (old != token) await _syncTokenToBackend(token, prefs);
      debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] _fetchAndSyncToken error: $e');
    }
  }

  static Future<void> _syncTokenToBackend(
      String token, SharedPreferences prefs) async {
    try {
      final jwt = prefs.getString(_kJwtKey);
      if (jwt == null) return;
      final r = await http
          .put(
            Uri.parse('$_kBackendUrl/users/me/fcm-token'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/json',
            },
            body: '{"fcm_token": "$token"}',
          )
          .timeout(const Duration(seconds: 8));
      debugPrint('[FCM] Backend token sync: ${r.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _syncTokenToBackend error: $e');
    }
  }
}
