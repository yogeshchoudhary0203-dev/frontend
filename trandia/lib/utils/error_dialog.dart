// lib/utils/error_dialog.dart
//
// Premium glassmorphic error & confirm dialogs.
// Compact, no yellow lines, glass blur effect, content-hugging layout.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class GlassErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final List<Widget>? actions;

  const GlassErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fg = isDark ? const Color(0xFFF5F4FF) : const Color(0xFF0E1124);
    final muted = isDark ? const Color(0x99F5F4FF) : const Color(0x8C141628);

    final cardFill = isDark
        ? const [Color(0x30FFFFFF), Color(0x10FFFFFF)]
        : const [Color(0xE8FFFFFF), Color(0xB0FFFFFF)];
    final cardBorder = isDark ? const Color(0x2EFFFFFF) : const Color(0xD9FFFFFF);
    final cardShadow = [
      BoxShadow(
        color: isDark ? const Color(0xCC000000) : const Color(0x33282050),
        blurRadius: 40,
        offset: const Offset(0, 16),
        spreadRadius: -10,
      )
    ];

    final btnFill = isDark
        ? const [Color(0xFFF2F2F7), Color(0xFFE6E6F5)]
        : const [Color(0xFF5A5A60), Color(0xFF3D3D42)];
    final btnFg = isDark ? const Color(0xFF0B0A18) : const Color(0xFFFFFFFF);
    final btnBorder = isDark ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF);

    final finalTitle = title.isEmpty ? 'Error'.tr(context) : title;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: cardFill,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error icon — compact
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0x1AEF4444)
                                : const Color(0x14EF4444),
                            border: Border.all(
                              color: const Color(0x40EF4444),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        finalTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: fg,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Message
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: muted,
                          height: 1.4,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Actions
                      if (actions != null && actions!.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children:
                              actions!.map((a) => Expanded(child: a)).toList(),
                        )
                      else
                        // Default glass pill button
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: btnBorder, width: 1),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: btnFill,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'OK'.tr(context),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: btnFg,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the premium glassmorphic error popup with blurred backdrop.
Future<T?> showErrorDialog<T>(
  BuildContext context, {
  String? title,
  required String message,
  List<Widget>? actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GlassErrorDialog(
        title: title ?? '',
        message: message,
        actions: actions,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = Curves.easeOutCubic.transform(animation.value);
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 6 * animation.value,
          sigmaY: 6 * animation.value,
        ),
        child: Transform.scale(
          scale: 0.88 + (curved * 0.12),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Glass-styled confirmation dialog (for delete, destructive actions).
/// Returns `true` if confirmed, `false` / null otherwise.
Future<bool?> showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _GlassConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = Curves.easeOutCubic.transform(animation.value);
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 6 * animation.value,
          sigmaY: 6 * animation.value,
        ),
        child: Transform.scale(
          scale: 0.88 + (curved * 0.12),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    },
  );
}

class _GlassConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;

  const _GlassConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fg = isDark ? const Color(0xFFF5F4FF) : const Color(0xFF0E1124);
    final muted = isDark ? const Color(0x99F5F4FF) : const Color(0x8C141628);

    final cardFill = isDark
        ? const [Color(0x30FFFFFF), Color(0x10FFFFFF)]
        : const [Color(0xE8FFFFFF), Color(0xB0FFFFFF)];
    final cardBorder = isDark ? const Color(0x2EFFFFFF) : const Color(0xD9FFFFFF);
    final cardShadow = [
      BoxShadow(
        color: isDark ? const Color(0xCC000000) : const Color(0x33282050),
        blurRadius: 40,
        offset: const Offset(0, 16),
        spreadRadius: -10,
      )
    ];

    final cancelBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final cancelBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.08);

    final confirmBg = destructive
        ? const [Color(0xFFDC2626), Color(0xFFB91C1C)]
        : isDark
            ? const [Color(0xFFF2F2F7), Color(0xFFE6E6F5)]
            : const [Color(0xFF5A5A60), Color(0xFF3D3D42)];
    final confirmFg = destructive
        ? Colors.white
        : isDark
            ? const Color(0xFF0B0A18)
            : const Color(0xFFFFFFFF);

    final iconColor = destructive ? const Color(0xFFEF4444) : fg;
    final iconBg = destructive
        ? (isDark ? const Color(0x1AEF4444) : const Color(0x14EF4444))
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05));
    final iconBorder = destructive
        ? const Color(0x40EF4444)
        : (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08));

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder, width: 1.2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: cardFill,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconBg,
                            border: Border.all(color: iconBorder, width: 1.2),
                          ),
                          child: Icon(
                            destructive
                                ? Icons.delete_outline_rounded
                                : Icons.help_outline_rounded,
                            color: iconColor,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: fg,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Message
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: muted,
                          height: 1.4,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Buttons row
                      Row(
                        children: [
                          // Cancel
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, false),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: cancelBg,
                                  border: Border.all(
                                      color: cancelBorder, width: 1),
                                ),
                                child: Center(
                                  child: Text(
                                    cancelLabel ?? 'Cancel'.tr(context),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: fg,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Confirm
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, true),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: destructive
                                        ? Colors.transparent
                                        : (isDark
                                            ? const Color(0x66FFFFFF)
                                            : const Color(0x33FFFFFF)),
                                    width: 1,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: confirmBg,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    confirmLabel ?? 'Confirm'.tr(context),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: confirmFg,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
