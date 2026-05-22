import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import '../../services/auth_service.dart';

class IntroSlidesScreen extends StatefulWidget {
  const IntroSlidesScreen({Key? key}) : super(key: key);

  @override
  State<IntroSlidesScreen> createState() => _IntroSlidesScreenState();
}

class _IntroSlidesScreenState extends State<IntroSlidesScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  final List<Widget> _pages = [
    _Slide(
      title: 'Welcome to Trandia',
      description: 'Your social hub to connect and share.',
    ),
    _Slide(
      title: 'Explore Features',
      description: 'Chat, follow, and discover new content daily.',
    ),
    _Slide(
      title: 'Stay Updated',
      description: 'Receive notifications and never miss out.',
    ),
  ];

  void _next() async {
    if (_page < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // after slides decide where to go based on auth
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (c, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: _next,
                child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String title;
  final String description;
  const _Slide({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
