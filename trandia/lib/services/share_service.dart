import 'api_service.dart';
import 'post_service.dart';

class ShareService {
  ShareService._();

  // Calls backend to create a tracked short link.
  // Falls back to a plain URL on any error so sharing never fails.
  static Future<String> getShareUrl(PostModel post) async {
    try {
      final data = await ApiService.post(
        '/share/create',
        {
          'videoId': post.id,
          'creatorId': post.userId,
          'videoType': post.isVideo ? 'shot' : 'ttube',
        },
        requiresAuth: true,
      );
      final url = data['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return _fallbackUrl(post);
  }

  static String _fallbackUrl(PostModel post) {
    final path = post.isVideo ? 'video' : 'post';
    return 'https://trandia.com/$path/${post.id}';
  }

  static String buildShareText(PostModel post, String url) {
    final name = post.userName.isNotEmpty ? post.userName : post.userUsername;
    final captionPart = post.caption.isNotEmpty ? '\n\n${post.caption}' : '';
    return '$name ka yeh dekho Trandia pe! 🔥$captionPart\n\n$url\n\nTrandia — Scroll Smart. Grow Fast. 🚀';
  }
}
