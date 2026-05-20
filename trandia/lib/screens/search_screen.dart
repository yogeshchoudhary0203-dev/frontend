// search_screen.dart
// Matte glass search — header (back + search pill) → filter chips →
// Recent · Suggested · Discover mosaic. Pixel-perfect with the JSX.
//
// Drop in `lib/` alongside glass_common.dart.

import 'dart:ui';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_common.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/chat_model.dart';
import 'chat_screen.dart';

Future<void> _startChat(BuildContext context, String username, bool dark, {UserProfile? selectedUser}) async {
  try {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final convId = await ChatService().startConversation(username);
    final convs = await ChatService().getConversations();
    final myUserId = await AuthService.getCurrentUserId();

    ChatConversation? conversation;
    try {
      conversation = convs.firstWhere((c) => c.id == convId);
    } catch (_) {
      if (selectedUser != null && myUserId != null) {
        conversation = ChatConversation(
          id: convId,
          participants: [
            UserProfile(id: myUserId, name: '', username: '', picture: null),
            selectedUser,
          ],
          lastMessage: null,
          lastMessageTime: null,
          unreadCounts: {},
          isGroup: false,
        );
      }
    }

    if (context.mounted) Navigator.of(context).pop(); // pop loading

    if (context.mounted) {
      if (conversation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open chat. Please try again.')),
        );
        return;
      }

      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => ChatScreen(
            dark: dark,
            conversation: conversation!,
            myUserId: myUserId ?? '',
          ),
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // pop loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    }
  }
}


// ───────────────────────────────────────────────────────────────
// Data models
// ───────────────────────────────────────────────────────────────

enum RecentKind { user, tag, place }

class RecentItem {
  final RecentKind kind;
  final String name;
  final String sub;
  const RecentItem({required this.kind, required this.name, required this.sub});
}

class SuggestedItem {
  final String name;
  final String sub;
  final bool followed;
  const SuggestedItem({required this.name, required this.sub, this.followed = false});
}

enum TileKind { photo, reel, carousel }

class DiscoverTile {
  final int span;        // 1 or 2 (row span)
  final TileKind kind;
  final int? count;      // for carousel
  const DiscoverTile({required this.span, required this.kind, this.count});
}

const _filters = ['Top', 'People', 'Tags', 'Posts', 'Places'];

const _recents = <RecentItem>[
  RecentItem(kind: RecentKind.user,  name: 'sarah.d',        sub: 'Sarah Dietrich · Following'),
  RecentItem(kind: RecentKind.tag,   name: '#slowliving',    sub: '128K posts'),
  RecentItem(kind: RecentKind.place, name: 'Studio Atelier', sub: 'Berlin, Germany'),
  RecentItem(kind: RecentKind.user,  name: 'mikhail',        sub: 'Mikhail Volkov · 2 mutual'),
  RecentItem(kind: RecentKind.tag,   name: '#interiors',     sub: '4.2M posts'),
  RecentItem(kind: RecentKind.user,  name: 'aanya_',         sub: 'Aanya · Followed by devon.b'),
];

const _suggested = <SuggestedItem>[
  SuggestedItem(name: 'studio.atelier', sub: 'Suggested'),
  SuggestedItem(name: 'noor.j',         sub: 'Followed by you', followed: true),
  SuggestedItem(name: 'rena.k',         sub: 'New on Trandia'),
  SuggestedItem(name: 'oslo.house',     sub: '2 mutual'),
  SuggestedItem(name: 'ren.x',          sub: 'You may know'),
  SuggestedItem(name: 'devon.b',        sub: 'Suggested'),
];

const _tiles = <DiscoverTile>[
  DiscoverTile(span: 2, kind: TileKind.photo),
  DiscoverTile(span: 1, kind: TileKind.reel),
  DiscoverTile(span: 1, kind: TileKind.photo),
  DiscoverTile(span: 1, kind: TileKind.carousel, count: 5),
  DiscoverTile(span: 2, kind: TileKind.photo),
  DiscoverTile(span: 1, kind: TileKind.reel),
  DiscoverTile(span: 1, kind: TileKind.photo),
  DiscoverTile(span: 1, kind: TileKind.photo),
  DiscoverTile(span: 1, kind: TileKind.carousel, count: 3),
  DiscoverTile(span: 2, kind: TileKind.reel),
  DiscoverTile(span: 1, kind: TileKind.photo),
  DiscoverTile(span: 1, kind: TileKind.photo),
];

