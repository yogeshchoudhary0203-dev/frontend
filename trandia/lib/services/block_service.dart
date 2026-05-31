import 'dart:developer' as developer;
import 'api_service.dart';

/// Singleton — manages the current user's block list.
/// Call [load()] once at app startup / login.
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  Set<String> _blockedIds = {};

  /// Whether the current user has blocked [userId].
  bool isBlocked(String userId) => _blockedIds.contains(userId);

  /// Immutable snapshot (for widgets that need to iterate).
  Set<String> get blockedIds => Set.unmodifiable(_blockedIds);

  // ── Load ────────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      final data = await ApiService.get('/users/me/blocked-ids', requiresAuth: true);
      final ids = List<String>.from(data['blocked_ids'] as List? ?? []);
      _blockedIds = ids.toSet();
      developer.log('[BlockService] loaded ${_blockedIds.length} blocked ids');
    } catch (e) {
      developer.log('[BlockService] load error: $e');
    }
  }

  // ── Block ────────────────────────────────────────────────────────────────

  Future<void> blockUser(String userId) async {
    _blockedIds.add(userId); // optimistic
    try {
      await ApiService.post('/users/$userId/block', {}, requiresAuth: true);
    } catch (e) {
      _blockedIds.remove(userId); // rollback
      developer.log('[BlockService] blockUser error: $e');
      rethrow;
    }
  }

  // ── Unblock ──────────────────────────────────────────────────────────────

  Future<void> unblockUser(String userId) async {
    _blockedIds.remove(userId); // optimistic
    try {
      await ApiService.delete('/users/$userId/block', requiresAuth: true);
    } catch (e) {
      _blockedIds.add(userId); // rollback
      developer.log('[BlockService] unblockUser error: $e');
      rethrow;
    }
  }

  // ── Clear (on logout) ────────────────────────────────────────────────────

  void clear() => _blockedIds = {};
}
