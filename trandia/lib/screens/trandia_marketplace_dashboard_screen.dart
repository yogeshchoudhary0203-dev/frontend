// trandia_marketplace_dashboard_screen.dart
//
// Trandia Marketplace · Creator Dashboard (frontend-only mock).
// Shown after the user has submitted their application
// (SharedPreferences flag TmApplyKeys.applied == true).
// Theme: shared glass system from glass_common.dart.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glass_common.dart';
import 'trandia_marketplace_apply_screen.dart';

class TrandiaMarketplaceDashboardScreen extends StatefulWidget {
  final bool dark;
  const TrandiaMarketplaceDashboardScreen({super.key, required this.dark});

  @override
  State<TrandiaMarketplaceDashboardScreen> createState() =>
      _TrandiaMarketplaceDashboardScreenState();
}

class _TrandiaMarketplaceDashboardScreenState
    extends State<TrandiaMarketplaceDashboardScreen> {
  String? _contentType;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _contentType = prefs.getString(TmApplyKeys.contentType);
      _phone = prefs.getString(TmApplyKeys.phone);
    });
  }

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GlassHeader(
                    dark: dark,
                    padding: const EdgeInsets.only(left: 7, right: 8),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          dark: dark,
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 16,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Marketplace Dashboard',
                            style: manrope(
                                size: 16,
                                weight: FontWeight.w800,
                                color: fg),
                          ),
                        ),
                        GlassCircleButton(
                          dark: dark,
                          icon: Icons.notifications_none_rounded,
                          iconSize: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    children: [
                      _StatusCard(
                        dark: dark,
                        contentType: _contentType,
                        phone: _phone,
                      ),
                      const SizedBox(height: 16),
                      _EarningsHero(dark: dark),
                      const SizedBox(height: 16),
                      _SectionTitle('OVERVIEW', color: sub),
                      const SizedBox(height: 4),
                      _StatsGrid(dark: dark),
                      const SizedBox(height: 20),
                      _SectionRow(
                        title: 'REQUESTS',
                        trailing: '4 new',
                        color: sub,
                      ),
                      const SizedBox(height: 6),
                      _RequestsList(dark: dark),
                      const SizedBox(height: 20),
                      _SectionRow(
                        title: 'HISTORY',
                        trailing: 'See all',
                        color: sub,
                      ),
                      const SizedBox(height: 6),
                      _HistoryList(dark: dark),
                      const SizedBox(height: 20),
                      _SectionTitle('QUICK ACTIONS', color: sub),
                      const SizedBox(height: 6),
                      _QuickActions(dark: dark),
                    ],
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

// ── Status card (top) ───────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final bool dark;
  final String? contentType;
  final String? phone;
  const _StatusCard({required this.dark, this.contentType, this.phone});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return GlassSurface(
      dark: dark,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white : const Color(0xFF0A0A0A),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.verified_rounded,
              size: 24,
              color: dark ? const Color(0xFF0A0A0A) : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Approved',
                      style: manrope(
                          size: 14.5,
                          weight: FontWeight.w800,
                          color: fg),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  contentType != null && contentType!.isNotEmpty
                      ? '$contentType Creator • Marketplace ID #TR-${(phone ?? '0000').padLeft(4, '0').substring((phone ?? '0000').length - 4)}'
                      : 'Marketplace Creator',
                  style: manrope(
                      size: 12, weight: FontWeight.w600, color: sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Earnings hero ───────────────────────────────────────────────────────────
class _EarningsHero extends StatelessWidget {
  final bool dark;
  const _EarningsHero({required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return GlassSurface(
      dark: dark,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH',
                style: manrope(
                    size: 10,
                    weight: FontWeight.w800,
                    color: sub,
                    letterSpacing: 1.3),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_upward_rounded,
                      size: 12,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '24%',
                      style: manrope(
                          size: 11,
                          weight: FontWeight.w800,
                          color: const Color(0xFF22C55E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹84,500',
                style: manrope(
                    size: 34,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -1.2,
                    height: 1),
              ),
              const SizedBox(width: 8),
              Text(
                'earned',
                style: manrope(
                    size: 13.5, weight: FontWeight.w600, color: sub),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat(dark, '₹32K', 'Pending', sub, fg),
              const SizedBox(width: 24),
              _miniStat(dark, '₹1.2L', 'Lifetime', sub, fg),
              const SizedBox(width: 24),
              _miniStat(dark, '8', 'Brands', sub, fg),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(bool dark, String val, String label, Color sub, Color fg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val,
            style: manrope(
                size: 15.5, weight: FontWeight.w800, color: fg)),
        const SizedBox(height: 2),
        Text(label,
            style: manrope(
                size: 11, weight: FontWeight.w600, color: sub)),
      ],
    );
  }
}

// ── Section helpers ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Text(
        text,
        style: manrope(
            size: 11,
            weight: FontWeight.w800,
            color: color,
            letterSpacing: 0.9),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final String trailing;
  final Color color;
  const _SectionRow(
      {required this.title, required this.trailing, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: manrope(
                size: 11,
                weight: FontWeight.w800,
                color: color,
                letterSpacing: 0.9),
          ),
          Text(
            trailing,
            style: manrope(
                size: 11,
                weight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

// ── Stats grid (2x2) ────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final bool dark;
  const _StatsGrid({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: _StatTile(
                  dark: dark,
                  icon: Icons.inbox_rounded,
                  value: '4',
                  label: 'PENDING REQUESTS')),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  dark: dark,
                  icon: Icons.work_outline_rounded,
                  value: '2',
                  label: 'ACTIVE JOBS')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _StatTile(
                  dark: dark,
                  icon: Icons.check_circle_outline_rounded,
                  value: '32',
                  label: 'COMPLETED')),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  dark: dark,
                  icon: Icons.star_rounded,
                  value: '4.9',
                  label: 'AVG RATING')),
        ]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String value;
  final String label;
  const _StatTile({
    required this.dark,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return GlassSurface(
      dark: dark,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: fg),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: manrope(
                size: 22, weight: FontWeight.w800, color: fg, letterSpacing: -0.6),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: manrope(
                size: 10,
                weight: FontWeight.w800,
                color: sub,
                letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}

// ── Requests list ───────────────────────────────────────────────────────────
class _RequestsList extends StatelessWidget {
  final bool dark;
  const _RequestsList({required this.dark});

  @override
  Widget build(BuildContext context) {
    const items = [
      ['Boat', 'Reel Integration (60s)', '₹25,000', 'New'],
      ['Zomato', 'Story Mention', '₹3,500', 'New'],
      ['CRED', 'Promo Video', '₹18,000', 'Discussing'],
      ['Mamaearth', 'Long-form Review', '₹42,000', 'New'],
    ];
    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            _RequestRow(
              dark: dark,
              brand: items[i][0],
              type: items[i][1],
              price: items[i][2],
              status: items[i][3],
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final bool dark;
  final String brand, type, price, status;
  const _RequestRow({
    required this.dark,
    required this.brand,
    required this.type,
    required this.price,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final isNew = status == 'New';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            alignment: Alignment.center,
            child: Text(
              brand[0],
              style: manrope(
                  size: 15, weight: FontWeight.w800, color: fg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      brand,
                      style: manrope(
                          size: 14.5,
                          weight: FontWeight.w800,
                          color: fg),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNew
                            ? (dark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.08))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.20)
                              : Colors.black.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: manrope(
                            size: 10,
                            weight: FontWeight.w800,
                            color: fg,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  type,
                  style: manrope(
                      size: 12, weight: FontWeight.w600, color: sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: manrope(
                    size: 14,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.2),
              ),
              const SizedBox(height: 2),
              Icon(Icons.chevron_right_rounded, color: sub, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

// ── History list ────────────────────────────────────────────────────────────
class _HistoryList extends StatelessWidget {
  final bool dark;
  const _HistoryList({required this.dark});

  @override
  Widget build(BuildContext context) {
    const items = [
      ['Myntra', 'Reel · Delivered', '₹28,000', 'Paid'],
      ['Nykaa', 'Story · Delivered', '₹4,200', 'Paid'],
      ['Realme', 'Promo · Delivered', '₹15,000', 'Paid'],
    ];
    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            _HistoryRow(
              dark: dark,
              brand: items[i][0],
              detail: items[i][1],
              price: items[i][2],
              status: items[i][3],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final bool dark;
  final String brand, detail, price, status;
  const _HistoryRow({
    required this.dark,
    required this.brand,
    required this.detail,
    required this.price,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF22C55E), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  style: manrope(
                      size: 14, weight: FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: manrope(
                      size: 12, weight: FontWeight.w600, color: sub),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: manrope(
                    size: 14, weight: FontWeight.w800, color: fg),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: manrope(
                    size: 10.5,
                    weight: FontWeight.w800,
                    color: const Color(0xFF22C55E),
                    letterSpacing: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ───────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final bool dark;
  const _QuickActions({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            dark: dark,
            icon: Icons.tune_rounded,
            label: 'Edit\nPricing',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            dark: dark,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Withdraw\nEarnings',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            dark: dark,
            icon: Icons.help_outline_rounded,
            label: 'Get\nSupport',
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  const _ActionCard(
      {required this.dark, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    return PressableScale(
      onTap: () {},
      child: GlassSurface(
        dark: dark,
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: fg),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: manrope(
                  size: 12,
                  weight: FontWeight.w800,
                  color: fg,
                  height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
