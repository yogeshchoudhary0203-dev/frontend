import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Fire-and-forget Learn-Feed engagement reporting for the Skill-Score feature.
///
/// The Learn-Feed player calls [sendEvent] ONCE per video (on swipe-away) with
/// the highest watch-% reached + any engagements the user made on that video.
/// The call is intentionally fire-and-forget: it is never awaited by the UI,
/// has a short timeout, and swallows every error — a skill-score hiccup must
/// never block the feed or surface to the user.
class LearnService {
  /// Report a Learn-Feed engagement event. Returns immediately on the caller's
  /// side (caller does NOT await). Any failure is silently ignored.
  static void sendEvent({
    required String contentId,
    required int watchPercent,
    required List<String> engagements,
  }) {
    // Deliberately not awaited — fully detached from the UI.
    _post(contentId, watchPercent, engagements);
  }

  static Future<void> _post(
    String contentId,
    int watchPercent,
    List<String> engagements,
  ) async {
    try {
      if (contentId.isEmpty) return;
      final token = await ApiService.getToken();
      if (token == null) return;
      await http
          .post(
            Uri.parse('$baseUrl/learn/event'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'contentId': contentId,
              'watchPercent': watchPercent,
              'engagements': engagements,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Silent — skill-score reporting must never disrupt the feed.
    }
  }
}
