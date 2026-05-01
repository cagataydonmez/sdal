import 'dart:convert';
import 'dart:io';

import '../storage/app_support_directory.dart';

class OnboardingHintStore {
  OnboardingHintStore._(this._file);

  final File _file;

  static Future<OnboardingHintStore> create() async {
    final supportDir = await getSdalAppSupportDirectory();
    final file = File('${supportDir.path}/sdal_onboarding_hints.json');
    return OnboardingHintStore._(file);
  }

  Future<Set<String>> loadDismissed() async {
    try {
      if (!await _file.exists()) return <String>{};
      final raw = await _file.readAsString();
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return <String>{};
      final dismissed = map['dismissed'];
      if (dismissed is! List) return <String>{};
      return dismissed.map((item) => item.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> isDismissed(String id) async {
    final dismissed = await loadDismissed();
    return dismissed.contains(id);
  }

  Future<void> dismiss(String id) async {
    final dismissed = await loadDismissed();
    dismissed.add(id);
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode(<String, Object?>{'dismissed': dismissed.toList()..sort()}),
      flush: true,
    );
  }
}
