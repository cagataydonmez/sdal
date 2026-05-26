import 'dart:convert';
import 'dart:io';

import '../../../core/storage/app_support_directory.dart';

class AdminQuickAccessStore {
  AdminQuickAccessStore._(this._file);

  final File _file;

  static const defaultQuickAccessIds = <String>[
    'members',
    'memberJourney',
    'requests',
    'content',
    'media',
    'siteControls',
  ];

  static Future<AdminQuickAccessStore> create() async {
    final supportDir = await getSdalAppSupportDirectory();
    final file = File('${supportDir.path}/sdal_admin_quick_access.json');
    return AdminQuickAccessStore._(file);
  }

  Future<List<String>> load() async {
    try {
      if (!await _file.exists()) return defaultQuickAccessIds;
      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      final rawItems = decoded is Map<String, dynamic>
          ? decoded['items']
          : decoded;
      if (rawItems is! List) return defaultQuickAccessIds;
      return _normalize(rawItems);
    } catch (_) {
      return defaultQuickAccessIds;
    }
  }

  Future<void> save(List<String> ids) async {
    final normalized = _normalize(ids);
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
    await _file.writeAsString(
      jsonEncode(<String, Object?>{'items': normalized}),
      flush: true,
    );
  }

  List<String> _normalize(Iterable<Object?> values) {
    final ids = <String>[];
    for (final value in values) {
      final id = value.toString().trim();
      if (id.isEmpty || ids.contains(id)) continue;
      ids.add(id);
      if (ids.length >= 12) break;
    }
    return ids;
  }
}
