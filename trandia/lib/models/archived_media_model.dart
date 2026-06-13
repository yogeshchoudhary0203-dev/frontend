class ArchivedMedia {
  final String id;
  final String? messageId;
  final String mediaUrl;
  final String mediaType; // "image" | "video"
  final String? mediaPublicId;
  final DateTime archivedAt;

  ArchivedMedia({
    required this.id,
    this.messageId,
    required this.mediaUrl,
    required this.mediaType,
    this.mediaPublicId,
    required this.archivedAt,
  });

  factory ArchivedMedia.fromJson(Map<String, dynamic> json) {
    return ArchivedMedia(
      id: json['id'] as String? ?? '',
      messageId: json['message_id'] as String?,
      mediaUrl: json['media_url'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'image',
      mediaPublicId: json['media_public_id'] as String?,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_public_id': mediaPublicId,
      'archived_at': archivedAt.toIso8601String(),
    };
  }
}
