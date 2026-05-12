import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Status bar icons color matches theme
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
    );

    final islandBg = isDark ? const Color(0xFFF0F0EC) : const Color(0xFF1A1A1A);
    final islandText = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // Blank full screen
          const SizedBox.expand(),

          // Trandia Island
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TrandiaIsland(
                  background: islandBg,
                  textColor: islandText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrandiaIsland extends StatelessWidget {
  final Color background;
  final Color textColor;

  const _TrandiaIsland({
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 37,
      width: 124, // Approximate width of iPhone Dynamic Island
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22), // Authentic Dynamic Island radius
      ),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            decoration: TextDecoration.none,
          ),
          child: const Text('Trandia'),
        ),
      ),
    );
  }
}
