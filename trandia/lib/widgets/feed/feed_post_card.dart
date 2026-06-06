import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../screens/comments_screen.dart';
import '../../screens/liked_by_screen.dart';
import '../../screens/user_profile_screen.dart' as user_profile;
import '../../services/post_service.dart';
import '../../utils/share_helper.dart';
import '../shared/home_shared.dart';
import 'video_card.dart';

// ═════════════════════════════════════════════════════
//  POST CARD
// ═════════════════════════════════════════════════════

class PostCard extends StatefulWidget {
  final PostModel post;
  final bool isDark;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final ValueChanged<PostModel>? onLearnWatched;
  final int postIndex;
  final List<PostModel> allPosts;
  const PostCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.onLike,
    required this.onSave,
    this.onLearnWatched,
    required this.postIndex,
    required this.allPosts,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;
  late int _commentsCount;

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.post.commentsCount;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.commentsCount != widget.post.commentsCount) {
      _commentsCount = widget.post.commentsCount;
    }
  }

  Color _avatarColor(String userId) {
    const colors = [Color(0xFF2D3561), Color(0xFF1B4332), Color(0xFF3D0C11), Color(0xFF2C2C54), Color(0xFF1A1A2E), Color(0xFF0D3349)];
    return colors[userId.hashCode.abs() % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _openUserProfile() {
    final p = widget.post;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => user_profile.ProfileScreen(
        userId: p.userId,
        username: p.userUsername.isNotEmpty ? p.userUsername : p.userName,
        displayName: p.userName, handle: p.userUsername, initialFollowing: false,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p    = widget.post;
    final dark = widget.isDark;
    final Color border      = (dark ? Colors.white : Colors.black).op(0.12);
    final Color textPrimary = (dark ? Colors.white : Colors.black).op(0.90);
    final Color textSub     = (dark ? Colors.white : Colors.black).op(0.45);
    final Color iconCol     = (dark ? Colors.white : Colors.black).op(0.80);
    final Color likedCol    = dark ? const Color(0xFFFF3040) : const Color(0xFFED4956);
    final avatarBg          = _avatarColor(p.userId);

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(children: [
            GestureDetector(
              onTap: _openUserProfile, behavior: HitTestBehavior.opaque,
              child: Row(children: [
                Container(width: 30, height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg, border: Border.all(color: border, width: 0.8)),
                  child: ClipOval(child: p.userPicture != null
                    ? CachedNetworkImage(imageUrl: p.userPicture!, fit: BoxFit.cover,
                        fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                        placeholderFadeInDuration: Duration.zero,
                        placeholder: (_, __) => Center(child: Text(_initials(p.userName), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
                        errorWidget: (_, __, ___) => Center(child: Text(_initials(p.userName), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))))
                    : Center(child: Text(_initials(p.userName), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))))),
                const SizedBox(width: 8),
                Text(p.userName, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text(p.timeAgo, style: TextStyle(color: textSub, fontSize: 11)),
          ])),

        p.isVideo
            ? VideoCard(
                post: p,
                isDark: dark,
                postIndex: widget.postIndex,
                allPosts: widget.allPosts,
                onLearnWatched: widget.onLearnWatched,
              )
            : AspectRatio(aspectRatio: p.aspectRatio,
                child: InteractiveViewer(clipBehavior: Clip.none, minScale: 1.0, maxScale: 4.0,
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(imageUrl: p.mediaUrl, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                      errorWidget: (_, __, ___) => Container(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        child: Icon(Icons.broken_image_outlined, color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.25)))),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.op(0.18)]))),
                  ]))),

        Padding(padding: const EdgeInsets.fromLTRB(8, 8, 10, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ActionStat(count: '${p.likesCount}', color: textPrimary,
              icon: _LikeButton(
                isLiked: p.isLiked,
                onTap: () { HapticFeedback.lightImpact(); widget.onLike(); },
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, animation, __) => LikedByScreen(dark: dark, postUser: p.userName, likeCount: p.likesCount, postId: p.id),
                    transitionDuration: const Duration(milliseconds: 380),
                    reverseTransitionDuration: const Duration(milliseconds: 300),
                    transitionsBuilder: (_, animation, __, child) {
                      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
                      return SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
                        child: FadeTransition(opacity: curved, child: child));
                    },
                  ));
                },
                likedColor: likedCol, iconColor: iconCol,
              )),
            const SizedBox(width: 12),
            _ActionStat(count: '$_commentsCount', color: textPrimary,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, animation, __) => CommentsScreen(
                    dark: dark, postUser: p.userName, postDescription: p.caption,
                    postInitials: _initials(p.userName), postUserColor: avatarBg, postId: p.id,
                    onCommentPosted: (newCount) { if (mounted) setState(() => _commentsCount = newCount); },
                  ),
                  transitionDuration: const Duration(milliseconds: 380),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) {
                    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
                    return SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
                      child: FadeTransition(opacity: curved, child: child));
                  },
                ));
              },
              icon: SizedBox(width: 26, height: 26, child: CustomPaint(painter: _CommentBubblePainter(color: iconCol)))),
            const SizedBox(width: 12),
            _ActionStat(count: '${p.sharesCount}', color: textPrimary,
              onTap: () { HapticFeedback.lightImpact(); ShareHelper.showShareBottomSheet(context, p); },
              icon: Icon(Icons.near_me_rounded, size: 26, color: iconCol)),
            const Spacer(),
            SizedBox(width: 34, height: 32,
              child: Center(
                child: _SaveButton(
                  isSaved: p.isSaved,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSave();
                  },
                  iconColor: iconCol,
                ),
              )),
          ])),

        if (p.caption.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: GestureDetector(
              onTap: () { setState(() => _expanded = !_expanded); HapticFeedback.selectionClick(); },
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic, alignment: Alignment.topCenter,
                child: _expanded
                    ? Text.rich(TextSpan(children: [
                        TextSpan(text: '${p.userName} ', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        TextSpan(text: p.caption, style: TextStyle(color: textPrimary.op(0.85), fontSize: 13, height: 1.45)),
                      ]))
                    : Text.rich(TextSpan(children: [
                        TextSpan(text: '${p.userName} ', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        TextSpan(text: p.caption, style: TextStyle(color: textPrimary.op(0.85), fontSize: 13, height: 1.45)),
                      ]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ))),
        if (p.caption.isEmpty) const SizedBox(height: 10),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════
//  ACTION WIDGETS + PAINTERS
// ═════════════════════════════════════════════════════

class _ActionStat extends StatelessWidget {
  final Widget icon;
  final String count;
  final Color color;
  final VoidCallback? onTap;
  const _ActionStat({required this.icon, required this.count, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 34, height: 44,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 28, height: 28, child: Center(child: icon)),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          switchInCurve: Curves.easeOut, switchOutCurve: Curves.easeIn,
          child: Text(count, key: ValueKey<String>(count), maxLines: 1,
            overflow: TextOverflow.fade, softWrap: false, textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 11.5, height: 1.0, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
    if (onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }
}

class _LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color likedColor, iconColor;
  const _LikeButton({required this.isLiked, required this.onTap, this.onLongPress, required this.likedColor, required this.iconColor});
  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.35, end: 0.9).chain(CurveTween(curve: Curves.easeIn)), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    ]).animate(_controller);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { widget.onTap(); _controller.forward(from: 0.0); },
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scaleAnimation,
        child: SizedBox(width: 26, height: 26,
          child: CustomPaint(painter: _IgHeartPainter(color: widget.isLiked ? widget.likedColor : widget.iconColor, filled: widget.isLiked)))),
    );
  }
}