/// Monochrome tile gradient with varied angle.
LinearGradient _tileGradient(bool dark, int i) {
  final double a, b;
  if (dark) {
    a = (22 - (i % 5) * 3).toDouble();
    b = (a - 12).clamp(4, 100).toDouble();
  } else {
    a = (92 - (i % 5) * 4).toDouble();
    b = (a - 18).clamp(56, 100).toDouble();
  }
  final angle = (135 + (i * 23) % 90) * 3.14159 / 180.0;
  // Convert angle to begin/end alignments
  final dx = -1 * (i.isEven ? 1 : -1).toDouble();
  final dy = -1.0;
  // We approximate by switching alignments based on index to vary direction.
  final begin = (i % 4 == 0) ? Alignment.topLeft
              : (i % 4 == 1) ? Alignment.topCenter
              : (i % 4 == 2) ? Alignment.topRight
              :                Alignment.centerLeft;
  final end   = (i % 4 == 0) ? Alignment.bottomRight
              : (i % 4 == 1) ? Alignment.bottomCenter
              : (i % 4 == 2) ? Alignment.bottomLeft
              :                Alignment.centerRight;
  return LinearGradient(
    begin: begin, end: end,
    colors: [
      HSLColor.fromAHSL(1, 0, 0, a / 100).toColor(),
      HSLColor.fromAHSL(1, 0, 0, b / 100).toColor(),
    ],
  );
}

