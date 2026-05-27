// voice_call_screen.dart
// iOS 26 Liquid Glass style Voice Call Screen with full Agora integration.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/agora_service.dart';
import 'glass_common.dart';

class VoiceCallScreen extends StatefulWidget {
  final bool dark;
  final String channelName;
  final String remoteUserName;
  final String myUserId;
  final String remoteUserId;

  const VoiceCallScreen({
    super.key,
    required this.dark,
    required this.channelName,
    required this.remoteUserName,
    required this.myUserId,
    required this.remoteUserId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  final _agora = AgoraService();

  CallState _callState = CallState.connecting;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _seconds = 0;
  Timer? _timer;
  bool _remoteJoined = false;

  // Animations
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse1;
  late final Animation<double> _pulse2;
  late final Animation<double> _pulse3;

  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );

    // Pulse rings for avatar
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _pulse1 = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _pulse2 = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.15, 0.85, curve: Curves.easeOut)),
    );
    _pulse3 = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.30, 1.0, curve: Curves.easeOut)),
    );

    // Wave controller for connected state
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _entranceCtrl.forward();
    _setupAgora();
  }

  Future<void> _setupAgora() async {
    _agora.onCallStateChanged = (state) {
      if (!mounted) return;
      setState(() => _callState = state);
      if (state == CallState.connected && !_remoteJoined) {
        setState(() => _remoteJoined = true);
        _startTimer();
      }
    };
    _agora.onUserJoined = (uid) {
      if (!mounted) return;
      setState(() { _remoteJoined = true; _callState = CallState.connected; });
      _startTimer();
    };
    _agora.onUserOffline = (uid) {
      if (!mounted) return;
      _endCall();
    };
    _agora.onError = (err) {
      if (!mounted) return;
      _endCall();
    };

    try {
      await _agora.joinVoiceCall(channelName: widget.channelName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
        _endCall();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _durationStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    await _agora.toggleMute();
    if (mounted) setState(() => _isMuted = _agora.isMuted);
  }

  Future<void> _toggleSpeaker() async {
    HapticFeedback.selectionClick();
    await _agora.toggleSpeaker();
    if (mounted) setState(() => _isSpeakerOn = _agora.isSpeakerOn);
  }

  Future<void> _endCall() async {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    await _agora.leaveCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.paddingOf(context).bottom;

    // Color scheme
    final bg1 = widget.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F0F8);
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    final avatarLetter = widget.remoteUserName.isNotEmpty
        ? widget.remoteUserName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: bg1,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entranceCtrl, _pulseCtrl, _waveCtrl]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Animated gradient background ───────────────────
              _LiquidBackground(dark: widget.dark, wave: _waveCtrl.value),

              // ── Main content ───────────────────────────────────
              FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: 24),

                        // ── Status label ──────────────────────
                        _StatusChip(
                          dark: widget.dark,
                          label: _callState == CallState.connected
                              ? _durationStr
                              : _callState == CallState.connecting
                                  ? 'Connecting…'
                                  : 'Calling…',
                          connected: _callState == CallState.connected,
                        ),

                        SizedBox(height: 40),

                        // ── Pulsing avatar ────────────────────
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulse ring 1
                            Opacity(
                              opacity: (1 - _pulseCtrl.value).clamp(0, 1) * 0.35,
                              child: Transform.scale(
                                scale: _pulse1.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: widget.dark
                                          ? Colors.white.withOpacity(0.4)
                                          : Colors.black.withOpacity(0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Pulse ring 2
                            Opacity(
                              opacity: (1 - _pulseCtrl.value * 0.85).clamp(0, 1) * 0.45,
                              child: Transform.scale(
                                scale: _pulse2.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: widget.dark
                                          ? Colors.white.withOpacity(0.5)
                                          : Colors.black.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Pulse ring 3
                            Opacity(
                              opacity: (1 - _pulseCtrl.value * 0.7).clamp(0, 1) * 0.55,
                              child: Transform.scale(
                                scale: _pulse3.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: widget.dark
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.black.withOpacity(0.25),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Avatar
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: monoAvatar(widget.dark, 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(widget.dark ? 0.6 : 0.2),
                                    blurRadius: 40,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                avatarLetter,
                                style: manrope(
                                  size: 48,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 28),

                        // ── Name ──────────────────────────────
                        Text(
                          widget.remoteUserName,
                          style: manrope(
                            size: 28,
                            weight: FontWeight.w800,
                            color: fg,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Voice Call',
                          style: manrope(size: 14, weight: FontWeight.w500, color: sub),
                        ),

                        const Spacer(),

                        // ── Waveform (when connected) ──────────
                        if (_callState == CallState.connected)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: _VoiceWave(dark: widget.dark, value: _waveCtrl.value),
                          ),

                        // ── Control buttons ───────────────────
                        Padding(
                          padding: EdgeInsets.only(bottom: botPad + 40, left: 24, right: 24),
                          child: _CallControls(
                            dark: widget.dark,
                            isMuted: _isMuted,
                            isSpeakerOn: _isSpeakerOn,
                            isVideoCall: false,
                            onMute: _toggleMute,
                            onSpeaker: _toggleSpeaker,
                            onEndCall: _endCall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Video Call Screen
// ──────────────────────────────────────────────────────────────────────────────

class VideoCallScreen extends StatefulWidget {
  final bool dark;
  final String channelName;
  final String remoteUserName;
  final String myUserId;
  final String remoteUserId;

  const VideoCallScreen({
    super.key,
    required this.dark,
    required this.channelName,
    required this.remoteUserName,
    required this.myUserId,
    required this.remoteUserId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  final _agora = AgoraService();

  CallState _callState = CallState.connecting;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _remoteJoined = false;
  int? _remoteUid;
  int _seconds = 0;
  Timer? _timer;
  Timer? _hideControlsTimer;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final AnimationController _controlsAnim;
  late final Animation<double> _controlsFade;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut),
    );

    _controlsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _controlsFade = Tween<double>(begin: 0.0, end: 1.0).animate(_controlsAnim);

    _setupAgora();
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controlsAnim.reverse();
      }
    });
  }

  void _showControls() {
    _controlsAnim.forward();
    _scheduleHideControls();
  }

  Future<void> _setupAgora() async {
    _agora.onCallStateChanged = (state) {
      if (!mounted) return;
      setState(() => _callState = state);
    };
    _agora.onUserJoined = (uid) {
      if (!mounted) return;
      setState(() {
        _remoteJoined = true;
        _remoteUid = uid;
        _callState = CallState.connected;
      });
      _startTimer();
    };
    _agora.onUserOffline = (uid) {
      if (!mounted) return;
      _endCall();
    };
    _agora.onError = (err) {
      if (!mounted) return;
      _endCall();
    };

    try {
      await _agora.joinVideoCall(channelName: widget.channelName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video call failed: $e')),
        );
        _endCall();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _durationStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    await _agora.toggleMute();
    if (mounted) setState(() => _isMuted = _agora.isMuted);
  }

  Future<void> _toggleCamera() async {
    HapticFeedback.selectionClick();
    await _agora.toggleCamera();
    if (mounted) setState(() => _isCameraOff = _agora.isCameraOff);
  }

  Future<void> _switchCamera() async {
    HapticFeedback.selectionClick();
    await _agora.switchCamera();
  }

  Future<void> _endCall() async {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    await _agora.leaveCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _entranceCtrl.dispose();
    _controlsAnim.dispose();
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  Widget _buildRemoteView() {
    if (!_remoteJoined || _remoteUid == null) {
      return _WaitingOverlay(dark: widget.dark, name: widget.remoteUserName);
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: AgoraService().rtcEngine!,
        canvas: VideoCanvas(uid: _remoteUid!),
        connection: RtcConnection(channelId: widget.channelName),
      ),
    );
  }

  Widget _buildLocalView() {
    if (_isCameraOff) {
      return Container(
        color: widget.dark ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E),
        child: Center(
          child: Icon(Icons.videocam_off_rounded,
              color: Colors.white.withOpacity(0.6), size: 28),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: AgoraService().rtcEngine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.paddingOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showControls,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entranceCtrl, _controlsAnim]),
          builder: (context, _) {
            return FadeTransition(
              opacity: _fadeIn,
              child: Stack(
                children: [
                  // ── Remote video (full screen) ─────────────────
                  Positioned.fill(child: _buildRemoteView()),

                  // ── Connecting overlay ────────────────────────
                  if (!_remoteJoined)
                    Positioned.fill(
                      child: _LiquidBackground(dark: true, wave: 0),
                    ),

                  // ── Local video (pip) ─────────────────────────
                  Positioned(
                    top: topPad + 16,
                    right: 16,
                    width: 110,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          _buildLocalView(),
                          // Glass border
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          // Switch camera button
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _switchCamera,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: const Icon(
                                  Icons.flip_camera_ios_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Top bar ───────────────────────────────────
                  FadeTransition(
                    opacity: _controlsFade,
                    child: Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.remoteUserName,
                                  style: manrope(
                                    size: 18,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  _callState == CallState.connected
                                      ? _durationStr
                                      : 'Connecting…',
                                  style: manrope(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom controls ───────────────────────────
                  FadeTransition(
                    opacity: _controlsFade,
                    child: Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(24, 28, 24, botPad + 36),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          ),
                        ),
                        child: _CallControls(
                          dark: true,
                          isMuted: _isMuted,
                          isSpeakerOn: _isSpeakerOn,
                          isCameraOff: _isCameraOff,
                          isVideoCall: true,
                          onMute: _toggleMute,
                          onSpeaker: null,
                          onCamera: _toggleCamera,
                          onEndCall: _endCall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ──────────────────────────────────────────────────────────────────────────────

/// Liquid gradient animated background
class _LiquidBackground extends StatelessWidget {
  final bool dark;
  final double wave;
  const _LiquidBackground({required this.dark, required this.wave});

  @override
  Widget build(BuildContext context) {
    final t = wave;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.6),
              radius: 1.4,
              colors: dark
                  ? const [Color(0xFF141420), Color(0xFF0A0A14), Color(0xFF05050A)]
                  : const [Color(0xFFE8E8F8), Color(0xFFD8D8F0), Color(0xFFCCCCE8)],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Animated blobs
        _blob(
          color: dark ? const Color(0xFF2A2A5A).withOpacity(0.5) : const Color(0xFF9898D8).withOpacity(0.3),
          alignment: Alignment(math.sin(t * math.pi * 2) * 0.4 - 0.6, -0.6),
          size: 300,
        ),
        _blob(
          color: dark ? const Color(0xFF1A1A40).withOpacity(0.4) : const Color(0xFF7878C8).withOpacity(0.25),
          alignment: Alignment(math.cos(t * math.pi * 2) * 0.5 + 0.5, 0.2),
          size: 260,
        ),
        _blob(
          color: dark ? const Color(0xFF0A0A30).withOpacity(0.3) : const Color(0xFF6060B0).withOpacity(0.2),
          alignment: Alignment(math.sin(t * math.pi * 2 + 1) * 0.3, 0.8),
          size: 280,
        ),
        // Glass blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }

  Widget _blob({required Color color, required Alignment alignment, required double size}) =>
      Align(
        alignment: alignment,
        child: IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
              ),
            ),
          ),
        ),
      );
}

/// Status chip (connecting / timer)
class _StatusChip extends StatelessWidget {
  final bool dark;
  final String label;
  final bool connected;
  const _StatusChip({required this.dark, required this.label, required this.connected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: connected
                ? (dark ? Colors.green.withOpacity(0.25) : Colors.green.withOpacity(0.15))
                : (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.07)),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: connected
                  ? Colors.green.withOpacity(0.35)
                  : (dark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.10)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (connected)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
              Text(
                label,
                style: manrope(
                  size: 14,
                  weight: FontWeight.w700,
                  color: connected
                      ? Colors.green
                      : GlassTokens.fg(dark),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Waiting overlay when remote hasn't joined yet
class _WaitingOverlay extends StatelessWidget {
  final bool dark;
  final String name;
  const _WaitingOverlay({required this.dark, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: monoAvatar(dark, 3),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: manrope(size: 40, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: manrope(size: 22, weight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for video…',
            style: manrope(size: 14, color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

/// Animated voice waveform bars
class _VoiceWave extends StatelessWidget {
  final bool dark;
  final double value;
  const _VoiceWave({required this.dark, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = GlassTokens.fg(dark);
    const bars = 9;
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(bars, (i) {
          final phase = i / bars;
          final h = (math.sin((value + phase) * math.pi * 2) * 0.5 + 0.5) * 36 + 8;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 4,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: color.withOpacity(0.6),
            ),
          );
        }),
      ),
    );
  }
}

/// Shared call control buttons row
class _CallControls extends StatelessWidget {
  final bool dark;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraOff;
  final bool isVideoCall;
  final VoidCallback? onMute;
  final VoidCallback? onSpeaker;
  final VoidCallback? onCamera;
  final VoidCallback onEndCall;

  const _CallControls({
    required this.dark,
    required this.isMuted,
    required this.isSpeakerOn,
    this.isCameraOff = false,
    required this.isVideoCall,
    required this.onMute,
    required this.onSpeaker,
    this.onCamera,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mute
        _ControlBtn(
          dark: dark,
          icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: isMuted ? 'Unmute' : 'Mute',
          active: isMuted,
          onTap: onMute,
        ),

        const SizedBox(width: 18),

        if (isVideoCall) ...[
          // Camera toggle
          _ControlBtn(
            dark: dark,
            icon: isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: isCameraOff ? 'Camera On' : 'Camera Off',
            active: isCameraOff,
            onTap: onCamera,
          ),
          const SizedBox(width: 18),
        ] else ...[
          // Speaker toggle
          _ControlBtn(
            dark: dark,
            icon: isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: isSpeakerOn ? 'Speaker' : 'Earpiece',
            active: !isSpeakerOn,
            onTap: onSpeaker,
          ),
          const SizedBox(width: 18),
        ],

        // End call (red)
        _EndCallBtn(onTap: onEndCall),
      ],
    );
  }
}

/// Single glass control button
class _ControlBtn extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ControlBtn({
    required this.dark,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? (dark
                          ? Colors.white.withOpacity(0.22)
                          : Colors.black.withOpacity(0.14))
                      : (dark
                          ? Colors.white.withOpacity(0.10)
                          : Colors.black.withOpacity(0.07)),
                  border: Border.all(
                    color: active
                        ? (dark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.25))
                        : (dark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.10)),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: GlassTokens.fg(dark),
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: manrope(
              size: 11,
              weight: FontWeight.w600,
              color: GlassTokens.sub(dark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Red end call button
class _EndCallBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF3B30), Color(0xFFCC2222)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B30).withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'End',
            style: manrope(
              size: 11,
              weight: FontWeight.w600,
              color: const Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }
}
