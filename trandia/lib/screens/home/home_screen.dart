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
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Foreground FCM message listener
    FcmService.startForegroundListener();

    // Fetch user profile
    _fetchMe();

    // Notification setup — runs after first frame so Activity is fully
    // RESUMED. This is the ONLY place permission is requested.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.setupForHomeScreen();
    });
  }

  Future<void> _fetchMe() async {
    try {
      final data = await ApiService.get('/users/me', requiresAuth: true);
      if (!mounted) return;
      setState(() { _user = data; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('Session expired')) { _pushToLogin(); return; }
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile. Check your connection.';
        _loading = false;
      });
    }
  }

  void _pushToLogin() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    _pushToLogin();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _fetchMe();
              },
              child: const Text('Retry'),
            ),
          ]),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          if (username.isNotEmpty)
            Text('@$username',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(email,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ]),
      ),
    );
  }
}
