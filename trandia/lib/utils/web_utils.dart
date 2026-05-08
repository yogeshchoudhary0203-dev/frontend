/// Conditional export: uses dart:html on web, stub on all other platforms.
export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
