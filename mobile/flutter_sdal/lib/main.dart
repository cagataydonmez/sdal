import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme_mode_store.dart';
import 'features/push_notifications/application/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      // TODO: switch to providerAndroid/providerApple after the FlutterFire
      // type aliases in the pinned firebase_app_check release line up.
      // ignore: deprecated_member_use
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (error) {
    if (kDebugMode) debugPrint('[firebase] initialization skipped: $error');
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
