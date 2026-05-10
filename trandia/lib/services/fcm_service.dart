import 'dart:async';
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kChannelId   = 'trandia_ch2';
const _kChannelName = 'Trandia';
const _kChannelDesc = 'Trandia notifications';
const _kTokenKey    = 'fcm_token';
const _kJwtKey      = 'auth_token';
const _kBackendUrl  = 'https://web-production-c105c.up.railway.app';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized    = false;
bool _listenerActive = false;

// ── Pending notification queue ───────────────────────────────────────────────
// Notification is queued at login/signup and fired only AFTER permission
// is confirmed in HomeScreen — eliminating the race condition where the
// notification fired before the user tapped "Allow".
String? _pendingTitle;
String? _pendingBody;

class FcmService {

  // ── Called from main() before runApp() ───────────────────────────────────
  // Initialises plugin + channel ONLY. No permission request here.
  static Future<void> init() async {
    if (kIsWeb) return;
    await _initPlugin();
  }

  // ── Plugin + channel init ─────────────────────────────────────────────────
  static Future<void> _initPlugin() async {
    if (_initialized) return;
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
            debugPrint('[FCM] tapped: ${r.payload}'),
      );
      _initialized = true;
      debugPrint('[FCM] ✅ Plugin initialized');

      await _setupChannel();
    } catch (e) {
      debugPrint('[FCM] ❌ init error: $e');
    }
  }

  // ── Channel setup ─────────────────────────────────────────────────────────
  static Future<void> _setupChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Delete stale channel so Importance.max always applies fresh
    try { await android.deleteNotificationChannel(_kChannelId); } catch (_) {}

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF00C853),
    ));
    debugPrint('[FCM] ✅ Channel ready: $_kChannelId');
  }

  // ── Queue a welcome notification ──────────────────────────────────────────
  // Called right after login/signup API succeeds.
  // Does NOT show the notification yet — HomeScreen shows it after
  // permission is confirmed, eliminating the race condition.
  static void queueWelcome({required String title, required String body}) {
    _pendingTitle = title;
    _pendingBody  = body;
    debugPrint('[FCM] Notification queued: "$title"');
  }

  // ── Show pending notification (called from HomeScreen) ────────────────────
  // Only fires if there is a queued notification.
  // Called AFTER requestPermissionAndSyncToken() so permission is guaranteed.
  static Future<void> showPending() async {
    if (_pendingTitle == null) return;
    final title = _pendingTitle!;
    final body  = _pendingBody ?? '';
    _pendingTitle = null;
    _pendingBody  = null;
    await _show(title: title, body: body);
  }

  // ── Request permission + sync token (called from HomeScreen) ─────────────
  // Activity is RESUMED here → dialog shows correctly on Android 13+.
  // Returns true if permission is granted.
  static Future<bool> requestPermissionAndSyncToken() async {
    if (kIsWeb) return false;
    try {
      final msg      = FirebaseMessaging.instance;
      final settings = await msg.requestPermission(
        alert: true, badge: true, sound: true,
      );
      await msg.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('[FCM] Permission: ${settings.authorizationStatus} | granted=$granted');
      if (!granted) return false;

      // Also request local notification permission (Android 13+)
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }

      // Get + cache + sync token
      final token = await msg.getToken();
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final old   = prefs.getString(_kTokenKey);
        await prefs.setString(_kTokenKey, token);
        if (old != token) await _syncToken(token, prefs);
        debugPrint('[FCM] Token ready: ${token.substring(0, 20)}...');
      }

      return true;
    } catch (e) {
      debugPrint('[FCM] ❌ requestPermissionAndSyncToken: $e');
      return false;
    }
  }

  // ── Foreground listener ───────────────────────────────────────────────────
  static void startForegroundListener() {
    if (_listenerActive) return;
    _listenerActive = true;
    FirebaseMessaging.onMessage.listen((msg) async {
      if (msg.data['type'] == 'welcome') return; // shown locally
      final title = msg.notification?.title ?? msg.data['title'] as String? ?? 'Trandia';
      final body  = msg.notification?.body  ?? msg.data['body']  as String? ?? '';
      await _show(title: title, body: body);
    });
    debugPrint('[FCM] ✅ Foreground listener active');
  }

  // ── Token refresh listener ────────────────────────────────────────────────
  static void listenForTokenRefresh() {
    if (kIsWeb) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await _syncToken(token, prefs);
      debugPrint('[FCM] Token refreshed');
    });
  }

  // ── Get cached FCM token (for login/signup body) ──────────────────────────
  // Uses SharedPreferences only — no network call during login.
  static Future<String?> getCachedToken() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_kTokenKey);
      debugPrint('[FCM] Cached token: ${t != null ? "${t.substring(0, 20)}..." : "null"}');
      return t;
    } catch (_) {
      return null;
    }
  }

  // ── Internal: show a notification ────────────────────────────────────────
  static Future<void> _show({required String title, required String body}) async {
    if (!_initialized) await _initPlugin();
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
      debugPrint('[FCM] ✅ Shown: "$title"');
    } catch (e) {
      debugPrint('[FCM] ❌ show failed: $e');
    }
  }

  // ── Sync token with backend ───────────────────────────────────────────────
  static Future<void> _syncToken(String token, SharedPreferences prefs) async {
    try {
      final jwt = prefs.getString(_kJwtKey);
      if (jwt == null) return;
      final r = await http.put(
        Uri.parse('$_kBackendUrl/users/me/fcm-token'),
        headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
        body: '{"fcm_token": "$token"}',
      ).timeout(const Duration(seconds: 10));
      debugPrint('[FCM] Token synced: ${r.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _syncToken error: $e');
    }
  }
}
