import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Production Railway URL — works on all platforms (web, Android, iOS)
const String _prodUrl = 'https://web-production-c105c.up.railway.app';

String get baseUrl => _prodUrl;
String get wsUrl => _prodUrl.replaceFirst('http', 'ws');

const Duration _kTimeout    = Duration(seconds: 15);
const Duration _kCacheTtl   = Duration(seconds: 90);
const int      _kCacheMaxSz = 40;   // max entries before LRU eviction

// ── In-memory GET response cache ────────────────────────────────────────────
// Prevents re-fetching identical requests within 90 s (tab switches,
// orientation changes, returning from sub-screens) without hitting the server.

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  _CacheEntry(this.data) : expiresAt = DateTime.now().add(_kCacheTtl);
  bool get valid => DateTime.now().isBefore(expiresAt);
}

final _getCache = <String, _CacheEntry>{};

void _cachePut(String key, Map<String, dynamic> data) {
  if (_getCache.length >= _kCacheMaxSz) {
    // Evict the single oldest entry to keep memory bounded
    final oldest = _getCache.entries
        .reduce((a, b) => a.value.expiresAt.isBefore(b.value.expiresAt) ? a : b)
        .key;
    _getCache.remove(oldest);
  }
  _getCache[key] = _CacheEntry(data);
}

/// Invalidate cache entries whose key contains [pathPrefix].
/// Call after write operations that change feed data.
void invalidateGetCache(String pathPrefix) {
  _getCache.removeWhere((k, _) => k.contains(pathPrefix));
}

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    // BUG FIX: jsonDecode had no try-catch.
    // Railway returns an HTML 502/503 page (not JSON) when the app is cold-
    // starting or crashing. Without this guard, jsonDecode throws a
    // FormatException that bypasses all ApiException handlers and shows the
    // user a raw Dart crash message. Now it maps to a clean error string.
    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
          'Server returned an unexpected response (HTTP ${response.statusCode}). '
          'Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    final detail =
        data is Map ? (data['detail'] ?? 'Request failed') : 'Request failed';
    throw ApiException(detail.toString());
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool requiresAuth = false,
    bool bypassCache  = false,    // pass true on pull-to-refresh
  }) async {
    // ── In-memory cache check ───────────────────────────────────────────────
    if (!bypassCache) {
      final entry = _getCache[path];
      if (entry != null && entry.valid) {
        return entry.data;
      }
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: headers,
          )
          .timeout(_kTimeout);
    } on Exception {
      // Return stale cache if network is unavailable (offline resilience)
      if (!bypassCache) {
        final stale = _getCache[path];
        if (stale != null) return stale.data;
      }
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    // BUG FIX: same as post() — guard against non-JSON responses.
    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
          'Server returned an unexpected response (HTTP ${response.statusCode}). '
          'Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = data as Map<String, dynamic>;
      _cachePut(path, result);
      return result;
    }
    final detail =
        data is Map ? (data['detail'] ?? 'Request failed') : 'Request failed';
    throw ApiException(detail.toString());
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final http.Response response;
    try {
      response = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
          'Server returned an unexpected response (HTTP ${response.statusCode}). '
          'Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    final detail =
        data is Map ? (data['detail'] ?? 'Request failed') : 'Request failed';
    throw ApiException(detail.toString());
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final http.Response response;
    try {
      response = await http
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
          'Server returned an unexpected response (HTTP ${response.statusCode}). '
          'Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    final detail =
        data is Map ? (data['detail'] ?? 'Request failed') : 'Request failed';
    throw ApiException(detail.toString());
  }

  /// GET that returns a List (for endpoints like /notifications).
  static Future<List<dynamic>> getList(
    String path, {
    bool requiresAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: headers,
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
          'Server returned an unexpected response (HTTP ${response.statusCode}). '
          'Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data is List) return data;
      return [data];
    }
    final detail =
        data is Map ? (data['detail'] ?? 'Request failed') : 'Request failed';
    throw ApiException(detail.toString());
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