// ───────────────────────────────────────────────────────────────
// SearchScreen
// ───────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  final bool dark;
  const SearchScreen({super.key, required this.dark});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _filter = 'Top';
  String _query = '';
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _query = query;
    });
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }
      
      setState(() {
        _isSearching = true;
      });
      
      try {
        final results = await UserService.searchUsers(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        developer.log('Search error: $e');
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Search error: $e'),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final headerTop = MediaQuery.paddingOf(context).top + 8;

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(children: [
        GlassBackdrop(dark: dark),

        // ── Scrollable content ────────────────────────────────
        Positioned.fill(
          top: headerTop + 102,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (_query.isNotEmpty) ...[
                _Section(title: 'Search Results', action: 'Clear', dark: dark),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text('No users found',
                        style: manrope(size: 14, color: sub)),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      for (int i = 0; i < _searchResults.length; i++)
                        _UserResultRow(u: _searchResults[i], i: i, dark: dark),
                    ]),
                  ),
              ] else ...[
                _Section(title: 'Recent', action: 'Clear all', dark: dark),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [
                    for (int i = 0; i < _recents.length; i++)
                      _RecentRow(r: _recents[i], i: i, dark: dark),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              _Section(title: 'Suggested for you', action: 'See all', dark: dark),
              SizedBox(
                height: 174,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _suggested.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _SuggestedCard(s: _suggested[i], i: i, dark: dark),
                ),
              ),
              const SizedBox(height: 14),
              _Section(title: 'Discover', dark: dark),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _DiscoverGrid(dark: dark),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Header: back + search input ───────────────────────
        Positioned(
          top: headerTop, left: 12, right: 12,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              // Back button
              _CircleGlass(
                dark: dark,
                size: 44,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: fg),
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              // Search input pill
              Expanded(child: _SearchInputPill(
                dark: dark,
                value: _query,
                placeholder: 'Search Trandia',
                onChanged: _onSearchChanged,
                onClear: () => _onSearchChanged(''),
              )),
            ]),
          ),
        ),

        // ── Filter chips ──────────────────────────────────────
        Positioned(
          top: headerTop + 60, left: 0, right: 0,
          child: SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final label = _filters[i];
                final active = _filter == label;
                IconData? lead;
                if (label == 'Tags')   lead = Icons.local_offer_outlined;
                if (label == 'Places') lead = Icons.location_on_outlined;
                return _FilterChip(
                  label: label, active: active, dark: dark,
                  leading: lead,
                  onTap: () => setState(() => _filter = label),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Sub-widgets
// ───────────────────────────────────────────────────────────────

class _CircleGlass extends StatelessWidget {
  final bool dark;
  final double size;
  final Widget child;
  final VoidCallback? onTap;
  const _CircleGlass({required this.dark, required this.size, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: size, height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6),
              border: Border.all(color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95)),
              boxShadow: [
                BoxShadow(
                  color: dark ? Colors.black.withOpacity(0.7) : const Color(0xFF14161E).withOpacity(0.18),
                  blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -14,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SearchInputPill extends StatefulWidget {
  final bool dark;
  final String value;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback onClear;
  const _SearchInputPill({
    required this.dark, required this.value, required this.placeholder, 
    this.onChanged, required this.onClear,
  });

  @override
  State<_SearchInputPill> createState() => _SearchInputPillState();
}

class _SearchInputPillState extends State<_SearchInputPill> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SearchInputPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final hasText = _controller.text.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: dark
                ? [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)]
                : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.62)],
            ),
            border: Border.all(color: dark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.95)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: dark ? Colors.black.withOpacity(0.7) : const Color(0xFF14161E).withOpacity(0.20),
                blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -14,
              ),
            ],
          ),
          child: Stack(alignment: Alignment.center, children: [
            // top sheen
            Positioned(
              top: 0, left: 20, right: 20, height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: dark
                    ? [Colors.transparent, Colors.white.withOpacity(0.22), Colors.transparent]
                    : [Colors.transparent, Colors.white, Colors.transparent]),
                ),
              ),
            ),
            Row(children: [
              Icon(Icons.search_rounded, size: 18, color: hasText ? fg : sub),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _controller,
                onChanged: (val) {
                  setState(() {});
                  if (widget.onChanged != null) widget.onChanged!(val);
                },
                style: manrope(
                  size: 14.5,
                  weight: hasText ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  letterSpacing: -0.145,
                ),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: manrope(
                    size: 14.5,
                    weight: FontWeight.w500,
                    color: sub,
                    letterSpacing: -0.145,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )),
              const SizedBox(width: 6),
              if (hasText)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() {});
                    widget.onClear();
                  },
                  child: Container(
                    width: 26, height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    ),
                    child: Icon(Icons.close_rounded, size: 14, color: fg),
                  ),
                )
              else
                SizedBox(
                  width: 32, height: 32,
                  child: Icon(Icons.mic_none_rounded, size: 18, color: sub),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool dark;
  final IconData? leading;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, required this.active, required this.dark,
    required this.onTap, this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                ? (dark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.85))
                : (dark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45)),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active
                ? (dark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.12))
                : (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[
                Icon(leading, size: 13, color: fg),
                const SizedBox(width: 5),
              ],
              Text(label,
                style: manrope(
                  size: 12.5,
                  weight: active ? FontWeight.w700 : FontWeight.w600,
                  color: fg, letterSpacing: -0.125,
                )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? action;
  final bool dark;
  const _Section({required this.title, required this.dark, this.action});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Row(children: [
        Text(title.toUpperCase(),
          style: manrope(size: 11, weight: FontWeight.w700, color: sub, letterSpacing: 0.88)),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: () {},
            child: Text(action!,
              style: manrope(size: 12, weight: FontWeight.w700, color: fg, letterSpacing: -0.12)),
          ),
      ]),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final RecentItem r;
  final int i;
  final bool dark;
  const _RecentRow({required this.r, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    Widget leading;
    if (r.kind == RecentKind.user) {
      leading = Container(
        width: 46, height: 46,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, i)),
        alignment: Alignment.center,
        child: Text(r.name[0].toUpperCase(),
          style: manrope(size: 17, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.34)),
      );
    } else {
      leading = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 46, height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
              border: Border.all(color: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06)),
            ),
            child: Icon(
              r.kind == RecentKind.tag ? Icons.local_offer_outlined : Icons.location_on_outlined,
              size: 18, color: fg,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (r.kind == RecentKind.user) {
          _startChat(context, r.name, dark);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(children: [
        leading,
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: manrope(size: 14, weight: FontWeight.w700, color: fg, letterSpacing: -0.14)),
          const SizedBox(height: 2),
          Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: manrope(size: 11.5, weight: FontWeight.w500, color: sub, letterSpacing: -0.06)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 28, height: 28, alignment: Alignment.center,
            child: Icon(Icons.close_rounded, size: 14, color: sub),
          ),
        ),
      ]),
      ),
    );
  }
}

class _UserResultRow extends StatelessWidget {
  final UserProfile u;
  final int i;
  final bool dark;
  const _UserResultRow({required this.u, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return GestureDetector(
      onTap: () {
        _startChat(context, u.username, dark, selectedUser: u);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              gradient: monoAvatar(dark, i),
              image: u.picture != null 
                  ? DecorationImage(image: NetworkImage(u.picture!), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: u.picture == null ? Text(u.name[0].toUpperCase(),
              style: manrope(size: 17, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.34)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: manrope(size: 14, weight: FontWeight.w700, color: fg, letterSpacing: -0.14)),
            const SizedBox(height: 2),
            Text('@${u.username}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: manrope(size: 11.5, weight: FontWeight.w500, color: sub, letterSpacing: -0.06)),
          ])),
        ]),
      ),
    );
  }
}