class _IgHeartPainter extends CustomPainter {
  final Color color;
  final bool filled;
  const _IgHeartPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 26.0;
    final sy = size.height / 26.0;
    final path = Path()
      ..moveTo(13.0 * sx, 23.0 * sy)
      ..cubicTo(6.0 * sx, 19.0 * sy, 1.0 * sx, 14.0 * sy, 1.0 * sx, 9.5 * sy)
      ..cubicTo(1.0 * sx, 5.0 * sy, 4.5 * sx, 2.5 * sy, 7.5 * sx, 2.5 * sy)
      ..cubicTo(10.0 * sx, 2.5 * sy, 12.0 * sx, 4.0 * sy, 13.0 * sx, 6.0 * sy)
      ..cubicTo(14.0 * sx, 4.0 * sy, 16.0 * sx, 2.5 * sy, 18.5 * sx, 2.5 * sy)
      ..cubicTo(21.5 * sx, 2.5 * sy, 25.0 * sx, 5.0 * sy, 25.0 * sx, 9.5 * sy)
      ..cubicTo(25.0 * sx, 14.0 * sy, 20.0 * sx, 19.0 * sy, 13.0 * sx, 23.0 * sy)
      ..close();
    if (filled) {
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_IgHeartPainter o) => o.color != color || o.filled != filled;
}

