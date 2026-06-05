import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Production Railway URL — works on all platforms (web, Android, iOS)
const String _prodUrl = 'https://web-production-eae2.up.railway.app';

String get baseUrl => _prodUrl;
String get wsUrl => _prodUrl.replaceFirst('http', 'ws');

const Duration _kTimeout    = Duration(seconds: 15);
const Duration _kCacheTtl   = Duration(seconds: 90);
const int      _kCacheMaxSz = 40;   // max entries before LRU eviction

// ── In-memory token caches ───────────────────────────────────────────────────
String? _cachedToken;
String? _cachedRefreshToken;

// ── In-memory GET response cache ────────────────────────────────────────────
class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  _CacheEntry(this.data) : expiresAt = DateTime.now().add(_kCacheTtl);
  bool get valid => DateTime.now().isBefore(expiresAt);
}

final _getCache = <String, _CacheEntry>{};

void _cachePut(String key, Map<String, dynamic> data) {
  if (_getCache.length >= _kCacheMaxSz) {
    final oldest = _getCache.entries
        .reduce((a, b) => a.value.expiresAt.isBefore(b.value.expiresAt) ? a : b)
        .key;
    _getCache.remove(oldest);
  }
  _getCache[key] = _CacheEntry(data);
}

/// Invalidate cache entries whose key contains [pathPrefix].
void invalidateGetCache(String pathPrefix) {
  _getCache.removeWhere((k, _) => k.contains(pathPrefix));
}

// ── Refresh lock ─────────────────────────────────────────────────────────────
// Ensures only ONE /auth/refresh call fires at a time.
// All concurrent callers wait on the same Completer and get the same result.
bool _isRefreshing = false;
Completer<String?>? _refreshCompleter;

