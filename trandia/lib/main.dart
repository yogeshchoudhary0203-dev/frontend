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
// BUG FIX: Required so notification tap handlers (_handleNotificationTap)
// can navigate from outside any widget's BuildContext — i.e. from the
// onMessageOpenedApp and getInitialMessage callbacks that fire before or
// outside the widget tree.
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

  // 3. Init local notifications + fetch FCM token
  await FcmService.initAndCache();

  // 4. Token refresh listener
  FcmService.listenForTokenRefresh();

  // 5. BUG FIX: Register onMessageOpenedApp BEFORE runApp.
  //    This fires when the user TAPS a notification while the app is in the
  //    BACKGROUND (not terminated). Previously this was never listened to,
  //    so tapping a background notification brought the app to foreground
  //    but did nothing — no navigation, no in-app action.
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

  FlutterError.onError = (d) => FlutterError.presentError(d);

  runZonedGuarded(
    () => runApp(MyApp()),
    (e, st) => debugPrint('[UNCAUGHT] $e\n$st'),
  );
}

/// Handles a notification tap regardless of whether the app was in
/// background (onMessageOpenedApp) or terminated (getInitialMessage).
/// Extend this as Trandia grows: deep-link into DMs, post, profile, etc.
void _handleNotificationTap(RemoteMessage message) {
  debugPrint('[FCM] Notification tapped: ${message.data}');
  final type = message.data['type'] as String?;
  // Currently only one notification type exists. Add routing logic here
  // as more notification types (new_message, new_like, etc.) are added.
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
    // BUG FIX: Handle notification tap from TERMINATED state.
    // getInitialMessage() returns the RemoteMessage that caused the app to
    // open from a terminated state (user tapped notification in system tray).
    // Previously this was never called — tapping such a notification simply
    // opened the app to whatever screen was active, with no action taken.
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