class _SuggestedCard extends StatelessWidget {
  final SuggestedItem s;
  final int i;
  final bool dark;
  const _SuggestedCard({required this.s, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return GestureDetector(
      onTap: () => _startChat(context, s.name, dark),
      child: SizedBox(
        width: 132,
      child: GlassSurface(
        dark: dark, radius: 20,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, i + 1)),
            alignment: Alignment.center,
            child: Text(s.name[0].toUpperCase(),
              style: manrope(size: 22, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.44)),
          ),
          const SizedBox(height: 8),
          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: manrope(size: 13, weight: FontWeight.w700, color: fg, letterSpacing: -0.13)),
          const SizedBox(height: 1),
          Text(s.sub, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: manrope(size: 10.5, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 30,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                elevation: 0,
                backgroundColor: s.followed
                  ? (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06))
                  : (dark ? Colors.white : const Color(0xFF0A0A0A)),
                foregroundColor: s.followed ? fg : (dark ? const Color(0xFF0A0A0A) : Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: s.followed
                    ? BorderSide(color: dark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08))
                    : BorderSide.none,
                ),
              ),
              onPressed: () {},
              child: Text(s.followed ? 'Following' : 'Follow',
                style: manrope(
                  size: 12, weight: FontWeight.w700,
                  color: s.followed ? fg : (dark ? const Color(0xFF0A0A0A) : Colors.white),
                  letterSpacing: -0.12,
                )),
            ),
          ),
        ]),
      ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Discover grid — 3-col masonry where each tile spans 1 or 2 rows.
// Pure layout math (no third-party deps).
// ───────────────────────────────────────────────────────────────

class _DiscoverGrid extends StatelessWidget {
  final bool dark;
  const _DiscoverGrid({required this.dark});

  static const double _rowH = 128;
  static const double _gap  = 6;
  static const int    _cols = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final tileW = (c.maxWidth - _gap * (_cols - 1)) / _cols;
      // place each tile into the shortest column
      final colHeights = List<double>.filled(_cols, 0);
      final positions  = <_Pos>[];
      double maxH = 0;
      for (int i = 0; i < _tiles.length; i++) {
        int col = 0;
        for (int k = 1; k < _cols; k++) {
          if (colHeights[k] < colHeights[col]) col = k;
        }
        final span = _tiles[i].span;
        final h = _rowH * span + (span - 1) * _gap;
        final top = colHeights[col];
        positions.add(_Pos(col: col, top: top, height: h));
        colHeights[col] = top + h + _gap;
        if (colHeights[col] - _gap > maxH) maxH = colHeights[col] - _gap;
      }

      return SizedBox(
        height: maxH,
        child: Stack(children: [
          for (int i = 0; i < _tiles.length; i++)
            Positioned(
              left: positions[i].col * (tileW + _gap),
              top: positions[i].top,
              width: tileW,
              height: positions[i].height,
              child: _DiscoverTileView(t: _tiles[i], i: i, dark: dark),
            ),
        ]),
      );
    });
  }
}

class _Pos {
  final int col;
  final double top;
  final double height;
  _Pos({required this.col, required this.top, required this.height});
}

class _DiscoverTileView extends StatelessWidget {
  final DiscoverTile t;
  final int i;
  final bool dark;
  const _DiscoverTileView({required this.t, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _tileGradient(dark, i),
          boxShadow: [
            BoxShadow(
              color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.5),
              blurRadius: 0, offset: const Offset(0, 1), spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(fit: StackFit.expand, children: [
          // subtle top vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -1),
                radius: 1.2,
                colors: dark
                  ? [Colors.white.withOpacity(0.06), Colors.transparent]
                  : [Colors.white.withOpacity(0.55), Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          // kind chip top-right
          if (t.kind != TileKind.photo)
            Positioned(
              top: 6, right: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.black.withOpacity(0.42),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        t.kind == TileKind.reel ? Icons.movie_creation_outlined : Icons.collections_outlined,
                        size: 12, color: Colors.white,
                      ),
                      if (t.kind == TileKind.carousel && t.count != null) ...[
                        const SizedBox(width: 3),
                        Text('${t.count}',
                          style: manrope(size: 10, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.1)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          // reel play glyph centered
          if (t.kind == TileKind.reel)
            Center(child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.35),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                ),
              ),
            )),
        ]),
      ),
    );
  }
}
