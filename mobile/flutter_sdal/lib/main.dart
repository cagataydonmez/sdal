import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme_mode_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (kDebugMode) {
    debugPrint(
      '[app-config] apiBaseUrl=${config.apiBaseUrl} siteBaseUrl=${config.siteBaseUrl}',
    );
  }
  final apiClient = await ApiClient.create(config);
  final themeModeStore = await ThemeModeStore.create();
  final initialThemeModePreference = await themeModeStore.load();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        apiClientProvider.overrideWithValue(apiClient),
        themeModeStoreProvider.overrideWithValue(themeModeStore),
        initialThemeModePreferenceProvider.overrideWithValue(
          initialThemeModePreference,
        ),
      ],
      child: const SdalFlutterApp(),
    ),
  );
}