class ApiService {
  // ── Access token ─────────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ── Refresh token ─────────────────────────────────────────────────────────
  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedRefreshToken = prefs.getString('refresh_token');
    return _cachedRefreshToken;
  }

  static Future<void> saveRefreshToken(String token) async {
    _cachedRefreshToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', token);
  }

  static Future<void> clearRefreshToken() async {
    _cachedRefreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('refresh_token');
  }

  /// Clear ALL auth state (access + refresh tokens).
  static Future<void> clearAllTokens() async {
    await clearToken();
    await clearRefreshToken();
  }

  // ── Token validation (sync — no I/O) ─────────────────────────────────────

  /// Returns the cached access token if it is still valid (> 30s remaining).
  /// Returns null if missing, malformed, or near/past expiry.
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
      // 30-second buffer before actual expiry
      if (DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 30) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  // ── Silent token refresh ──────────────────────────────────────────────────

  /// Silently exchange the stored refresh token for a new access + refresh pair.
  ///
  /// Thread-safe: if multiple callers trigger a refresh simultaneously, only
  /// ONE network request fires.  All other callers await the same Completer.
  ///
  /// Returns the new access token on success, or null if the refresh token is
  /// invalid/expired (caller must log the user out).
  static Future<String?> silentRefresh() async {
    // ── Queue: wait for in-progress refresh ──────────────────────────────
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    String? result;
    try {
      // Warm the refresh token cache
      if (_cachedRefreshToken == null) await getRefreshToken();
      final refreshToken = _cachedRefreshToken;

      if (refreshToken == null || refreshToken.isEmpty) {
        result = null;
      } else {
        // Call /auth/refresh directly via http (NOT through ApiService.post to
        // avoid infinite recursion — this endpoint needs no auth header).
        final response = await http
            .post(
              Uri.parse('$baseUrl/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final newAccess  = data['access_token']  as String?;
          final newRefresh = data['refresh_token'] as String?;
          if (newAccess != null && newAccess.isNotEmpty) {
            await saveToken(newAccess);
            if (newRefresh != null && newRefresh.isNotEmpty) {
              await saveRefreshToken(newRefresh);
            }
            result = newAccess;
          }
        }
        // 401 from /auth/refresh → refresh token expired/revoked → result stays null
      }
    } catch (_) {
      result = null; // network error — result stays null
    } finally {
      _isRefreshing = false;
      _refreshCompleter!.complete(result);
      _refreshCompleter = null;
    }
    return result;
  }

  // ── Auth headers (with pre-emptive refresh) ───────────────────────────────

  /// Build Authorization headers.
  ///
  /// Flow:
  ///   1. If access token is valid → use it directly (fast path, no network).
  ///   2. If access token expired → try silentRefresh().
  ///   3. If refresh succeeds  → use the new access token.
  ///   4. If refresh fails     → clear ALL tokens + throw ApiException so the
  ///      app can route the user to the login screen.
  static Future<Map<String, String>> _authHeaders() async {
    // Warm in-memory cache on first call after cold start
    if (_cachedToken == null) await getToken();

    final token = _validTokenSync();
    if (token != null) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    }

    // Access token expired — attempt silent refresh
    final newToken = await silentRefresh();
    if (newToken != null) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      };
    }

    // Refresh failed → full logout
    await clearAllTokens();
    throw const ApiException('Session expired. Please sign in again.');
  }

  /// Handle a 401 response from any endpoint.
  ///
  /// Tries silentRefresh once.  Returns the new token string on success, or
  /// throws ApiException (which clears tokens) on failure.
  static Future<String> _handleUnauthorized() async {
    final newToken = await silentRefresh();
    if (newToken != null) return newToken;
    await clearAllTokens();
    throw const ApiException('Session expired. Please sign in again.');
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    var headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
    http.Response response;
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

    // 401 → try silent refresh once, then retry
    if (response.statusCode == 401 && requiresAuth) {
      final newToken = await _handleUnauthorized(); // throws if refresh fails
      headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      };
      try {
        response = await http
            .post(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body))
            .timeout(_kTimeout);
      } on Exception {
        throw const ApiException('Could not connect to server. Check your network.');
      }
      if (response.statusCode == 401) {
        await clearAllTokens();
        throw const ApiException('Session expired. Please sign in again.');
      }
    } else if (response.statusCode == 401) {
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

  static Future<Map<String, dynamic>> get(
    String path, {
    bool requiresAuth = false,
    bool bypassCache  = false,
  }) async {
    // ── In-memory cache check ────────────────────────────────────────────────
    if (!bypassCache) {
      final entry = _getCache[path];
      if (entry != null && entry.valid) return entry.data;
    }

    var headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
    http.Response response;
    try {
      response = await http
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(_kTimeout);
    } on Exception {
      if (!bypassCache) {
        final stale = _getCache[path];
        if (stale != null) return stale.data;
      }
      throw const ApiException('Could not connect to server. Check your network.');
    }

    // 401 → try silent refresh once, then retry
    if (response.statusCode == 401 && requiresAuth) {
      final newToken = await _handleUnauthorized();
      headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      };
      try {
        response = await http
            .get(Uri.parse('$baseUrl$path'), headers: headers)
            .timeout(_kTimeout);
      } on Exception {
        throw const ApiException('Could not connect to server. Check your network.');
      }
      if (response.statusCode == 401) {
        await clearAllTokens();
        throw const ApiException('Session expired. Please sign in again.');
      }
    } else if (response.statusCode == 401) {
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
    var headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
    http.Response response;
    try {
      response = await http
          .put(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body))
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException('Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401 && requiresAuth) {
      final newToken = await _handleUnauthorized();
      headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      };
      try {
        response = await http
            .put(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body))
            .timeout(_kTimeout);
      } on Exception {
        throw const ApiException('Could not connect to server. Check your network.');
      }
      if (response.statusCode == 401) {
        await clearAllTokens();
        throw const ApiException('Session expired. Please sign in again.');
      }
    } else if (response.statusCode == 401) {
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
    var headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
    http.Response response;
    try {
      response = await http
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException('Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401 && requiresAuth) {
      final newToken = await _handleUnauthorized();
      headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      };
      try {
        response = await http
            .delete(
              Uri.parse('$baseUrl$path'),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_kTimeout);
      } on Exception {
        throw const ApiException('Could not connect to server. Check your network.');
      }
      if (response.statusCode == 401) {
        await clearAllTokens();
        throw const ApiException('Session expired. Please sign in again.');
      }
    } else if (response.statusCode == 401) {
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
    var headers = requiresAuth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};
    http.Response response;
    try {
      response = await http
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException('Could not connect to server. Check your network.');
    }

    if (response.statusCode == 401 && requiresAuth) {
      final newToken = await _handleUnauthorized();
      headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      };
      try {
        response = await http
            .get(Uri.parse('$baseUrl$path'), headers: headers)
            .timeout(_kTimeout);
      } on Exception {
        throw const ApiException('Could not connect to server. Check your network.');
      }
      if (response.statusCode == 401) {
        await clearAllTokens();
        throw const ApiException('Session expired. Please sign in again.');
      }
    } else if (response.statusCode == 401) {
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
