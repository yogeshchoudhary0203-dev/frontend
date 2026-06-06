import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// A creator listed in the Trandia Marketplace (someone who has applied).
class MarketplaceCreator {
  final String userId;
  final String name;
  final String username;
  final String? picture;
  final String category;
  final List<String> languages;
  final int followers;
  final String bio;
  final bool verified;

  const MarketplaceCreator({
    required this.userId,
    required this.name,
    required this.username,
    this.picture,
    required this.category,
    required this.languages,
    required this.followers,
    required this.bio,
    required this.verified,
  });

  factory MarketplaceCreator.fromJson(Map<String, dynamic> json) {
    return MarketplaceCreator(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      picture: json['picture'] as String?,
      category: json['category'] as String? ?? '',
      languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      bio: json['bio'] as String? ?? '',
      verified: json['verified'] == true,
    );
  }

  /// "Hindi · English" — joined language label for the card.
  String get languageLabel => languages.join(' · ');

  /// First letters of the name for the avatar fallback ("Aryan Sharma" → "AS").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// One row in the "Top posts" list returned by the dashboard endpoint.
class DashboardTopPost {
  final int rank;
  final String id;
  final String views;
  final String likes;
  final bool isReel;
  final String thumbnailUrl;
  const DashboardTopPost({
    required this.rank,
    required this.id,
    required this.views,
    required this.likes,
    required this.isReel,
    required this.thumbnailUrl,
  });
  factory DashboardTopPost.fromJson(Map<String, dynamic> j) => DashboardTopPost(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        id: j['id'] as String? ?? '',
        views: j['views'] as String? ?? '0',
        likes: j['likes'] as String? ?? '0',
        isReel: j['is_reel'] == true,
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
      );
}

/// Honest analytics payload returned by GET /marketplace/dashboard.
class DashboardData {
  final int window;
  final int followers;
  final int following;
  final int postCount;
  final String reach;
  final String reachDelta;
  final String engagementRate;
  final String engagementDelta;
  final String followersNet;
  final String followersDelta;
  final List<double> reachTrend;
  final List<double> weeklyBars;
  final List<String> weeklyLabels;
  final List<DashboardTopPost> topPosts;
  final String username;

  const DashboardData({
    required this.window,
    required this.followers,
    required this.following,
    required this.postCount,
    required this.reach,
    required this.reachDelta,
    required this.engagementRate,
    required this.engagementDelta,
    required this.followersNet,
    required this.followersDelta,
    required this.reachTrend,
    required this.weeklyBars,
    required this.weeklyLabels,
    required this.topPosts,
    required this.username,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    List<double> dl(dynamic v) =>
        (v as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [];
    List<String> sl(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return DashboardData(
      window: (j['window'] as num?)?.toInt() ?? 30,
      followers: (j['followers'] as num?)?.toInt() ?? 0,
      following: (j['following'] as num?)?.toInt() ?? 0,
      postCount: (j['post_count'] as num?)?.toInt() ?? 0,
      reach: j['reach'] as String? ?? '0',
      reachDelta: j['reach_delta'] as String? ?? '0',
      engagementRate: j['engagement_rate'] as String? ?? '0%',
      engagementDelta: j['engagement_delta'] as String? ?? '0',
      followersNet: j['followers_net'] as String? ?? '+0',
      followersDelta: j['followers_delta'] as String? ?? '0',
      reachTrend: dl(j['reach_trend']),
      weeklyBars: dl(j['weekly_bars']),
      weeklyLabels: sl(j['weekly_labels']),
      topPosts: (j['top_posts'] as List?)
              ?.map((e) => DashboardTopPost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      username: j['username'] as String? ?? '',
    );
  }
}

class MarketplaceService {
  // ── Apply / re-apply (idempotent upsert on backend) ────────────────────────
  static Future<bool> apply({
    required String phone,
    required String contentType,
    required int followers,
    required List<String> languages,
    required String bio,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.post(
        Uri.parse('$baseUrl/marketplace/apply'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'content_type': contentType,
          'followers': followers,
          'languages': languages,
          'bio': bio,
        }),
      ).timeout(const Duration(seconds: 15));
      developer.log('marketplace apply → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('marketplace apply error: $e');
      return false;
    }
  }

  // ── Has the current user applied? ──────────────────────────────────────────
  static Future<bool> hasApplied() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.get(
        Uri.parse('$baseUrl/marketplace/status'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return decoded['applied'] == true;
      }
      return false;
    } catch (e) {
      developer.log('marketplace status error: $e');
      return false;
    }
  }

  // ── Search / list applied creators ─────────────────────────────────────────
  static Future<List<MarketplaceCreator>> searchCreators(String query, {int limit = 20}) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final encoded = Uri.encodeComponent(query.trim());
      final uri = Uri.parse('$baseUrl/marketplace/creators?q=$encoded&limit=$limit');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      developer.log('marketplace search "$query" → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded.map((e) => MarketplaceCreator.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      developer.log('marketplace search error: $e');
      return [];
    }
  }

  // ── Collab requests ────────────────────────────────────────────────────────

  /// Sends a collab request. Returns null on failure, otherwise the new status
  /// (usually 'pending'). Idempotent: re-sending while one is pending is a no-op.
  static Future<String?> sendCollabRequest(String toUserId, {String message = ''}) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final res = await http.post(
        Uri.parse('$baseUrl/marketplace/collab/request'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'to_user_id': toUserId, 'message': message}),
      ).timeout(const Duration(seconds: 12));
      developer.log('collab request → ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return decoded['status'] as String? ?? 'pending';
      }
      return null;
    } catch (e) {
      developer.log('collab request error: $e');
      return null;
    }
  }

  /// Accept an incoming collab request. Returns the conversation_id on success.
  static Future<String?> acceptCollabRequest(String requestId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final res = await http.put(
        Uri.parse('$baseUrl/marketplace/collab/requests/$requestId/accept'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      developer.log('collab accept → ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return decoded['conversation_id'] as String?;
      }
      return null;
    } catch (e) {
      developer.log('collab accept error: $e');
      return null;
    }
  }

  /// Decline an incoming collab request.
  static Future<bool> declineCollabRequest(String requestId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.put(
        Uri.parse('$baseUrl/marketplace/collab/requests/$requestId/decline'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      developer.log('collab decline → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('collab decline error: $e');
      return false;
    }
  }

  // ── Creator dashboard analytics ────────────────────────────────────────────

  /// Fetches honest analytics for the current user. Returns null on failure.
  /// [window] is the period in days (7 / 30 / 90).
  static Future<DashboardData?> getDashboard({int window = 30}) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final res = await http.get(
        Uri.parse('$baseUrl/marketplace/dashboard?window=$window'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      developer.log('dashboard($window) → ${res.statusCode}');
      if (res.statusCode == 200) {
        return DashboardData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      developer.log('dashboard error: $e');
      return null;
    }
  }

  /// 1500 → "1.5K", 1_200_000 → "1.2M".
  static String compactCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}
