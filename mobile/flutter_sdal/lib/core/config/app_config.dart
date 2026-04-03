class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.siteBaseUrl,
    required this.appName,
    required this.oauthCallbackScheme,
  });

  final String apiBaseUrl;
  final String siteBaseUrl;
  final String appName;
  final String oauthCallbackScheme;

  Uri get apiBaseUri => Uri.parse(apiBaseUrl);
  Uri get siteBaseUri => Uri.parse(siteBaseUrl);

  Uri resolveUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return siteBaseUri;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    return siteBaseUri.resolve(trimmed.startsWith('/') ? trimmed : '/$trimmed');
  }

  static AppConfig fromEnvironment() {
    const rawApiBaseUrl = String.fromEnvironment(
      'SDAL_API_BASE_URL',
      defaultValue: 'https://sdalsosyal.mywire.org/api',
    );
    const rawCallbackScheme = String.fromEnvironment(
      'SDAL_OAUTH_CALLBACK_SCHEME',
      defaultValue: 'sdalnative',
    );
    const rawAppName = String.fromEnvironment(
      'SDAL_APP_NAME',
      defaultValue: 'SDAL',
    );

    final normalizedApiBaseUrl = _normalizeUrl(rawApiBaseUrl);
    final normalizedSiteBaseUrl = normalizedApiBaseUrl.endsWith('/api')
        ? normalizedApiBaseUrl.substring(0, normalizedApiBaseUrl.length - 4)
        : normalizedApiBaseUrl;

    return AppConfig(
      apiBaseUrl: normalizedApiBaseUrl,
      siteBaseUrl: normalizedSiteBaseUrl,
      appName: rawAppName,
      oauthCallbackScheme: rawCallbackScheme.trim().isEmpty
          ? 'sdalnative'
          : rawCallbackScheme.trim(),
    );
  }

  static String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'https://sdalsosyal.mywire.org/api';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
