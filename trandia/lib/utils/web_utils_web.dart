import 'package:web/web.dart';

void launchWebUrl(String url) => window.location.href = url;

String getWindowOrigin() => window.location.origin;

Map<String, String> getUrlSearchParams() {
  final search = window.location.search;
  if (search.isEmpty || search == '?') return {};
  return Uri.splitQueryString(search.substring(1));
}

void clearUrlSearchParams() => window.history.pushState(null, '/');
