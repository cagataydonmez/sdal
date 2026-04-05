import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/theme/theme_mode_store.dart';

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
