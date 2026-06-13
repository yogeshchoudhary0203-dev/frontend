import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import '../models/archived_media_model.dart';
import 'api_service.dart';
import 'follow_state.dart';


class UserService {
  // ── Follow / Unfollow / Status ───────────────────────────────────────────

  static Future<bool> followUser(String targetId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.post(
        Uri.parse('$baseUrl/users/$targetId/follow'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      developer.log('followUser $targetId → ${res.statusCode}');
      final ok = res.statusCode == 200;
      if (ok) {
        FollowState.set(targetId, true);
        // My following_count just changed → drop the cached profile so the next
        // profile open shows the fresh, accurate count instead of a stale one.
        invalidateProfileCache();
      }
      return ok;
    } catch (e) {
      developer.log('followUser error: $e');
      return false;
    }
  }

  static Future<bool> unfollowUser(String targetId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.delete(
        Uri.parse('$baseUrl/users/$targetId/follow'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      developer.log('unfollowUser $targetId → ${res.statusCode}');
      final ok = res.statusCode == 200;
      if (ok) {
        FollowState.set(targetId, false);
        // My following_count just changed → drop the cached profile so the next
        // profile open shows the fresh, accurate count instead of a stale one.
        invalidateProfileCache();
      }
      return ok;
    } catch (e) {
      developer.log('unfollowUser error: $e');
      return false;
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────

  static Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final token = await ApiService.getToken();
      developer.log('UserService.searchUsers: query="$query", token=${token != null ? "present" : "NULL"}');

      if (token == null) {
        developer.log('UserService.searchUsers: No auth token — returning empty list');
        return [];
      }

      // URL-encode the query so special chars don't break the request
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse('$baseUrl/users/search?q=$encodedQuery');
      developer.log('UserService.searchUsers: GET $uri');

      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      developer.log('UserService.searchUsers: status=${res.statusCode}, body=${res.body}');

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        final List data = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['results'] is List)
                ? decoded['results'] as List
                : [];
        developer.log('UserService.searchUsers: found ${data.length} users');
        return data.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      } else if (res.statusCode == 401) {
        developer.log('UserService.searchUsers: 401 Unauthorized');
        throw const ApiException('Session expired. Please sign in again.');
      } else {
        developer.log('UserService.searchUsers: error ${res.statusCode}: ${res.body}');
        throw ApiException('Search failed (${res.statusCode})');
      }
    } catch (e) {
      developer.log('UserService.searchUsers ERROR: $e');
      rethrow;
    }
  }

  // ── Account type ───────────────────────────────────────────────────────────

