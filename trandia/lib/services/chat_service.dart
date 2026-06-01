import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import 'api_service.dart';
import 'cryptography_service.dart';
import 'auth_service.dart';

/// Singleton chat service — WebSocket + REST.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  WebSocketChannel? _channel;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectDelay = 1; // seconds, doubles each attempt

  final _messageCtrl      = StreamController<ChatMessage>.broadcast();
  final _typingCtrl       = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _callCtrl         = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _deletedCtrl      = StreamController<Map<String, dynamic>>.broadcast();

  // Tracks which user IDs are currently online (updated via WS presence events)
  final Set<String> _onlineUserIds = {};

  // In-memory messages cache: convId → list (most-recent first)
  final Map<String, List<ChatMessage>> _msgCache = {};

  // Typing throttle — only send 1 event per 2 seconds
  DateTime? _lastTypingSent;

  String? _myUserId;
  String? _localPublicKey;
  String? _localPrivateKey;

  Stream<ChatMessage>            get messageStream      => _messageCtrl.stream;
  Stream<Map<String, dynamic>>   get typingStream       => _typingCtrl.stream;
  Stream<Map<String, dynamic>>   get reactionStream     => _reactionCtrl.stream;
  Stream<Map<String, dynamic>>   get notificationStream => _notificationCtrl.stream;
  Stream<Map<String, dynamic>>   get callStream         => _callCtrl.stream;
  Stream<Map<String, dynamic>>   get presenceStream     => _presenceCtrl.stream;
  Stream<Map<String, dynamic>>   get deletedStream      => _deletedCtrl.stream;
  Set<String> get onlineUserIds => Set.unmodifiable(_onlineUserIds);
  bool get isConnected => _channel != null;

  // ── WebSocket ────────────────────────────────────────────────

  Future<void> connectWebSocket() async {
    if (_channel != null || _isConnecting) return;
    _isConnecting = true;

    try {
      final results = await Future.wait([
        AuthService.getCurrentUserId(),
        CryptographyService().initKeys(),
        CryptographyService().getLocalPrivateKey(),
        ApiService.getToken(),
      ]);
      _myUserId        = results[0] as String?;
      _localPublicKey  = results[1] as String?;
      _localPrivateKey = results[2] as String?;
      final token      = results[3] as String?;

      if (token == null) { _isConnecting = false; return; }

      final wsUri = Uri.parse('$wsUrl/chat/ws?token=$token');
      developer.log('[ChatService] Connecting WebSocket: $wsUri');

      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready.timeout(const Duration(seconds: 8));
      _reconnectDelay = 1;
      developer.log('[ChatService] WebSocket connected ✓');

      _channel!.stream.listen(
        _onWsMessage,
        onDone: _onWsDone,
        onError: _onWsError,
        cancelOnError: false,
      );
    } catch (e) {
      developer.log('[ChatService] WebSocket connect failed: $e');
      _channel = null;
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _onWsMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'message':
          var msg = ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
          msg = decryptMessage(msg);
          final cached = _msgCache[msg.conversationId];
          if (cached != null) {
            final exists = cached.any((m) => m.id == msg.id);
            if (!exists) cached.insert(0, msg);
          }
          _messageCtrl.add(msg);

        case 'message_deleted':
          final msgId = data['message_id'] as String? ?? '';
          final convId = data['conversation_id'] as String? ?? '';
          if (msgId.isNotEmpty) {
            _msgCache[convId]?.removeWhere((m) => m.id == msgId);
            _deletedCtrl.add({'message_id': msgId, 'conversation_id': convId});
          }

        case 'typing':
          _typingCtrl.add({
            'conversation_id': data['conversation_id'],
            'user_id': data['user_id'],
          });

        case 'react':
          final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
          final Map<String, List<String>> reactions = {};
          rawReactions.forEach((emoji, users) {
            reactions[emoji] = List<String>.from(users as List);
          });
          _reactionCtrl.add({
            'message_id':      data['message_id'] as String,
            'conversation_id': data['conversation_id'] as String,
            'reactions':       reactions,
          });

        case 'notification':
          _notificationCtrl.add(data['notification'] as Map<String, dynamic>);

        // ── Call signaling ──────────────────────────────────
        case 'call_invite':
        case 'call_accept':
        case 'call_reject':
        case 'call_end':
          _callCtrl.add(Map<String, dynamic>.from(data));

        // ── Presence ────────────────────────────────────────
        case 'presence':
          final uid = data['user_id'] as String? ?? '';
          final isOnline = data['online'] as bool? ?? false;
          if (uid.isNotEmpty) {
            if (isOnline) {
              _onlineUserIds.add(uid);
            } else {
              _onlineUserIds.remove(uid);
            }
            _presenceCtrl.add({'user_id': uid, 'online': isOnline});
          }

        case 'presence_init':
          final ids = List<String>.from(data['online_user_ids'] as List? ?? []);
          _onlineUserIds.addAll(ids);
          _presenceCtrl.add({'type': 'presence_init', 'online_user_ids': ids});
      }
    } catch (e) {
      developer.log('[ChatService] WS parse error: $e');
    }
  }

  void _onWsDone() {
    developer.log('[ChatService] WebSocket closed — scheduling reconnect');
    _channel = null;
    _scheduleReconnect();
  }

  void _onWsError(Object error) {
    developer.log('[ChatService] WebSocket error: $error');
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _reconnectDelay;
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, 16);
    developer.log('[ChatService] Reconnecting in ${delay}s…');
    _reconnectTimer = Timer(Duration(seconds: delay), connectWebSocket);
  }

  void disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectDelay = 1;
    _channel?.sink.close();
    _channel = null;
  }

  /// Call on logout — closes every StreamController so listeners are released
  /// and the Dart GC can collect the backing memory.
  void dispose() {
    disconnectWebSocket();
    _messageCtrl.close();
    _typingCtrl.close();
    _reactionCtrl.close();
    _notificationCtrl.close();
    _callCtrl.close();
    _presenceCtrl.close();
    _deletedCtrl.close();
    _onlineUserIds.clear();
    _msgCache.clear();
  }

  // ── Call Signaling ───────────────────────────────────────────

  /// Caller sends this to invite callee.
  bool sendCallInvite({
    required String calleeId,
    required String channelName,
    required String callType,   // 'voice' | 'video'
    required String callerName,
  }) {
    if (_channel == null) {
      developer.log('[ChatService] sendCallInvite: WS not connected');
      return false;
    }
    _channel!.sink.add(jsonEncode({
      'type':         'call_invite',
      'callee_id':    calleeId,
      'channel_name': channelName,
      'call_type':    callType,
      'caller_name':  callerName,
    }));
    developer.log('[ChatService] call_invite sent → $calleeId ($callType)');
    return true;
  }

  /// Send call_accept / call_reject / call_end to the other party.
  bool sendCallSignal({
    required String signalType,   // 'call_accept' | 'call_reject' | 'call_end'
    required String targetId,
    required String channelName,
  }) {
    if (_channel == null) {
      developer.log('[ChatService] sendCallSignal: WS not connected');
      return false;
    }
    _channel!.sink.add(jsonEncode({
      'type':         signalType,
      'target_id':    targetId,
      'channel_name': channelName,
    }));
    developer.log('[ChatService] $signalType sent → $targetId');
    return true;
  }

  // ── Send helpers ─────────────────────────────────────────────

  Future<void> sendMessage(
    String conversationId,
    String text,
    List<UserProfile> participants, {
    DateTime? createdAt,
    String? replyToId,
    String? replyToText,
  }) async {
    if (_channel == null) {
      developer.log('[ChatService] sendMessage: WS not connected');
      return;
    }

    try {
      await _ensureKeysLoaded();

      final aesKey        = CryptographyService().generateRandomAESKey();
      final encryptedText = CryptographyService().encryptAES(text, aesKey);

      final Map<String, String> encryptedAesKeys = {};
      for (final p in participants) {
        if (p.publicKey != null && p.publicKey!.isNotEmpty) {
          encryptedAesKeys[p.id] =
              CryptographyService().encryptAESKeyWithRSA(aesKey, p.publicKey!);
        }
      }

      if (_myUserId != null &&
          _localPublicKey != null &&
          _localPublicKey!.isNotEmpty &&
          !encryptedAesKeys.containsKey(_myUserId)) {
        encryptedAesKeys[_myUserId!] =
            CryptographyService().encryptAESKeyWithRSA(aesKey, _localPublicKey!);
      }

      _channel!.sink.add(jsonEncode({
        'type':               'message',
        'conversation_id':    conversationId,
        'text':               encryptedText,
        'client_created_at':  (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        'encrypted_aes_keys': encryptedAesKeys,
        if (replyToId != null)   'reply_to_id':   replyToId,
        if (replyToText != null) 'reply_to_text': replyToText,
      }));
    } catch (e) {
      developer.log('[ChatService] Error encrypting and sending message: $e');
    }
  }

  void sendReaction(String conversationId, String messageId, String emoji) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type':            'react',
      'conversation_id': conversationId,
      'message_id':      messageId,
      'emoji':           emoji,
    }));
  }

  void sendTyping(String conversationId) {
    if (_channel == null) return;
    final now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!).inSeconds < 2) return;
    _lastTypingSent = now;
    _channel!.sink.add(jsonEncode({
      'type':            'typing',
      'conversation_id': conversationId,
    }));
  }

  void markAsRead(String conversationId) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type':            'read',
      'conversation_id': conversationId,
    }));
  }

  // ── REST endpoints ───────────────────────────────────────────

  Future<List<ChatConversation>> getConversations() async {
    final token = await ApiService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      await _ensureKeysLoaded();
      return data.map((e) {
        final conv = ChatConversation.fromJson(e as Map<String, dynamic>);
        final decryptedText = decryptLastMessage(
            conv.lastMessage, conv.lastMessageEncryptedAesKeys);
        return ChatConversation(
          id: conv.id,
          participants: conv.participants,
          lastMessage: decryptedText,
          lastMessageTime: conv.lastMessageTime,
          unreadCounts: conv.unreadCounts,
          isGroup: conv.isGroup,
          name: conv.name,
          lastMessageEncryptedAesKeys: conv.lastMessageEncryptedAesKeys,
        );
      }).toList();
    } else if (res.statusCode == 401) {
      await ApiService.clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    } else {
      throw ApiException('Failed to load conversations (${res.statusCode})');
    }
  }

  /// Returns in-memory cached messages immediately (empty list if not cached yet).
  List<ChatMessage> getCachedMessages(String conversationId) {
    return List.unmodifiable(_msgCache[conversationId] ?? []);
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int skip = 0,
    int limit = 50,
    String? beforeId,
  }) async {
    final token = await ApiService.getToken();
    final query = StringBuffer('skip=$skip&limit=$limit');
    if (beforeId != null) query.write('&before_id=$beforeId');

    final res = await http.get(
      Uri.parse('$baseUrl/chat/$conversationId/messages?$query'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      await _ensureKeysLoaded();
      final msgs = await _decryptMessagesInBatches(data);
      // Update in-memory cache only for first page
      if (skip == 0 && beforeId == null && msgs.isNotEmpty) {
        _msgCache[conversationId] = msgs;
      }
      return msgs;
    } else if (res.statusCode == 401) {
      await ApiService.clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    } else {
      throw ApiException('Failed to load messages (${res.statusCode})');
    }
  }

  /// Fetch only messages newer than [afterId] — used to sync missed messages.
  Future<List<ChatMessage>> syncMessagesAfter(
    String conversationId,
    String afterId,
  ) async {
    // We fetch a fresh first page and return only messages newer than afterId
    try {
      final fresh = await getMessages(conversationId, limit: 50);
      final idx = fresh.indexWhere((m) => m.id == afterId);
      if (idx <= 0) return [];          // already up to date or afterId not found
      return fresh.sublist(0, idx);     // messages newer than afterId
    } catch (_) {
      return [];
    }
  }

  void updateCachedMessage(ChatMessage msg) {
    final cached = _msgCache[msg.conversationId];
    if (cached == null) return;
    final idx = cached.indexWhere((m) => m.id == msg.id);
    if (idx != -1) {
      cached[idx] = msg;
    }
  }

  void evictConversationCache(String conversationId) {
    _msgCache.remove(conversationId);
  }

  // ── Cryptography helpers ─────────────────────────────────────

  Future<void> _ensureKeysLoaded() async {
    if (_myUserId == null) {
      _myUserId = await AuthService.getCurrentUserId();
    }
    if (_localPublicKey == null) {
      _localPublicKey = await CryptographyService().initKeys();
    }
    if (_localPrivateKey == null) {
      _localPrivateKey = await CryptographyService().getLocalPrivateKey();
    }
  }

  ChatMessage decryptMessage(ChatMessage msg) {
    if (msg.encryptedAesKeys.isEmpty) return msg;

    final myId = _myUserId;
    final myPrivKey = _localPrivateKey;

    if (myId == null || myPrivKey == null) {
      return _hiddenEncryptedMessage(msg);
    }

    final encAesKey = msg.encryptedAesKeys[myId];
    if (encAesKey == null) {
      return _hiddenEncryptedMessage(msg);
    }

    try {
      final aesKey   = CryptographyService().decryptAESKeyWithRSA(encAesKey, myPrivKey);
      final plainText = CryptographyService().decryptAES(msg.text, aesKey);
      return ChatMessage(
        id: msg.id, conversationId: msg.conversationId, senderId: msg.senderId,
        text: plainText, createdAt: msg.createdAt, readBy: msg.readBy,
        encryptedAesKeys: msg.encryptedAesKeys, reactions: msg.reactions,
        replyToId: msg.replyToId, replyToText: msg.replyToText,
      );
    } catch (e) {
      developer.log('[ChatService] Decryption error: $e');
      return _hiddenEncryptedMessage(msg);
    }
  }

  Future<List<ChatMessage>> _decryptMessagesInBatches(List data) async {
    final messages = <ChatMessage>[];
    for (var i = 0; i < data.length; i++) {
      final msg = ChatMessage.fromJson(data[i] as Map<String, dynamic>);
      messages.add(decryptMessage(msg));
      // Yield every 5 items — keeps UI responsive during heavy RSA decryption
      if (i % 5 == 4) await Future<void>.delayed(Duration.zero);
    }
    return messages;
  }

  ChatMessage _hiddenEncryptedMessage(ChatMessage msg) => ChatMessage(
    id: msg.id, conversationId: msg.conversationId, senderId: msg.senderId,
    text: '', createdAt: msg.createdAt, readBy: msg.readBy,
    encryptedAesKeys: msg.encryptedAesKeys, reactions: msg.reactions,
    replyToId: msg.replyToId, replyToText: msg.replyToText,
  );

  String? decryptLastMessage(
      String? lastMessage, Map<String, String> encryptedAesKeys) {
    if (lastMessage == null || lastMessage.isEmpty || encryptedAesKeys.isEmpty) {
      return lastMessage;
    }
    final myId = _myUserId;
    final myPrivKey = _localPrivateKey;
    if (myId == null || myPrivKey == null) return '🔒 [Encrypted Message]';

    final encAesKey = encryptedAesKeys[myId];
    if (encAesKey == null) return '🔒 [Encrypted Message]';

    try {
      final aesKey = CryptographyService().decryptAESKeyWithRSA(encAesKey, myPrivKey);
      return CryptographyService().decryptAES(lastMessage, aesKey);
    } catch (e) {
      developer.log('[ChatService] Decrypt preview error: $e');
      return '🔒 [Encrypted Message]';
    }
  }

  void clearCachedKeys() {
    _myUserId = null;
    _localPublicKey = null;
    _localPrivateKey = null;
  }

  Future<String> startConversation(String participantUsername) async {
    final response = await ApiService.post(
      '/chat/conversations',
      {'participant_username': participantUsername},
      requiresAuth: true,
    );
    return response['conversation_id'] as String;
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    final token = await ApiService.getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/chat/$conversationId/messages/$messageId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw ApiException('Failed to delete message (${res.statusCode})');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final token = await ApiService.getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/chat/$conversationId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw ApiException('Failed to delete conversation (${res.statusCode})');
    }
  }
}
