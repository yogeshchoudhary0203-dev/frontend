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

  FlutterError.onError = (d) => FlutterError.presentError(d);

  runZonedGuarded(
    () => runApp(const MyApp()),
    (e, st) => debugPrint('[UNCAUGHT] $e\n$st'),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Trandia',
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
