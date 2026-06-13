// lib/widgets/profile/profile_posts_box.dart
// Posts grid box + post card modal shown on grid tile tap.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/glass_common.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../models/archived_media_model.dart';
import 'profile_video_thumbnail.dart';


/// Wider tonal range tile gradient.
LinearGradient profileTileGradient(bool dark, int i) {
  final double a, b;
  if (dark) {
    a = (22 - (i % 5) * 3).toDouble();
    b = (a - 12).clamp(4, 100).toDouble();
  } else {
    a = (92 - (i % 5) * 4).toDouble();
    b = (a - 18).clamp(56, 100).toDouble();
  }
  final begin = (i % 4 == 0)
      ? Alignment.topLeft
      : (i % 4 == 1)
      ? Alignment.topCenter
      : (i % 4 == 2)
      ? Alignment.topRight
      : Alignment.centerLeft;
  final end = (i % 4 == 0)
      ? Alignment.bottomRight
      : (i % 4 == 1)
      ? Alignment.bottomCenter
      : (i % 4 == 2)
      ? Alignment.bottomLeft
      : Alignment.centerRight;
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [
      HSLColor.fromAHSL(1, 0, 0, a / 100).toColor(),
      HSLColor.fromAHSL(1, 0, 0, b / 100).toColor(),
    ],
  );
}

// ── Posts box (glass surface wrapping the grid) ────────────────

class ProfilePostsBox extends StatefulWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

  const ProfilePostsBox({
    super.key,
    required this.dark,
    required this.fg,
    required this.sub,
    required this.posts,
    required this.isLoading,
    this.isLoadingMore = false,
    this.myUserId,
    this.onPostDeleted,
  });

  @override
  State<ProfilePostsBox> createState() => _ProfilePostsBoxState();
}

