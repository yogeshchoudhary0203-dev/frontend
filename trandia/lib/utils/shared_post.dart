// lib/utils/shared_post.dart
// Encodes a Trandia post (image/reel) so it can travel inside a normal
// (end-to-end encrypted) chat message and be rendered as an Instagram-style
// card on the other side — WITHOUT any extra DB/API hit. Everything the card
// needs to draw (media url, thumbnail, author, caption, aspect) is embedded in
// the message text itself.

import 'dart:convert';
import '../services/post_service.dart';

class SharedPost {
  final String id;
  final String mediaType; // 'video' | 'image'
  final String mediaUrl;
  final String? thumbnailUrl;
  final String caption;
  final String userName;
  final String userUsername;
  final String? userPicture;
  final double aspectRatio;

  const SharedPost({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption = '',
    this.userName = '',
    this.userUsername = '',
    this.userPicture,
    this.aspectRatio = 1.0,
  });

  bool get isVideo => mediaType == 'video';

  // Marker stored under "_t" so a parsed JSON message is recognised as a shared
  // post (and never confused with an ordinary text message or an encrypted blob).
  static const String _marker = 'shared_post';

  factory SharedPost.fromPost(PostModel p) => SharedPost(
        id: p.id,
        mediaType: p.mediaType,
        mediaUrl: p.mediaUrl,
        thumbnailUrl: p.thumbnailUrl,
        caption: p.caption,
        userName: p.userName,
        userUsername: p.userUsername,
        userPicture: p.userPicture,
        aspectRatio: p.aspectRatio,
      );

  /// Compact JSON that becomes the chat message body.
  String encode() => jsonEncode({
        '_t': _marker,
        'id': id,
        'mt': mediaType,
        'u': mediaUrl,
        'th': thumbnailUrl,
        'cap': caption,
        'un': userName,
        'uu': userUsername,
        'up': userPicture,
        'ar': aspectRatio,
      });

  /// Returns a [SharedPost] if [text] is a shared-post payload, else null.
  /// Cheap fast-path bail-out before attempting a JSON decode.
  static SharedPost? tryParse(String text) {
    final t = text.trimLeft();
    if (!t.startsWith('{') || !t.contains('"_t"')) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map || decoded['_t'] != _marker) return null;
      return SharedPost(
        id: decoded['id'] as String? ?? '',
        mediaType: decoded['mt'] as String? ?? 'image',
        mediaUrl: decoded['u'] as String? ?? '',
        thumbnailUrl: decoded['th'] as String?,
        caption: decoded['cap'] as String? ?? '',
        userName: decoded['un'] as String? ?? '',
        userUsername: decoded['uu'] as String? ?? '',
        userPicture: decoded['up'] as String?,
        aspectRatio: (decoded['ar'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Short label for the conversation-list preview row.
  String get previewLabel => isVideo ? '🎬 Shared a reel' : '📷 Shared a post';
}
