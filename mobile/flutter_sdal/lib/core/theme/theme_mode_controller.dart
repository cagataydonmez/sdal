import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'theme_mode_store.dart';

class ThemeModeController extends Notifier<ThemeModePreference> {
  ThemeModeStore get _store => ref.read(themeModeStoreProvider);

  @override
  ThemeModePreference build() => ref.read(initialThemeModePreferenceProvider);

  Future<void> setPreference(ThemeModePreference preference) async {
    if (state == preference) return;
    state = preference;
    await _store.save(preference);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeModePreference>(
      ThemeModeController.new,
    );
