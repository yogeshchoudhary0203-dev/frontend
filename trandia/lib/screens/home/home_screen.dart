import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/fcm_service.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // BUG FIX #2 — Request Android 13+ POST_NOTIFICATIONS permission here,
    // NOT in main() before runApp().
    //
    // Before runApp() the Android Activity has not yet reached its RESUMED
    // state. On Android 13+ (API 33), the POST_NOTIFICATIONS permission dialog
    // is shown via ActivityCompat.requestPermissions(), which requires a
    // foreground Activity.  Calling it from main() caused the dialog to fail
    // silently: it returned null without ever prompting the user, so local
    // notifications were permanently denied on first install.
    //
    // HomeScreen.initState() is the first place where:
    //  (a) the user has already seen a screen (so the request is contextual),
    //  (b) the Activity is definitely in RESUMED state,
    //  (c) the local-notification plugin is fully initialised (_initialized=true).
    //
    // startForegroundListener() below is now a no-op because main() already
    // registered the onMessage listener.  We keep the call so the _listenerActive
    // guard is exercised and the log line confirms the listener is alive.
    FcmService.requestPermissionIfNeeded();
    FcmService.startForegroundListener(); // no-op if already registered in main()

    _fetchMe();
  }

  Future<void> _fetchMe() async {
    try {
      final data = await ApiService.get('/users/me', requiresAuth: true);
      if (!mounted) return;
      setState(() {
        _user = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('Session expired')) {
        _pushToLogin();
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile. Check your connection.';
        _loading = false;
      });
    }
  }

  void _pushToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    _pushToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trandia ✦'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _fetchMe();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final name     = _user?['name']     as String? ?? 'User';
    final username = _user?['username'] as String? ?? '';
    final email    = _user?['email']    as String? ?? '';
    final picture  = _user?['picture']  as String?;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (picture != null)
              CircleAvatar(
                radius: 40,
                backgroundImage: CachedNetworkImageProvider(picture),
                onBackgroundImageError: (_, __) {},
              )
            else
              CircleAvatar(
                radius: 40,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600)),
            if (username.isNotEmpty)
              Text('@$username',
                  style:
                      const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(email,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
