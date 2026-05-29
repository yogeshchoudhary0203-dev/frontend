import 'package:flutter/foundation.dart';

/// Global follow state — maps userId → isFollowing.
/// All screens that show follow buttons listen to this notifier.
/// When any screen calls followUser / unfollowUser, it must also call
/// FollowState.set(userId, isFollowing) so other screens update instantly.
class FollowState {
  FollowState._();

  static final ValueNotifier<Map<String, bool>> notifier =
      ValueNotifier<Map<String, bool>>({});

  /// Returns the known follow state for [userId], or null if not yet fetched.
  static bool? get(String userId) => notifier.value[userId];

  /// Update the follow state for [userId] and notify all listeners.
  static void set(String userId, bool isFollowing) {
    if (userId.isEmpty) return;
    final updated = Map<String, bool>.from(notifier.value);
    updated[userId] = isFollowing;
    notifier.value = updated;
  }

  /// Seed multiple entries at once (e.g. after loading a list of users).
  static void seed(Iterable<MapEntry<String, bool>> entries) {
    final updated = Map<String, bool>.from(notifier.value);
    for (final e in entries) {
      if (e.key.isNotEmpty) updated[e.key] = e.value;
    }
    notifier.value = updated;
  }
}
