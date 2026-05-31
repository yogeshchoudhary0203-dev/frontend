import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Constants ─────────────────────────────────────────────────
const _kChannelId        = 'trandia_v4';
const _kChannelName      = 'Trandia';
const _kChannelDesc      = 'Trandia notifications';
const _kTokenKey         = 'fcm_token';
const _kJwtKey           = 'auth_token';
const _kBackendUrl       = 'https://web-production-c105c.up.railway.app';
// SharedPreferences keys — same keys used by NotificationSettingsScreen
const _kMasterKey    = 'settings_notifications';
const _kFollowsKey   = 'settings_notif_follows';
const _kLikesKey     = 'settings_notif_likes';
const _kCommentsKey  = 'settings_notif_comments';
const _kMessagesKey  = 'settings_notif_messages';
const _kStoriesKey   = 'settings_notif_stories';
const _kMentionsKey  = 'settings_notif_mentions';

// ── Module-level state ────────────────────────────────────────
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

bool _pluginReady = false;
bool _listenerOn  = false;

String? _pendingTitle;
String? _pendingBody;

/// The conversation_id that the user currently has open.
/// Notifications for this conversation are suppressed (user already sees it).
String? _activeConversationId;

// In-memory notification flags — loaded from SharedPreferences via reloadNotificationSettings()
bool _masterEnabled    = true;
bool _followsEnabled   = true;
bool _likesEnabled     = true;
bool _commentsEnabled  = true;
bool _chatNotifsEnabled = true;   // messages
bool _storiesEnabled   = true;
bool _mentionsEnabled  = true;

