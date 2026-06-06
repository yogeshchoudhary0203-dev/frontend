import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'glass_common.dart';
import '../l10n/app_localizations.dart';
import '../services/post_service.dart';
import 'single_post_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  final bool dark;
  const SavedPostsScreen({super.key, required this.dark});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _nextCursor;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSavedPosts(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadSavedPosts();
    }
  }

  Future<void> _loadSavedPosts({bool refresh = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _nextCursor = null;
        });
      }
    } else {
      if (_isLoadingMore || _nextCursor == null) return;
      if (mounted) {
        setState(() {
          _isLoadingMore = true;
        });
      }
    }

    try {
      final result = await PostService.instance.getSavedPosts(
        cursor: refresh ? null : _nextCursor,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _posts.clear();
        }
        _posts.addAll(result.posts);
        _nextCursor = result.nextCursor;
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = _posts.isEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);

    Widget contentBody;
    if (_isLoading) {
      contentBody = Center(
        child: CircularProgressIndicator(
          color: widget.dark ? Colors.white : Colors.black,
          strokeWidth: 2,
        ),
      );
    } else if (_hasError) {
      contentBody = RefreshIndicator(
        onRefresh: () => _loadSavedPosts(refresh: true),
        color: widget.dark ? Colors.white : Colors.black,
        backgroundColor: widget.dark ? const Color(0xFF1C1C1F) : Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: fg.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load saved posts'.tr(context),
                    style: manrope(
                      size: 16,
                      weight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _loadSavedPosts(refresh: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.dark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        'Retry'.tr(context),
                        style: manrope(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (_posts.isEmpty) {
      contentBody = RefreshIndicator(
        onRefresh: () => _loadSavedPosts(refresh: true),
        color: widget.dark ? Colors.white : Colors.black,
        backgroundColor: widget.dark ? const Color(0xFF1C1C1F) : Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      border: Border.all(
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.bookmark_border_rounded,
                      size: 48,
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Saved Posts Yet'.tr(context),
                    style: manrope(
                      size: 20,
                      weight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'When you save a post, it will appear here. Only you can see what you\'ve saved.'.tr(context),
                      textAlign: TextAlign.center,
                      style: manrope(
                        size: 14,
                        weight: FontWeight.w500,
                        color: sub,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      contentBody = RefreshIndicator(
        onRefresh: () => _loadSavedPosts(refresh: true),
        color: widget.dark ? Colors.white : Colors.black,
        backgroundColor: widget.dark ? const Color(0xFF1C1C1F) : Colors.white,
        child: GridView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _posts.length + (_isLoadingMore ? 3 : 0),
          itemBuilder: (context, index) {
            if (index >= _posts.length) {
              return Container(
                decoration: BoxDecoration(
                  color: widget.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }
            final post = _posts[index];
            final isVideo = post.isVideo;
            final imageUrl = isVideo && post.thumbnailUrl != null
                ? post.thumbnailUrl!
                : post.mediaUrl;

            return GestureDetector(
              onTap: () async {
                HapticFeedback.selectionClick();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SinglePostScreen(
                      postId: post.id,
                      dark: widget.dark,
                    ),
                  ),
                );
                _loadSavedPosts(refresh: true);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: widget.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: widget.dark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.03),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 20),
                        ),
                      ),
                      if (isVideo)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: widget.dark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GlassHeader(
                    dark: widget.dark,
                    padding: const EdgeInsets.only(left: 7, right: 8),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          dark: widget.dark,
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 16,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Saved'.tr(context),
                          style: manrope(
                            size: 17,
                            weight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: contentBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
