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
    if (trimmed.isEmpty) return Uri();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    // Bare filename (no path separator) = profile photo stored in vesikalik directory.
    // The backend stores only the filename in the `resim` column; the web frontend
    // consistently resolves these via /api/media/vesikalik/<filename>.
    if (!trimmed.contains('/')) {
      return siteBaseUri.resolve('/api/media/vesikalik/$trimmed');
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
    final normalizedInput = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final parsed = Uri.tryParse(normalizedInput);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return normalizedInput;
    }

    final normalizedPath =
        parsed.path.isNotEmpty &&
            parsed.path.length > 1 &&
            parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;

    return Uri(
      scheme: parsed.scheme,
      userInfo: parsed.userInfo.isEmpty ? null : parsed.userInfo,
      host: parsed.host,
      port: parsed.hasPort && parsed.port > 0 ? parsed.port : null,
      path: normalizedPath,
    ).toString();
  }
}
