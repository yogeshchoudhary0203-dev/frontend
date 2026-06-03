import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// The auth state held by [AuthNotifier].
///
/// [isLoggedIn] mirrors what [AuthService.isLoggedIn()] returns.
/// [userId]     is the decoded JWT "sub" claim (null when logged out).
/// [isLoading]  is true only during the initial session check.
class AuthState {
  const AuthState({
    this.isLoggedIn = false,
    this.userId,
    this.isLoading = true,
  });

  final bool isLoggedIn;
  final String? userId;
  final bool isLoading;

  AuthState copyWith({
    bool? isLoggedIn,
    String? userId,
    bool? isLoading,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: isLoggedIn == false ? null : (userId ?? this.userId),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() =>
      'AuthState(isLoggedIn: $isLoggedIn, userId: $userId, isLoading: $isLoading)';
}

/// Manages authentication state.
///
/// This notifier is a thin wrapper around [AuthService] — it does NOT
/// duplicate any logic; it only reads/writes state based on AuthService calls.
/// All existing screens continue to call [AuthService] directly for login,
/// logout, etc.  After doing so they can call [refresh()] on this notifier
/// to sync the provider state.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  /// Called once at startup to populate state from the stored token.
  Future<void> _init() async {
    final loggedIn = await AuthService.isLoggedIn();
    final userId = loggedIn ? await AuthService.getCurrentUserId() : null;
    state = AuthState(
      isLoggedIn: loggedIn,
      userId: userId,
      isLoading: false,
    );
  }

  /// Re-check the token and update state.
  /// Call this after login, logout, or token changes.
  Future<void> refresh() async {
    final loggedIn = await AuthService.isLoggedIn();
    final userId = loggedIn ? await AuthService.getCurrentUserId() : null;
    state = state.copyWith(
      isLoggedIn: loggedIn,
      userId: userId,
      isLoading: false,
    );
  }

  /// Convenience: mark as logged out without hitting the disk.
  void markLoggedOut() {
    state = const AuthState(isLoggedIn: false, isLoading: false);
  }
}

/// The global provider — use [ref.watch(authProvider)] anywhere in the tree.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
