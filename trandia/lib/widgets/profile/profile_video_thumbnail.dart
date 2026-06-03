// lib/widgets/profile/profile_video_thumbnail.dart
// Auto-generating thumbnail for video tiles in the profile grid.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ── In-memory thumbnail cache ──────────────────────────────────────────────
// Prevents re-generating the same thumbnail on every grid rebuild.
// Key = video URL, Value = raw JPEG bytes.
final thumbCache = <String, Uint8List>{};

class ProfileVideoThumbnailTile extends StatefulWidget {
  final String videoUrl;
  const ProfileVideoThumbnailTile({super.key, required this.videoUrl});

  @override
  State<ProfileVideoThumbnailTile> createState() =>
      _ProfileVideoThumbnailTileState();
}

class _ProfileVideoThumbnailTileState
    extends State<ProfileVideoThumbnailTile> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1. Check in-memory cache first
    final cached = thumbCache[widget.videoUrl];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _loading = false;
        });
      }
      return;
    }

    // 2. Generate from video URL
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 70,
      );
      if (bytes != null && bytes.isNotEmpty) {
        thumbCache[widget.videoUrl] = bytes; // cache for reuse
      }
      if (mounted) setState(() { _bytes = bytes; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white38,
          ),
        ),
      );
    }
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return const Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: Colors.white54,
        size: 30,
      ),
    );
  }
}
