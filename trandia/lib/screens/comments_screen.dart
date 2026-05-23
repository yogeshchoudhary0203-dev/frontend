import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/comment_service.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../models/chat_model.dart';
import 'glass_common.dart';

class CommentsScreen extends StatefulWidget {
  final bool dark;
  final String postUser;
  final String postDescription;
  final String postInitials;
  final Color postUserColor;

  const CommentsScreen({
    super.key,
    required this.dark,
    required this.postUser,
    required this.postDescription,
    required this.postInitials,
    required this.postUserColor,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  List<LocalComment> _comments = [];
  bool _isLoading = true;
  UserProfile? _myProfile;
  bool _sending = false;

  // Reply state
  String? _replyToCommentId;   // comment id being replied to
  String? _replyToAuthorName;  // author name shown in reply hint
  late AnimationController _replyBannerCtrl;
  late Animation<double> _replyBannerAnim;

  @override
  void initState() {
    super.initState();
    _replyBannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _replyBannerAnim = CurvedAnimation(
      parent: _replyBannerCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _replyBannerCtrl.dispose();
    // No socket rooms to leave — this screen uses local storage only.
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load current user profile in parallel with comments
      final results = await Future.wait([
        CommentService.getComments(widget.postUser, widget.postDescription),
        UserService.getMyProfile(),
      ]);

      final loadedComments = results[0] as List<LocalComment>;
      final userProfile = results[1] as UserProfile?;

      // Double check liked state from SharedPreferences for mock comments
      final finalComments = <LocalComment>[];
      for (var c in loadedComments) {
        if (c.id.startsWith('mock_')) {
          final isLiked = await CommentService.isMockCommentLiked(c.id);
          // Also check replies
          final updatedReplies = <LocalComment>[];
          for (var r in c.replies) {
            if (r.id.startsWith('mock_')) {
              final rLiked = await CommentService.isMockCommentLiked(r.id);
              updatedReplies.add(r.copyWith(isLiked: rLiked));
            } else {
              updatedReplies.add(r);
            }
          }
          finalComments.add(c.copyWith(isLiked: isLiked, replies: updatedReplies));
        } else {
          finalComments.add(c);
        }
      }

      if (mounted) {
        setState(() {
          _comments = finalComments;
          _myProfile = userProfile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Reply mode helpers ──────────────────────────────────────────────────

  void _startReply(String commentId, String authorName) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyToCommentId = commentId;
      _replyToAuthorName = authorName;
    });
    _replyBannerCtrl.forward();
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    HapticFeedback.selectionClick();
    _replyBannerCtrl.reverse().then((_) {
      if (mounted) {
        setState(() {
          _replyToCommentId = null;
          _replyToAuthorName = null;
        });
      }
    });
  }

  // ── Post comment or reply ───────────────────────────────────────────────

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    // ✅ JWT auth check before posting
    final isAuthed = await CommentService.isAuthenticated();
    if (!isAuthed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please sign in to comment.'),
            backgroundColor: widget.dark ? const Color(0xFF2A2A2D) : null,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() {
      _sending = true;
    });

    final myName = _myProfile?.name ?? 'You';
    final myInitials = myName.isNotEmpty
        ? myName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'YO';

    HapticFeedback.mediumImpact();

    final isReply = _replyToCommentId != null;

    try {
      if (isReply) {
        // ── Save reply ──
        final reply = await CommentService.saveReply(
          widget.postUser,
          widget.postDescription,
          _replyToCommentId!,
          text,
          myName,
          myInitials,
        );

        _commentController.clear();
        _cancelReply();

        // Optimistically insert reply into the local state
        if (mounted) {
          setState(() {
            final parentIdx = _comments.indexWhere((c) => c.id == reply.parentId);
            if (parentIdx != -1) {
              final parent = _comments[parentIdx];
              _comments[parentIdx] = parent.copyWith(
                replies: [...parent.replies, reply],
              );
            }
            _sending = false;
          });
        }
      } else {
        // ── Save top-level comment ──
        await CommentService.saveComment(
          widget.postUser,
          widget.postDescription,
          text,
          myName,
          myInitials,
        );

        // Optimistic locally added comment
        final newComment = LocalComment(
          id: 'user_comment_${DateTime.now().millisecondsSinceEpoch}',
          authorName: myName,
          authorInitials: myInitials,
          text: text,
          timeAgo: 'just now',
        );

        _commentController.clear();

        if (mounted) {
          setState(() {
            _comments.add(newComment);
            _sending = false;
          });

          // Scroll to the bottom to show the new comment
          Future.delayed(const Duration(milliseconds: 150), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuad,
              );
            }
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: widget.dark ? const Color(0xFF2A2A2D) : null,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post. Please try again.')),
        );
      }
    }
  }

  Future<void> _toggleLike(String commentId) async {
    HapticFeedback.selectionClick();

    // Find in top-level or nested replies
    int topIdx = -1;
    int replyIdx = -1;
    for (int i = 0; i < _comments.length; i++) {
      if (_comments[i].id == commentId) {
        topIdx = i;
        break;
      }
      for (int j = 0; j < _comments[i].replies.length; j++) {
        if (_comments[i].replies[j].id == commentId) {
          topIdx = i;
          replyIdx = j;
          break;
        }
      }
      if (topIdx != -1) break;
    }
    if (topIdx == -1) return;

    if (replyIdx == -1) {
      // Top-level comment like
      final comment = _comments[topIdx];
      final updated = comment.copyWith(isLiked: !comment.isLiked);
      setState(() => _comments[topIdx] = updated);
      try {
        await CommentService.toggleCommentLike(
          widget.postUser, widget.postDescription, commentId,
        );
      } catch (_) {
        if (mounted) setState(() => _comments[topIdx] = comment);
      }
    } else {
      // Reply like
      final parent = _comments[topIdx];
      final reply = parent.replies[replyIdx];
      final updatedReply = reply.copyWith(isLiked: !reply.isLiked);
      final newReplies = List<LocalComment>.from(parent.replies);
      newReplies[replyIdx] = updatedReply;
      setState(() => _comments[topIdx] = parent.copyWith(replies: newReplies));
      try {
        await CommentService.toggleCommentLike(
          widget.postUser, widget.postDescription, commentId,
        );
      } catch (_) {
        if (mounted) {
          newReplies[replyIdx] = reply;
          setState(() => _comments[topIdx] = parent.copyWith(replies: newReplies));
        }
      }
    }
  }

  // ── Total comments + replies count ──────────────────────────────────────

  int get _totalCount {
    int count = 0;
    for (final c in _comments) {
      count += 1 + c.replies.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    final navPad = MediaQuery.paddingOf(context).bottom;

    const headerH = 66.0;
    const inputH = 54.0;
    final headerTop = topPad + 8;
    final replyBannerH = 36.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          // Theme-matching blur backdrop
          GlassBackdrop(dark: widget.dark),

          // Main Comments List
          Positioned(
            top: headerTop + headerH,
            bottom: inputH + 16 + bottomPad + navPad,
            left: 0,
            right: 0,
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.dark ? Colors.white : Colors.black,
                    ),
                  )
                : _comments.isEmpty
                    ? _buildEmptyState(sub)
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _comments.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildOriginalPostHeader(fg, sub);
                          }
                          final comment = _comments[index - 1];
                          return _buildCommentWithReplies(comment, fg, sub);
                        },
                      ),
          ),

          // Top Header Bar
          Positioned(
            top: headerTop,
            left: 12,
            right: 12,
            child: GlassHeader(
              dark: widget.dark,
              height: headerH,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Comments',
                    style: manrope(
                      size: 17,
                      weight: FontWeight.w800,
                      color: fg,
                      letterSpacing: -0.34,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$_totalCount comments',
                      style: manrope(
                        size: 11,
                        weight: FontWeight.w600,
                        color: sub,
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),

          // ── Reply banner (shows who you're replying to) ──
          Positioned(
            bottom: inputH + 16 + bottomPad + navPad,
            left: 12,
            right: 12,
            child: AnimatedBuilder(
              animation: _replyBannerAnim,
              builder: (_, __) {
                if (_replyBannerAnim.value == 0 && _replyToCommentId == null) {
                  return const SizedBox.shrink();
                }
                return ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: _replyBannerAnim.value,
                    child: Opacity(
                      opacity: _replyBannerAnim.value,
                      child: Container(
                        height: replyBannerH,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: widget.dark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: widget.dark
                                  ? Colors.white.withOpacity(0.10)
                                  : Colors.black.withOpacity(0.06),
                              width: 0.6,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 14,
                              color: sub,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Replying to ${_replyToAuthorName ?? '...'}',
                                style: manrope(
                                  size: 11.5,
                                  weight: FontWeight.w600,
                                  color: sub,
                                  letterSpacing: -0.05,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelReply,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: sub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Send Input Bar
          Positioned(
            bottom: bottomPad + navPad + 8,
            left: 12,
            right: 12,
            child: SizedBox(
              height: inputH,
              child: GlassSurface(
                dark: widget.dark,
                radius: 999,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                blurSigma: 28,
                shadow: BoxShadow(
                  color: widget.dark
                      ? Colors.black.withOpacity(0.6)
                      : const Color(0xFF14161E).withOpacity(0.20),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                  spreadRadius: -16,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    // User Avatar/Initials
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: monoAvatar(widget.dark, 0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _myProfile?.name.isNotEmpty == true
                            ? _myProfile!.name[0].toUpperCase()
                            : 'Y',
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _inputFocusNode,
                        onSubmitted: (_) => _postComment(),
                        textInputAction: TextInputAction.send,
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w500,
                          color: fg,
                          letterSpacing: -0.07,
                        ),
                        decoration: InputDecoration(
                          hintText: _replyToCommentId != null
                              ? 'Reply to ${_replyToAuthorName ?? '...'}...'
                              : 'Add a comment...',
                          hintStyle: manrope(
                            size: 14,
                            weight: FontWeight.w500,
                            color: sub,
                            letterSpacing: -0.07,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _postComment,
                      child: GlassCircleButton(
                        dark: widget.dark,
                        icon: Icons.arrow_upward_rounded,
                        size: 38,
                        iconSize: 18,
                        bg: widget.dark ? Colors.white : const Color(0xFF0A0A0A),
                        fg: widget.dark ? const Color(0xFF0A0A0A) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color subColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 48,
          color: subColor.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'No comments yet',
          style: manrope(
            size: 15,
            weight: FontWeight.w700,
            color: GlassTokens.fg(widget.dark),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Be the first to share your thoughts!',
          style: manrope(
            size: 12.5,
            weight: FontWeight.w500,
            color: subColor,
            letterSpacing: -0.05,
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalPostHeader(Color fgColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.dark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.postUserColor,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.postInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.postUser,
                  style: manrope(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: fgColor,
                    letterSpacing: -0.15,
                  ),
                ),
                const Spacer(),
                Text(
                  'Author',
                  style: manrope(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: subColor.withOpacity(0.7),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.postDescription,
              style: manrope(
                size: 13,
                weight: FontWeight.w500,
                color: fgColor.withOpacity(0.85),
                height: 1.45,
                letterSpacing: -0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Comment + nested replies widget ─────────────────────────────────────

  Widget _buildCommentWithReplies(LocalComment comment, Color fgColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentRow(comment, fgColor, subColor, isReply: false),
        // Replies (max 1 level — enforced server-side)
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 0),
            child: Column(
              children: comment.replies.map((reply) {
                return _buildCommentRow(reply, fgColor, subColor, isReply: true);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow(LocalComment comment, Color fgColor, Color subColor,
      {required bool isReply}) {
    final isLiked = comment.isLiked;
    final likedColor = widget.dark ? const Color(0xFFFF3040) : const Color(0xFFED4956);
    final accentReplyColor = widget.dark
        ? Colors.white.withOpacity(0.45)
        : Colors.black.withOpacity(0.40);

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 6 : 12),
      child: GlassSurface(
        dark: widget.dark,
        radius: isReply ? 14 : 18,
        padding: EdgeInsets.all(isReply ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User initials avatar
                Container(
                  width: isReply ? 28 : 34,
                  height: isReply ? 28 : 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: monoAvatar(widget.dark, comment.authorName.hashCode),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    comment.authorInitials,
                    style: manrope(
                      size: isReply ? 9 : 11,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                SizedBox(width: isReply ? 8 : 10),
                // Comment text & info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isReply)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 12,
                                color: accentReplyColor,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              comment.authorName,
                              style: manrope(
                                size: isReply ? 12 : 13,
                                weight: FontWeight.w700,
                                color: fgColor,
                                letterSpacing: -0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            comment.timeAgo,
                            style: manrope(
                              size: isReply ? 10 : 11,
                              weight: FontWeight.w500,
                              color: subColor,
                              letterSpacing: -0.05,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.text,
                        style: manrope(
                          size: isReply ? 11.5 : 12.5,
                          weight: FontWeight.w500,
                          color: fgColor.withOpacity(0.85),
                          height: 1.4,
                          letterSpacing: -0.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Like button
                GestureDetector(
                  onTap: () => _toggleLike(comment.id),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: SizedBox(
                      key: ValueKey(isLiked),
                      width: isReply ? 24 : 28,
                      height: isReply ? 24 : 28,
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: isLiked
                            ? likedColor
                            : subColor.withOpacity(0.6),
                        size: isReply ? 15 : 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Reply button row
            if (!isReply) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _startReply(comment.id, comment.authorName),
                child: Padding(
                  padding: EdgeInsets.only(left: isReply ? 36 : 44),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 13,
                        color: accentReplyColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: manrope(
                          size: 11,
                          weight: FontWeight.w700,
                          color: accentReplyColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (comment.replies.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentReplyColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'}',
                          style: manrope(
                            size: 10.5,
                            weight: FontWeight.w600,
                            color: accentReplyColor,
                            letterSpacing: -0.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Reply button for replies too (tapping attaches to root parent)
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _startReply(
                  comment.parentId ?? comment.id, // attach to root parent (1-level enforcement)
                  comment.authorName,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    'Reply',
                    style: manrope(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: accentReplyColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
