import 'dart:developer' as developer;
import 'api_service.dart';

/// Reports objectionable content / users to the backend (POST /reports).
///
/// Pairs with [BlockService]: a user can Block (stop seeing someone) and/or
/// Report (flag content for the moderation team). The backend is idempotent —
/// reporting the same target twice is a harmless no-op.
class ReportService {
  ReportService._();

  /// Valid target types accepted by the backend.
  static const String targetPost = 'post';
  static const String targetComment = 'comment';
  static const String targetStory = 'story';
  static const String targetUser = 'user';
  static const String targetMessage = 'message';

  /// Reason codes shown in the report sheet → backend.
  /// label is what the user sees; code is what the API expects.
  static const List<MapEntry<String, String>> reasons = [
    MapEntry('Spam or misleading', 'spam'),
    MapEntry('Nudity or sexual content', 'nudity'),
    MapEntry('Hate speech', 'hate'),
    MapEntry('Violence or dangerous acts', 'violence'),
    MapEntry('Harassment or bullying', 'harassment'),
    MapEntry('Child safety', 'child_safety'),
    MapEntry('Self-harm or suicide', 'self_harm'),
    MapEntry('Something else', 'other'),
  ];

  /// File a report. Returns true on success.
  static Future<bool> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    try {
      await ApiService.post(
        '/reports',
        {
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          'details': details,
        },
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      developer.log('[ReportService] report error: $e');
      return false;
    }
  }
}
