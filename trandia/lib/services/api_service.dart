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

// ── In-memory token cache ────────────────────────────────────────────────────
// Avoids hitting SharedPreferences (disk I/O) on every single API request.
// Updated on every saveToken / clearToken call so it always stays in sync.
String? _cachedToken;

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
  /// Returns the auth token — memory-first, falls back to SharedPreferences.
  /// This avoids disk I/O on every single API call.
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  static Future<void> saveToken(String token) async {
    _cachedToken = token;                          // update memory immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;                           // clear memory immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Check token validity in memory — no disk I/O, no network call.
  /// Returns the valid token string, or null if missing/expired.
  static String? _validTokenSync() {
    final t = _cachedToken;
    if (t == null) return null;
    try {
      final parts = t.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map;
      final exp = payload['exp'] as int?;
      if (exp == null) return null;
      // 30-second buffer — treat as expired slightly early to avoid edge cases
      if (DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 30) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  /// Build auth headers for a request that requires authentication.
  /// Throws [ApiException] immediately (no network round-trip) if the token
  /// is missing or already expired — prevents 401 errors at the server.
  static Future<Map<String, String>> _authHeaders() async {
    // Warm the in-memory cache if this is the first call after a cold start
    if (_cachedToken == null) await getToken();

    final token = _validTokenSync();
    if (token == null) {
      // Token is missing or expired — clear it so isLoggedIn() returns false
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    final headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
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

    final headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
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
    final headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
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
    final headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
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
    final headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
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
