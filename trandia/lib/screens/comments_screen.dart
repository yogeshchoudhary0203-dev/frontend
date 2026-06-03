import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/comment_service.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../models/chat_model.dart';
import '../utils/error_dialog.dart';
import 'glass_common.dart';

class CommentsScreen extends StatefulWidget {
  final bool dark;
  final String postUser;
  final String postDescription;
  final String postInitials;
  final Color postUserColor;
  final String? postId;
  final void Function(int newCount)? onCommentPosted;

  const CommentsScreen({
    super.key,
    required this.dark,
    required this.postUser,
    required this.postDescription,
    required this.postInitials,
    required this.postUserColor,
    this.postId,
    this.onCommentPosted,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextCursor;
  UserProfile? _myProfile;
  bool _sending = false;

  // Reply state
  String? _replyToCommentId;
  String? _replyToAuthorName;
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
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _replyBannerCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls near the bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() { _isLoading = true; _comments = []; _nextCursor = null; });
    }

    try {
      final results = await Future.wait([
        _fetchComments(cursor: null),
        UserService.getMyProfile(),
      ]);
      final result = results[0] as CommentsResult;
      final profile = results[1] as UserProfile?;
      if (!mounted) return;
      setState(() {
        _comments    = result.comments;
        _nextCursor  = result.nextCursor;
        _myProfile   = profile;
        _isLoading   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<CommentsResult> _fetchComments({String? cursor}) async {
    if (widget.postId == null || widget.postId!.isEmpty) {
      return const CommentsResult(comments: []);
    }
    return CommentService.instance.fetchComments(
      widget.postId!,
      cursor: cursor,
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _fetchComments(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _comments.addAll(result.comments);
        _nextCursor   = result.nextCursor;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Reply mode helpers ───────────────────────────────────────────────────

  void _startReply(String commentId, String authorName) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyToCommentId  = commentId;
      _replyToAuthorName = authorName;
    });
    _replyBannerCtrl.forward();
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    HapticFeedback.selectionClick();
    _replyBannerCtrl.reverse().then((_) {
      if (mounted) setState(() { _replyToCommentId = null; _replyToAuthorName = null; });
    });
  }

  // ── Post comment / reply ─────────────────────────────────────────────────

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    if (widget.postId == null || widget.postId!.isEmpty) {
      showErrorDialog(context, message: 'Cannot comment on this post.');
      return;
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    final myName     = _myProfile?.name ?? 'You';
    final myUsername = _myProfile?.username ?? '';
    final myPicture  = _myProfile?.picture;
    final myId       = _myProfile?.id ?? '';
    final isReply    = _replyToCommentId != null;
    final parentId   = _replyToCommentId;

    // ── Optimistic insert ────────────────────────────────────────────────
    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Comment(
      id:           optimisticId,
      postId:       widget.postId!,
      userId:       myId,
      userName:     myName,
      userUsername: myUsername,
      userPicture:  myPicture,
      text:         text,
      parentId:     parentId,
      createdAt:    DateTime.now(),
    );

    _commentController.clear();
    if (isReply) _cancelReply();

    setState(() {
      if (isReply && parentId != null) {
        final parentIdx = _comments.indexWhere((c) => c.id == parentId);
        if (parentIdx != -1) {
          final parent = _comments[parentIdx];
          _comments[parentIdx] = parent.copyWith(
            replies: [...parent.replies, optimistic],
          );
        }
      } else {
        _comments.add(optimistic);
      }
      _sending = false;
    });

    // Scroll to bottom after adding
    if (!isReply) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuad,
          );
        }
      });
    }

    // ── Real API call in background ─────────────────────────────────────
    try {
      final confirmed = await CommentService.instance.postComment(
        widget.postId!,
        text,
        parentId: parentId,
      );

      // Replace optimistic comment with server-confirmed one
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null) {
          final parentIdx = _comments.indexWhere((c) => c.id == parentId);
          if (parentIdx != -1) {
            final parent = _comments[parentIdx];
            final newReplies = parent.replies
                .map((r) => r.id == optimisticId ? confirmed : r)
                .toList();
            _comments[parentIdx] = parent.copyWith(replies: newReplies);
          }
        } else {
          final idx = _comments.indexWhere((c) => c.id == optimisticId);
          if (idx != -1) _comments[idx] = confirmed;
        }
      });

      // Notify parent widget of new comment count (top-level only)
      if (!isReply && widget.onCommentPosted != null) {
        widget.onCommentPosted!(_totalCount);
      }
    } on ApiException catch (e) {
      // Rollback optimistic insert on failure
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null) {
          final parentIdx = _comments.indexWhere((c) => c.id == parentId);
          if (parentIdx != -1) {
            final parent = _comments[parentIdx];
            _comments[parentIdx] = parent.copyWith(
              replies: parent.replies.where((r) => r.id != optimisticId).toList(),
            );
          }
        } else {
          _comments.removeWhere((c) => c.id == optimisticId);
        }
      });
      showErrorDialog(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == optimisticId);
      });
      showErrorDialog(context, message: 'Failed to post. Please try again.');
    }
  }

  // ── Toggle like ──────────────────────────────────────────────────────────

  Future<void> _toggleLike(String commentId) async {
    HapticFeedback.selectionClick();

    // Find the comment (top-level or reply)
    int topIdx   = -1;
    int replyIdx = -1;
    for (int i = 0; i < _comments.length; i++) {
      if (_comments[i].id == commentId) { topIdx = i; break; }
      for (int j = 0; j < _comments[i].replies.length; j++) {
        if (_comments[i].replies[j].id == commentId) { topIdx = i; replyIdx = j; break; }
      }
      if (topIdx != -1) break;
    }
    if (topIdx == -1) return;

    // Optimistic toggle
    if (replyIdx == -1) {
      final c = _comments[topIdx];
      setState(() => _comments[topIdx] = c.copyWith(
        isLiked:    !c.isLiked,
        likesCount: c.likesCount + (c.isLiked ? -1 : 1),
      ));
      try {
        if (!_comments[topIdx].isLiked) {
          await CommentService.instance.unlikeComment(commentId);
        } else {
          await CommentService.instance.likeComment(commentId);
        }
      } catch (_) {
        // Rollback
        if (mounted) setState(() => _comments[topIdx] = c);
      }
    } else {
      final parent = _comments[topIdx];
      final reply  = parent.replies[replyIdx];
      final updated = reply.copyWith(
        isLiked:    !reply.isLiked,
        likesCount: reply.likesCount + (reply.isLiked ? -1 : 1),
      );
      final newReplies = List<Comment>.from(parent.replies)..[replyIdx] = updated;
      setState(() => _comments[topIdx] = parent.copyWith(replies: newReplies));
      try {
        if (!updated.isLiked) {
          await CommentService.instance.unlikeComment(commentId);
        } else {
          await CommentService.instance.likeComment(commentId);
        }
      } catch (_) {
        // Rollback
        if (mounted) {
          final rollback = List<Comment>.from(parent.replies)..[replyIdx] = reply;
          setState(() => _comments[topIdx] = parent.copyWith(replies: rollback));
        }
      }
    }
  }

  // ── Total comment count ──────────────────────────────────────────────────

  int get _totalCount {
    int count = 0;
    for (final c in _comments) {
      count += 1 + c.replies.length;
    }
    return count;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fg     = GlassTokens.fg(widget.dark);
    final sub    = GlassTokens.sub(widget.dark);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    final navPad    = MediaQuery.paddingOf(context).bottom;

    const headerH = 66.0;
    const inputH  = 54.0;
    final headerTop    = topPad + 8;
    const replyBannerH = 36.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: widget.dark),

          // ── Comments list ─────────────────────────────────────────────
          Positioned(
            top:    headerTop + headerH,
            bottom: inputH + 16 + bottomPad + navPad,
            left:   0,
            right:  0,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(
                    color: widget.dark ? Colors.white : Colors.black))
                : RefreshIndicator(
                    onRefresh: () => _loadData(refresh: true),
                    color: widget.dark ? Colors.white : Colors.black,
                    backgroundColor: widget.dark
                        ? const Color(0xFF1C1C1F)
                        : Colors.white,
                    child: _comments.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: _buildEmptyState(sub),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: _comments.length + 2, // +1 header, +1 loader
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildOriginalPostHeader(fg, sub);
                              }
                              if (index == _comments.length + 1) {
                                return _isLoadingMore
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: widget.dark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }
                              return _buildCommentWithReplies(
                                _comments[index - 1], fg, sub);
                            },
                          ),
                  ),
          ),

          // ── Top Header ───────────────────────────────────────────────
          Positioned(
            top:   headerTop,
            left:  12,
            right: 12,
            child: GlassHeader(
              dark:    widget.dark,
              height:  headerH,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: fg, size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Comments',
                      style: manrope(size: 17, weight: FontWeight.w800,
                          color: fg, letterSpacing: -0.34)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 0.8,
                      ),
                    ),
                    child: Text('$_totalCount comments',
                        style: manrope(size: 11, weight: FontWeight.w600,
                            color: sub, letterSpacing: -0.05)),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),

          // ── Reply banner ─────────────────────────────────────────────
          Positioned(
            bottom: inputH + 16 + bottomPad + navPad,
            left:   12,
            right:  12,
            child: AnimatedBuilder(
              animation: _replyBannerAnim,
              builder: (_, __) {
                if (_replyBannerAnim.value == 0 &&
                    _replyToCommentId == null) {
                  return const SizedBox.shrink();
                }
                return ClipRect(
                  child: Align(
                    alignment:  Alignment.bottomCenter,
                    heightFactor: _replyBannerAnim.value,
                    child: Opacity(
                      opacity: _replyBannerAnim.value,
                      child: Container(
                        height: replyBannerH,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: widget.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14)),
                          border: Border(
                            top: BorderSide(
                              color: widget.dark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.black.withValues(alpha: 0.06),
                              width: 0.6,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply_rounded, size: 14, color: sub),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Replying to ${_replyToAuthorName ?? '...'}',
                                style: manrope(size: 11.5,
                                    weight: FontWeight.w600,
                                    color: sub, letterSpacing: -0.05),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelReply,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: sub),
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

          // ── Input bar ────────────────────────────────────────────────
          Positioned(
            bottom: bottomPad + navPad + 8,
            left:   12,
            right:  12,
            child: SizedBox(
              height: inputH,
              child: GlassSurface(
                dark:      widget.dark,
                radius:    999,
                padding:   const EdgeInsets.symmetric(horizontal: 6),
                blurSigma: 28,
                shadow: BoxShadow(
                  color: widget.dark
                      ? Colors.black.withValues(alpha: 0.6)
                      : const Color(0xFF14161E).withValues(alpha: 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                  spreadRadius: -16,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Container(
                      width:  36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape:    BoxShape.circle,
                        gradient: monoAvatar(widget.dark, 0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _myProfile?.name.isNotEmpty == true
                            ? _myProfile!.name[0].toUpperCase()
                            : 'Y',
                        style: manrope(size: 14, weight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller:      _commentController,
                        focusNode:       _inputFocusNode,
                        onSubmitted:     (_) => _postComment(),
                        textInputAction: TextInputAction.send,
                        style: manrope(size: 14, weight: FontWeight.w500,
                            color: fg, letterSpacing: -0.07),
                        decoration: InputDecoration(
                          hintText: _replyToCommentId != null
                              ? 'Reply to ${_replyToAuthorName ?? '...'}...'
                              : 'Add a comment...',
                          hintStyle: manrope(size: 14,
                              weight: FontWeight.w500,
                              color: sub, letterSpacing: -0.07),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _postComment,
                      child: GlassCircleButton(
                        dark:     widget.dark,
                        icon:     Icons.arrow_upward_rounded,
                        size:     38,
                        iconSize: 18,
                        bg: widget.dark
                            ? Colors.white
                            : const Color(0xFF0A0A0A),
                        fg: widget.dark
                            ? const Color(0xFF0A0A0A)
                            : Colors.white,
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

  // ── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(Color subColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline_rounded,
            size: 48, color: subColor.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('No comments yet',
            style: manrope(size: 15, weight: FontWeight.w700,
                color: GlassTokens.fg(widget.dark), letterSpacing: -0.2)),
        const SizedBox(height: 4),
        Text('Be the first to share your thoughts!',
            style: manrope(size: 12.5, weight: FontWeight.w500,
                color: subColor, letterSpacing: -0.05)),
      ],
    );
  }

  Widget _buildOriginalPostHeader(Color fgColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width:  32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.postUserColor,
                  ),
                  alignment: Alignment.center,
                  child: Text(widget.postInitials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Text(widget.postUser,
                    style: manrope(size: 13.5, weight: FontWeight.w700,
                        color: fgColor, letterSpacing: -0.15)),
                const Spacer(),
                Text('Author',
                    style: manrope(size: 10.5, weight: FontWeight.w600,
                        color: subColor.withValues(alpha: 0.7),
                        letterSpacing: 0.2)),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.postDescription,
                style: manrope(size: 13, weight: FontWeight.w500,
                    color: fgColor.withValues(alpha: 0.85),
                    height: 1.45, letterSpacing: -0.05)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentWithReplies(
      Comment comment, Color fgColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentRow(comment, fgColor, subColor, isReply: false),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 0),
            child: Column(
              children: comment.replies
                  .map((r) => _buildCommentRow(r, fgColor, subColor,
                      isReply: true))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow(Comment comment, Color fgColor, Color subColor,
      {required bool isReply}) {
    final isLiked       = comment.isLiked;
    final likedColor    = widget.dark
        ? const Color(0xFFFF3040)
        : const Color(0xFFED4956);
    final accentReplyColor = widget.dark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.40);

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 6 : 12),
      child: GlassSurface(
        dark:    widget.dark,
        radius:  isReply ? 14 : 18,
        padding: EdgeInsets.all(isReply ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width:  isReply ? 28 : 34,
                  height: isReply ? 28 : 34,
                  decoration: BoxDecoration(
                    shape:    BoxShape.circle,
                    gradient: monoAvatar(
                        widget.dark, comment.userName.hashCode),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    comment.initials,
                    style: manrope(
                        size:   isReply ? 9 : 11,
                        weight: FontWeight.w700,
                        color:  Colors.white,
                        letterSpacing: -0.2),
                  ),
                ),
                SizedBox(width: isReply ? 8 : 10),

                // Name + text
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
                                size: 12, color: accentReplyColor),
                            ),
                          Flexible(
                            child: Text(comment.userName,
                                style: manrope(
                                    size:   isReply ? 12 : 13,
                                    weight: FontWeight.w700,
                                    color:  fgColor,
                                    letterSpacing: -0.1),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Text(comment.timeAgo,
                              style: manrope(
                                  size:   isReply ? 10 : 11,
                                  weight: FontWeight.w500,
                                  color:  subColor,
                                  letterSpacing: -0.05)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.text,
                          style: manrope(
                              size:   isReply ? 11.5 : 12.5,
                              weight: FontWeight.w500,
                              color:  fgColor.withValues(alpha: 0.85),
                              height: 1.4,
                              letterSpacing: -0.05)),
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
                      key:    ValueKey(isLiked),
                      width:  isReply ? 24 : 28,
                      height: isReply ? 24 : 28,
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: isLiked
                            ? likedColor
                            : subColor.withValues(alpha: 0.6),
                        size: isReply ? 15 : 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Reply button
            if (!isReply) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _startReply(comment.id, comment.userName),
                child: Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 13, color: accentReplyColor),
                      const SizedBox(width: 4),
                      Text('Reply',
                          style: manrope(
                              size:   11,
                              weight: FontWeight.w700,
                              color:  accentReplyColor,
                              letterSpacing: 0.1)),
                      if (comment.replies.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width:  3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentReplyColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${comment.replies.length} '
                          '${comment.replies.length == 1 ? 'reply' : 'replies'}',
                          style: manrope(
                              size:   10.5,
                              weight: FontWeight.w600,
                              color:  accentReplyColor,
                              letterSpacing: -0.05),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _startReply(
                  comment.parentId ?? comment.id,
                  comment.userName,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text('Reply',
                      style: manrope(
                          size:   10.5,
                          weight: FontWeight.w700,
                          color:  accentReplyColor,
                          letterSpacing: 0.1)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
