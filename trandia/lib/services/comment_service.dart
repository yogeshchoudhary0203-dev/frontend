import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LocalComment {
  final String id;
  final String authorName;
  final String authorInitials;
  final String text;
  final String timeAgo;
  final bool isLiked;
  final String? parentId; // null = top-level comment, non-null = reply (max 1 level)
  final List<LocalComment> replies; // only populated for top-level comments

  LocalComment({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.text,
    required this.timeAgo,
    this.isLiked = false,
    this.parentId,
    this.replies = const [],
  });

  LocalComment copyWith({bool? isLiked, List<LocalComment>? replies}) {
    return LocalComment(
      id: id,
      authorName: authorName,
      authorInitials: authorInitials,
      text: text,
      timeAgo: timeAgo,
      isLiked: isLiked ?? this.isLiked,
      parentId: parentId,
      replies: replies ?? this.replies,
    );
  }

  factory LocalComment.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>? ?? [];
    return LocalComment(
      id: json['id'] ?? '',
      authorName: json['authorName'] ?? '',
      authorInitials: json['authorInitials'] ?? '',
      text: json['text'] ?? '',
      timeAgo: json['timeAgo'] ?? '',
      isLiked: json['isLiked'] ?? false,
      parentId: json['parentId'],
      replies: rawReplies.map((e) => LocalComment.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'authorInitials': authorInitials,
      'text': text,
      'timeAgo': timeAgo,
      'isLiked': isLiked,
      'parentId': parentId,
      'replies': replies.map((e) => e.toJson()).toList(),
    };
  }
}

class CommentService {
  static const String _keyPrefix = 'post_comments_';

  static String _getPostKey(String user, String description) {
    final cleanDesc = description.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final hash = cleanDesc.hashCode;
    return '$_keyPrefix${user.replaceAll(" ", "_")}_$hash';
  }

