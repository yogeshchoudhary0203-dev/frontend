import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../utils/navigator_key.dart';   // ← no more circular import
import '../screens/single_post_screen.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void init() {
    // 1. Listen for links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('[DeepLink] Stream: $uri');
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        debugPrint('[DeepLink] Stream error: $err');
      },
    );

    // 2. Cold-start initial link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        debugPrint('[DeepLink] Initial link: $uri');
        Future.delayed(const Duration(milliseconds: 1200), () {
          _handleDeepLink(uri);
        });
      }
    }).catchError((Object err) {
      debugPrint('[DeepLink] Initial link error: $err');
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLink] scheme=${uri.scheme} host=${uri.host} path=${uri.path}');

    String? postId;

    // trandia://post/ID  or  trandia://video/ID
    if (uri.scheme == 'trandia') {
      if (uri.host == 'post' || uri.host == 'video') {
        postId = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : uri.queryParameters['id'];
      }
    }
    // https://trandia.com/post/ID  or  https://trandia.com/video/ID
    else if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host == 'trandia.com' || uri.host == 'www.trandia.com') {
        final segs = uri.pathSegments;
        if (segs.length >= 2 && (segs[0] == 'post' || segs[0] == 'video')) {
          postId = segs[1];
        } else if (segs.isNotEmpty && (segs[0] == 'post' || segs[0] == 'video')) {
          postId = uri.queryParameters['id'];
        }
      }
    }

    if (postId != null && postId.isNotEmpty) {
      debugPrint('[DeepLink] postId=$postId → navigating');
      _navigateToPost(postId);
    } else {
      debugPrint('[DeepLink] No valid postId found');
    }
  }

  void _navigateToPost(String postId) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[DeepLink] context null, retrying in 1s');
      Future.delayed(const Duration(seconds: 1), () => _navigateToPost(postId));
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => SinglePostScreen(postId: postId, dark: isDark),
      ),
    );
  }
}
