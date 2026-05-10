import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'utils/web_utils.dart';

/// MUST be top-level. Runs in a separate isolate when app is terminated/background.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message: ${message.notification?.title}');
  // Android auto-shows notification when app is background/terminated
  // because the message has a notification payload — no manual show needed.
}

// ── Global navigator key ──────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[Firebase] ✅ Initialized');
  } catch (e) {
    debugPrint('[Firebase] ❌ $e');
  }

  // 2. Background message handler (must be registered before runApp)
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // 3. Init local notifications channel + fetch FCM token.
  //    Note: Android 13+ POST_NOTIFICATIONS permission is intentionally NOT
  //    requested here. Before runApp() the Activity is not yet in its RESUMED
  //    state, so the permission dialog silently fails on Android 13+.  The
  //    permission is requested from HomeScreen.initState() instead via
  //    FcmService.requestPermissionIfNeeded().
  await FcmService.initAndCache();

  // 4. BUG FIX #3 — Register onMessage listener HERE in main(), not only in
  //    HomeScreen.initState().
  //
  //    Root cause of "notification sent but not received on device":
  //    The backend sends the FCM message 3 seconds after login/signup.
  //    Navigation from LoginScreen → HomeScreen can take 300–800 ms on
  //    mid-range devices.  In the gap between the API response returning and
  //    HomeScreen.initState() completing, onMessage had no subscriber.
  //    If the message arrived in that window (possible if Railway was warm and
  //    the 3s delay was shorter than the round-trip), it was silently dropped.
  //
  //    Registering here means the listener is active from the first frame.
  //    The _listenerActive guard in startForegroundListener() prevents double-
  //    registration if HomeScreen also calls the method (it becomes a no-op).
  FcmService.startForegroundListener();

  // 5. Token refresh listener
  FcmService.listenForTokenRefresh();

  // 6. Handle notification tap when app was in BACKGROUND (not terminated).
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

  FlutterError.onError = (d) => FlutterError.presentError(d);

  runZonedGuarded(
    () => runApp(MyApp()),
    (e, st) => debugPrint('[UNCAUGHT] $e\n$st'),
  );
}

/// Handles a notification tap regardless of whether the app was in
/// background (onMessageOpenedApp) or terminated (getInitialMessage).
void _handleNotificationTap(RemoteMessage message) {
  debugPrint('[FCM] Notification tapped: ${message.data}');
  final type = message.data['type'] as String?;
  switch (type) {
    case 'welcome':
    // Already on HomeScreen — nothing extra to do.
    default:
      break;
  }
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Handle notification tap from TERMINATED state.
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final RemoteMessage? initial =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] App opened from terminated via notification: ${initial.data}');
      _handleNotificationTap(initial);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Trandia',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const _SplashRouter(),
      );
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();
  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Web Google OAuth redirect
    final params = getUrlSearchParams();
    if (params.containsKey('token')) {
      await ApiService.saveToken(params['token']!);
      clearUrlSearchParams();
      if (!mounted) return;
      _go(const HomeScreen());
      return;
    }
    try {
      final ok = await AuthService.isLoggedIn();
      if (!mounted) return;
      _go(ok ? const HomeScreen() : const LoginScreen());
    } catch (_) {
      if (!mounted) return;
      _go(const LoginScreen());
    }
  }

  void _go(Widget w) => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