  /// Persist the user's account type on the backend so it survives reinstalls
  /// and syncs across devices. [accountType] may be any case (e.g. 'Creator');
  /// it is lowercased before sending to match the server's stored format.
  static Future<bool> updateAccountType(String accountType) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.put(
        Uri.parse('$baseUrl/users/me/account-type'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'account_type': accountType.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 10));
      developer.log('updateAccountType "$accountType" → ${res.statusCode}');
      if (res.statusCode == 200) {
        invalidateProfileCache();
        return true;
      }
      return false;
    } catch (e) {
      developer.log('updateAccountType error: $e');
      return false;
    }
  }

  // ── Collaborator discovery (Find & Collaborate) ────────────────────────────

  /// Searches eligible collaborators (creator / business / professional accounts
  /// only — personal & private are never returned). Empty [query] returns a
  /// default eligible list.
  static Future<List<UserProfile>> searchCollaborators(String query) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final encoded = Uri.encodeComponent(query.trim());
      final uri = Uri.parse('$baseUrl/users/collaborators?q=$encoded');
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      developer.log('searchCollaborators "$query" → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded
            .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      developer.log('searchCollaborators error: $e');
      return [];
    }
  }

  // ── In-memory profile cache ──────────────────────────────────────────────
  // Avoids a fresh Railway round-trip on every profile screen open.
  // TTL: 90 seconds — same as ApiService GET cache.
  static UserProfile? _cachedProfile;
  static DateTime? _profileCachedAt;
  static const _kProfileCacheTtl = Duration(seconds: 90);

  /// The last successfully fetched profile (may be stale).
  /// Use this for instant render before the background refresh completes.
  static UserProfile? get cachedProfile => _cachedProfile;

  /// Invalidate the profile cache — call after edit-profile or logout.
  static void invalidateProfileCache() {
    _cachedProfile = null;
    _profileCachedAt = null;
  }

  // ── Profile and Follower Lists ──────────────────────────────────────────

  /// Fetches own profile.
  /// • [forceRefresh] = false → returns cached data if < 90 s old (no network).
  /// • [forceRefresh] = true  → always hits the server (pull-to-refresh).
  /// On network error, returns stale cache instead of null so the UI never
  /// goes blank.
  static Future<UserProfile?> getMyProfile({bool forceRefresh = false}) async {
    // ── Serve from cache if still fresh ─────────────────────────────────
    if (!forceRefresh &&
        _cachedProfile != null &&
        _profileCachedAt != null &&
        DateTime.now().difference(_profileCachedAt!) < _kProfileCacheTtl) {
      developer.log('getMyProfile → cache hit');
      return _cachedProfile;
    }

    // ── Fetch from network ───────────────────────────────────────────────
    try {
      final token = await ApiService.getToken();
      if (token == null) return _cachedProfile; // return stale if no token
      final res = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getMyProfile → ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(decoded);
        _cachedProfile = profile;
        _profileCachedAt = DateTime.now();
        return profile;
      }
      return _cachedProfile; // return stale on non-200
    } catch (e) {
      developer.log('getMyProfile error: $e');
      return _cachedProfile; // return stale on network error
    }
  }

  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getUserProfile $userId → ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return UserProfile.fromJson(decoded);
      }
      return null;
    } catch (e) {
      developer.log('getUserProfile error: $e');
      return null;
    }
  }

  static Future<List<UserProfile>> getFollowers(
    String userId, {
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId/followers?skip=$skip&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getFollowers → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      developer.log('getFollowers error: $e');
      return [];
    }
  }

  static Future<List<UserProfile>> getPostLikers(
    String postId, {
    int skip = 0,
    int limit = 30,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/posts/$postId/likers?skip=$skip&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getPostLikers $postId → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      developer.log('getPostLikers error: $e');
      return [];
    }
  }

  static Future<List<UserProfile>> getSuggestedUsers({int limit = 10}) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/users/suggested?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getSuggestedUsers → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      developer.log('getSuggestedUsers error: $e');
      return [];
    }
  }

  // ── Location ─────────────────────────────────────────────────────────────

  static Future<bool> updateLocation(double lat, double lng, String city) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.put(
        Uri.parse('$baseUrl/users/me/location'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'latitude': lat, 'longitude': lng, 'city': city}),
      ).timeout(const Duration(seconds: 10));
      developer.log('updateLocation → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('updateLocation error: $e');
      return false;
    }
  }

  static Future<bool> updateLocationPrivacy(bool isPublic) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.put(
        Uri.parse('$baseUrl/users/me/location-privacy'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'is_public': isPublic}),
      ).timeout(const Duration(seconds: 10));
      developer.log('updateLocationPrivacy → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('updateLocationPrivacy error: $e');
      return false;
    }
  }

  static Future<bool> updateChatColors(String? senderColor, String? receiverColor) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.put(
        Uri.parse('$baseUrl/users/me/chat-colors'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_bubble_color': senderColor,
          'receiver_bubble_color': receiverColor,
        }),
      ).timeout(const Duration(seconds: 10));
      developer.log('updateChatColors → ${res.statusCode}');
      if (res.statusCode == 200) {
        invalidateProfileCache();
        return true;
      }
      return false;
    } catch (e) {
      developer.log('updateChatColors error: $e');
      return false;
    }
  }


  static Future<bool> removeLocation() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.delete(
        Uri.parse('$baseUrl/users/me/location'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      developer.log('removeLocation → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('removeLocation error: $e');
      return false;
    }
  }

  static Future<List<UserProfile>> getFollowing(
    String userId, {
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId/following?skip=$skip&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getFollowing → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      developer.log('getFollowing error: $e');
      return [];
    }
  }

  // ── Media Archiving ──────────────────────────────────────────────────────────

  static Future<bool> archiveMedia(String messageId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.post(
        Uri.parse('$baseUrl/users/me/archive'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message_id': messageId}),
      ).timeout(const Duration(seconds: 10));
      developer.log('archiveMedia $messageId → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('archiveMedia error: $e');
      return false;
    }
  }

  static Future<List<ArchivedMedia>> getArchivedMedia() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/users/me/archive'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('getArchivedMedia → ${res.statusCode}');
      if (res.statusCode == 200) {
        final List decoded = jsonDecode(res.body) as List;
        return decoded.map((e) => ArchivedMedia.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      developer.log('getArchivedMedia error: $e');
      return [];
    }
  }

  static Future<bool> deleteArchivedMedia(String archiveId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final res = await http.delete(
        Uri.parse('$baseUrl/users/me/archive/$archiveId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      developer.log('deleteArchivedMedia $archiveId → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      developer.log('deleteArchivedMedia error: $e');
      return false;
    }
  }
}

