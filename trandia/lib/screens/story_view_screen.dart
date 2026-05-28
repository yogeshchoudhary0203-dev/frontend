import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_model.dart';
import '../services/api_service.dart';
import '../services/story_service.dart';
import '../services/chat_service.dart';

class StoryViewScreen extends StatefulWidget {
  final List<StoryUserGroup> groups;
  final int initialGroupIndex;

  const StoryViewScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late List<StoryUserGroup> _groups;
  late int _groupIdx;
  int  _storyIdx   = 0;
  bool _imageReady = false;
  bool _paused     = false;

  late AnimationController _prog;

  static const Duration _kStoryDuration = Duration(seconds: 8);

  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  StoryUserGroup get _group => _groups[_groupIdx];
  StoryModel     get _story => _group.stories[_storyIdx];

  @override
  void initState() {
    super.initState();
    _groups = List.from(widget.groups);
    _groupIdx = widget.initialGroupIndex.clamp(0, _groups.length - 1);
    
    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _pause();
      } else {
        _resume();
      }
    });

    _prog = AnimationController(vsync: this, duration: _kStoryDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) _goNext();
      });
    _beginStory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheUpcomingStories();
    });
  }

  @override
  void dispose() {
    _prog.dispose();
    _replyCtrl.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _precacheUpcomingStories() {
    if (!mounted || _groups.isEmpty) return;
    
    // Pre-cache remaining stories in the current group
    final currentGroup = _groups[_groupIdx];
    for (int i = _storyIdx; i < currentGroup.stories.length; i++) {
      final url = currentGroup.stories[i].mediaUrl;
      precacheImage(CachedNetworkImageProvider(url), context);
    }
    
    // Pre-cache first story of the next group
    if (_groupIdx < _groups.length - 1) {
      final nextGroup = _groups[_groupIdx + 1];
      if (nextGroup.stories.isNotEmpty) {
        final url = nextGroup.stories[0].mediaUrl;
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _goTo({required int groupIdx, required int storyIdx}) {
    if (!mounted || _groups.isEmpty) return;
    final storyId = _groups[groupIdx].stories[storyIdx].id;
    setState(() {
      _groupIdx   = groupIdx;
      _storyIdx   = storyIdx;
      _imageReady = false;
      _paused     = false;
    });
    _prog.reset();
    _precacheUpcomingStories();
    StoryService.instance.view(storyId);
  }

  void _beginStory() {
    if (_groups.isEmpty) return;
    _imageReady = false;
    _paused     = false;
    _prog.reset();
    _precacheUpcomingStories();
    StoryService.instance.view(_story.id);
  }

  void _goNext() {
    if (_groups.isEmpty) return;
    if (_storyIdx < _group.stories.length - 1) {
      _goTo(groupIdx: _groupIdx, storyIdx: _storyIdx + 1);
    } else if (_groupIdx < _groups.length - 1) {
      _goTo(groupIdx: _groupIdx + 1, storyIdx: 0);
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _goPrev() {
    if (_groups.isEmpty) return;
    if (_storyIdx > 0) {
      _goTo(groupIdx: _groupIdx, storyIdx: _storyIdx - 1);
    } else if (_groupIdx > 0) {
      final prevGroup = _groups[_groupIdx - 1];
      _goTo(groupIdx: _groupIdx - 1, storyIdx: prevGroup.stories.length - 1);
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _pause()  { if (!_paused) { _paused = true;  _prog.stop(); } }
  void _resume() { if (_paused && !_replyFocusNode.hasFocus)  { _paused = false; _prog.forward(); } }

  void _onImageReady() {
    if (!_imageReady && mounted) {
      _imageReady = true;
      _prog.forward();
    }
  }

  // ── Settings / actions ──────────────────────────────────────────────────────

  void _openSettings() {
    _pause();
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: Colors.transparent,
      builder:         (ctx) => _SettingsSheet(
        onHideFrom:     () { Navigator.pop(ctx); _showHideDialog(); },
        onCloseFriends: () => Navigator.pop(ctx),
        onDelete:       () { Navigator.pop(ctx); _confirmDelete(); },
      ),
    ).whenComplete(_resume);
  }

  void _confirmDelete() {
    _pause();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete story?',
            style: GoogleFonts.manrope(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to permanently delete this story?',
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.manrope(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await StoryService.instance.deleteStory(_story.id);
                if (mounted) {
                  // Remove deleted story from local group
                  setState(() {
                    _group.stories.removeAt(_storyIdx);
                  });
                  // If no stories left, close or move to next group
                  if (_group.stories.isEmpty) {
                    _groups.removeAt(_groupIdx);
                    if (_groups.isEmpty) {
                      Navigator.pop(context);
                    } else {
                      _goTo(
                        groupIdx: _groupIdx.clamp(0, _groups.length - 1),
                        storyIdx: 0,
                      );
                    }
                  } else {
                    _goTo(
                      groupIdx: _groupIdx,
                      storyIdx: _storyIdx.clamp(0, _group.stories.length - 1),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to delete story',
                        style: GoogleFonts.manrope(color: Colors.white)),
                    backgroundColor: Colors.red.shade800,
                  ));
                }
              }
            },
            child: Text('Delete',
                style: GoogleFonts.manrope(
                  color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(_resume);
  }

  void _showHideDialog() {
    _pause();
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hide story from',
            style: GoogleFonts.manrope(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the username of the person you want to hide your story from.',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus:  true,
            style:      GoogleFonts.manrope(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText:  'username',
              hintStyle: GoogleFonts.manrope(color: Colors.white30),
              filled:    true,
              fillColor: Colors.white.withOpacity(0.07),
              prefixText: '@',
              prefixStyle: GoogleFonts.manrope(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.manrope(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final username = ctrl.text.trim().replaceAll('@', '');
              if (username.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await StoryService.instance.hideAllFrom(username);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Story hidden from @$username',
                        style: GoogleFonts.manrope(color: Colors.white)),
                    backgroundColor: const Color(0xFF2A2A2C),
                    behavior:        SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.all(16),
                  ));
                }
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.message,
                        style: GoogleFonts.manrope(color: Colors.white)),
                    backgroundColor: Colors.red.shade800,
                    behavior:        SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.all(16),
                  ));
                }
              }
            },
            child: Text('Hide',
                style: GoogleFonts.manrope(
                  color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(_resume);
  }

  Future<void> _sendStoryReply(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _replyCtrl.clear();
    _replyFocusNode.unfocus();

    try {
      final convId = await ChatService().startConversation(_group.userUsername);
      final conversations = await ChatService().getConversations();
      final conv = conversations.firstWhere(
        (c) => c.id == convId,
        orElse: () => ChatConversation(id: convId, participants: []),
      );
      
      if (conv.participants.isNotEmpty) {
        await ChatService().sendMessage(
          convId,
          "Replied to your story: \"$cleanText\"",
          conv.participants,
        );
      } else {
        throw Exception("Conversation has no participants");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Message sent to @${_group.userUsername}',
              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send reply. Please try again.',
              style: GoogleFonts.manrope(color: Colors.white)),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inHours   < 1)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) return const SizedBox.shrink();
    
    final group   = _group;
    final story   = _story;
    final isOwn   = group.isOwn;
    final storyCount = group.stories.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Story image ───────────────────────────────────────────────
            CachedNetworkImage(
              key:          ValueKey('${story.id}_$_storyIdx'),
              imageUrl:     story.mediaUrl,
              fit:          BoxFit.cover,
              imageBuilder: (ctx, img) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _onImageReady());
                return Image(image: img, fit: BoxFit.cover);
              },
              placeholder: (_, __) => Container(
                color: Colors.black,
                child: Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.35)),
                    ),
                  ),
                ),
              ),
              errorWidget:  (_, __, ___) => const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white24, size: 52),
                ),
              ),
            ),

            // ── Gradients ─────────────────────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   const Alignment(0, -0.3),
                    colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end:   Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Tap zones (prev / next) ───────────────────────────────────
            Row(children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:    _goPrev,
                  child:    const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:    _goNext,
                  child:    const SizedBox.expand(),
                ),
              ),
            ]),

            // ── Top bar: progress bar + user info ────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Segmented progress indicator
                    AnimatedBuilder(
                      animation: _prog,
                      builder: (ctx, _) => Row(
                        children: List.generate(storyCount, (i) {
                          final double val = i < _storyIdx
                              ? 1.0
                              : i == _storyIdx
                                  ? _prog.value
                                  : 0.0;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: i < storyCount - 1 ? 4.0 : 0.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: SizedBox(
                                  height: 3,
                                  child: LinearProgressIndicator(
                                    value: val,
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // User info row
                    Row(children: [
                      CircleAvatar(
                        radius:          19,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        backgroundImage: group.userPicture != null
                            ? CachedNetworkImageProvider(group.userPicture!)
                            : null,
                        child: group.userPicture == null
                            ? Text(
                                group.userName.isNotEmpty
                                    ? group.userName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.manrope(
                                  color: Colors.white, fontSize: 14,
                                  fontWeight: FontWeight.w700))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(group.userName,
                                style: GoogleFonts.manrope(
                                  color: Colors.white, fontSize: 14,
                                  fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis),
                            Text(_timeAgo(story.createdAt),
                                style: GoogleFonts.manrope(
                                  color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // ── Bottom bar: viewer count / reply field + settings ────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isOwn) ...[
                        // Left: viewer count
                        const Icon(Icons.remove_red_eye_rounded,
                            color: Colors.white70, size: 15),
                        const SizedBox(width: 4),
                        Text('${story.viewCount}',
                            style: GoogleFonts.manrope(
                              color: Colors.white70, fontSize: 13,
                              fontWeight: FontWeight.w600)),
                        const Spacer(),
                        // Right: settings
                        GestureDetector(
                          onTap: _openSettings,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.tune_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ] else ...[
                        // Bottom text field reply for other users' stories
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(23),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _replyCtrl,
                                    focusNode: _replyFocusNode,
                                    style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Send message...',
                                      hintStyle: GoogleFonts.manrope(color: Colors.white54, fontSize: 14),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onSubmitted: _sendStoryReply,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _sendStoryReply(_replyCtrl.text),
                                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  final VoidCallback onHideFrom;
  final VoidCallback onCloseFriends;
  final VoidCallback onDelete;
  
  const _SettingsSheet({
    required this.onHideFrom,
    required this.onCloseFriends,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(0.16),
          ),
        ),
        const SizedBox(height: 8),
        _Tile(
          icon:     Icons.visibility_off_rounded,
          title:    'Hide story from',
          subtitle: 'Hide your story from a specific person',
          onTap:    onHideFrom,
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06),
            indent: 16, endIndent: 16),
        _Tile(
          icon:     Icons.star_rounded,
          title:    'Close friends',
          subtitle: 'Coming soon',
          enabled:  false,
          onTap:    onCloseFriends,
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06),
            indent: 16, endIndent: 16),
        _Tile(
          icon:       Icons.delete_forever_rounded,
          title:      'Delete story',
          subtitle:   'Permanently remove this photo',
          titleColor: Colors.redAccent,
          iconColor:  Colors.redAccent,
          onTap:      onDelete,
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final bool         enabled;
  final Color?       titleColor;
  final Color?       iconColor;
  final VoidCallback onTap;
  
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.titleColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor != null 
                ? iconColor!.withOpacity(0.12)
                : Colors.white.withOpacity(enabled ? 0.09 : 0.04),
          ),
          child: Icon(icon, color: iconColor ?? (enabled ? Colors.white : Colors.white24),
              size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: GoogleFonts.manrope(
                  color:      titleColor ?? (enabled ? Colors.white : Colors.white30),
                  fontSize:   15, fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: GoogleFonts.manrope(
                  color: Colors.white38, fontSize: 12)),
          ],
        )),
        if (!enabled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.06),
            ),
            child: Text('Soon',
                style: GoogleFonts.manrope(
                  color: Colors.white24, fontSize: 11)),
          ),
      ]),
    ),
  );
}
