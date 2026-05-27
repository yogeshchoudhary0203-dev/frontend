import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/single_post_screen.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void init() {
    // 1. Listen for link stream when app is running (foreground or background)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLink] Stream event received: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('[DeepLink] Stream error: $err');
      },
    );

    // 2. Process initial link when app is cold-started
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[DeepLink] Initial link received: $uri');
        // Add a slight delay to ensure the UI navigator is ready
        Future.delayed(const Duration(milliseconds: 1200), () {
          _handleDeepLink(uri);
        });
      }
    }).catchError((err) {
      debugPrint('[DeepLink] Error getting initial link: $err');
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLink] Processing link: scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}');
    
    String? postId;

    // 1. Handle custom URL scheme (trandia://post/12345 or trandia://video/12345)
    if (uri.scheme == 'trandia') {
      if (uri.host == 'post' || uri.host == 'video') {
        if (uri.pathSegments.isNotEmpty) {
          postId = uri.pathSegments.first;
        } else {
          postId = uri.queryParameters['id'];
        }
      }
    }
    // 2. Handle HTTP/HTTPS App Links (https://trandia.com/post/12345 or https://trandia.com/video/12345)
    else if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host == 'trandia.com' || uri.host == 'www.trandia.com') {
        final segments = uri.pathSegments;
        if (segments.length >= 2 && (segments[0] == 'post' || segments[0] == 'video')) {
          postId = segments[1];
        } else if (segments.isNotEmpty && (segments[0] == 'post' || segments[0] == 'video')) {
          postId = uri.queryParameters['id'];
        }
      }
    }

    if (postId != null && postId.isNotEmpty) {
      debugPrint('[DeepLink] Parsed Post ID: $postId. Navigating...');
      _navigateToPost(postId);
    } else {
      debugPrint('[DeepLink] No valid Post ID found in URI.');
    }
  }

  void _navigateToPost(String postId) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[DeepLink] Navigator context is null. Retrying in 1s...');
      Future.delayed(const Duration(seconds: 1), () => _navigateToPost(postId));
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Navigate using the global navigatorKey
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => SinglePostScreen(
          postId: postId,
          dark: isDark,
        ),
      ),
    );
  }
}
