import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import 'api_service.dart';

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
      return res.statusCode == 200;
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
      return res.statusCode == 200;
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

  // ── Profile and Follower Lists ──────────────────────────────────────────

  static Future<UserProfile?> getMyProfile() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
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
        return UserProfile.fromJson(decoded);
      }
      return null;
    } catch (e) {
      developer.log('getMyProfile error: $e');
      return null;
    }
  }

  static Future<List<UserProfile>> getFollowers(String userId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId/followers'),
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

  static Future<List<UserProfile>> getFollowing(String userId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId/following'),
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
}
