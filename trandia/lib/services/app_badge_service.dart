import 'dart:developer' as developer;
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Manages the launcher-icon unread badge (WhatsApp / Instagram style).
///
/// Two update paths:
///   • [refresh] — authoritative: asks the server for the exact total unread
///     (messages + notifications) and sets the badge. Called on app open/resume
///     and whenever something is read. Self-heals any drift.
///   • [bump]    — best-effort: increments a persisted counter without a server
///     call. Used by the FCM background isolate so the badge keeps growing while
///     the app is killed; the next [refresh] corrects it to the exact value.
class AppBadgeService {
  static const _kCountKey = 'app_badge_count';

  // Cached platform-support check (some Android launchers don't support badges).
  static bool? _supported;

  static Future<bool> _isSupported() async {
    if (_supported != null) return _supported!;
    try {
      _supported = await AppBadgePlus.isSupported();
    } catch (_) {
      _supported = false;
    }
    return _supported!;
  }

  /// Authoritative refresh from the server. Safe to call frequently.
  static Future<void> refresh() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return; // not logged in
      final res = await ApiService.get(
        '/users/me/badge',
        requiresAuth: true,
        bypassCache: true,
      );
      final total = (res['total'] as num?)?.toInt() ?? 0;
      await _apply(total);
    } catch (e) {
      developer.log('[AppBadge] refresh failed: $e');
    }
  }

  /// Increment the badge by [by] without a network call (background isolate).
  static Future<void> bump([int by = 1]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_kCountKey) ?? 0) + by;
      await _apply(next, prefs: prefs);
    } catch (e) {
      developer.log('[AppBadge] bump failed: $e');
    }
  }

  /// Clear the badge (logout, or everything read).
  static Future<void> clear() => _apply(0);

  static Future<void> _apply(int count, {SharedPreferences? prefs}) async {
    final c = count < 0 ? 0 : count;
    try {
      prefs ??= await SharedPreferences.getInstance();
      await prefs.setInt(_kCountKey, c);
    } catch (_) {}
    if (!await _isSupported()) return;
    try {
      await AppBadgePlus.updateBadge(c); // 0 clears the badge
    } catch (e) {
      developer.log('[AppBadge] updateBadge failed: $e');
    }
  }
}
