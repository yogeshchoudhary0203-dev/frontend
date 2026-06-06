class UserProfile {
  final String id;
  final String name;
  final String username;
  final String? picture;
  final String? publicKey;
  final bool isFollowing;
  final int followersCount;
  final int followingCount;
  final String? bio;
  final String? link;
  final String? snapchatLink;
  final String? instagramLink;
  final String? whatsappLink;
  final String? facebookLink;
  final String? twitterLink;
  final String? youtubeLink;
  final String? locationCity;
  final bool locationPublic;
  final double? locationLat;
  final double? locationLng;
  final String accountType;
  final String? senderBubbleColor;
  final String? receiverBubbleColor;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.picture,
    this.publicKey,
    this.isFollowing = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.bio,
    this.link,
    this.snapchatLink,
    this.instagramLink,
    this.whatsappLink,
    this.facebookLink,
    this.twitterLink,
    this.youtubeLink,
    this.locationCity,
    this.locationPublic = true,
    this.locationLat,
    this.locationLng,
    this.accountType = 'personal',
    this.senderBubbleColor,
    this.receiverBubbleColor,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      picture: json['picture'] as String?,
      publicKey: json['public_key'] as String?,
      isFollowing: json['is_following'] == true,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      bio: json['bio'] as String?,
      link: json['link'] as String?,
      snapchatLink: json['snapchat_link'] as String?,
      instagramLink: json['instagram_link'] as String?,
      whatsappLink: json['whatsapp_link'] as String?,
      facebookLink: json['facebook_link'] as String?,
      twitterLink: json['twitter_link'] as String?,
      youtubeLink: json['youtube_link'] as String?,
      locationCity: json['location_city'] as String?,
      locationPublic: json['location_public'] as bool? ?? true,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      accountType: (json['account_type'] as String?)?.trim().isNotEmpty == true
          ? (json['account_type'] as String)
          : 'personal',
      senderBubbleColor: json['sender_bubble_color'] as String?,
      receiverBubbleColor: json['receiver_bubble_color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'picture': picture,
      'public_key': publicKey,
      'is_following': isFollowing,
      'followers_count': followersCount,
      'following_count': followingCount,
      'bio': bio,
      'link': link,
      'snapchat_link': snapchatLink,
      'instagram_link': instagramLink,
      'whatsapp_link': whatsappLink,
      'facebook_link': facebookLink,
      'twitter_link': twitterLink,
      'youtube_link': youtubeLink,
      'location_city': locationCity,
      'location_public': locationPublic,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'account_type': accountType,
      'sender_bubble_color': senderBubbleColor,
      'receiver_bubble_color': receiverBubbleColor,
    };
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

  /// reactions: emoji → list of user-ids who reacted
  final Map<String, List<String>> reactions;

  /// The message this is replying to (if any)
  final String? replyToId;
  final String? replyToText;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readBy = const [],
    this.encryptedAesKeys = const {},
    this.reactions = const {},
    this.replyToId,
    this.replyToText,
  });

  /// Returns a copy with updated reactions (for real-time WS updates).
  ChatMessage copyWithReactions(Map<String, List<String>> newReactions) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
      readBy: readBy,
      encryptedAesKeys: encryptedAesKeys,
      reactions: newReactions,
      replyToId: replyToId,
      replyToText: replyToText,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final Map<String, String> encryptedAesKeys = {};
    if (json['encrypted_aes_keys'] != null) {
      json['encrypted_aes_keys'].forEach((key, value) {
        encryptedAesKeys[key] = value as String;
      });
    }

    final Map<String, List<String>> reactions = {};
    if (json['reactions'] != null) {
      (json['reactions'] as Map<String, dynamic>).forEach((emoji, users) {
        reactions[emoji] = List<String>.from(users as List);
      });
    }

    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      readBy: List<String>.from(json['read_by'] ?? []),
      encryptedAesKeys: encryptedAesKeys,
      reactions: reactions,
      replyToId: json['reply_to_id'] as String?,
      replyToText: json['reply_to_text'] as String?,
    );
  }
}
