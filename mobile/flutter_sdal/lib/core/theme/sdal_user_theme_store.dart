import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/app_support_directory.dart';
import 'sdal_app_theme.dart';

/// Persists the user's explicit theme preference.
/// A stored value of null (missing file) means "follow admin default".
class SdalUserThemeStore {
  SdalUserThemeStore._(this._file);

  final File _file;

  static Future<SdalUserThemeStore> create() async {
    final supportDir = await getSdalAppSupportDirectory();
    final file = File('${supportDir.path}/sdal_user_theme.json');
    return SdalUserThemeStore._(file);
  }

  /// Returns null if no explicit choice has been made.
  Future<SdalAppTheme?> load() async {
    try {
      if (!await _file.exists()) return null;
      final raw = await _file.readAsString();
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final value = map['userTheme']?.toString();
      if (value == null || value.isEmpty) return null;
      return SdalAppTheme.values.firstWhere(
        (t) => t.id == value,
        orElse: () => SdalAppTheme.kor,
      );
    } catch (_) {
      return null;
    }
  }

  /// Pass null to clear the user preference (revert to admin default).
  Future<void> save(SdalAppTheme? theme) async {
    if (theme == null) {
      if (await _file.exists()) await _file.delete();
      return;
    }
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode(<String, Object?>{'userTheme': theme.id}),
      flush: true,
    );
  }
}

final sdalUserThemeStoreProvider = Provider<SdalUserThemeStore>(
  (_) => throw UnimplementedError(
    'sdalUserThemeStoreProvider must be overridden in main().',
  ),
);
