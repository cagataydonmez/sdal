import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/storage/app_support_directory.dart';

class PushNotificationsStore {
  PushNotificationsStore(this._file);

  final File _file;

  static Future<PushNotificationsStore> create() async {
    final supportDir = await getSdalAppSupportDirectory();
    final file = File('${supportDir.path}/push_notifications.json');
    return PushNotificationsStore(file);
  }

  Future<String> readInstallationId() async {
    final payload = await _readJson();
    final existing = _readString(payload['installationId']);
    if (existing != null) return existing;
    final next = _generateInstallationId();
    await _writeJson(<String, Object?>{...payload, 'installationId': next});
    return next;
  }

  Future<void> saveLastToken(String token) async {
    final payload = await _readJson();
    await _writeJson(<String, Object?>{...payload, 'lastToken': token.trim()});
  }

  Future<String?> readLastToken() async {
    final payload = await _readJson();
    return _readString(payload['lastToken']);
  }

  Future<void> savePendingRoute(String? route) async {
    final payload = await _readJson();
    final next = <String, Object?>{...payload};
    final normalized = _readString(route);
    if (normalized == null) {
      next.remove('pendingRoute');
    } else {
      next['pendingRoute'] = normalized;
    }
    await _writeJson(next);
  }

  Future<String?> takePendingRoute() async {
    final payload = await _readJson();
    final route = _readString(payload['pendingRoute']);
    if (route == null) return null;
    final next = <String, Object?>{...payload}..remove('pendingRoute');
    await _writeJson(next);
    return route;
  }

  Future<Map<String, Object?>> _readJson() async {
    if (!await _file.exists()) return <String, Object?>{};
    try {
      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((key, value) => MapEntry(key, value));
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return <String, Object?>{};
    }
    return <String, Object?>{};
  }

  Future<void> _writeJson(Map<String, Object?> payload) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(payload));
  }

  String _generateInstallationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final buffer = StringBuffer(
      DateTime.now().millisecondsSinceEpoch.toRadixString(16),
    );
    for (final value in bytes) {
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String? _readString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
