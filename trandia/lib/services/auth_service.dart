import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import '../utils/web_utils.dart';

const String _webClientId =
    '461111861227-6lp4k1p2iuoe50sl46bvpdp2d6smvola.apps.googleusercontent.com';

const String _backendUrl = 'https://web-production-c105c.up.railway.app';

// Lazy init — not created at startup, only when Google Sign-In is triggered
GoogleSignIn? _googleSignInInstance;
GoogleSignIn get _googleSignIn {
  _googleSignInInstance ??= GoogleSignIn(serverClientId: _webClientId);
  return _googleSignInInstance!;
}

class AuthService {
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final data = await ApiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
    await ApiService.saveToken(data['access_token'] as String);
    return data;
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await ApiService.post('/auth/signup', {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
    });
    await ApiService.saveToken(data['access_token'] as String);
    return data;
  }

  static Future<Map<String, dynamic>?> loginWithGoogle() async {
    if (kIsWeb) {
      // BUG FIX: Was throwing an ApiException on web, so Google Sign-In
      // was completely broken for web users. Now we correctly redirect the
      // browser to the backend OAuth flow, passing the current origin so
      // the callback knows where to send the token after auth.
      final origin = getWindowOrigin();
      final redirectUrl =
          '$_backendUrl/auth/google/web?app_origin=${Uri.encodeComponent(origin)}';
      launchWebUrl(redirectUrl);
      // Return null — the browser is navigating away. The token will be picked
      // up from the URL query params when the app reloads after the redirect.
      return null;
    }

    // Mobile: native Google Sign-In
    final account = await _googleSignIn.signIn();
    if (account == null) throw const ApiException('Google sign-in cancelled');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const ApiException('Could not get Google ID token from device.');
    }

    final data = await ApiService.post('/auth/google/verify', {
      'id_token': idToken,
    });
    await ApiService.saveToken(data['access_token'] as String);
    return data;
  }

  // BUG FIX: Was only checking if a token exists in SharedPreferences.
  // An expired token would pass this check and the user would be routed to
  // HomeScreen — then every API call would fail with 401 until they manually
  // logged out. Now we decode the JWT expiry locally (no network needed) and
  // clear the token if it has expired.
  static Future<bool> isLoggedIn() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      if (_isTokenExpired(token)) {
        await ApiService.clearToken();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Decode the JWT payload and check the `exp` claim without any library.
  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      // Base64url padding
      final normalized = base64Url.normalize(parts[1]);
      final payloadMap =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payloadMap['exp'] as int?;
      if (exp == null) return true;
      // Add a 30-second buffer so we never use a token that's about to expire
      final nowSecs =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSecs >= (exp - 30);
    } catch (_) {
      return true; // If we can't decode, treat as expired
    }
  }

  static Future<void> logout() async {
    try {
      await ApiService.clearToken();
    } catch (_) {}
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }
}
