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
  int _reconnectDelay = 2; // seconds, doubles each attempt

  final _messageCtrl = StreamController<ChatMessage>.broadcast();
  final _typingCtrl  = StreamController<Map<String, dynamic>>.broadcast();

  // Typing throttle — only send 1 event per 2 seconds
  DateTime? _lastTypingSent;

  String? _myUserId;
  String? _localPublicKey;
  String? _localPrivateKey;

  Stream<ChatMessage> get messageStream => _messageCtrl.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingCtrl.stream;
  bool get isConnected => _channel != null;

  // ── WebSocket ────────────────────────────────────────────────

  Future<void> connectWebSocket() async {
    if (_channel != null || _isConnecting) return;
    _isConnecting = true;

    try {
      _myUserId = await AuthService.getCurrentUserId();
      _localPublicKey = await CryptographyService().initKeys();
      _localPrivateKey = await CryptographyService().getLocalPrivateKey();
    } catch (e) {
      developer.log('[ChatService] Failed to load local keys: $e');
    }

    final token = await ApiService.getToken();
    if (token == null) { _isConnecting = false; return; }

    final wsUri = Uri.parse('$wsUrl/chat/ws?token=$token');
    developer.log('[ChatService] Connecting WebSocket: $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);

      // Wait for connection to be ready (throws if server rejects)
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _reconnectDelay = 2; // reset backoff on success
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
      if (type == 'message') {
        var msg = ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
        msg = decryptMessage(msg);
        _messageCtrl.add(msg);
      } else if (type == 'typing') {
        _typingCtrl.add({
          'conversation_id': data['conversation_id'],
          'user_id': data['user_id'],
        });
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
    _reconnectDelay = (_reconnectDelay * 2).clamp(2, 60); // max 60s
    developer.log('[ChatService] Reconnecting in ${delay}s…');
    _reconnectTimer = Timer(Duration(seconds: delay), connectWebSocket);
  }

  void disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  // ── Send helpers ─────────────────────────────────────────────

  Future<void> sendMessage(
    String conversationId,
    String text,
    List<UserProfile> participants, {
    DateTime? createdAt,
  }) async {
    if (_channel == null) {
      developer.log('[ChatService] sendMessage: WS not connected');
      return;
    }

    try {
      await _ensureKeysLoaded();

      // 1. Generate a random AES symmetric key
      final aesKey = CryptographyService().generateRandomAESKey();

      // 2. Encrypt the plaintext text with the AES key
      final encryptedText = CryptographyService().encryptAES(text, aesKey);

      // 3. Encrypt the AES key with each participant's public key
      final Map<String, String> encryptedAesKeys = {};
      for (final p in participants) {
        if (p.publicKey != null && p.publicKey!.isNotEmpty) {
          final encKey = CryptographyService().encryptAESKeyWithRSA(aesKey, p.publicKey!);
          encryptedAesKeys[p.id] = encKey;
        } else {
          developer.log('[ChatService] Warning: participant ${p.username} has no public key');
        }
      }

      // Conversations opened from search can omit my own public key from the
      // lightweight participant object. Add it so sender echoes/history decrypt.
      if (_myUserId != null &&
          _localPublicKey != null &&
          _localPublicKey!.isNotEmpty &&
          !encryptedAesKeys.containsKey(_myUserId)) {
        encryptedAesKeys[_myUserId!] =
            CryptographyService().encryptAESKeyWithRSA(aesKey, _localPublicKey!);
      }

      // 4. Send the payload over WebSocket
      _channel!.sink.add(jsonEncode({
        'type': 'message',
        'conversation_id': conversationId,
        'text': encryptedText,
        'client_created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        'encrypted_aes_keys': encryptedAesKeys,
      }));
    } catch (e) {
      developer.log('[ChatService] Error encrypting and sending message: $e');
    }
  }

  /// Throttled — sends at most 1 typing event per 2 seconds.
  void sendTyping(String conversationId) {
    if (_channel == null) return;
    final now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!).inSeconds < 2) return;
    _lastTypingSent = now;
    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'conversation_id': conversationId,
    }));
  }

  void markAsRead(String conversationId) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'read',
      'conversation_id': conversationId,
    }));
  }

  // ── REST endpoints ───────────────────────────────────────────

  /// BUG FIX: Removed the broken ApiService.get() call that was at the top.
  /// ApiService.get() casts the response to Map<String, dynamic>, but
  /// /chat/conversations returns a JSON *array*. That cast always threw a
  /// TypeError, and the correct http.get below it NEVER ran.
  /// Result: chat list was always empty, and _startChat always failed.
  Future<List<ChatConversation>> getConversations() async {
    final token = await ApiService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      await _ensureKeysLoaded();
      return data.map((e) {
        final conv = ChatConversation.fromJson(e as Map<String, dynamic>);
        final decryptedText = decryptLastMessage(conv.lastMessage, conv.lastMessageEncryptedAesKeys);
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

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int skip = 0,
    int limit = 50,
  }) async {
    final token = await ApiService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/chat/$conversationId/messages?skip=$skip&limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      await _ensureKeysLoaded();
      return _decryptMessagesInBatches(data);
    } else if (res.statusCode == 401) {
      await ApiService.clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    } else {
      throw ApiException('Failed to load messages (${res.statusCode})');
    }
  }

  // ── Cryptography and Key Cache Helpers ───────────────────────────

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
    if (msg.encryptedAesKeys.isEmpty) {
      return msg;
    }

    final myId = _myUserId;
    final myPrivKey = _localPrivateKey;

    if (myId == null || myPrivKey == null) {
      developer.log('[ChatService] Cannot decrypt message: user ID or local private key is null');
      return _hiddenEncryptedMessage(msg);
    }

    final encAesKey = msg.encryptedAesKeys[myId];
    if (encAesKey == null) {
      developer.log('[ChatService] Cannot decrypt message: no encrypted AES key found for current user $myId');
      return _hiddenEncryptedMessage(msg);
    }

    try {
      final aesKey = CryptographyService().decryptAESKeyWithRSA(encAesKey, myPrivKey);
      final plainText = CryptographyService().decryptAES(msg.text, aesKey);
      return ChatMessage(
        id: msg.id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        text: plainText,
        createdAt: msg.createdAt,
        readBy: msg.readBy,
        encryptedAesKeys: msg.encryptedAesKeys,
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
      if (i % 5 == 4) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return messages;
  }

  ChatMessage _hiddenEncryptedMessage(ChatMessage msg) {
    return ChatMessage(
      id: msg.id,
      conversationId: msg.conversationId,
      senderId: msg.senderId,
      text: '',
      createdAt: msg.createdAt,
      readBy: msg.readBy,
      encryptedAesKeys: msg.encryptedAesKeys,
    );
  }

  String? decryptLastMessage(String? lastMessage, Map<String, String> encryptedAesKeys) {
    if (lastMessage == null || lastMessage.isEmpty || encryptedAesKeys.isEmpty) {
      return lastMessage;
    }

    final myId = _myUserId;
    final myPrivKey = _localPrivateKey;

    if (myId == null || myPrivKey == null) {
      return '🔒 [Encrypted Message]';
    }

    final encAesKey = encryptedAesKeys[myId];
    if (encAesKey == null) {
      return '🔒 [Encrypted Message]';
    }

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