class _ProfilePostsBoxState extends State<ProfilePostsBox> {
  String _activeTab = 'Posts';
  List<ArchivedMedia> _archives = [];
  bool _archivesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArchivesCount();
  }

  Future<void> _loadArchivesCount() async {
    try {
      final res = await UserService.getArchivedMedia();
      if (mounted) {
        setState(() {
          _archives = res;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadArchives() async {
    setState(() => _archivesLoading = true);
    try {
      final res = await UserService.getArchivedMedia();
      if (mounted) {
        setState(() {
          _archives = res;
          _archivesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _archivesLoading = false);
    }
  }

  Widget _buildTabButton(String tabName, int count) {
    final isSelected = _activeTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabName;
        });
        if (tabName == 'Archive') {
          _loadArchives();
        } else {
          _loadArchivesCount();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tabName,
                style: manrope(
                  size: 15,
                  weight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? widget.fg : widget.sub,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.fg.withValues(alpha: 0.12)
                      : widget.sub.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: manrope(
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: isSelected ? widget.fg : widget.sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: 32,
            decoration: BoxDecoration(
              color: isSelected ? widget.fg : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullscreenArchiveViewer(BuildContext context, ArchivedMedia item) {
    final isVideo = item.mediaType == 'video';
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: widget.dark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVideo ? 'Archived Video' : 'Archived Photo',
                        style: manrope(
                          size: 15,
                          weight: FontWeight.w700,
                          color: GlassTokens.fg(widget.dark),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete from Archive?'),
                                  content: const Text('Are you sure you want to permanently delete this media from your archive?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final deleted = await UserService.deleteArchivedMedia(item.id);
                                if (deleted && mounted) {
                                  Navigator.pop(ctx);
                                  _loadArchives();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Removed from Archive'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent.withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, size: 20, color: Colors.redAccent),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                              ),
                              child: Icon(Icons.close_rounded, size: 18, color: GlassTokens.fg(widget.dark)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Media Content
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: isVideo
                          ? _ArchiveVideoPlayer(url: item.mediaUrl)
                          : CachedNetworkImage(
                              imageUrl: item.mediaUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Text('Could not load image'),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: widget.dark,
      radius: 28,
      padding: const EdgeInsets.all(10),
      blurSigma: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Row(
              children: [
                _buildTabButton('Posts', widget.posts.length),
                const SizedBox(width: 24),
                _buildTabButton('Archive', _archives.length),
              ],
            ),
          ),
          if (_activeTab == 'Posts') ...[
            if (widget.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(widget.fg),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (widget.posts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No posts yet',
                    style: manrope(size: 14, weight: FontWeight.w500, color: widget.sub),
                  ),
                ),
              )
            else ...[
              ProfilePostsGrid(
                dark: widget.dark,
                posts: widget.posts,
                myUserId: widget.myUserId,
                onPostDeleted: widget.onPostDeleted,
              ),
              if (widget.isLoadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(widget.fg),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ] else ...[
            if (_archivesLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(widget.fg),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_archives.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No archived media yet',
                    style: manrope(size: 14, weight: FontWeight.w500, color: widget.sub),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: _archives.length,
                itemBuilder: (context, i) {
                  final item = _archives[i];
                  final isVideo = item.mediaType == 'video';
                  return GestureDetector(
                    onTap: () {
                      _showFullscreenArchiveViewer(context, item);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: profileTileGradient(widget.dark, i),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isVideo)
                              Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: Icon(Icons.videocam_rounded, color: Colors.white, size: 28),
                                ),
                              )
                            else
                              CachedNetworkImage(
                                imageUrl: item.mediaUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.black12),
                                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                              ),
                            if (isVideo)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}


// ── 3-column grid ──────────────────────────────────────────────

class ProfilePostsGrid extends StatelessWidget {
  final bool dark;
  final List<PostModel> posts;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

  const ProfilePostsGrid({
    super.key,
    required this.dark,
    required this.posts,
    this.myUserId,
    this.onPostDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) => ProfilePostTile(
        post: posts[i],
        i: i,
        dark: dark,
        myUserId: myUserId,
        onDeleted: () => onPostDeleted?.call(posts[i].id),
      ),
    );
  }
}

// ── Individual tile ────────────────────────────────────────────

class ProfilePostTile extends StatelessWidget {
  final PostModel post;
  final int i;
  final bool dark;
  final String? myUserId;
  final VoidCallback? onDeleted;

  const ProfilePostTile({
    super.key,
    required this.post,
    required this.i,
    required this.dark,
    this.myUserId,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = post.mediaType == 'video';
    final imageUrl =
        isVideo && post.thumbnailUrl != null ? post.thumbnailUrl! : post.mediaUrl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'post_card',
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => ProfilePostCardModal(
            post: post,
            myUserId: myUserId,
            onDeleted: onDeleted,
          ),
          transitionBuilder: (ctx, anim, _, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutBack,
            );
            return FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(gradient: profileTileGradient(dark, i)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!isVideo)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                )
              else if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
                Image.network(
                  post.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      ProfileVideoThumbnailTile(videoUrl: post.mediaUrl),
                )
              else
                ProfileVideoThumbnailTile(videoUrl: post.mediaUrl),
              if (isVideo)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        color: Colors.black.withValues(alpha: 0.42),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Post card modal ────────────────────────────────────────────

class ProfilePostCardModal extends StatefulWidget {
  final PostModel post;
  final String? myUserId;
  final VoidCallback? onDeleted;

  const ProfilePostCardModal({
    super.key,
    required this.post,
    this.myUserId,
    this.onDeleted,
  });

  @override
  State<ProfilePostCardModal> createState() => _ProfilePostCardModalState();
}

class _ProfilePostCardModalState extends State<ProfilePostCardModal> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _liked = false;
  late int _likesCount;
  bool _muted = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    if (widget.post.isVideo) {
      _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.mediaUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _videoReady = true);
            _videoCtrl!.play();
          }
        });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    if (_liked) {
      PostService.instance.likePost(widget.post.id);
    } else {
      PostService.instance.unlikePost(widget.post.id);
    }
  }

  void _openComments() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/comments', arguments: widget.post.id);
  }

  bool get _isOwner =>
      widget.myUserId != null && widget.post.userId == widget.myUserId;

  void _showOptions() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              if (_isOwner)
                _OptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Post',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.of(sheetCtx, rootNavigator: true).pop();
                    _confirmDelete();
                  },
                ),
              _OptionTile(
                icon: Icons.copy_outlined,
                label: 'Copy Link',
                color: dark ? Colors.white : Colors.black87,
                onTap: () {
                  Navigator.of(sheetCtx, rootNavigator: true).pop();
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    if (!mounted) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete Post?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'This will permanently delete the post. This cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await _executeDelete();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeDelete() async {
    if (!mounted || widget.post.id.isEmpty) return;
    if (mounted) setState(() => _deleting = true);
    try {
      await PostService.instance.deletePost(widget.post.id);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        widget.onDeleted?.call();
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delete Failed',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              e.toString().replaceFirst('ApiException: ', ''),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF00E676)),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width * 0.88;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-0.015),
                child: Container(
                  width: cardW,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.07),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.40),
                        blurRadius: 42,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.05),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),
                          _buildMedia(cardW),
                          _buildActions(),
                          if (widget.post.caption.isNotEmpty) _buildCaption(),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.50),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: widget.post.userPicture != null
                  ? Image.network(
                      widget.post.userPicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarFallback(widget.post.userName),
                    )
                  : _avatarFallback(widget.post.userName),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  '@${widget.post.userUsername}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.post.timeAgo,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _showOptions,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: Colors.white24,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildMedia(double cardW) {
    final isVideo = widget.post.isVideo;
    final thumbUrl = isVideo && widget.post.thumbnailUrl != null
        ? widget.post.thumbnailUrl!
        : widget.post.mediaUrl;
    final mediaH = cardW - 24;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: cardW - 24,
        height: mediaH,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black26),
            ),
            if (isVideo && _videoReady && _videoCtrl != null)
              GestureDetector(
                onTap: () => setState(() {
                  _videoCtrl!.value.isPlaying
                      ? _videoCtrl!.pause()
                      : _videoCtrl!.play();
                }),
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoCtrl!.value.size.width,
                      height: _videoCtrl!.value.size.height,
                      child: VideoPlayer(_videoCtrl!),
                    ),
                  ),
                ),
              ),
            if (isVideo && !_videoReady)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            if (isVideo && _videoReady && _videoCtrl != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoCtrl!,
                builder: (_, val, __) {
                  if (val.isPlaying) return const SizedBox.shrink();
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            if (isVideo && _videoReady)
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _muted = !_muted;
                    _videoCtrl!.setVolume(_muted ? 0 : 1);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          _ActionBtn(
            icon: _liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor:
                _liked ? const Color(0xFFFF4D6D) : Colors.white,
            label: _fmtCount(_likesCount),
            onTap: _toggleLike,
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.mode_comment_outlined,
            iconColor: Colors.white,
            label: _fmtCount(widget.post.commentsCount),
            onTap: _openComments,
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.send_rounded,
            iconColor: Colors.white,
            label: _fmtCount(widget.post.sharesCount),
            onTap: () => HapticFeedback.selectionClick(),
          ),
          const Spacer(),
          _ActionBtn(
            icon: Icons.bookmark_border_rounded,
            iconColor: Colors.white,
            label: '',
            onTap: () => HapticFeedback.selectionClick(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Text(
        widget.post.caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }
}

// ── Action button ──────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Options bottom sheet tile ──────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ArchiveVideoPlayer extends StatefulWidget {
  final String url;
  const _ArchiveVideoPlayer({required this.url});

  @override
  State<_ArchiveVideoPlayer> createState() => _ArchiveVideoPlayerState();
}

class _ArchiveVideoPlayerState extends State<_ArchiveVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Text("Could not play video", style: TextStyle(color: Colors.white)));
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.white)),
        ],
      ),
    );
  }
}

