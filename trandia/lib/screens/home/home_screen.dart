import 'dart:ui' as ui;
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
          // 1. Background Gradient (Base for Glass)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: isDark
                      ? [const Color(0xFF1C1C1F), const Color(0xFF050506)]
                      : [const Color(0xFFF8F8FA), const Color(0xFFE2E2E8)],
                ),
              ),
            ),
          ),

          // 2. Decorative Background Orbs (to make glass visible)
          _Orb(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            size: 300,
            top: 100,
            left: -50,
          ),
          _Orb(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            size: 250,
            bottom: 150,
            right: -30,
          ),

          // 3. Frosted Glass Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withOpacity(0.1) 
                      : Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ),

          // 4. Content
          SafeArea(
            child: Stack(
              children: [
                // Trandia Island (Centered)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _TrandiaIsland(
                      background: islandBg,
                      textColor: islandText,
                    ),
                  ),
                ),

                // Chat Icon (Top Right)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: IconButton(
                      onPressed: () {
                        // TODO: Open Chat
                      },
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;

  const _Orb({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
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
      width: 124,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
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
