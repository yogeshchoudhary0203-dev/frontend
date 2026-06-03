// lib/widgets/profile/profile_header_info.dart
// Name block, location chip, title chip, bio, creator dashboard card.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../screens/glass_common.dart';

// ── Name + handle ──────────────────────────────────────────────

class ProfileNameBlock extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final String name;
  final String username;

  const ProfileNameBlock({
    super.key,
    required this.dark,
    required this.fg,
    required this.sub,
    required this.name,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: manrope(
                    size: 24,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.verified_rounded, size: 18, color: fg),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '@$username',
            style: manrope(
              size: 13,
              weight: FontWeight.w500,
              color: sub,
              letterSpacing: -0.065,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location chip ──────────────────────────────────────────────

class ProfileLocationChip extends StatelessWidget {
  final bool dark;
  final String? city;
  final bool isPublic;
  final bool isLoading;
  final VoidCallback onTap;

  const ProfileLocationChip({
    super.key,
    required this.dark,
    required this.isPublic,
    required this.isLoading,
    required this.onTap,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    final hasCity = city?.isNotEmpty == true;
    final sub = GlassTokens.sub(dark);

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.6),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(sub),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasCity
                            ? (isPublic
                                ? Icons.location_on_rounded
                                : Icons.location_off_rounded)
                            : Icons.add_location_alt_outlined,
                        size: 13,
                        color: hasCity ? const Color(0xFFFF3B30) : sub,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasCity
                            ? (isPublic ? city! : '${city!} (hidden)')
                            : 'Add location',
                        style: manrope(
                          size: 12,
                          weight: FontWeight.w600,
                          color: hasCity
                              ? GlassTokens.fg(dark).withValues(alpha: 0.8)
                              : sub,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Title chip (creator/business/professional) ─────────────────

class ProfileTitleChip extends StatelessWidget {
  final bool dark;
  final Color muted;
  final Color fg;
  final String label;

  const ProfileTitleChip({
    super.key,
    required this.dark,
    required this.muted,
    required this.fg,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.6),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: manrope(
                  size: 12,
                  weight: FontWeight.w600,
                  color: muted,
                  letterSpacing: -0.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Creator dashboard card ─────────────────────────────────────

class ProfileCreatorDashboardCard extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final String accountType;

  const ProfileCreatorDashboardCard({
    super.key,
    required this.dark,
    required this.fg,
    required this.sub,
    required this.accountType,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      blurSigma: 24,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            child: Icon(Icons.insights_rounded, color: fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$accountType Dashboard',
                  style: manrope(
                    size: 14,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Analytics coming soon',
                  style: manrope(
                    size: 12,
                    weight: FontWeight.w500,
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: sub, size: 20),
        ],
      ),
    );
  }
}