class _CommentBubblePainter extends CustomPainter {
  final Color color;
  const _CommentBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 26.0;
    final sy = size.height / 26.0;
    final bounds = Offset.zero & size;
    final bubble = Path()
      ..moveTo(8.0 * sx, 4.0 * sy)..lineTo(18.0 * sx, 4.0 * sy)
      ..cubicTo(22.0 * sx, 4.0 * sy, 24.0 * sx, 7.0 * sy, 24.0 * sx, 11.0 * sy)
      ..lineTo(24.0 * sx, 15.0 * sy)
      ..cubicTo(24.0 * sx, 19.0 * sy, 21.0 * sx, 21.0 * sy, 17.0 * sx, 21.0 * sy)
      ..lineTo(15.0 * sx, 21.0 * sy)
      ..cubicTo(12.5 * sx, 21.0 * sy, 10.6 * sx, 22.0 * sy, 8.0 * sx, 24.0 * sy)
      ..cubicTo(7.4 * sx, 24.5 * sy, 6.6 * sx, 24.0 * sy, 6.6 * sx, 23.2 * sy)
      ..lineTo(6.6 * sx, 20.8 * sy)
      ..cubicTo(3.6 * sx, 19.9 * sy, 2.0 * sx, 17.3 * sy, 2.0 * sx, 14.0 * sy)
      ..lineTo(2.0 * sx, 11.0 * sy)
      ..cubicTo(2.0 * sx, 7.0 * sy, 4.0 * sx, 4.0 * sy, 8.0 * sx, 4.0 * sy)
      ..close();
    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(bubble, Paint()..color = color);
    final clear = Paint()..blendMode = BlendMode.clear;
    for (final cx in [9.5, 13.0, 16.5]) {
      canvas.drawCircle(Offset(cx * sx, 13.0 * sy), 1.6 * sx, clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CommentBubblePainter o) => o.color != color;
}

class _SaveButton extends StatefulWidget {
  final bool isSaved;
  final VoidCallback onTap;
  final Color iconColor;
  const _SaveButton({required this.isSaved, required this.onTap, required this.iconColor});
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 0.95).chain(CurveTween(curve: Curves.easeIn)), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    ]).animate(_controller);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { widget.onTap(); _controller.forward(from: 0.0); },
      child: ScaleTransition(scale: _scaleAnimation,
        child: SizedBox(width: 26, height: 26,
          child: CustomPaint(painter: _SaveCirclePainter(color: widget.iconColor, filled: widget.isSaved)))),
    );
  }
}

class _SaveCirclePainter extends CustomPainter {
  final Color color;
  final bool filled;
  const _SaveCirclePainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 26.0;
    final sy = size.height / 26.0;
    final bookmark = Path()
      ..moveTo(5.0 * sx, 22.5 * sy)..lineTo(5.0 * sx, 6.8 * sy)
      ..cubicTo(5.0 * sx, 4.0 * sy, 7.0 * sx, 2.7 * sy, 9.4 * sx, 2.7 * sy)
      ..lineTo(16.6 * sx, 2.7 * sy)
      ..cubicTo(19.0 * sx, 2.7 * sy, 21.0 * sx, 4.0 * sy, 21.0 * sx, 6.8 * sy)
      ..lineTo(21.0 * sx, 22.5 * sy)..lineTo(13.0 * sx, 15.6 * sy)..close();
    if (filled) {
      canvas.drawPath(bookmark, Paint()..color = color..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(bookmark, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_SaveCirclePainter o) => o.color != color || o.filled != filled;
}
