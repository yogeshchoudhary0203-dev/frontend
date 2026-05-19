class UserProfile {
  final String id;
  final String name;
  final String username;
  final String? picture;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.picture,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      username: json['username'],
      picture: json['picture'],
    );
  }
}

class ChatConversation {
  final String id;
  final List<UserProfile> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCounts;
  final bool isGroup;
  final String? name;

  ChatConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCounts = const {},
    this.isGroup = false,
    this.name,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final Map<String, int> unreadCounts = {};
    if (json['unread_counts'] != null) {
      json['unread_counts'].forEach((key, value) {
        unreadCounts[key] = value as int;
      });
    }

    return ChatConversation(
      id: json['id'],
      participants: (json['participants'] as List)
          .map((p) => UserProfile.fromJson(p))
          .toList(),
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time']).toLocal()
          : null,
      unreadCounts: unreadCounts,
      isGroup: json['is_group'] ?? false,
      name: json['name'],
    );
  }

  UserProfile getOtherParticipant(String myUserId) {
    return participants.firstWhere((p) => p.id != myUserId, orElse: () => participants.first);
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readBy = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      readBy: List<String>.from(json['read_by'] ?? []),
    );
  }
}
