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

  /// Step 1: Create Firebase user + send verification email.
  ///
  /// Handles orphaned Firebase users — when a previous signup attempt was
  /// started but never completed (user went back / closed app), Firebase
  /// retains the unverified user. This causes a false "email-already-in-use"
  /// error even though MongoDB has no account for that email.
  ///
  /// Fix: if Firebase says email-already-in-use, try signing in with the
  /// same credentials. If that succeeds AND the email is still unverified,
  /// it's a stale orphaned account — delete it and create fresh.
  static Future<String> initiateFirebaseSignup({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.sendEmailVerification();
      return email;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;

      // ── Orphaned signup check ─────────────────────────────────────────────
      // Firebase says email-already-in-use. Could be:
      //   A) Same user retrying with SAME password → sign in, check, delete & recreate
      //   B) Same user retrying with DIFFERENT password → sign in fails
      //   C) Genuinely registered user → email exists in MongoDB

      // Try signing in with the provided password.
      try {
        final existing = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final fbUser = existing.user!;
        await fbUser.reload();
        final refreshed = FirebaseAuth.instance.currentUser!;

        if (!refreshed.emailVerified) {
          // Unverified = orphaned / abandoned previous signup attempt.
          await refreshed.delete();
          final fresh = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
          await fresh.user!.sendEmailVerification();
          return email;
        }

        // Email IS verified in Firebase → likely a real account.
        await FirebaseAuth.instance.signOut();
        rethrow;
      } on FirebaseAuthException catch (signInErr) {
        if (signInErr.code != 'wrong-password' &&
            signInErr.code != 'invalid-credential' &&
            signInErr.code != 'INVALID_LOGIN_CREDENTIALS') {
          rethrow;
        }

        // Password mismatch — orphaned Firebase user with different password,
        // OR genuinely registered user. We need to check MongoDB.
        //
        // Strategy: try backend cleanup → try check-email → fallback to reset
        
        // ── Attempt 1: Backend cleanup endpoint ─────────────────────────────
        try {
          final cleanupResult = await ApiService.post(
            '/auth/cleanup-orphaned-firebase',
            {'email': email},
          );
          if (cleanupResult['cleaned'] == true) {
            final fresh = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                    email: email, password: password);
            await fresh.user!.sendEmailVerification();
            return email;
          }
          // cleaned=false → orphan confirmed but couldn't delete
          // Fall through to password reset
        } on ApiException catch (apiErr) {
          final msg = apiErr.message.toLowerCase();
          if (msg.contains('already registered')) {
            // 409 → email IS in MongoDB → genuinely registered
            throw e;
          }
          // 404 "Not Found" or other → endpoint not available, try next
        } catch (_) {}

        // ── Attempt 2: Check email via backend ──────────────────────────────
        try {
          final checkResult = await ApiService.get(
            '/users/check-email?email=${Uri.encodeComponent(email)}',
          );
          if (checkResult['exists'] == true) {
            // Email IS in MongoDB → genuinely registered
            throw e;
          }
          // Email NOT in MongoDB → definitely orphaned, fall through to reset
        } on ApiException catch (apiErr) {
          final msg = apiErr.message.toLowerCase();
          if (msg.contains('already registered')) {
            throw e;
          }
          // 404 or other → endpoint not available, fall through
        } catch (_) {}

        // ── Attempt 3: Password reset (last resort) ─────────────────────────
        // We're fairly confident this is an orphaned Firebase user since both
        // cleanup endpoints are unavailable (backend not deployed with them).
        // Send a password reset email so the user can reclaim the account.
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        } catch (_) {}
        
        throw const ApiException(
          'A previous incomplete signup was found. We sent a password reset '
          'email to your inbox. Please reset your password first, then '
          'try signing up again with the new password.',
        );
      }
    }
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

  static Future<String?> getCurrentUserId() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      return payload['sub'] as String?;
    } catch (_) { return null; }
  }

  static Future<void> logout() async {
    try { await ApiService.clearToken(); } catch (_) {}
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    if (!kIsWeb) {
      try { await _googleSignIn.signOut(); } catch (_) {}
    }
  }
}
