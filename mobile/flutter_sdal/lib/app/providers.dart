import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/theme/theme_mode_store.dart';

// Re-export the active-theme providers so main() and app.dart can import from one file.
export '../core/theme/sdal_active_theme_store.dart'
    show
        SdalActiveThemeStore,
        sdalActiveThemeStoreProvider,
        initialActiveThemeProvider,
        sdalActiveThemeProvider;
export '../core/theme/sdal_app_theme.dart' show SdalAppTheme;

final appConfigProvider = Provider<AppConfig>(
  (_) => throw UnimplementedError(
    'appConfigProvider must be overridden in main().',
  ),
);

final apiClientProvider = Provider<ApiClient>(
  (_) => throw UnimplementedError(
    'apiClientProvider must be overridden in main().',
  ),
);

final themeModeStoreProvider = Provider<ThemeModeStore>(
  (_) => throw UnimplementedError(
    'themeModeStoreProvider must be overridden in main().',
  ),
);

final initialThemeModePreferenceProvider = Provider<ThemeModePreference>(
  (_) => ThemeModePreference.system,
);
