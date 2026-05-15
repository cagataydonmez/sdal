import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_controller.dart';
import '../storage/app_support_directory.dart';
import 'sdal_app_theme.dart';

// ---------------------------------------------------------------------------
// Admin default theme — persisted so the correct palette shows on cold start
// before the first network response arrives.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// The admin-set default theme. Reads from the live session when available,
/// falls back to the cold-start value loaded in main().
final sdalAdminThemeProvider = Provider<SdalAppTheme>((ref) {
  final sessionValue = ref.watch(sessionControllerProvider);
  if (sessionValue.hasValue && sessionValue.value != null) {
    return sessionValue.value!.siteAccess.activeTheme;
  }
  return ref.watch(initialActiveThemeProvider);
});

// ---------------------------------------------------------------------------
// User theme notifier — Riverpod 3 compatible (no StateProvider)
// ---------------------------------------------------------------------------

/// The user's explicit theme choice. null = follow admin default.
/// Initial value comes from [initialUserThemeProvider] (loaded in main()).
class SdalUserThemeNotifier extends Notifier<SdalAppTheme?> {
  @override
  SdalAppTheme? build() => ref.read(initialUserThemeProvider);

  void set(SdalAppTheme? theme) => state = theme;
}

final sdalUserThemeProvider =
    NotifierProvider<SdalUserThemeNotifier, SdalAppTheme?>(
      SdalUserThemeNotifier.new,
    );

/// Seed provider — overridden in main() with the value loaded from disk.
final initialUserThemeProvider = Provider<SdalAppTheme?>((_) => null);

/// The fully resolved active theme: user choice beats admin default.
final sdalActiveThemeProvider = Provider<SdalAppTheme>((ref) {
  return ref.watch(sdalUserThemeProvider) ?? ref.watch(sdalAdminThemeProvider);
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
