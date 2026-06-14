import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/interest_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/intro_slides.dart';
import 'screens/app_lock_screen.dart';
import 'services/analytics_service.dart';
import 'services/api_service.dart';
import 'services/app_badge_service.dart';
import 'services/auth_service.dart';
import 'services/app_lock_service.dart';
import 'services/fcm_service.dart';
import 'services/local_db.dart';
import 'services/deep_link_service.dart';
import 'services/receive_sharing_service.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_manager.dart';
import 'utils/web_utils.dart';
import 'utils/navigator_key.dart';
import 'utils/route_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'utils/navigator_key.dart' show navigatorKey;

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] background: ${message.notification?.title}');

  // Grow the launcher-icon badge while the app is backgrounded/killed.
  // Android only: on iOS the system sets the badge from the push's aps.badge
  // field (sent by the backend), so bumping here would double-count.
  final type = message.data['type'] as String?;
  if (type == 'quiz_ready' || type == 'welcome') return; // silent / non-counting
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await AppBadgeService.bump();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Theme settings
  await ThemeManager.init();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[Firebase] ✅ initialized');
    // Product analytics (users / screens / feature usage). Fire-and-forget so
    // it never delays startup; setUser is best-effort and self-heals on login.
    unawaited(AnalyticsService.setEnabled(true));
    unawaited(AuthService.getUserId().then(AnalyticsService.setUser));
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

  // Route Flutter framework errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  runZonedGuarded(
    () {
      runApp(const ProviderScope(child: TrandiaApp()));
    },
    (e, st) {
      debugPrint('[UNCAUGHT] $e\n$st');
      FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
    },
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
    ReceiveSharingService.instance.init();
    _checkInitialNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _languageController.dispose();
    DeepLinkService.instance.dispose();
    ReceiveSharingService.instance.dispose();
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
        pageBuilder: (_, _a, _b) => AppLockVerifyScreen(dark: dark),
        transitionsBuilder: (_, animation, _a2, child) => FadeTransition(
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return AnimatedBuilder(
          animation: _languageController,
          builder: (context, _) => AppLanguageScope(
            controller: _languageController,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Trandia',
              navigatorKey: navigatorKey,
              navigatorObservers: [appRouteObserver, AnalyticsService.navigatorObserver()],
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFFFFFFF),
                colorScheme: const ColorScheme.light(surface: Color(0xFFFFFFFF)),
                // iOS-style smooth slide transitions on every screen change
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  },
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF111111),
                colorScheme: const ColorScheme.dark(surface: Color(0xFF111111)),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  },
                ),
              ),
              themeMode: currentThemeMode,
              home: const SplashScreen(nextScreen: _StartupRouter()),
            ),
          ),
        );
      },
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
              // Route through the interest gate (instant local 12h check) so the
              // every-12h interest prompt fires on normal app opens too.
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => const InterestGateScreen()),
              );
            },
          ),
        ),
      );
    } else {
      // Route through the interest gate (instant local 12h check) so the
      // every-12h interest prompt fires on normal app opens too.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const InterestGateScreen()),
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
