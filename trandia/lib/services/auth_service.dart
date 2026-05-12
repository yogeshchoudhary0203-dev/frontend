import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import 'fcm_service.dart';
import '../utils/web_utils.dart';

const String _webClientId =
    '461111861227-6lp4k1p2iuoe50sl46bvpdp2d6smvola.apps.googleusercontent.com';
const String _backendUrl = 'https://web-production-c105c.up.railway.app';

GoogleSignIn? _googleSignInInstance;
GoogleSignIn get _googleSignIn {
  _googleSignInInstance ??= GoogleSignIn(serverClientId: _webClientId);
  return _googleSignInInstance!;
}

class AuthService {

  // ── Firebase Email Verification Signup ─────────────────────────────────────

  /// Step 1: Create Firebase user + send verification email
  static Future<String> initiateFirebaseSignup({
    required String email,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    await credential.user!.sendEmailVerification();
    return email;
  }

  /// Step 2: Check if email is verified (no force refresh to avoid errors)
  static Future<bool> checkEmailVerified() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      await user.reload(); // refresh from Firebase server
      return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Step 3: Complete signup — get Firebase ID token (email_verified=true) and send to backend
  static Future<Map<String, dynamic>> completeSignup({
    required String email,
    required String name,
    required String username,
    required String password,
  }) async {
    // Get the current Firebase user (whose email is now verified)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw const ApiException('Session expired. Please sign up again.');
    }

    // Reload to ensure email_verified is true in the token
    await firebaseUser.reload();
    final freshUser = FirebaseAuth.instance.currentUser;
    if (freshUser == null || !freshUser.emailVerified) {
      throw const ApiException('Email not verified. Please click the link in your inbox.');
    }

    // Get fresh ID token — this will have email_verified = true
    final idToken = await freshUser.getIdToken(true); // forceRefresh=true
    if (idToken == null) {
      throw const ApiException('Could not get verification token. Please try again.');
    }

    final fcmToken = await FcmService.getCachedToken();

    final body = <String, dynamic>{
      'firebase_id_token': idToken,
      'name': name,
      'username': username,
      'password': password,
    };
    if (fcmToken != null) body['fcm_token'] = fcmToken;

    final data = await ApiService.post('/auth/signup', body);
    await ApiService.saveToken(data['access_token'] as String);

    // Clean up Firebase user (no longer needed after backend account creation)
    try { await FirebaseAuth.instance.currentUser?.delete(); } catch (_) {}
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}

    final firstName = name.split(' ').first;
    FcmService.queueWelcome(
      title: 'Welcome to Trandia ✦',
      body: 'Hi $firstName, you\'re all set. Explore and connect with people.',
    );

    return data;
  }

  static Future<void> resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const ApiException('Session expired. Please signup again.');
    await user.sendEmailVerification();
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final fcmToken = await FcmService.getCachedToken();
    final body = <String, dynamic>{'email': email, 'password': password};
    if (fcmToken != null) body['fcm_token'] = fcmToken;

    final data = await ApiService.post('/auth/login', body);
    await ApiService.saveToken(data['access_token'] as String);

    final user = data['user'] as Map<String, dynamic>?;
    final firstName = user?['name']?.toString().split(' ').first ?? 'there';
    FcmService.queueWelcome(
      title: 'Welcome back, $firstName ✦',
      body: 'Great to have you back. Your feed is right where you left it.',
    );
    return data;
  }

  // ── Google Auth ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> loginWithGoogle() async {
    if (kIsWeb) {
      final origin = getWindowOrigin();
      final redirectUrl =
          '$_backendUrl/auth/google/web?app_origin=${Uri.encodeComponent(origin)}';
      launchWebUrl(redirectUrl);
      return null;
    }

    final account = await _googleSignIn.signIn();
    if (account == null) throw const ApiException('Google sign-in cancelled');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw const ApiException('Could not get Google ID token.');

    final fcmToken = await FcmService.getCachedToken();
    final body = <String, dynamic>{'id_token': idToken};
    if (fcmToken != null) body['fcm_token'] = fcmToken;

    final data = await ApiService.post('/auth/google/verify', body);
    await ApiService.saveToken(data['access_token'] as String);

    final user = data['user'] as Map<String, dynamic>?;
    final firstName = user?['name']?.toString().split(' ').first ?? 'there';
    FcmService.queueWelcome(
      title: 'Welcome to Trandia ✦',
      body: 'Hi $firstName, you\'re all set. Explore and connect with people.',
    );
    return data;
  }

  // ── Session ────────────────────────────────────────────────────────────────

  static Future<bool> isLoggedIn() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      if (_isTokenExpired(token)) {
        await ApiService.clearToken();
        return false;
      }
      return true;
    } catch (_) { return false; }
  }

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= (exp - 30);
    } catch (_) { return true; }
  }

  static Future<void> logout() async {
    try { await ApiService.clearToken(); } catch (_) {}
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    if (!kIsWeb) {
      try { await _googleSignIn.signOut(); } catch (_) {}
    }
  }
}
