import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Production Railway URL — works on all platforms (web, Android, iOS)
const String _prodUrl = 'https://web-production-c105c.up.railway.app';

String get _baseUrl => _prodUrl;

// BUG FIX: Added a global request timeout.
// Without this, if Railway is sleeping or Google/FCM is slow, every HTTP
// call hangs indefinitely, making the app appear completely frozen.
const Duration _kTimeout = Duration(seconds: 15);

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
            Uri.parse('$_baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    // BUG FIX: Handle 401 explicitly.
    // Previously a 401 response was treated as a generic ApiException.
    // Now we clear the stored token so the user is effectively logged out
    // and can re-authenticate instead of being stuck in a broken state.
    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    final data = jsonDecode(response.body);
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
            Uri.parse('$_baseUrl$path'),
            headers: headers,
          )
          .timeout(_kTimeout);
    } on Exception {
      throw const ApiException(
          'Could not connect to server. Check your network.');
    }

    // BUG FIX: Same 401 handling as post() above.
    if (response.statusCode == 401) {
      await clearToken();
      throw const ApiException('Session expired. Please sign in again.');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data as Map<String, dynamic>;
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
