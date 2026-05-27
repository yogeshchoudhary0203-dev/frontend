import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class StoryModel {
  final String   id;
  final String   userId;
  final String   userName;
  final String   userUsername;
  final String?  userPicture;
  final String   mediaUrl;
  final String   publicId;
  final int      expiresInHours;
  final DateTime expiresAt;
  final DateTime createdAt;
  final int      viewCount;
  final bool     viewed;
  final bool     isOwn;

  const StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userPicture,
    required this.mediaUrl,
    required this.publicId,
    required this.expiresInHours,
    required this.expiresAt,
    required this.createdAt,
    required this.viewCount,
    required this.viewed,
    required this.isOwn,
  });

  factory StoryModel.fromJson(Map<String, dynamic> j) => StoryModel(
    id:             j['id'] ?? '',
    userId:         j['user_id'] ?? '',
    userName:       j['user_name'] ?? '',
    userUsername:   j['user_username'] ?? '',
    userPicture:    j['user_picture'],
    mediaUrl:       j['media_url'] ?? '',
    publicId:       j['public_id'] ?? '',
    expiresInHours: (j['expires_in_hours'] as num?)?.toInt() ?? 24,
    expiresAt:      DateTime.tryParse(j['expires_at'] ?? '') ??
                    DateTime.now().add(const Duration(hours: 24)),
    createdAt:      DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    viewCount:      (j['view_count'] as num?)?.toInt() ?? 0,
    viewed:         j['viewed'] == true,
    isOwn:          j['is_own'] == true,
  );
}

class StoryUserGroup {
  final String         userId;
  final String         userName;
  final String         userUsername;
  final String?        userPicture;
  final bool           isOwn;
  final bool           allSeen;
  final List<StoryModel> stories;

  const StoryUserGroup({
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userPicture,
    required this.isOwn,
    required this.allSeen,
    required this.stories,
  });

  bool get hasStories => stories.isNotEmpty;

  factory StoryUserGroup.fromJson(Map<String, dynamic> j) => StoryUserGroup(
    userId:       j['user_id'] ?? '',
    userName:     j['user_name'] ?? '',
    userUsername: j['user_username'] ?? '',
    userPicture:  j['user_picture'],
    isOwn:        j['is_own'] == true,
    allSeen:      j['all_seen'] == true,
    stories:      (j['stories'] as List? ?? [])
        .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class StoryService {
  StoryService._();
  static final StoryService instance = StoryService._();

  Future<List<StoryUserGroup>> getFeed() async {
    final data = await ApiService.get(
      '/stories/',
      requiresAuth: true,
      bypassCache: true,
    );
    return (data['users'] as List? ?? [])
        .map((u) => StoryUserGroup.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<StoryModel> create({
    required String mediaUrl,
    required String publicId,
    required int    expiresInHours,
  }) async {
    final data = await ApiService.post(
      '/stories/',
      {
        'media_url':        mediaUrl,
        'public_id':        publicId,
        'expires_in_hours': expiresInHours,
      },
      requiresAuth: true,
    );
    return StoryModel.fromJson(data);
  }

  Future<void> view(String storyId) async {
    try {
      await ApiService.post('/stories/$storyId/view', {}, requiresAuth: true);
    } catch (_) {}
  }

  Future<void> hideAllFrom(String targetUsername) async {
    await ApiService.post(
      '/stories/hide-all-from',
      {'target_username': targetUsername},
      requiresAuth: true,
    );
  }

  Future<void> deleteStory(String storyId) async {
    await ApiService.delete('/stories/$storyId', requiresAuth: true);
  }
}
