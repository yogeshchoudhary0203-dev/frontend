import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';

void main() async {
  // Required before any Flutter engine calls on Android/iOS
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trandia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
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
    // FIX: addPostFrameCallback ensures Navigator is fully ready before we
    // attempt any navigation. Without this, Navigator.pushReplacement can
    // throw a silent exception in release mode (no red screen — app just closes).
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Request notification permission on first launch (Android 13+ / API 33+)
    await _requestNotificationPermission();

    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      _navigateTo(loggedIn ? const HomeScreen() : const LoginScreen());
    } catch (e) {
      if (!mounted) return;
      _navigateTo(const LoginScreen());
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isProvisional) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Permission request failure should never block app startup
    }
  }

  void _navigateTo(Widget screen, {String? error}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