// Module-level notifier (accessed as FcmService.chatNotifsNotifier via class below)

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

  /// Reactive notifier — chat bell and notification settings screen both
  /// listen to this so they stay in sync without manual coordination.
  static final ValueNotifier<bool> chatNotifsNotifier = ValueNotifier(true);

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

    // 3. Load all notification preferences
    await reloadNotificationSettings();

    // 4. Fetch + cache FCM token eagerly (no permission needed)
    unawaited(_fetchAndCacheToken());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // registerMessageTapHandler()
  // ─────────────────────────────────────────────────────────────────────────
  static void registerMessageTapHandler(ConversationNavigator handler) {
    _onMessageTapped = handler;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // setActiveConversation()
  // ─────────────────────────────────────────────────────────────────────────
  static void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    debugPrint('[FCM] active conversation: $conversationId');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reload all notification flags from SharedPreferences (single source of truth)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> reloadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _masterEnabled     = prefs.getBool(_kMasterKey)   ?? true;
      _followsEnabled    = prefs.getBool(_kFollowsKey)  ?? true;
      _likesEnabled      = prefs.getBool(_kLikesKey)    ?? true;
      _commentsEnabled   = prefs.getBool(_kCommentsKey) ?? true;
      _chatNotifsEnabled = prefs.getBool(_kMessagesKey) ?? true;
      _storiesEnabled    = prefs.getBool(_kStoriesKey)  ?? true;
      _mentionsEnabled   = prefs.getBool(_kMentionsKey) ?? true;
      // Notify all listeners (bell icon, settings screen)
      chatNotifsNotifier.value = _masterEnabled && _chatNotifsEnabled;
      debugPrint('[FCM] prefs reloaded — master=$_masterEnabled '
          'msgs=$_chatNotifsEnabled follows=$_followsEnabled');
    } catch (e) {
      debugPrint('[FCM] reloadNotificationSettings error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chat bell toggle — saves to the same key as NotificationSettingsScreen
  // ─────────────────────────────────────────────────────────────────────────
  static bool get chatNotificationsEnabled => _chatNotifsEnabled;

  static Future<void> setChatNotificationsEnabled(bool enabled) async {
    _chatNotifsEnabled = enabled;
    chatNotifsNotifier.value = _masterEnabled && enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMessagesKey, enabled);
      debugPrint('[FCM] messages pref set to $enabled');
    } catch (e) {
      debugPrint('[FCM] setChatNotificationsEnabled error: $e');
    }
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

    // Always refresh in-memory flags from prefs on home screen open
    await reloadNotificationSettings();

    // ── FIX: ALWAYS sync token to DB on every home screen open ──
    // Previously only synced if token changed — this caused FCM to break
    // whenever DB was cleared or token wasn't in DB yet.
    unawaited(_syncLatestToken());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // forceSyncToken()  — call explicitly after login/signup to ensure
  // the fresh JWT reaches the backend with the FCM token.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> forceSyncToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await _doSyncToken(token, prefs);
      debugPrint('[FCM] ✅ forceSyncToken done');
    } catch (e) {
      debugPrint('[FCM] forceSyncToken error: $e');
    }
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
          iOS: _kIosDetails,
        ),
        payload: conversationId,
      );
      debugPrint('[FCM] ✅ show(): "$title"  conv=$conversationId');
    } catch (e, st) {
      debugPrint('[FCM] ❌ show() error: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // startForegroundListener()
  // ─────────────────────────────────────────────────────────────────────────
  static void startForegroundListener() {
    if (_listenerOn) return;
    _listenerOn = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final msgType = msg.data['type'] as String?;
      debugPrint('[FCM] onMessage type=$msgType title="${msg.notification?.title}"');

      if (msgType == 'welcome') return; // shown locally — no duplicate

      // Master switch — all notifications off
      if (!_masterEnabled) {
        debugPrint('[FCM] suppressed — master notifications off');
        return;
      }

      // Follow
      if (msgType == 'follow') {
        if (!_followsEnabled) return;
        final title = msg.data['title'] as String? ?? msg.notification?.title ?? 'New follower';
        final body  = msg.data['body']  as String? ?? msg.notification?.body  ?? 'started following you';
        await show(title: title, body: body);
        return;
      }

      // Like
      if (msgType == 'like') {
        if (!_likesEnabled) return;
        final title = msg.data['title'] as String? ?? msg.notification?.title ?? 'Trandia';
        final body  = msg.data['body']  as String? ?? msg.notification?.body  ?? 'liked your post ❤️';
        await show(title: title, body: body);
        return;
      }

      // Comment
      if (msgType == 'comment') {
        if (!_commentsEnabled) return;
        final title = msg.data['title'] as String? ?? msg.notification?.title ?? 'New comment';
        final body  = msg.data['body']  as String? ?? msg.notification?.body  ?? '';
        await show(title: title, body: body);
        return;
      }

      // Story
      if (msgType == 'story') {
        if (!_storiesEnabled) return;
        final title = msg.data['title'] as String? ?? msg.notification?.title ?? 'Story';
        final body  = msg.data['body']  as String? ?? msg.notification?.body  ?? '';
        await show(title: title, body: body);
        return;
      }

      // Mention
      if (msgType == 'mention') {
        if (!_mentionsEnabled) return;
        final title = msg.data['title'] as String? ?? msg.notification?.title ?? 'Mention';
        final body  = msg.data['body']  as String? ?? msg.notification?.body  ?? '';
        await show(title: title, body: body);
        return;
      }

      // Message (chat) — default type when conversation_id is present
      final conversationId = msg.data['conversation_id'] as String?;
      final title = msg.notification?.title ?? (msg.data['title'] as String?) ?? 'Trandia';
      final body  = msg.notification?.body  ?? (msg.data['body']  as String?) ?? '';

      if (!_chatNotifsEnabled) {
        debugPrint('[FCM] suppressed — message notifications off');
        return;
      }
      if (conversationId != null && conversationId == _activeConversationId) {
        debugPrint('[FCM] suppressed — user is viewing this conversation');
        return;
      }

      await show(title: title, body: body, conversationId: conversationId);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      final conversationId = msg.data['conversation_id'] as String?;
      debugPrint('[FCM] onMessageOpenedApp conv=$conversationId');
      if (conversationId != null) _onMessageTapped?.call(conversationId);
    });

    debugPrint('[FCM] ✅ foreground listener active');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // listenForTokenRefresh()
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
  // getCachedToken()
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

  // ── FIX: Removed "only sync if changed" logic. ──────────────────────────
  // Old behavior: `if (old != token) await _doSyncToken(token, prefs)` 
  //   → Token in DB could go missing (DB reset, new deployment) and
  //     never get re-synced because prefs cache matched Firebase token.
  // New behavior: Always sync to DB on every setupForHomeScreen() call.
  //   → One extra PUT request per session open — completely acceptable.
  static Future<void> _syncLatestToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      // ✅ Always sync — no "if old != token" check
      await _doSyncToken(token, prefs);
    } catch (e) {
      debugPrint('[FCM] _syncLatestToken error: $e');
    }
  }

  static Future<void> _doSyncToken(String token, SharedPreferences prefs) async {
    try {
      final jwt = prefs.getString(_kJwtKey);
      if (jwt == null) {
        debugPrint('[FCM] _doSyncToken: no JWT — skipping');
        return;
      }
      final r = await http.put(
        Uri.parse('$_kBackendUrl/users/me/fcm-token'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      ).timeout(const Duration(seconds: 8));
      debugPrint('[FCM] ✅ token synced to backend: ${r.statusCode}');
    } catch (e) {
      debugPrint('[FCM] _doSyncToken error: $e');
    }
  }
}
