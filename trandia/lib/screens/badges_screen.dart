// badges_screen.dart
// Achievements & Badges screen — matches the app's glassmorphism monochrome design.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeItem {
  final String name;
  final String requirement;
  final String emoji;
  final bool earned;
  final bool isSecret;
  final bool isDynamic;

  const _BadgeItem({
    required this.name,
    required this.requirement,
    required this.emoji,
    this.earned = false,
    this.isSecret = false,
    this.isDynamic = false,
  });
}

class _BadgeCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_BadgeItem> badges;
  final Color accentColor;

  const _BadgeCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badges,
    required this.accentColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Static badge data
// ─────────────────────────────────────────────────────────────────────────────

final List<_BadgeCategory> _badgeCategories = [
  _BadgeCategory(
    title: 'Follower Milestones',
    subtitle: 'Grow your audience to earn prestige badges',
    icon: Icons.people_outline_rounded,
    accentColor: const Color(0xFFFFB300),
    badges: [
      _BadgeItem(name: 'Trend Maker 🔥', requirement: '10K Followers', emoji: '🔥', earned: false),
      _BadgeItem(name: 'Viral Force ⚡', requirement: '50K Followers', emoji: '⚡', earned: false),
      _BadgeItem(name: 'Influence Titan 💎', requirement: '100K Followers', emoji: '💎', earned: false),
      _BadgeItem(name: 'Creator King 👑', requirement: '500K Followers', emoji: '👑', earned: false),
      _BadgeItem(name: 'Digital Monarch 👑✨', requirement: '1M Followers', emoji: '👑', earned: false),
      _BadgeItem(name: 'Internet Legend 🌍', requirement: '10M Followers', emoji: '🌍', earned: false),
      _BadgeItem(name: 'Global Icon 🚀', requirement: '100M Followers', emoji: '🚀', earned: false),
    ],
  ),
  _BadgeCategory(
    title: 'Top Creator Badges',
    subtitle: 'Dynamic ranking badges — may be removed if rank changes',
    icon: Icons.leaderboard_outlined,
    accentColor: const Color(0xFF00B4D8),
    badges: [
      _BadgeItem(name: 'Elite ⭐', requirement: 'Top 100 on Platform', emoji: '⭐', earned: false, isDynamic: true),
      _BadgeItem(name: 'Trandia Elite 💠', requirement: 'Top 50 on Platform', emoji: '💠', earned: false, isDynamic: true),
      _BadgeItem(name: 'Trandia Elite Pro 👑', requirement: 'Top 10 on Platform', emoji: '👑', earned: false, isDynamic: true),
    ],
  ),
  _BadgeCategory(
    title: 'Early Adopter',
    subtitle: 'Permanent badges for the legends who came first',
    icon: Icons.history_edu_outlined,
    accentColor: const Color(0xFF9C27B0),
    badges: [
      _BadgeItem(name: 'Founding 100 👑', requirement: 'First 100 users on Trandia', emoji: '👑', earned: false),
      _BadgeItem(name: 'Trandia Pioneer 🚀', requirement: 'First 1,000 users', emoji: '🚀', earned: false),
      _BadgeItem(name: 'Early Explorer 🧭', requirement: 'First 10,000 users', emoji: '🧭', earned: false),
      _BadgeItem(name: 'Beta Legend 🧪', requirement: 'Participated in Beta', emoji: '🧪', earned: false),
    ],
  ),
  _BadgeCategory(
    title: 'Activity Streak',
    subtitle: 'Post consistently to earn these rare badges',
    icon: Icons.local_fire_department_outlined,
    accentColor: const Color(0xFFFF5722),
    badges: [
      _BadgeItem(name: 'Consistent Creator 🔥', requirement: '30-Day Posting Streak', emoji: '🔥', earned: false),
      _BadgeItem(name: 'Iron Creator 🛡️', requirement: '100-Day Posting Streak', emoji: '🛡️', earned: false),
      _BadgeItem(name: 'Unstoppable ⚔️', requirement: '365-Day Posting Streak', emoji: '⚔️', earned: false),
    ],
  ),
  _BadgeCategory(
    title: 'Brand Collaboration',
    subtitle: 'Partner with brands to unlock these badges',
    icon: Icons.handshake_outlined,
    accentColor: const Color(0xFF4CAF50),
    badges: [
      _BadgeItem(name: 'Brand Rookie 💼', requirement: 'First Brand Deal', emoji: '💼', earned: false),
      _BadgeItem(name: 'Trusted Partner 🤝', requirement: '10 Brand Deals', emoji: '🤝', earned: false),
      _BadgeItem(name: 'Brand Magnet 🧲', requirement: '50 Brand Deals', emoji: '🧲', earned: false),
      _BadgeItem(name: 'Business Legend 👑', requirement: '100 Brand Deals', emoji: '👑', earned: false),
    ],
  ),
  _BadgeCategory(
    title: 'Niche Expert',
    subtitle: 'Auto-assigned by AI based on your content category',
    icon: Icons.emoji_objects_outlined,
    accentColor: const Color(0xFF00BCD4),
    badges: [
      _BadgeItem(name: 'Tech Master 💻', requirement: 'Technology Content', emoji: '💻', earned: false),
      _BadgeItem(name: 'Fashion Icon 👗', requirement: 'Fashion Content', emoji: '👗', earned: false),
      _BadgeItem(name: 'Fitness Beast 💪', requirement: 'Fitness Content', emoji: '💪', earned: false),
      _BadgeItem(name: 'Gaming Pro 🎮', requirement: 'Gaming Content', emoji: '🎮', earned: false),
      _BadgeItem(name: 'Education Guru 📚', requirement: 'Education Content', emoji: '📚', earned: false),
      _BadgeItem(name: 'News Reporter 🎤', requirement: 'News Content', emoji: '🎤', earned: false),
      _BadgeItem(name: 'Food Explorer 🍔', requirement: 'Food Content', emoji: '🍔', earned: false),
      _BadgeItem(name: 'Travel Explorer ✈️', requirement: 'Travel Content', emoji: '✈️', earned: false),
      _BadgeItem(name: 'Lens Master 📸', requirement: 'Photography Content', emoji: '📸', earned: false),
      _BadgeItem(name: 'Music Maestro 🎵', requirement: 'Music Content', emoji: '🎵', earned: false),
    ],
  ),
  _BadgeCategory(
    title: 'Secret Badges',
    subtitle: 'Hidden challenges — unlock to discover your legend status',
    icon: Icons.lock_outline_rounded,
    accentColor: const Color(0xFF607D8B),
    badges: [
      _BadgeItem(name: 'Night Owl 🌙', requirement: 'Active on 100 nights', emoji: '🌙', earned: false, isSecret: true),
      _BadgeItem(name: 'Trend Hunter 🔍', requirement: 'Discover multiple trends', emoji: '🔍', earned: false, isSecret: true),
      _BadgeItem(name: 'Comeback King 🔄', requirement: 'Go viral after inactivity', emoji: '🔄', earned: false, isSecret: true),
      _BadgeItem(name: 'Hidden Gem 💎', requirement: 'High engagement + low followers', emoji: '💎', earned: false, isSecret: true),
      _BadgeItem(name: 'OG Creator 🏛️', requirement: '5+ years on Trandia', emoji: '🏛️', earned: false, isSecret: true),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class BadgesScreen extends StatefulWidget {
  final bool dark;
  const BadgesScreen({super.key, required this.dark});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _badgeCategories.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _totalEarned =>
      _badgeCategories.expand((c) => c.badges).where((b) => b.earned).length;

  int get _totalBadges =>
      _badgeCategories.expand((c) => c.badges).length;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: dark),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GlassHeader(
                    dark: dark,
                    padding: const EdgeInsets.only(left: 7, right: 14),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          dark: dark,
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 16,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Achievements & Badges',
                          style: manrope(
                              size: 17, weight: FontWeight.w800, color: fg),
                        ),
                        const Spacer(),
                        // Earned count chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            '$_totalEarned / $_totalBadges',
                            style: manrope(
                                size: 11.5,
                                weight: FontWeight.w800,
                                color: sub),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Summary strip ────────────────────────────────────────
                _SummaryStrip(dark: dark, fg: fg, sub: sub),

                const SizedBox(height: 14),

                // ── Category tab bar ─────────────────────────────────────
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _badgeCategories.length,
                    itemBuilder: (_, i) {
                      final cat = _badgeCategories[i];
                      final selected = _selectedTab == i;
                      return GestureDetector(
                        onTap: () {
                          _tabController.animateTo(i);
                          setState(() => _selectedTab = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 0),
                          decoration: BoxDecoration(
                            color: selected
                                ? (dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08))
                                : (dark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.65)),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: selected
                                  ? (dark
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : Colors.black.withValues(alpha: 0.15))
                                  : (dark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.9)),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                size: 14,
                                color: selected ? fg : sub,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.title.split(' ').first,
                                style: manrope(
                                  size: 12,
                                  weight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected ? fg : sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // ── Tab content ──────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _badgeCategories
                        .map((cat) => _CategoryTabView(
                              dark: dark,
                              fg: fg,
                              sub: sub,
                              category: cat,
                              onBadgeTap: (badge) =>
                                  _showBadgeDetail(context, badge, cat, dark),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(
      BuildContext context, _BadgeItem badge, _BadgeCategory cat, bool dark) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xE0101012) : const Color(0xF2FAFAFA),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: GlassTokens.glassBorder(dark),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),

                // Badge emoji display
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cat.accentColor.withValues(alpha: dark ? 0.25 : 0.15),
                        cat.accentColor.withValues(alpha: dark ? 0.10 : 0.06),
                      ],
                    ),
                    border: Border.all(
                      color: cat.accentColor.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: badge.isSecret && !badge.earned
                      ? Icon(Icons.lock_outline_rounded,
                          size: 40, color: sub)
                      : Text(
                          badge.emoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                ),

                const SizedBox(height: 20),

                // Badge name
                Text(
                  badge.isSecret && !badge.earned ? '???' : badge.name,
                  style: manrope(size: 22, weight: FontWeight.w800, color: fg),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Category chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: cat.accentColor.withValues(alpha: dark ? 0.15 : 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color:
                          cat.accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon,
                          size: 12,
                          color: cat.accentColor
                              .withValues(alpha: dark ? 0.9 : 0.8)),
                      const SizedBox(width: 5),
                      Text(
                        cat.title,
                        style: manrope(
                          size: 11,
                          weight: FontWeight.w700,
                          color: cat.accentColor
                              .withValues(alpha: dark ? 0.9 : 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Requirement card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge.isSecret && !badge.earned
                            ? 'HOW TO UNLOCK'
                            : 'REQUIREMENT',
                        style: manrope(
                          size: 10,
                          weight: FontWeight.w800,
                          color: sub,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge.isSecret && !badge.earned
                            ? 'Complete hidden challenges to reveal this secret badge. Keep exploring Trandia!'
                            : badge.requirement,
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w600,
                          color: fg,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                if (badge.isDynamic) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: Colors.orange.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dynamic badge — may be removed if your ranking changes',
                            style: manrope(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: Colors.orange.shade400,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Status row
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: badge.earned
                        ? Colors.green.withValues(alpha: 0.12)
                        : (dark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: badge.earned
                          ? Colors.green.withValues(alpha: 0.30)
                          : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        badge.earned
                            ? Icons.check_circle_rounded
                            : Icons.lock_clock_outlined,
                        size: 18,
                        color: badge.earned ? Colors.green : sub,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        badge.earned ? 'Badge Unlocked!' : 'Not Yet Earned',
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w800,
                          color: badge.earned ? Colors.green : sub,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Summary strip at top
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;

  const _SummaryStrip(
      {required this.dark, required this.fg, required this.sub});

  @override
  Widget build(BuildContext context) {
    final int totalEarned =
        _badgeCategories.expand((c) => c.badges).where((b) => b.earned).length;
    final int total =
        _badgeCategories.expand((c) => c.badges).length;
    final int locked = total - totalEarned;
    final int secret = _badgeCategories
        .expand((c) => c.badges)
        .where((b) => b.isSecret)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GlassSurface(
        dark: dark,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        blurSigma: 0,
        child: Row(
          children: [
            _StatPill(
              dark: dark,
              label: 'Earned',
              value: '$totalEarned',
              icon: Icons.military_tech_rounded,
              color: Colors.green,
            ),
            _divider(dark),
            _StatPill(
              dark: dark,
              label: 'Locked',
              value: '$locked',
              icon: Icons.lock_outline_rounded,
              color: sub,
            ),
            _divider(dark),
            _StatPill(
              dark: dark,
              label: 'Secret',
              value: '$secret',
              icon: Icons.visibility_off_outlined,
              color: const Color(0xFF9C27B0),
            ),
            _divider(dark),
            _StatPill(
              dark: dark,
              label: 'Total',
              value: '$total',
              icon: Icons.grid_view_rounded,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool dark) => Container(
        width: 1,
        height: 32,
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      );
}

class _StatPill extends StatelessWidget {
  final bool dark;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.dark,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.85)),
          const SizedBox(height: 4),
          Text(
            value,
            style: manrope(
                size: 17,
                weight: FontWeight.w900,
                color: GlassTokens.fg(dark)),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: manrope(
                size: 10.5,
                weight: FontWeight.w600,
                color: GlassTokens.sub(dark)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category tab view
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTabView extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final _BadgeCategory category;
  final void Function(_BadgeItem badge) onBadgeTap;

  const _CategoryTabView({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.category,
    required this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final earned = category.badges.where((b) => b.earned).length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      children: [
        // Category header card
        GlassSurface(
          dark: dark,
          radius: 22,
          padding: const EdgeInsets.all(16),
          blurSigma: 0,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      category.accentColor
                          .withValues(alpha: dark ? 0.25 : 0.15),
                      category.accentColor
                          .withValues(alpha: dark ? 0.10 : 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: category.accentColor.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Icon(category.icon,
                    size: 22,
                    color: category.accentColor
                        .withValues(alpha: dark ? 0.9 : 0.8)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: manrope(
                          size: 15, weight: FontWeight.w800, color: fg),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.subtitle,
                      style: manrope(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: sub,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Earned count pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: earned > 0
                      ? Colors.green.withValues(alpha: 0.12)
                      : (dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: earned > 0
                        ? Colors.green.withValues(alpha: 0.30)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '$earned/${category.badges.length}',
                  style: manrope(
                    size: 11,
                    weight: FontWeight.w800,
                    color: earned > 0 ? Colors.green : sub,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Badges grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: category.badges.length,
          itemBuilder: (_, i) => _BadgeCard(
            dark: dark,
            badge: category.badges[i],
            category: category,
            onTap: () => onBadgeTap(category.badges[i]),
          ),
        ),

        // Dynamic note for ranking badges
        if (category.badges.any((b) => b.isDynamic)) ...[
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15,
                    color: Colors.orange.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dynamic badges — ranking change hone par remove ho sakte hain',
                    style: manrope(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: Colors.orange.shade400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Secret note
        if (category.badges.any((b) => b.isSecret)) ...[
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 15,
                    color: const Color(0xFF9C27B0)
                        .withValues(alpha: dark ? 0.9 : 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conditions pehle se nahi batayi jayengi — keep exploring to unlock!',
                    style: manrope(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: const Color(0xFF9C27B0)
                          .withValues(alpha: dark ? 0.9 : 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual badge card
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeCard extends StatefulWidget {
  final bool dark;
  final _BadgeItem badge;
  final _BadgeCategory category;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.dark,
    required this.badge,
    required this.category,
    required this.onTap,
  });

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final badge = widget.badge;
    final cat = widget.category;
    final sub = GlassTokens.sub(dark);
    final fg = GlassTokens.fg(dark);

    final isLocked = !badge.earned;
    final isSecret = badge.isSecret;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutBack,
        child: GlassSurface(
          dark: dark,
          radius: 18,
          padding: EdgeInsets.zero,
          blurSigma: 0,
          child: Opacity(
            opacity: isLocked ? (isSecret ? 0.65 : 0.55) : 1.0,
            child: Stack(
              children: [
                // Main content
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Emoji / icon in circle
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cat.accentColor.withValues(
                                  alpha: isLocked
                                      ? (dark ? 0.12 : 0.08)
                                      : (dark ? 0.28 : 0.18)),
                              cat.accentColor.withValues(
                                  alpha: isLocked
                                      ? (dark ? 0.05 : 0.04)
                                      : (dark ? 0.12 : 0.08)),
                            ],
                          ),
                          border: Border.all(
                            color: cat.accentColor.withValues(
                                alpha: isLocked ? 0.15 : 0.35),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isSecret && isLocked
                            ? Icon(Icons.lock_outline_rounded,
                                size: 22, color: sub)
                            : Text(
                                badge.emoji,
                                style: TextStyle(
                                    fontSize: isLocked ? 22 : 26),
                              ),
                      ),

                      const SizedBox(height: 8),

                      // Badge name
                      Text(
                        isSecret && isLocked ? '???' : _cleanName(badge.name),
                        style: manrope(
                          size: 10.5,
                          weight: FontWeight.w700,
                          color: isLocked ? sub : fg,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Lock overlay for locked badges
                if (isLocked)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: sub,
                      ),
                    ),
                  ),

                // Earned checkmark
                if (!isLocked)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.green,
                      ),
                    ),
                  ),

                // Dynamic badge indicator
                if (badge.isDynamic)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        Icons.sync_rounded,
                        size: 9,
                        color: Colors.orange.shade400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Strip trailing emoji from the name for display in the compact card.
  String _cleanName(String name) {
    // Keep it concise — show up to ~20 chars
    return name;
  }
}
