import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/intro_slides.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'utils/web_utils.dart';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background: ${message.notification?.title}');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[Firebase] ✅ initialized');
  } catch (e) {
    debugPrint('[Firebase] ❌ $e');
  }

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

  // Initialize local notifications and token handling
  await FcmService.init();
  FcmService.startForegroundListener();
  FcmService.listenForTokenRefresh();

  // Handle notification taps when app is terminated
  FirebaseMessaging.onMessageOpenedApp.listen(
    (msg) => debugPrint('[FCM] opened from background: ${msg.data}'),
  );

  FlutterError.onError = (d) => FlutterError.presentError(d);
  runZonedGuarded(
    () => runApp(const TrandiaApp()),
    (e, st) => debugPrint('[UNCAUGHT] $e\n$st'),
  );
}

class TrandiaApp extends StatefulWidget {
  const TrandiaApp({super.key});

  @override
  State<TrandiaApp> createState() => _TrandiaAppState();
}

class _TrandiaAppState extends State<TrandiaApp> {
  @override
  void initState() {
    super.initState();
    _checkInitialNotification();
  }

  Future<void> _checkInitialNotification() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg != null) {
      debugPrint('[FCM] app opened from terminated: ${msg.data}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trandia',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorScheme: const ColorScheme.light(surface: Color(0xFFFFFFFF)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: const ColorScheme.dark(surface: Color(0xFF111111)),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(nextScreen: IntroSlidesScreen()),
    );
  }
}

// Retained original splash routing logic (unchanged)
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
    final params = getUrlSearchParams();
    if (params.containsKey('token')) {
      await ApiService.saveToken(params['token']!);
      clearUrlSearchParams();
      if (!mounted) return;
      return;
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
