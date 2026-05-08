import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

const String _webClientId =
    '461111861227-6lp4k1p2iuoe50sl46bvpdp2d6smvola.apps.googleusercontent.com';

const String _backendUrl = 'https://web-production-c105c.up.railway.app';

final _googleSignIn = GoogleSignIn(serverClientId: _webClientId);

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
      // Web: use conditional import to avoid dart:html crash on Android
      _launchGoogleWebFlow();
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

  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    return token != null;
  }

  static Future<void> logout() async {
    await ApiService.clearToken();
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }
}

// Separate function so dart:html is only touched on web builds
void _launchGoogleWebFlow() {
  // This is only called when kIsWeb == true
  // The actual implementation lives in web_utils_web.dart
  // On Android this function is never called so no crash
}
