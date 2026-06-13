import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'glass_common.dart';
import '../l10n/app_localizations.dart';
import '../services/user_service.dart';
import '../models/archived_media_model.dart';
import '../widgets/profile/profile_video_thumbnail.dart';

class ArchiveScreen extends StatefulWidget {
  final bool dark;
  const ArchiveScreen({super.key, required this.dark});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<ArchivedMedia> _mediaList = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadArchivedMedia();
  }

  Future<void> _loadArchivedMedia() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final list = await UserService.getArchivedMedia();
      if (mounted) {
        setState(() {
          _mediaList = list;
          _isLoading = false;
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

  Future<void> _saveMedia(BuildContext context, ArchivedMedia item) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final downloadingMsg = 'Downloading media...'.tr(context);
    final failPrefix = 'Failed to save: '.tr(context);
    try {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(downloadingMsg),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      final response = await http.get(Uri.parse(item.mediaUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final ext = item.mediaType == 'video' ? 'mp4' : 'jpg';
        final file = File('${tempDir.path}/archived_${item.id}.$ext');
        await file.writeAsBytes(response.bodyBytes);

        // Share/Save dialog using share_plus
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'Saved from Trandia Archive');
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$failPrefix$e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showFullscreenViewer(BuildContext context, ArchivedMedia item) {
    final isVideo = item.mediaType == 'video';
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: widget.dark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVideo ? 'Archived Video'.tr(context) : 'Archived Photo'.tr(context),
                        style: manrope(
                          size: 16,
                          weight: FontWeight.w800,
                          color: GlassTokens.fg(widget.dark),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Save Button
                          GestureDetector(
                            onTap: () {
                              _saveMedia(context, item);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              ),
                              child: Icon(Icons.download_rounded, size: 20, color: GlassTokens.fg(widget.dark)),
                            ),
                          ),
                          // Delete Button
                          GestureDetector(
                            onTap: () async {
                              final navigator = Navigator.of(ctx);
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final titleText = 'Delete from Archive?'.tr(context);
                              final contentText = 'Are you sure you want to permanently delete this media from your archive?'.tr(context);
                              final cancelText = 'Cancel'.tr(context);
                              final deleteText = 'Delete'.tr(context);
                              final successMsg = 'Removed from Archive'.tr(context);

                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  backgroundColor: widget.dark ? const Color(0xFF1E1E1E) : Colors.white,
                                  title: Text(titleText),
                                  content: Text(contentText),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(cancelText),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(
                                        deleteText,
                                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final deleted = await UserService.deleteArchivedMedia(item.id);
                                if (deleted && mounted) {
                                  navigator.pop();
                                  _loadArchivedMedia();
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(successMsg),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent.withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, size: 20, color: Colors.redAccent),
                            ),
                          ),
                          // Close Button
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              ),
                              child: Icon(Icons.close_rounded, size: 20, color: GlassTokens.fg(widget.dark)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Media Viewport
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: isVideo
                          ? _ArchiveVideoPlayer(url: item.mediaUrl)
                          : CachedNetworkImage(
                              imageUrl: item.mediaUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text('Could not load image'.tr(context)),
                              ),
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
  }

  LinearGradient _tileGradient(int i) {
    final double a, b;
    if (widget.dark) {
      a = (22 - (i % 5) * 3).toDouble();
      b = (a - 12).clamp(4, 100).toDouble();
    } else {
      a = (92 - (i % 5) * 4).toDouble();
      b = (a - 18).clamp(56, 100).toDouble();
    }
    return LinearGradient(
      colors: [
        HSLColor.fromAHSL(1, 0, 0, a / 100).toColor(),
        HSLColor.fromAHSL(1, 0, 0, b / 100).toColor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);

    Widget body;
    if (_isLoading) {
      body = Center(
        child: CircularProgressIndicator(
          color: widget.dark ? Colors.white : Colors.black,
          strokeWidth: 2,
        ),
      );
    } else if (_hasError) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: fg.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Could not load archive'.tr(context),
              style: manrope(size: 16, weight: FontWeight.w800, color: fg),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _loadArchivedMedia,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Retry'.tr(context), style: manrope(size: 14, weight: FontWeight.w700, color: fg)),
              ),
            ),
          ],
        ),
      );
    } else if (_mediaList.isEmpty) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              ),
              child: Icon(Icons.archive_outlined, size: 36, color: fg.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Archived Media'.tr(context),
              style: manrope(size: 18, weight: FontWeight.w800, color: fg),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Photos and videos you archive from chats will appear here.'.tr(context),
                textAlign: TextAlign.center,
                style: manrope(size: 13, weight: FontWeight.w500, color: sub, height: 1.5),
              ),
            ),
          ],
        ),
      );
    } else {
      body = GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: _mediaList.length,
        itemBuilder: (context, index) {
          final item = _mediaList[index];
          final isVideo = item.mediaType == 'video';

          return GestureDetector(
            onTap: () => _showFullscreenViewer(context, item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: _tileGradient(index),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isVideo)
                      ProfileVideoThumbnailTile(videoUrl: item.mediaUrl)
                    else
                      CachedNetworkImage(
                        imageUrl: item.mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.black12),
                        errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image)),
                      ),
                    if (isVideo)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
                          'Archive'.tr(context),
                          style: manrope(size: 17, weight: FontWeight.w800, color: fg),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: body),
              ],
            ),
          ),
        ],
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
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(playedColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
