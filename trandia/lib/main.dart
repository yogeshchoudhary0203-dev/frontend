import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/interest_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/intro_slides.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/deep_link_service.dart';
import 'l10n/app_localizations.dart';
import 'utils/web_utils.dart';
import 'utils/navigator_key.dart';

export 'utils/navigator_key.dart' show navigatorKey;

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background: ${message.notification?.title}');
}

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
  final AppLanguageController _languageController = AppLanguageController();

  @override
  void initState() {
    super.initState();
    _languageController.load();
    DeepLinkService.instance.init();
    _checkInitialNotification();
  }

  @override
  void dispose() {
    _languageController.dispose();
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  Future<void> _checkInitialNotification() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg != null) {
      debugPrint('[FCM] app opened from terminated: ${msg.data}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, _) => AppLanguageScope(
        controller: _languageController,
        child: MaterialApp(
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
          home: const SplashScreen(nextScreen: _StartupRouter()),
        ),
      ),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const InterestGateScreen()),
      );
      return;
    }

    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            isLoggedIn ? const InterestGateScreen() : const IntroSlidesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
