/// Safe web utilities — works on ALL platforms without dart:html.
/// On non-web platforms all functions are no-ops.
library web_utils;

export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
