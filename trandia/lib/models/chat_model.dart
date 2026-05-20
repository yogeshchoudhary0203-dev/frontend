class UserProfile {
  final String id;
  final String name;
  final String username;
  final String? picture;
  final String? publicKey;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.picture,
    this.publicKey,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      username: json['username'],
      picture: json['picture'],
      publicKey: json['public_key'],
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
  final Map<String, String> lastMessageEncryptedAesKeys;

  ChatConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCounts = const {},
    this.isGroup = false,
    this.name,
    this.lastMessageEncryptedAesKeys = const {},
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final Map<String, int> unreadCounts = {};
    if (json['unread_counts'] != null) {
      json['unread_counts'].forEach((key, value) {
        unreadCounts[key] = value as int;
      });
    }

    final Map<String, String> lastMessageEncryptedAesKeys = {};
    if (json['last_message_encrypted_aes_keys'] != null) {
      json['last_message_encrypted_aes_keys'].forEach((key, value) {
        lastMessageEncryptedAesKeys[key] = value as String;
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
      lastMessageEncryptedAesKeys: lastMessageEncryptedAesKeys,
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
  final Map<String, String> encryptedAesKeys;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readBy = const [],
    this.encryptedAesKeys = const {},
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final Map<String, String> encryptedAesKeys = {};
    if (json['encrypted_aes_keys'] != null) {
      json['encrypted_aes_keys'].forEach((key, value) {
        encryptedAesKeys[key] = value as String;
      });
    }

    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      readBy: List<String>.from(json['read_by'] ?? []),
      encryptedAesKeys: encryptedAesKeys,
    );
  }
}
