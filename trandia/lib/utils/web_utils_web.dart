import 'package:web/web.dart';

/// Navigates the browser tab to [url] (full page redirect).
void launchWebUrl(String url) {
  window.location.href = url;
}

/// Returns the current window origin, e.g. "http://localhost:59236".
String getWindowOrigin() => window.location.origin;

/// Parses window.location.search and returns params as a plain Dart map.
Map<String, String> getUrlSearchParams() {
  final search = window.location.search;
  if (search.isEmpty || search == '?') return {};
  // Remove leading '?' before splitting
  return Uri.splitQueryString(search.substring(1));
}

/// Replaces the browser URL with "/" so the token doesn't stay in the address bar.
void clearUrlSearchParams() {
  // package:web History.pushState takes 2 args (data, url) — no title param
  window.history.pushState(null, '/');
}
