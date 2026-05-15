import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_controller.dart';
import '../storage/app_support_directory.dart';
import 'sdal_app_theme.dart';

class SdalActiveThemeStore {
  SdalActiveThemeStore._(this._file);

  final File _file;

  static Future<SdalActiveThemeStore> create() async {
    final supportDir = await getSdalAppSupportDirectory();
    final file = File('${supportDir.path}/sdal_active_theme.json');
    return SdalActiveThemeStore._(file);
  }

  Future<SdalAppTheme> load() async {
    try {
      if (!await _file.exists()) return SdalAppTheme.kor;
      final raw = await _file.readAsString();
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return SdalAppTheme.kor;
      return SdalAppTheme.fromString(map['activeTheme']?.toString());
    } catch (_) {
      return SdalAppTheme.kor;
    }
  }

  Future<void> save(SdalAppTheme theme) async {
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode(<String, Object?>{'activeTheme': theme.id}),
      flush: true,
    );
  }
}

/// Provides the active [SdalAppTheme] from the session snapshot.
/// Falls back to the persisted last-known theme so the correct palette
/// is shown immediately on launch without waiting for a network call.
final sdalActiveThemeProvider = Provider<SdalAppTheme>((ref) {
  final sessionValue = ref.watch(sessionControllerProvider);
  if (sessionValue.hasValue && sessionValue.value != null) {
    return sessionValue.value!.siteAccess.activeTheme;
  }
  return ref.watch(initialActiveThemeProvider);
});

// ---------------------------------------------------------------------------
// Overrides registered in main() — same pattern as ThemeModeStore
// ---------------------------------------------------------------------------

final sdalActiveThemeStoreProvider = Provider<SdalActiveThemeStore>(
  (_) => throw UnimplementedError(
    'sdalActiveThemeStoreProvider must be overridden in main().',
  ),
);

final initialActiveThemeProvider = Provider<SdalAppTheme>(
  (_) => SdalAppTheme.kor,
);
