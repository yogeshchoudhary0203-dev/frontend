// call_screens.dart
// Voice call, Video call, and Incoming call screens.
// Uses Agora RTC for media + ChatService WebSocket for signaling.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/agora_service.dart';
import '../services/chat_service.dart';
import 'glass_common.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Incoming Call Screen  (shown on callee's device)
// ──────────────────────────────────────────────────────────────────────────────

class IncomingCallScreen extends StatefulWidget {
  final bool   dark;
  final String callerName;
  final String callerId;
  final String channelName;
  final String callType;   // 'voice' | 'video'
  final String myUserId;

  const IncomingCallScreen({
    super.key,
    required this.dark,
    required this.callerName,
    required this.callerId,
    required this.channelName,
    required this.callType,
    required this.myUserId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse1, _pulse2, _pulse3;
  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeIn;

  // Auto-dismiss if caller ends the call before we answer
  late final StreamSubscription<Map<String, dynamic>> _callSub;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _pulse1 = Tween<double>(begin: 1.0, end: 1.6).animate(
        CurvedAnimation(parent: _pulseCtrl,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _pulse2 = Tween<double>(begin: 1.0, end: 1.45).animate(
        CurvedAnimation(parent: _pulseCtrl,
            curve: const Interval(0.15, 0.85, curve: Curves.easeOut)));
    _pulse3 = Tween<double>(begin: 1.0, end: 1.28).animate(
        CurvedAnimation(parent: _pulseCtrl,
            curve: const Interval(0.30, 1.0, curve: Curves.easeOut)));

    // Listen for call_end from caller (they cancelled before we answered)
    _callSub = ChatService().callStream.listen((data) {
      final type = data['type'] as String?;
      final ch   = data['channel_name'] as String? ?? '';
      if ((type == 'call_end') && ch == widget.channelName) {
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _callSub.cancel();
    super.dispose();
  }

  void _accept() {
    HapticFeedback.mediumImpact();
    // Tell caller we accepted
    ChatService().sendCallSignal(
      signalType:  'call_accept',
      targetId:    widget.callerId,
      channelName: widget.channelName,
    );
    // Replace this screen with the active call screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: widget.callType == 'video'
              ? VideoCallScreen(
                  dark:           widget.dark,
                  channelName:    widget.channelName,
                  remoteUserName: widget.callerName,
                  myUserId:       widget.myUserId,
                  remoteUserId:   widget.callerId,
                  isCallee:       true,
                )
              : VoiceCallScreen(
                  dark:           widget.dark,
                  channelName:    widget.channelName,
                  remoteUserName: widget.callerName,
                  myUserId:       widget.myUserId,
                  remoteUserId:   widget.callerId,
                  isCallee:       true,
                ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _reject() {
    HapticFeedback.mediumImpact();
    ChatService().sendCallSignal(
      signalType:  'call_reject',
      targetId:    widget.callerId,
      channelName: widget.channelName,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.paddingOf(context).bottom;
    final fg     = GlassTokens.fg(widget.dark);
    final sub    = GlassTokens.sub(widget.dark);
    final letter = widget.callerName.isNotEmpty
        ? widget.callerName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor:
          widget.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F0F8),
      body: AnimatedBuilder(
        animation: Listenable.merge([_entranceCtrl, _pulseCtrl]),
        builder: (context, _) => Stack(children: [
          _LiquidBackground(dark: widget.dark, wave: _pulseCtrl.value * 0.5),

          FadeTransition(
            opacity: _fadeIn,
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 48),

                // Status label
                _StatusChip(dark: widget.dark, label: 'Incoming Call', connected: false),
                const SizedBox(height: 12),

                Text(
                  widget.callType == 'video' ? 'Video Call' : 'Voice Call',
                  style: manrope(size: 13, weight: FontWeight.w500, color: sub),
                ),

                const SizedBox(height: 40),

                // Pulsing avatar
                Stack(alignment: Alignment.center, children: [
                  _PulseRing(scale: _pulse1.value, pulse: _pulseCtrl.value,
                      offset: 0.0, dark: widget.dark),
                  _PulseRing(scale: _pulse2.value, pulse: _pulseCtrl.value,
                      offset: 0.15, dark: widget.dark),
                  _PulseRing(scale: _pulse3.value, pulse: _pulseCtrl.value,
                      offset: 0.30, dark: widget.dark),
                  _Avatar(letter: letter, dark: widget.dark, gradient: monoAvatar(widget.dark, 1)),
                ]),

                const SizedBox(height: 28),

                Text(widget.callerName,
                    style: manrope(size: 28, weight: FontWeight.w800,
                        color: fg, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('is calling you…',
                    style: manrope(size: 14, weight: FontWeight.w500, color: sub)),

                const Spacer(),

                // Accept / Reject buttons
                Padding(
                  padding: EdgeInsets.only(
                      bottom: botPad + 50, left: 32, right: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject
                      _RoundBtn(
                        icon: Icons.call_end_rounded,
                        bg: const Color(0xFFFF3B30),
                        label: 'Decline',
                        labelColor: const Color(0xFFFF3B30),
                        onTap: _reject,
                      ),
                      // Accept
                      _RoundBtn(
                        icon: widget.callType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        bg: const Color(0xFF34C759),
                        label: 'Accept',
                        labelColor: const Color(0xFF34C759),
                        onTap: _accept,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Voice Call Screen
// ──────────────────────────────────────────────────────────────────────────────

class VoiceCallScreen extends StatefulWidget {
  final bool   dark;
  final String channelName;
  final String remoteUserName;
  final String myUserId;
  final String remoteUserId;
  final bool   isCallee;   // true = we are the one who answered

  const VoiceCallScreen({
    super.key,
    required this.dark,
    required this.channelName,
    required this.remoteUserName,
    required this.myUserId,
    required this.remoteUserId,
    this.isCallee = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  final _agora = AgoraService();

  CallState _callState  = CallState.connecting;
  bool _isMuted         = false;
  bool _isSpeakerOn     = true;
  bool _remoteJoined    = false;
  int  _seconds         = 0;
  bool _declined        = false;  // callee rejected

  Timer? _timer;
  Timer? _ringTimeout;   // auto-end if no answer after 45s

  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse1, _pulse2, _pulse3;
  late final AnimationController _waveCtrl;

  late final StreamSubscription<Map<String, dynamic>> _callSub;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _pulse1 = Tween<double>(begin: 1.0, end: 1.6).animate(
        CurvedAnimation(parent: _pulseCtrl,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _pulse2 = Tween<double>(begin: 1.0, end: 1.45).animate(
        CurvedAnimation(parent: _pulseCtrl,
            curve: const Interval(0.15, 0.85, curve: Curves.easeOut)));
    _pulse3 = Tween<double>(begin: 1.0, end: 1.28).animate(
        CurvedAnimation(parent: _pulseCtrl,
            curve: const Interval(0.30, 1.0, curve: Curves.easeOut)));

    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    // Listen for signaling events
    _callSub = ChatService().callStream.listen(_onCallSignal);

    _setupAgora();

    // Caller-side: auto-end if no answer in 45s
    if (!widget.isCallee) {
      _ringTimeout = Timer(const Duration(seconds: 45), () {
        if (mounted && _callState != CallState.connected) _endCall();
      });
    }
  }

  void _onCallSignal(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    final ch   = data['channel_name'] as String? ?? '';
    if (ch != widget.channelName) return;

    switch (type) {
      case 'call_reject':
        setState(() => _declined = true);
        _ringTimeout?.cancel();
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _endCallSilent();
        });
      case 'call_end':
        _endCallSilent();
    }
  }

  Future<void> _setupAgora() async {
    _agora
      ..onCallStateChanged = (state) {
        if (!mounted) return;
        setState(() => _callState = state);
        if (state == CallState.connected && !_remoteJoined) {
          setState(() => _remoteJoined = true);
          _startTimer();
        }
      }
      ..onUserJoined = (uid) {
        if (!mounted) return;
        _ringTimeout?.cancel();
        setState(() { _remoteJoined = true; _callState = CallState.connected; });
        _startTimer();
      }
      ..onUserOffline = (uid) {
        if (mounted) _endCall();
      }
      ..onError = (_) {
        if (mounted) _endCall();
      };

    try {
      await _agora.joinVoiceCall(
        channelName: widget.channelName,
        uid: AgoraService.buildNumericUid(widget.myUserId),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Call failed: $e')));
        _endCallSilent();
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
    _ringTimeout?.cancel();
    _timer?.cancel();
    // Signal the other party
    ChatService().sendCallSignal(
      signalType:  'call_end',
      targetId:    widget.remoteUserId,
      channelName: widget.channelName,
    );
    await _agora.leaveCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endCallSilent() async {
    _ringTimeout?.cancel();
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
    _ringTimeout?.cancel();
    _callSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.paddingOf(context).bottom;
    final fg     = GlassTokens.fg(widget.dark);
    final sub    = GlassTokens.sub(widget.dark);
    final letter = widget.remoteUserName.isNotEmpty
        ? widget.remoteUserName[0].toUpperCase()
        : '?';

    String statusLabel;
    if (_declined) {
      statusLabel = 'Call Declined';
    } else if (_callState == CallState.connected) {
      statusLabel = _durationStr;
    } else if (widget.isCallee) {
      statusLabel = 'Connecting…';
    } else {
      statusLabel = 'Ringing…';
    }

    return Scaffold(
      backgroundColor:
          widget.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F0F8),
      body: AnimatedBuilder(
        animation: Listenable.merge([_entranceCtrl, _pulseCtrl, _waveCtrl]),
        builder: (context, _) => Stack(children: [
          _LiquidBackground(dark: widget.dark, wave: _waveCtrl.value),

          FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SafeArea(
                child: Column(children: [
                  const SizedBox(height: 24),
                  _StatusChip(
                      dark: widget.dark,
                      label: statusLabel,
                      connected: _callState == CallState.connected && !_declined),
                  const SizedBox(height: 40),

                  // Pulsing avatar
                  Stack(alignment: Alignment.center, children: [
                    _PulseRing(scale: _pulse1.value, pulse: _pulseCtrl.value,
                        offset: 0.0, dark: widget.dark),
                    _PulseRing(scale: _pulse2.value, pulse: _pulseCtrl.value,
                        offset: 0.15, dark: widget.dark),
                    _PulseRing(scale: _pulse3.value, pulse: _pulseCtrl.value,
                        offset: 0.30, dark: widget.dark),
                    _Avatar(letter: letter, dark: widget.dark,
                        gradient: monoAvatar(widget.dark, 2)),
                  ]),

                  const SizedBox(height: 28),
                  Text(widget.remoteUserName,
                      style: manrope(size: 28, weight: FontWeight.w800,
                          color: fg, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Voice Call',
                      style: manrope(size: 14, weight: FontWeight.w500, color: sub)),

                  const Spacer(),

                  if (_callState == CallState.connected && !_declined)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _VoiceWave(dark: widget.dark, value: _waveCtrl.value),
                    ),

                  Padding(
                    padding:
                        EdgeInsets.only(bottom: botPad + 40, left: 24, right: 24),
                    child: _CallControls(
                      dark:        widget.dark,
                      isMuted:     _isMuted,
                      isSpeakerOn: _isSpeakerOn,
                      isVideoCall: false,
                      onMute:      _declined ? null : _toggleMute,
                      onSpeaker:   _declined ? null : _toggleSpeaker,
                      onEndCall:   _endCall,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Video Call Screen
// ──────────────────────────────────────────────────────────────────────────────

class VideoCallScreen extends StatefulWidget {
  final bool   dark;
  final String channelName;
  final String remoteUserName;
  final String myUserId;
  final String remoteUserId;
  final bool   isCallee;

  const VideoCallScreen({
    super.key,
    required this.dark,
    required this.channelName,
    required this.remoteUserName,
    required this.myUserId,
    required this.remoteUserId,
    this.isCallee = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  final _agora = AgoraService();

  CallState _callState   = CallState.connecting;
  bool _isMuted          = false;
  bool _isCameraOff      = false;
  bool _remoteJoined     = false;
  int? _remoteUid;
  int  _seconds          = 0;

  Timer? _timer;
  Timer? _hideControlsTimer;
  Timer? _ringTimeout;

  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeIn;
  late final AnimationController _controlsAnim;
  late final Animation<double>   _controlsFade;

  late final StreamSubscription<Map<String, dynamic>> _callSub;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);

    _controlsAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300), value: 1.0);
    _controlsFade = CurvedAnimation(parent: _controlsAnim, curve: Curves.easeOut);

    _callSub = ChatService().callStream.listen(_onCallSignal);
    _setupAgora();
    _scheduleHideControls();

    if (!widget.isCallee) {
      _ringTimeout = Timer(const Duration(seconds: 45), () {
        if (mounted && _callState != CallState.connected) _endCall();
      });
    }
  }

  void _onCallSignal(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    final ch   = data['channel_name'] as String? ?? '';
    if (ch != widget.channelName) return;
    if (type == 'call_reject' || type == 'call_end') _endCallSilent();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _controlsAnim.reverse();
    });
  }

  void _showControls() {
    _controlsAnim.forward();
    _scheduleHideControls();
  }

  Future<void> _setupAgora() async {
    _agora
      ..onCallStateChanged = (state) {
        if (!mounted) return;
        setState(() => _callState = state);
      }
      ..onUserJoined = (uid) {
        if (!mounted) return;
        _ringTimeout?.cancel();
        setState(() {
          _remoteJoined = true;
          _remoteUid    = uid;
          _callState    = CallState.connected;
        });
        _startTimer();
      }
      ..onUserOffline = (uid) {
        if (mounted) _endCall();
      }
      ..onError = (_) {
        if (mounted) _endCall();
      };

    try {
      await _agora.joinVideoCall(
        channelName: widget.channelName,
        uid: AgoraService.buildNumericUid(widget.myUserId),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Video call failed: $e')));
        _endCallSilent();
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
    _ringTimeout?.cancel();
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    ChatService().sendCallSignal(
      signalType:  'call_end',
      targetId:    widget.remoteUserId,
      channelName: widget.channelName,
    );
    await _agora.leaveCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endCallSilent() async {
    _ringTimeout?.cancel();
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
    _ringTimeout?.cancel();
    _hideControlsTimer?.cancel();
    _callSub.cancel();
    super.dispose();
  }

  Widget _buildRemoteView() {
    if (!_remoteJoined || _remoteUid == null || _agora.rtcEngine == null) {
      return _WaitingOverlay(dark: widget.dark, name: widget.remoteUserName);
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _agora.rtcEngine!,
        canvas:     VideoCanvas(uid: _remoteUid!),
        connection: RtcConnection(
          channelId: widget.channelName,
          localUid:  AgoraService.buildNumericUid(widget.myUserId),
        ),
      ),
    );
  }

  Widget _buildLocalView() {
    if (_agora.rtcEngine == null) return const SizedBox.shrink();
    if (_isCameraOff) {
      return Container(
        color: const Color(0xFF1C1C1E),
        child: Center(
          child: Icon(Icons.videocam_off_rounded,
              color: Colors.white.withOpacity(0.6), size: 28)),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _agora.rtcEngine!,
        canvas:    const VideoCanvas(uid: 0),
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
        // Video views are OUTSIDE AnimatedBuilder — putting AgoraVideoView inside
        // AnimatedBuilder caused a new VideoViewController on every animation frame,
        // destroying the texture binding and showing a white screen.
        child: Stack(children: [
          Positioned.fill(child: _buildRemoteView()),

          if (!_remoteJoined)
            Positioned.fill(child: _LiquidBackground(dark: true, wave: 0)),

          Positioned(
            top: topPad + 16, right: 16,
            width: 110, height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(children: [
                Positioned.fill(child: _buildLocalView()),
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25), width: 1.5)),
                )),
                Positioned(
                  bottom: 8, right: 8,
                  child: GestureDetector(
                    onTap: _switchCamera,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5)),
                      child: const Icon(Icons.flip_camera_ios_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // Only the controls overlay animates — video is untouched by animations
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_entranceCtrl, _controlsAnim]),
              builder: (context, _) => Stack(children: [
                FadeTransition(
                  opacity: _controlsFade,
                  child: Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6), Colors.transparent
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.remoteUserName,
                              style: manrope(size: 18, weight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: -0.3)),
                          Text(
                            _callState == CallState.connected
                                ? _durationStr
                                : widget.isCallee ? 'Connecting…' : 'Ringing…',
                            style: manrope(size: 13, weight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _controlsFade,
                  child: Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, botPad + 36),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7), Colors.transparent
                          ],
                        ),
                      ),
                      child: _CallControls(
                        dark:        true,
                        isMuted:     _isMuted,
                        isSpeakerOn: true,
                        isCameraOff: _isCameraOff,
                        isVideoCall: true,
                        onMute:      _toggleMute,
                        onSpeaker:   null,
                        onCamera:    _toggleCamera,
                        onEndCall:   _endCall,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared private widgets
// ──────────────────────────────────────────────────────────────────────────────

class _LiquidBackground extends StatelessWidget {
  final bool dark;
  final double wave;
  const _LiquidBackground({required this.dark, required this.wave});

  @override
  Widget build(BuildContext context) {
    final t = wave;
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6), radius: 1.4,
            colors: dark
                ? const [Color(0xFF141420), Color(0xFF0A0A14), Color(0xFF05050A)]
                : const [Color(0xFFE8E8F8), Color(0xFFD8D8F0), Color(0xFFCCCCE8)],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
      _blob(
          color: dark
              ? const Color(0xFF2A2A5A).withOpacity(0.5)
              : const Color(0xFF9898D8).withOpacity(0.3),
          alignment:
              Alignment(math.sin(t * math.pi * 2) * 0.4 - 0.6, -0.6),
          size: 300),
      _blob(
          color: dark
              ? const Color(0xFF1A1A40).withOpacity(0.4)
              : const Color(0xFF7878C8).withOpacity(0.25),
          alignment:
              Alignment(math.cos(t * math.pi * 2) * 0.5 + 0.5, 0.2),
          size: 260),
    ]);
  }

  Widget _blob(
          {required Color color,
          required Alignment alignment,
          required double size}) =>
      Align(
        alignment: alignment,
        child: IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    RadialGradient(colors: [color, color.withOpacity(0)]),
              ),
            ),
          ),
        ),
      );
}

class _PulseRing extends StatelessWidget {
  final double scale, pulse, offset;
  final bool   dark;
  const _PulseRing(
      {required this.scale, required this.pulse, required this.offset,
       required this.dark});

  @override
  Widget build(BuildContext context) {
    final fade = (1 - (pulse - offset).abs()).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade * 0.45,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.2),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;
  final bool dark;
  final Gradient gradient;
  const _Avatar({required this.letter, required this.dark, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
    width: 120, height: 120,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: gradient,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.6 : 0.2),
          blurRadius: 40, offset: const Offset(0, 12)),
      ],
    ),
    alignment: Alignment.center,
    child: Text(letter,
        style: manrope(size: 48, weight: FontWeight.w700, color: Colors.white)),
  );
}

class _StatusChip extends StatelessWidget {
  final bool   dark, connected;
  final String label;
  const _StatusChip(
      {required this.dark, required this.label, required this.connected});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(50),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: connected
              ? (dark
                  ? Colors.green.withOpacity(0.25)
                  : Colors.green.withOpacity(0.15))
              : (dark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.black.withOpacity(0.07)),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: connected
                ? Colors.green.withOpacity(0.35)
                : (dark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.10)),
            width: 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (connected)
            Container(
              width: 7, height: 7,
              margin: const EdgeInsets.only(right: 7),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.green),
            ),
          Text(label,
              style: manrope(
                size: 14, weight: FontWeight.w700,
                color: connected ? Colors.green : GlassTokens.fg(dark),
                letterSpacing: 0.2,
              )),
        ]),
      ),
    ),
  );
}

class _WaitingOverlay extends StatelessWidget {
  final bool dark;
  final String name;
  const _WaitingOverlay({required this.dark, required this.name});

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
            shape: BoxShape.circle, gradient: monoAvatar(dark, 3)),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: manrope(size: 40, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
      const SizedBox(height: 20),
      Text(name,
          style: manrope(size: 22, weight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 8),
      Text('Waiting for video…',
          style: manrope(size: 14, color: Colors.white.withOpacity(0.6))),
    ]),
  );
}

class _VoiceWave extends StatelessWidget {
  final bool   dark;
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
            width: 4, height: h,
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

/// Accept / Reject rounded button for IncomingCallScreen
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color bg, labelColor;
  final String label;
  final VoidCallback onTap;
  const _RoundBtn({
    required this.icon, required this.bg, required this.label,
    required this.labelColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg,
            boxShadow: [
              BoxShadow(color: bg.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))
            ]),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 32),
      ),
      const SizedBox(height: 10),
      Text(label, style: manrope(size: 12, weight: FontWeight.w600, color: labelColor)),
    ]),
  );
}

class _CallControls extends StatelessWidget {
  final bool      dark, isMuted, isSpeakerOn, isVideoCall;
  final bool      isCameraOff;
  final VoidCallback? onMute, onSpeaker, onCamera;
  final VoidCallback  onEndCall;

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
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _ControlBtn(
          dark: dark, icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: isMuted ? 'Unmute' : 'Mute', active: isMuted, onTap: onMute),
      const SizedBox(width: 18),
      if (isVideoCall) ...[
        _ControlBtn(
            dark: dark,
            icon: isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: isCameraOff ? 'Camera On' : 'Camera Off',
            active: isCameraOff, onTap: onCamera),
        const SizedBox(width: 18),
      ] else ...[
        _ControlBtn(
            dark: dark,
            icon: isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: isSpeakerOn ? 'Speaker' : 'Earpiece',
            active: !isSpeakerOn, onTap: onSpeaker),
        const SizedBox(width: 18),
      ],
      _EndCallBtn(onTap: onEndCall),
    ],
  );
}

class _ControlBtn extends StatelessWidget {
  final bool dark, active;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ControlBtn({
    required this.dark, required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? (dark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.14))
                  : (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.07)),
              border: Border.all(
                color: active
                    ? (dark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.25))
                    : (dark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.10)),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: GlassTokens.fg(dark), size: 26),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: manrope(size: 11, weight: FontWeight.w600,
              color: GlassTokens.sub(dark))),
    ]),
  );
}

class _EndCallBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFFF3B30), Color(0xFFCC2222)]),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFF3B30).withOpacity(0.45),
                blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
      ),
      const SizedBox(height: 8),
      Text('End',
          style: manrope(size: 11, weight: FontWeight.w600,
              color: const Color(0xFFFF3B30))),
    ]),
  );
}
