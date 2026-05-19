import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import 'api_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  WebSocketChannel? _channel;
  final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  Future<void> connectWebSocket() async {
    if (_channel != null) return; // Already connected

    final token = await ApiService.getToken();
    if (token == null) return;

    final wsUri = Uri.parse('$wsUrl/chat/ws?token=$token');
    
    try {
      _channel = WebSocketChannel.connect(wsUri);
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'message') {
            final msg = ChatMessage.fromJson(data['message']);
            _messageController.add(msg);
          } else if (data['type'] == 'typing') {
            _typingController.add({
              'conversation_id': data['conversation_id'],
              'user_id': data['user_id'],
            });
          }
        },
        onDone: () {
          _channel = null;
          // Could implement reconnect logic here
        },
        onError: (error) {
          _channel = null;
        },
      );
    } catch (e) {
      _channel = null;
    }
  }

  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  void sendMessage(String conversationId, String text) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'message',
        'conversation_id': conversationId,
        'text': text,
      }));
    }
  }

  void sendTyping(String conversationId) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'conversation_id': conversationId,
      }));
    }
  }

  void markAsRead(String conversationId) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'read',
        'conversation_id': conversationId,
      }));
    }
  }

  // REST endpoints
  Future<List<ChatConversation>> getConversations() async {
    final response = await ApiService.get('/chat/conversations', requiresAuth: true);
    // API returns a list directly, but ApiService.get returns Map<String, dynamic> 
    // Wait, ApiService.get is hardcoded to return Map<String, dynamic>. 
    // If the endpoint returns a JSON array, jsonDecode(response.body) returns a List.
    // I need to adjust this. Let's use http directly or change the service.
    
    // Instead of using ApiService.get which enforces Map, we will use a custom call.
    final token = await ApiService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ChatConversation.fromJson(e)).toList();
    } else {
      throw ApiException('Failed to load conversations');
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId, {int skip = 0, int limit = 50}) async {
    final token = await ApiService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/chat/$conversationId/messages?skip=$skip&limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    } else {
      throw ApiException('Failed to load messages');
    }
  }

  Future<String> startConversation(String participantUsername) async {
    final response = await ApiService.post(
      '/chat/conversations',
      {'participant_username': participantUsername},
      requiresAuth: true,
    );
    return response['conversation_id'];
  }
}
