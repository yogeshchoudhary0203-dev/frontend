/// Stub implementation for non-web platforms (Android, iOS, desktop).
/// All methods are no-ops or return empty values.

/// Navigates the browser to [url]. No-op on non-web platforms.
void launchWebUrl(String url) {}

/// Returns the current window origin (e.g. "http://localhost:59236").
/// Returns empty string on non-web platforms.
String getWindowOrigin() => '';

/// Returns URL search params as a map (e.g. {"token": "abc", "user": "..."}).
/// Returns empty map on non-web platforms.
Map<String, String> getUrlSearchParams() => {};

/// Replaces the current URL with "/" to remove query params from the address bar.
/// No-op on non-web platforms.
void clearUrlSearchParams() {}
