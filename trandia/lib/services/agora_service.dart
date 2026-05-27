// agora_service.dart — agora_rtc_engine v6.x correct pattern

import 'dart:developer' as developer;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

const String kAgoraAppId = '4acf66a0e7e246fe80064783ec2bb879';

enum CallType  { voice, video }
enum CallState { idle, connecting, connected, ended }

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;

  RtcEngine? get rtcEngine => _engine;

  // State
  CallState callState     = CallState.idle;
  CallType? currentCallType;
  String?   currentChannel;
  int?      remoteUid;
  bool      isMuted       = false;
  bool      isSpeakerOn   = true;
  bool      isCameraOff   = false;
  bool      isFrontCamera = true;

  // Callbacks
  Function(int uid)?      onUserJoined;
  Function(int uid)?      onUserOffline;
  Function(CallState)?    onCallStateChanged;
  Function(String error)? onError;

  // ── Token fetch ──────────────────────────────────────────────

  Future<String> _fetchToken(String channelName, {int uid = 0}) async {
    try {
      final result = await ApiService.get(
        '/agora/token?channel=$channelName&uid=$uid',
        requiresAuth: false,
        bypassCache: true,
      );
      final token = result['token'] as String? ?? '';
      if (token.isEmpty) {
        throw Exception('Server returned empty token. Check AGORA_APP_CERTIFICATE in Railway.');
      }
      developer.log('[Agora] Token OK len=${token.length}');
      return token;
    } catch (e) {
      developer.log('[Agora] Token fetch failed: $e');
      rethrow;
    }
  }

  // ── Permissions ─────────────────────────────────────────────

  Future<bool> requestPermissions(CallType type) async {
    final perms = [Permission.microphone];
    if (type == CallType.video) perms.add(Permission.camera);
    final statuses = await perms.request();
    return statuses.values.every((s) => s.isGranted);
  }

  // ── Fresh engine per call ────────────────────────────────────
  // We create a new RtcEngine on every call and release it on end.
  // This avoids ALL state-carry-over bugs between calls.

  Future<RtcEngine> _createEngine() async {
    // Release any previous engine first
    if (_engine != null) {
      try { await _engine!.release(); } catch (_) {}
      _engine = null;
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: kAgoraAppId));

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
        developer.log('[Agora] Joined: ${conn.channelId}');
        callState = CallState.connecting;
        onCallStateChanged?.call(callState);
      },
      onUserJoined: (RtcConnection conn, int uid, int elapsed) {
        developer.log('[Agora] Remote joined: $uid');
        remoteUid = uid;
        callState = CallState.connected;
        onCallStateChanged?.call(callState);
        onUserJoined?.call(uid);
      },
      onUserOffline: (RtcConnection conn, int uid, UserOfflineReasonType reason) {
        developer.log('[Agora] Remote offline: $uid');
        remoteUid = null;
        onUserOffline?.call(uid);
      },
      onLeaveChannel: (RtcConnection conn, RtcStats stats) {
        developer.log('[Agora] Left channel');
        callState = CallState.ended;
        onCallStateChanged?.call(callState);
      },
      onError: (ErrorCodeType err, String msg) {
        developer.log('[Agora] Error: ${err.index} - $msg');
        onError?.call('${err.index}: $msg');
      },
      onTokenPrivilegeWillExpire: (RtcConnection conn, String token) {
        developer.log('[Agora] Token expiring soon');
      },
    ));

    _engine = engine;
    return engine;
  }

  // ── Join Voice ───────────────────────────────────────────────

  Future<void> joinVoiceCall({required String channelName, int uid = 0}) async {
    final granted = await requestPermissions(CallType.voice);
    if (!granted) throw Exception('Microphone permission denied');

    final token  = await _fetchToken(channelName, uid: uid);
    final engine = await _createEngine();

    currentCallType = CallType.voice;
    currentChannel  = channelName;
    isMuted         = false;
    isSpeakerOn     = true;

    // Voice only — disable video explicitly
    await engine.disableVideo();
    await engine.setEnableSpeakerphone(true);

    await engine.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       uid,
      options:   const ChannelMediaOptions(
        clientRoleType:         ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio:     true,
        autoSubscribeVideo:     false,
        publishMicrophoneTrack: true,
        publishCameraTrack:     false,
      ),
    );

    callState = CallState.connecting;
    onCallStateChanged?.call(callState);
  }

  // ── Join Video ───────────────────────────────────────────────

  Future<void> joinVideoCall({required String channelName, int uid = 0}) async {
    final granted = await requestPermissions(CallType.video);
    if (!granted) throw Exception('Camera/Microphone permission denied');

    final token  = await _fetchToken(channelName, uid: uid);
    final engine = await _createEngine();

    currentCallType = CallType.video;
    currentChannel  = channelName;
    isMuted         = false;
    isCameraOff     = false;
    isFrontCamera   = true;

    await engine.enableVideo();
    await engine.startPreview();

    await engine.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       uid,
      options:   const ChannelMediaOptions(
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

  // ── Controls ─────────────────────────────────────────────────

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

  // ── Leave ────────────────────────────────────────────────────

  Future<void> leaveCall() async {
    final eng = _engine;
    if (eng == null) return;
    _engine = null; // clear ref first so callbacks don't fire after

    try {
      await eng.leaveChannel();
      if (currentCallType == CallType.video) {
        await eng.stopPreview();
        await eng.disableVideo();
      }
      await eng.release();
    } catch (e) {
      developer.log('[Agora] leaveCall error: $e');
      try { await eng.release(); } catch (_) {}
    } finally {
      callState       = CallState.idle;
      currentChannel  = null;
      currentCallType = null;
      remoteUid       = null;
      isMuted         = false;
      isSpeakerOn     = true;
      isCameraOff     = false;
      isFrontCamera   = true;
      onUserJoined        = null;
      onUserOffline       = null;
      onCallStateChanged  = null;
      onError             = null;
    }
  }

  // ── Channel name helper ───────────────────────────────────────

  static String buildChannelName(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'trandia_${sorted[0]}_${sorted[1]}';
  }
}
