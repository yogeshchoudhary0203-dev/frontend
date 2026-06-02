// comment_service.dart
//
// Real API-backed comment service.
// All mock data, SharedPreferences, and local storage are removed.
// Every operation calls the backend; the UI layer does optimistic inserts.

import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userUsername;
  final String? userPicture;
  final String text;
  final String? parentId;   // null = top-level; non-null = reply (max 1 level)
  final int likesCount;
  bool isLiked;
  final DateTime createdAt;
  final List<Comment> replies;  // only populated on top-level comments

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userPicture,
    required this.text,
    this.parentId,
    this.likesCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> j) {
    final rawReplies = (j['replies'] as List?) ?? [];
    return Comment(
      id:           j['id'] ?? '',
      postId:       j['post_id'] ?? '',
      userId:       j['user_id'] ?? '',
      userName:     j['user_name'] ?? '',
      userUsername: j['user_username'] ?? '',
      userPicture:  j['user_picture'] as String?,
      text:         j['text'] ?? '',
      parentId:     j['parent_id'] as String?,
      likesCount:   (j['likes_count'] as num?)?.toInt() ?? 0,
      isLiked:      j['is_liked'] == true,
      createdAt:    DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      replies:      rawReplies
          .whereType<Map<String, dynamic>>()
          .map(Comment.fromJson)
          .toList(),
    );
  }

  /// Human-readable relative time (e.g. "2m ago", "3h ago").
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    if (diff.inDays < 30)     return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365)    return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Two-letter initials derived from the display name.
  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Comment copyWith({bool? isLiked, int? likesCount, List<Comment>? replies}) {
    return Comment(
      id:           id,
      postId:       postId,
      userId:       userId,
      userName:     userName,
      userUsername: userUsername,
      userPicture:  userPicture,
      text:         text,
      parentId:     parentId,
      likesCount:   likesCount ?? this.likesCount,
      isLiked:      isLiked ?? this.isLiked,
      createdAt:    createdAt,
      replies:      replies ?? this.replies,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result type for paginated fetch
// ─────────────────────────────────────────────────────────────────────────────

class CommentsResult {
  final List<Comment> comments;
  final String? nextCursor;
  const CommentsResult({required this.comments, this.nextCursor});
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class CommentService {
  CommentService._();
  static final CommentService instance = CommentService._();

  // ── Fetch ─────────────────────────────────────────────────────────────────

  /// Fetch paginated top-level comments (with replies inlined).
  /// Pass [cursor] = last seen comment id for subsequent pages.
  Future<CommentsResult> fetchComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async {
    final path = cursor != null
        ? '/posts/$postId/comments?cursor=$cursor&limit=$limit'
        : '/posts/$postId/comments?limit=$limit';

    final data = await ApiService.get(path, requiresAuth: true, bypassCache: true);
    final raw = (data['comments'] as List?) ?? [];
    final comments = raw
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();

    return CommentsResult(
      comments:   comments,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  // ── Create ────────────────────────────────────────────────────────────────

  /// Post a new comment or reply.
  /// Returns the server-confirmed [Comment] with its real MongoDB id.
  Future<Comment> postComment(
    String postId,
    String text, {
    String? parentId,
  }) async {
    final body = <String, dynamic>{
      'text': text.trim(),
      if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
    };
    final data = await ApiService.post(
      '/posts/$postId/comments',
      body,
      requiresAuth: true,
    );
    return Comment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteComment(String commentId) async {
    await ApiService.delete(
      '/posts/comments/$commentId',
      requiresAuth: true,
    );
  }

  // ── Like / Unlike ─────────────────────────────────────────────────────────

  Future<void> likeComment(String commentId) async {
    await ApiService.post(
      '/posts/comments/$commentId/like',
      {},
      requiresAuth: true,
    );
  }

  Future<void> unlikeComment(String commentId) async {
    await ApiService.delete(
      '/posts/comments/$commentId/like',
      requiresAuth: true,
    );
  }
}
