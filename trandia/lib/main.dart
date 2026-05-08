import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'utils/web_utils.dart';

void main() {
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
    _route();
  }

  Future<void> _route() async {
    // ── Check for Google OAuth redirect token in URL ─────────────
    // After the backend's /auth/google/web flow, it redirects back to
    // the Flutter app with ?token=...&user=... in the URL.
    final params = getUrlSearchParams();
    final oauthToken = params['token'];
    final oauthError = params['error'];

    if (oauthError != null && oauthError.isNotEmpty) {
      // Clear params from the address bar
      clearUrlSearchParams();
      if (!mounted) return;
      _navigateTo(const LoginScreen(), error: 'Google sign-in failed: $oauthError');
      return;
    }

    if (oauthToken != null && oauthToken.isNotEmpty) {
      // Save the JWT token that the backend passed back
      await ApiService.saveToken(oauthToken);
      // Clean the URL so the token doesn't stay visible in the address bar
      clearUrlSearchParams();
      if (!mounted) return;
      _navigateTo(const HomeScreen());
      return;
    }

    // ── Normal startup: check stored session ──────────────────────
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    _navigateTo(loggedIn ? const HomeScreen() : const LoginScreen());
  }

  void _navigateTo(Widget screen, {String? error}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );

    // Show error snackbar after the new screen is built
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
