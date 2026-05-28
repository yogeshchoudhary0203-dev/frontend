import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class PostModel {
  final String  id;
  final String  userId;
  final String  userName;
  final String  userUsername;
  final String? userPicture;
  final String  mediaUrl;
  final String? thumbnailUrl;
  final String  publicId;
  final String  mediaType;   // "image" | "video"
  final String  caption;
  final double  aspectRatio;
  final String? section;     // "fun" | "learn" for videos
  final int     likesCount;
  final int     commentsCount;
  final int     sharesCount;
  final bool    isLiked;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userPicture,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.publicId = '',
    required this.mediaType,
    required this.caption,
    required this.aspectRatio,
    this.section,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> j) => PostModel(
        id:            j['id'] ?? '',
        userId:        j['user_id'] ?? '',
        userName:      j['user_name'] ?? '',
        userUsername:  j['user_username'] ?? '',
        userPicture:   j['user_picture'],
        mediaUrl:      j['media_url'] ?? '',
        thumbnailUrl:  j['thumbnail_url'],
        publicId:      j['public_id'] ?? '',
        mediaType:     j['media_type'] ?? 'image',
        caption:       j['caption'] ?? '',
        aspectRatio:   (j['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
        section:       j['section'],
        likesCount:    (j['likes_count'] as num?)?.toInt() ?? 0,
        commentsCount: (j['comments_count'] as num?)?.toInt() ?? 0,
        sharesCount:
            ((j['shares_count'] ?? j['share_count']) as num?)?.toInt() ?? 0,
        isLiked:       j['is_liked'] == true,
        createdAt:     DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLiked,
  }) => PostModel(
        id:            id,
        userId:        userId,
        userName:      userName,
        userUsername:  userUsername,
        userPicture:   userPicture,
        mediaUrl:      mediaUrl,
        thumbnailUrl:  thumbnailUrl,
        publicId:      publicId,
        mediaType:     mediaType,
        caption:       caption,
        aspectRatio:   aspectRatio,
        section:       section,
        likesCount:    likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        sharesCount:   sharesCount ?? this.sharesCount,
        isLiked:       isLiked ?? this.isLiked,
        createdAt:     createdAt,
      );

  bool get isVideo => mediaType == 'video';

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
    if (diff.inHours < 24)    return '${diff.inHours}h';
    if (diff.inDays < 7)      return '${diff.inDays}d';
    if (diff.inDays < 30)     return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365)    return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  // ── Feed ──────────────────────────────────────────────────────────────────

  Future<({List<PostModel> posts, String? nextCursor})> getFeed({
    String? cursor,
    int limit = 20,
    bool refresh = false,   // bypass local cache on pull-to-refresh
  }) async {
    final path = cursor != null
        ? '/posts/?cursor=$cursor&limit=$limit'
        : '/posts/?limit=$limit';

    final data = await ApiService.get(
      path,
      requiresAuth: true,
      bypassCache: refresh || cursor != null,  // don't cache paginated pages
    );
    final rawPosts = (data['posts'] as List?) ?? [];
    final posts = rawPosts
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
    return (posts: posts, nextCursor: data['next_cursor'] as String?);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<PostModel> createPost({
    required String mediaUrl,
    String? thumbnailUrl,
    String publicId = '',
    required String mediaType,
    String caption = '',
    double aspectRatio = 1.0,
    String? section,
  }) async {
    final data = await ApiService.post(
      '/posts/',
      {
        'media_url':    mediaUrl,
        'thumbnail_url': thumbnailUrl,
        'public_id':    publicId,
        'media_type':   mediaType,
        'caption':      caption,
        'aspect_ratio': aspectRatio,
        if (section != null) 'section': section,
      },
      requiresAuth: true,
    );
    return PostModel.fromJson(data);
  }

  // ── Like / Unlike ─────────────────────────────────────────────────────────

  Future<void> likePost(String postId) async {
    await ApiService.post('/posts/$postId/like', {}, requiresAuth: true);
  }

  Future<void> unlikePost(String postId) async {
    await ApiService.delete('/posts/$postId/like', requiresAuth: true);
  }

  Future<void> deletePost(String postId) async {
    await ApiService.delete('/posts/$postId', requiresAuth: true);
  }

  // ── Shots feed (filtered by section: 'fun' | 'learn') ───────────────────

  Future<({List<PostModel> posts, String? nextCursor})> getShotsFeed({
    required String section,   // 'fun' or 'learn'
    String? cursor,
    int limit = 10,
    bool refresh = false,
  }) async {
    final query = cursor != null
        ? 'section=$section&cursor=$cursor&limit=$limit'
        : 'section=$section&limit=$limit';
    final data = await ApiService.get(
      '/posts/shots/?$query',
      requiresAuth: true,
      bypassCache: refresh || cursor != null,
    );
    final rawPosts = (data['posts'] as List?) ?? [];
    final posts = rawPosts
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
    return (posts: posts, nextCursor: data['next_cursor'] as String?);
  }

  // ── User posts ────────────────────────────────────────────────────────────

  Future<({List<PostModel> posts, String? nextCursor})> getUserPosts(
    String targetUserId, {
    String? cursor,
    int limit = 20,
  }) async {
    final path = cursor != null
        ? '/posts/user/$targetUserId?cursor=$cursor&limit=$limit'
        : '/posts/user/$targetUserId?limit=$limit';
    final data = await ApiService.get(path, requiresAuth: true);
    final rawPosts = (data['posts'] as List?) ?? [];
    final posts = rawPosts
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
    return (posts: posts, nextCursor: data['next_cursor'] as String?);
  }

  // ── Get Single Post by ID ──────────────────────────────────────────────────

  Future<PostModel?> getPostById(String postId) async {
    try {
      final data = await ApiService.get('/posts/$postId', requiresAuth: true);
      return PostModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }
}
