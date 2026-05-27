import 'package:flutter/material.dart';

/// Global navigator key — used by DeepLinkService and FCM handlers
/// to navigate without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