  // ── JWT Auth Check ──────────────────────────────────────────────────────
  /// Returns true if user has a valid (non-expired) JWT token.
  static Future<bool> isAuthenticated() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      // Decode and check expiry
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 < (exp - 30);
    } catch (_) {
      return false;
    }
  }

  /// Get mock comments tailored to the post user and context
  static List<LocalComment> _getMockComments(String user) {
    final cleanUser = user.trim().toLowerCase();
    if (cleanUser.contains('arjun')) {
      return [
        LocalComment(
          id: 'mock_arjun_1',
          authorName: 'Priya Sharma',
          authorInitials: 'PS',
          text: 'Beautiful click! Manali is absolute magic during golden hour. ❤️',
          timeAgo: '2m ago',
        ),
        LocalComment(
          id: 'mock_arjun_2',
          authorName: 'Rohan Verma',
          authorInitials: 'RV',
          text: 'Which camera/phone did you use to capture this? The colors are unreal!',
          timeAgo: '10m ago',
        ),
        LocalComment(
          id: 'mock_arjun_3',
          authorName: 'Sneha Nair',
          authorInitials: 'SN',
          text: 'Chasing mountains is the best therapy. Stunning capture Arjun!',
          timeAgo: '30m ago',
        ),
      ];
    } else if (cleanUser.contains('priya')) {
      return [
        LocalComment(
          id: 'mock_priya_1',
          authorName: 'Dev Malhotra',
          authorInitials: 'DM',
          text: 'That sunset transition was butter smooth! Please drop the BTS soon 🔥',
          timeAgo: '5m ago',
        ),
        LocalComment(
          id: 'mock_priya_2',
          authorName: 'Arjun Kapoor',
          authorInitials: 'AK',
          text: 'The grading is next level. What software did you use?',
          timeAgo: '12m ago',
        ),
        LocalComment(
          id: 'mock_priya_3',
          authorName: 'Kavya Rao',
          authorInitials: 'KR',
          text: 'Wow, watched this on loop. Absolute masterpiece Priya! 🙌',
          timeAgo: '25m ago',
        ),
      ];
    } else if (cleanUser.contains('rohan')) {
      return [
        LocalComment(
          id: 'mock_rohan_1',
          authorName: 'Sneha Nair',
          authorInitials: 'SN',
          text: 'Chandni Chowk aloo chaat is legendary! Now I\'m hungry at midnight 😂',
          timeAgo: '15m ago',
        ),
        LocalComment(
          id: 'mock_rohan_2',
          authorName: 'Nikhil Kumar',
          authorInitials: 'NK',
          text: 'Next time check out Natraj Dahi Bhalla near there, it\'s also incredible!',
          timeAgo: '20m ago',
        ),
        LocalComment(
          id: 'mock_rohan_3',
          authorName: 'Arjun Kapoor',
          authorInitials: 'AK',
          text: 'Spicy and perfect. Great recommendation Rohan!',
          timeAgo: '45m ago',
        ),
      ];
    } else if (cleanUser.contains('sneha')) {
      return [
        LocalComment(
          id: 'mock_sneha_1',
          authorName: 'Nikhil Kumar',
          authorInitials: 'NK',
          text: 'Night owl coder club! Good luck with the build. Let\'s connect! 💻',
          timeAgo: '1h ago',
        ),
        LocalComment(
          id: 'mock_sneha_2',
          authorName: 'Dev Malhotra',
          authorInitials: 'DM',
          text: 'Flutter is love. Clean code is life. Looking forward to seeing what you are making.',
          timeAgo: '1h ago',
        ),
        LocalComment(
          id: 'mock_sneha_3',
          authorName: 'Priya Sharma',
          authorInitials: 'PS',
          text: 'Lo-fi + late night is the ultimate developer cheat code.',
          timeAgo: '2h ago',
        ),
      ];
    } else if (cleanUser.contains('dev')) {
      return [
        LocalComment(
          id: 'mock_dev_1',
          authorName: 'Arjun Kapoor',
          authorInitials: 'AK',
          text: 'Sunrise from Triund is an unforgettable feeling! Hard work pays off.',
          timeAgo: '1h ago',
        ),
        LocalComment(
          id: 'mock_dev_2',
          authorName: 'Rohan Verma',
          authorInitials: 'RV',
          text: 'Did you get cold chai at the top? That guy is a lifesaver 😂',
          timeAgo: '2h ago',
        ),
        LocalComment(
          id: 'mock_dev_3',
          authorName: 'Kavya Rao',
          authorInitials: 'KR',
          text: 'Spectacular view Dev! Adding this to my trekking list.',
          timeAgo: '3h ago',
        ),
      ];
    }
    return [
      LocalComment(
        id: 'mock_generic_1',
        authorName: 'Trandia Fan',
        authorInitials: 'TF',
        text: 'This post is amazing! Keep sharing such amazing content.',
        timeAgo: '1h ago',
      ),
    ];
  }

  /// Get comments (mocks + custom user saved comments) with replies nested
  static Future<List<LocalComment>> getComments(String user, String description) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPostKey(user, description);
    final String? localCommentsJson = prefs.getString(key);

    final mockList = _getMockComments(user);

    List<LocalComment> savedList = [];
    if (localCommentsJson != null) {
      try {
        final List decoded = jsonDecode(localCommentsJson) as List;
        savedList = decoded.map((e) => LocalComment.fromJson(e)).toList();
      } catch (_) {}
    }

    // Merge: flat list of all comments
    final allFlat = <LocalComment>[...mockList, ...savedList];

    // Build parent-child map. Replies are ONLY 1 level deep.
    final Map<String, List<LocalComment>> repliesMap = {};
    final List<LocalComment> topLevel = [];

    for (final c in allFlat) {
      if (c.parentId != null && c.parentId!.isNotEmpty) {
        // This is a reply — but enforce 1-level limit:
        // If the parent itself has a parentId, attach to the root parent instead.
        final effectiveParentId = _resolveRootParent(c.parentId!, allFlat);
        repliesMap.putIfAbsent(effectiveParentId, () => []);
        repliesMap[effectiveParentId]!.add(c);
      } else {
        topLevel.add(c);
      }
    }

    // Attach replies to their parent comments
    final result = topLevel.map((parent) {
      final childReplies = repliesMap[parent.id] ?? [];
      return parent.copyWith(replies: childReplies);
    }).toList();

    return result;
  }

  /// Resolve to root parent (prevents infinite nesting — max 1 level)
  static String _resolveRootParent(String parentId, List<LocalComment> allComments) {
    final parent = allComments.where((c) => c.id == parentId).firstOrNull;
    if (parent != null && parent.parentId != null && parent.parentId!.isNotEmpty) {
      // The parent is itself a reply — use its parent (the root) instead
      return parent.parentId!;
    }
    return parentId;
  }

  /// Save new top-level comment (JWT validated)
  static Future<void> saveComment(
    String user,
    String description,
    String commentText,
    String myUserName,
    String myUserInitials,
  ) async {
    // JWT auth check
    final authenticated = await isAuthenticated();
    if (!authenticated) {
      throw const ApiException('Please sign in to post a comment.');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _getPostKey(user, description);

    // Get current saved comments (just custom ones)
    final String? localCommentsJson = prefs.getString(key);
    List<LocalComment> savedList = [];
    if (localCommentsJson != null) {
      try {
        final List decoded = jsonDecode(localCommentsJson) as List;
        savedList = decoded.map((e) => LocalComment.fromJson(e)).toList();
      } catch (_) {}
    }

    // Append new comment
    final newComment = LocalComment(
      id: 'user_comment_${DateTime.now().millisecondsSinceEpoch}',
      authorName: myUserName,
      authorInitials: myUserInitials,
      text: commentText,
      timeAgo: 'just now',
    );
    savedList.add(newComment);

    await prefs.setString(key, jsonEncode(savedList.map((e) => e.toJson()).toList()));
  }

  /// Save a reply to a comment (JWT validated, max 1-level enforced)
  static Future<LocalComment> saveReply(
    String user,
    String description,
    String parentCommentId,
    String replyText,
    String myUserName,
    String myUserInitials,
  ) async {
    // JWT auth check
    final authenticated = await isAuthenticated();
    if (!authenticated) {
      throw const ApiException('Please sign in to reply.');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _getPostKey(user, description);

    // Get all saved comments to resolve parent chain
    final String? localCommentsJson = prefs.getString(key);
    List<LocalComment> savedList = [];
    if (localCommentsJson != null) {
      try {
        final List decoded = jsonDecode(localCommentsJson) as List;
        savedList = decoded.map((e) => LocalComment.fromJson(e)).toList();
      } catch (_) {}
    }

    // Also load mocks to resolve parent chain
    final mockList = _getMockComments(user);
    final allComments = [...mockList, ...savedList];

    // Enforce 1-level max: if parent is already a reply, attach to its root parent
    final effectiveParentId = _resolveRootParent(parentCommentId, allComments);

    final reply = LocalComment(
      id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
      authorName: myUserName,
      authorInitials: myUserInitials,
      text: replyText,
      timeAgo: 'just now',
      parentId: effectiveParentId,
    );

    savedList.add(reply);
    await prefs.setString(key, jsonEncode(savedList.map((e) => e.toJson()).toList()));

    return reply;
  }

  /// Get only the user-made comments count
  static Future<int> getCommentsCount(String user, String description) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPostKey(user, description);
    final String? localCommentsJson = prefs.getString(key);
    if (localCommentsJson == null) return 0;
    try {
      final List decoded = jsonDecode(localCommentsJson) as List;
      return decoded.length;
    } catch (_) {
      return 0;
    }
  }

  /// Toggle like on a comment (works for both mocks and user comments)
  static Future<List<LocalComment>> toggleCommentLike(
      String user, String description, String commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPostKey(user, description);
    final String? localCommentsJson = prefs.getString(key);

    // Get custom list
    List<LocalComment> savedList = [];
    if (localCommentsJson != null) {
      try {
        final List decoded = jsonDecode(localCommentsJson) as List;
        savedList = decoded.map((e) => LocalComment.fromJson(e)).toList();
      } catch (_) {}
    }

    final mockList = _getMockComments(user);
    final allComments = [...mockList, ...savedList];

    // Find the comment and update it
    final index = allComments.indexWhere((c) => c.id == commentId);
    if (index != -1) {
      final currentComment = allComments[index];
      final updatedComment = currentComment.copyWith(isLiked: !currentComment.isLiked);

      // Check if it was in saved custom comments
      final savedIndex = savedList.indexWhere((c) => c.id == commentId);
      if (savedIndex != -1) {
        savedList[savedIndex] = updatedComment;
      } else {
        // It was a mock comment. To toggle its like state dynamically, we will
        // save the toggle preference. But wait, since it's a mock, we can either
        // save a list of liked mock IDs, or just add the modified mock to savedList,
        // or a simple shared pref bool 'liked_comment_<id>'.
        // Let's store the liked status of mocks in SharedPreferences under a custom key.
        final mockLikedKey = 'mock_comment_liked_$commentId';
        final isCurrentlyLiked = prefs.getBool(mockLikedKey) ?? false;
        await prefs.setBool(mockLikedKey, !isCurrentlyLiked);
      }
    }

    // Save custom list
    if (savedList.isNotEmpty) {
      await prefs.setString(key, jsonEncode(savedList.map((e) => e.toJson()).toList()));
    }

    return getComments(user, description);
  }

  /// Check if a mock comment is liked
  static Future<bool> isMockCommentLiked(String commentId) async {
    if (!commentId.startsWith('mock_')) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('mock_comment_liked_$commentId') ?? false;
  }
}
