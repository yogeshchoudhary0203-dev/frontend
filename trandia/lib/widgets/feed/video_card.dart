import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/post_service.dart';
import '../shared/home_shared.dart';

class VideoCard extends StatefulWidget {
  final PostModel post;
  final bool isDark;
  final ValueChanged<PostModel>? onLearnWatched;
  const VideoCard({super.key, required this.post, required this.isDark, this.onLearnWatched});
  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _muted       = false;
  bool _dataSaver   = false;
  bool _manualPause = false;
  bool _showOverlay = false;
  IconData _overlayIcon = Icons.pause_rounded;

  @override
  void initState() {
    super.initState();
    homeFeedActive.addListener(_onFeedActiveChanged);
    _checkConnectivity();
  }

  void _onFeedActiveChanged() {
    if (!homeFeedActive.value && _initialized) _ctrl?.pause();
  }

  Future<void> _checkConnectivity() async {}

  Future<void> _initAndPlay() async {
    if (_ctrl != null) return;
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
    } catch (_) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) { ctrl.dispose(); _ctrl = null; return; }
    ctrl.setLooping(true);
    ctrl.setVolume(_muted ? 0.0 : 1.0);
    setState(() => _initialized = true);
    if (!_manualPause) ctrl.play();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.5;
    if (visible) {
      widget.onLearnWatched?.call(widget.post);
      if (!_initialized && !_dataSaver) {
        _initAndPlay();
      } else if (_initialized && !_manualPause) {
        _ctrl?.play();
      }
    } else {
      if (_initialized) _ctrl?.pause();
    }
  }

  void _onTap() {
    if (!_initialized) { _dataSaver = false; _initAndPlay(); return; }
    if (_ctrl?.value.isPlaying ?? false) {
      _ctrl?.pause();
      _manualPause = true;
      setState(() { _showOverlay = true; _overlayIcon = Icons.pause_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() => _showOverlay = false); });
    } else {
      _manualPause = false;
      _ctrl?.play();
      setState(() { _showOverlay = true; _overlayIcon = Icons.play_arrow_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() => _showOverlay = false); });
    }
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    if (!_initialized) return;
    if (_ctrl?.value.isPlaying ?? false) {
      _ctrl?.pause();
      _manualPause = true;
      setState(() { _showOverlay = true; _overlayIcon = Icons.pause_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() => _showOverlay = false); });
    }
  }

  void _onTapManualPlay() {
    _dataSaver = false;
    _manualPause = false;
    if (!_initialized) _initAndPlay(); else { _ctrl?.play(); setState(() {}); }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl?.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    homeFeedActive.removeListener(_onFeedActiveChanged);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.post.thumbnailUrl;
    return VisibilityDetector(
      key: Key('vid_${widget.post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: widget.post.aspectRatio,
        child: GestureDetector(
          onTap: _onTap, onLongPress: _onLongPress,
          child: Stack(fit: StackFit.expand, children: [
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: thumbnailUrl, fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFF111111)),
                errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)))
            else
              Container(color: const Color(0xFF111111),
                child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white24, size: 44))),
            if (_initialized && _ctrl != null) VideoPlayer(_ctrl!),
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.22)]))))),
            if (_dataSaver && !_initialized)
              Center(child: GestureDetector(onTap: _onTapManualPlay,
                child: Container(width: 56, height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.55),
                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5)),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30)))),
            if (!_dataSaver && !_initialized)
              const Center(child: SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))),
            if (_showOverlay)
              Center(child: AnimatedOpacity(opacity: _showOverlay ? 1.0 : 0.0, duration: const Duration(milliseconds: 150),
                child: Container(width: 64, height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.55)),
                  child: Icon(_overlayIcon, color: Colors.white, size: 34)))),
            if (_initialized)
              Positioned(bottom: 10, right: 10,
                child: GestureDetector(onTap: _toggleMute,
                  child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.50)),
                    child: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 16)))),
            if (_initialized && _ctrl != null)
              Positioned(bottom: 0, left: 0, right: 0,
                child: VideoProgressIndicator(_ctrl!, allowScrubbing: true, padding: EdgeInsets.zero,
                  colors: VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white.withOpacity(0.30), backgroundColor: Colors.transparent))),
          ]),
        ),
      ),
    );
  }
}
