import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../storage/app_support_directory.dart';

enum ThemeModePreference { system, light, dark }

extension ThemeModePreferenceX on ThemeModePreference {
  ThemeMode get themeMode => switch (this) {
    ThemeModePreference.system => ThemeMode.system,
    ThemeModePreference.light => ThemeMode.light,
    ThemeModePreference.dark => ThemeMode.dark,
  };

  String get storageValue => name;

  static ThemeModePreference fromStorage(String? raw) {
    for (final value in ThemeModePreference.values) {
      if (value.name == raw) return value;
    }
    return ThemeModePreference.system;
  }
}

class ThemeModeStore {
  ThemeModeStore._(this._file);

  final File _file;

  static Future<ThemeModeStore> create() async {
    final supportDir = await getSdalAppSupportDirectory();
    final file = File('${supportDir.path}/sdal_theme_mode.json');
    return ThemeModeStore._(file);
  }

  Future<ThemeModePreference> load() async {
    try {
      if (!await _file.exists()) return ThemeModePreference.system;
      final raw = await _file.readAsString();
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return ThemeModePreference.system;
      return ThemeModePreferenceX.fromStorage(map['themeMode']?.toString());
    } catch (_) {
      return ThemeModePreference.system;
    }
  }

  Future<void> save(ThemeModePreference preference) async {
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode(<String, Object?>{'themeMode': preference.storageValue}),
      flush: true,
    );
  }
}
