// agora_service.dart
// Singleton Agora RTC service — manages voice & video call lifecycle.
// Token is fetched from backend /agora/token before every call.

import 'dart:developer' as developer;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

const String kAgoraAppId = '4acf66a0e7e246fe80064783ec2bb879';

enum CallType  { voice, video }
enum CallState { idle, connecting, connected, ended }

/// Agora RTC service — singleton
class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;

  RtcEngine? get rtcEngine => _engine;

  // Call state
  CallState callState      = CallState.idle;
  CallType? currentCallType;
  String?   currentChannel;
  int?      remoteUid;
  bool      isMuted        = false;
  bool      isSpeakerOn    = true;
  bool      isCameraOff    = false;
  bool      isFrontCamera  = true;

  // Callbacks — set by the active call screen, cleared on leaveCall
  Function(int uid)?       onUserJoined;
  Function(int uid)?       onUserOffline;
  Function(CallState)?     onCallStateChanged;
  Function(String error)?  onError;

  // ── Init ────────────────────────────────────────────────────────────────

  Future<RtcEngine> get engine async {
    if (_engine == null || !_isInitialized) await _init();
    return _engine!;
  }

  Future<void> _init() async {
    if (_isInitialized && _engine != null) return;
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: kAgoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          developer.log('[Agora] Joined channel: ${connection.channelId}');
          callState = CallState.connecting;
          onCallStateChanged?.call(callState);
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          developer.log('[Agora] Remote user joined: $uid');
          remoteUid  = uid;
          callState  = CallState.connected;
          onCallStateChanged?.call(callState);
          onUserJoined?.call(uid);
        },
        onUserOffline: (RtcConnection connection, int uid,
            UserOfflineReasonType reason) {
          developer.log('[Agora] Remote user offline: $uid');
          remoteUid = null;
          onUserOffline?.call(uid);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          developer.log('[Agora] Left channel');
          callState = CallState.ended;
          onCallStateChanged?.call(callState);
        },
        onError: (ErrorCodeType err, String msg) {
          developer.log('[Agora] Error: $err - $msg');
          onError?.call(msg);
        },
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state, ConnectionChangedReasonType reason) {
          developer.log('[Agora] Connection state: $state');
        },
      ));

      _isInitialized = true;
      developer.log('[Agora] Engine initialized ✓');
    } catch (e) {
      developer.log('[Agora] Init error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<bool> requestPermissions(CallType type) async {
    final permissions = [Permission.microphone];
    if (type == CallType.video) permissions.add(Permission.camera);
    final statuses = await permissions.request();
    for (final status in statuses.values) {
      if (!status.isGranted) return false;
    }
    return true;
  }

  // ── Token Fetch ───────────────────────────────────────────────────────────

  Future<String> _fetchToken(String channelName, {int uid = 0}) async {
    try {
      final result = await ApiService.get(
        '/agora/token?channel=$channelName&uid=$uid',
        requiresAuth: true,
        bypassCache: true,
      );
      final token = result['token'] as String? ?? '';
      developer.log('[Agora] Token fetched ✓ (len=${token.length})');
      return token;
    } catch (e) {
      developer.log('[Agora] Token fetch failed: $e — using empty token');
      // Empty token works when App Certificate is disabled in Agora console
      return '';
    }
  }

  // ── Join ─────────────────────────────────────────────────────────────────

  Future<void> joinVoiceCall({required String channelName, int uid = 0}) async {
    final granted = await requestPermissions(CallType.voice);
    if (!granted) throw Exception('Microphone permission denied');

    final token = await _fetchToken(channelName, uid: uid);
    final eng   = await engine;

    currentCallType = CallType.voice;
    currentChannel  = channelName;
    isMuted         = false;
    isSpeakerOn     = true;

    await eng.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await eng.enableAudio();
    await eng.disableVideo();
    await eng.setEnableSpeakerphone(true);

    await eng.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       uid,
      options: const ChannelMediaOptions(
        channelProfile:      ChannelProfileType.channelProfileCommunication,
        clientRoleType:      ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio:  true,
        autoSubscribeVideo:  false,
        publishMicrophoneTrack: true,
        publishCameraTrack:  false,
      ),
    );
    callState = CallState.connecting;
    onCallStateChanged?.call(callState);
  }

  Future<void> joinVideoCall({required String channelName, int uid = 0}) async {
    final granted = await requestPermissions(CallType.video);
    if (!granted) throw Exception('Camera/Microphone permission denied');

    final token = await _fetchToken(channelName, uid: uid);
    final eng   = await engine;

    currentCallType = CallType.video;
    currentChannel  = channelName;
    isMuted         = false;
    isCameraOff     = false;
    isFrontCamera   = true;

    await eng.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await eng.enableAudio();
    await eng.enableVideo();
    await eng.startPreview();

    await eng.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       uid,
      options: const ChannelMediaOptions(
        channelProfile:         ChannelProfileType.channelProfileCommunication,
        clientRoleType:         ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio:     true,
        autoSubscribeVideo:     true,
        publishMicrophoneTrack: true,
        publishCameraTrack:     true,
      ),
    );
    callState = CallState.connecting;
    onCallStateChanged?.call(callState);
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    if (_engine == null) return;
    isMuted = !isMuted;
    await _engine!.muteLocalAudioStream(isMuted);
  }

  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    isSpeakerOn = !isSpeakerOn;
    await _engine!.setEnableSpeakerphone(isSpeakerOn);
  }

  Future<void> toggleCamera() async {
    if (_engine == null) return;
    isCameraOff = !isCameraOff;
    await _engine!.muteLocalVideoStream(isCameraOff);
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;
    isFrontCamera = !isFrontCamera;
    await _engine!.switchCamera();
  }

  // ── Leave ─────────────────────────────────────────────────────────────────

  Future<void> leaveCall() async {
    if (_engine == null) return;
    try {
      await _engine!.leaveChannel();
      if (currentCallType == CallType.video) {
        await _engine!.stopPreview();
        await _engine!.disableVideo();
      }
    } catch (e) {
      developer.log('[Agora] leaveCall error: $e');
    } finally {
      // Always reset state & callbacks so stale references don't leak
      callState       = CallState.idle;
      currentChannel  = null;
      currentCallType = null;
      remoteUid       = null;
      isMuted         = false;
      isSpeakerOn     = true;
      isCameraOff     = false;
      isFrontCamera   = true;
      onUserJoined         = null;
      onUserOffline        = null;
      onCallStateChanged   = null;
      onError              = null;
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await leaveCall();
    await _engine?.release();
    _engine = null;
    _isInitialized = false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Deterministic channel: sorted user IDs joined by underscore
  static String buildChannelName(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'trandia_${sorted[0]}_${sorted[1]}';
  }
}
