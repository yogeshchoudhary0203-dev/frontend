import 'package:flutter/material.dart';
import '../services/post_service.dart';
import 'glass_common.dart';
import 'home/home_screen.dart';
import '../l10n/app_localizations.dart';

class SinglePostScreen extends StatefulWidget {
  final String postId;
  final bool dark;

  const SinglePostScreen({
    super.key,
    required this.postId,
    required this.dark,
  });

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  PostModel? _post;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final post = await PostService.instance.getPostById(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
          _hasError = post == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final p = _post!;
    final nextLiked = !p.isLiked;
    final nextLikes = p.likesCount + (nextLiked ? 1 : -1);
    
    setState(() {
      _post = p.copyWith(
        isLiked: nextLiked,
        likesCount: nextLikes,
      );
    });

    try {
      if (nextLiked) {
        await PostService.instance.likePost(p.id);
      } else {
        await PostService.instance.unlikePost(p.id);
      }
    } catch (_) {
      // Revert if API fails
      if (mounted) {
        setState(() {
          _post = p;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    final topPad = MediaQuery.paddingOf(context).top;
    final headerTop = topPad + 8;
    const headerH = 66.0;

    return Scaffold(
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          // Theme-matching blur backdrop
          GlassBackdrop(dark: widget.dark),

          // Content Area
          Positioned(
            top: headerTop + headerH,
            bottom: 0,
            left: 0,
            right: 0,
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.dark ? Colors.white : Colors.black,
                    ),
                  )
                : _hasError
                    ? _buildErrorState(sub)
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            PostCard(
                              post: _post!,
                              isDark: widget.dark,
                              onLike: _toggleLike,
                              onLearnWatched: (p) {},
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
          ),

          // Glass Header
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
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _post?.isVideo == true ? 'Video'.tr(context) : 'Post'.tr(context),
                    style: manrope(
                      size: 17,
                      weight: FontWeight.w800,
                      color: fg,
                      letterSpacing: -0.34,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color subColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: subColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Post Not Found'.tr(context),
              style: manrope(
                size: 16,
                weight: FontWeight.w800,
                color: GlassTokens.fg(widget.dark),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The link may be invalid or the post has been deleted.'.tr(context),
              textAlign: TextAlign.center,
              style: manrope(
                size: 13,
                weight: FontWeight.w500,
                color: subColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _fetchPost,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: widget.dark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  'Retry'.tr(context),
                  style: manrope(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: GlassTokens.fg(widget.dark),
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
