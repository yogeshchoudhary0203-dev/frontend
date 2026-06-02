import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/interest_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/intro_slides.dart';
import 'screens/app_lock_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/app_lock_service.dart';
import 'services/fcm_service.dart';
import 'services/local_db.dart';
import 'services/deep_link_service.dart';
import 'l10n/app_localizations.dart';
import 'utils/web_utils.dart';
import 'utils/navigator_key.dart';
import 'utils/route_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Pre-warm local SQLite database (opens file, creates tables if first run)
  unawaited(LocalDb.instance.db);

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
    () => runApp(const ProviderScope(child: TrandiaApp())),
    (e, st) => debugPrint('[UNCAUGHT] $e\n$st'),
  );
}

class TrandiaApp extends StatefulWidget {
  const TrandiaApp({super.key});

  @override
  State<TrandiaApp> createState() => _TrandiaAppState();
}

class _TrandiaAppState extends State<TrandiaApp> with WidgetsBindingObserver {
  final AppLanguageController _languageController = AppLanguageController();
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _languageController.load();
    DeepLinkService.instance.init();
    _checkInitialNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _languageController.dispose();
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _maybeShowLock();
    }
  }

  Future<void> _maybeShowLock() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) return;
    final enabled = await AppLockService.isEnabled();
    if (!enabled) return;
    if (AppLockService.lockShown) return;
    AppLockService.lockShown = true;
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final dark = brightness == Brightness.dark;
    navigatorKey.currentState?.push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => AppLockVerifyScreen(dark: dark),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
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
          navigatorObservers: [appRouteObserver],
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

    if (!isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IntroSlidesScreen()),
      );
      return;
    }

    final lockEnabled = await AppLockService.isEnabled();
    if (!mounted) return;

    if (lockEnabled) {
      AppLockService.lockShown = true;
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final dark = brightness == Brightness.dark;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppLockVerifyScreen(
            dark: dark,
            onVerified: () {
              AppLockService.lockShown = false;
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
