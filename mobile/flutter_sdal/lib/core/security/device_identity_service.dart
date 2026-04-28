import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _deviceIdStorageKey = 'sdal.auth.device_id.v1';

class AuthDeviceMetadata {
  const AuthDeviceMetadata({
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.appVersion,
  });

  final String deviceId;
  final String platform;
  final String deviceName;
  final String appVersion;

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'platform': platform,
    'device_name': deviceName,
    'app_version': appVersion,
  };
}

class DeviceIdentityService {
  DeviceIdentityService({
    FlutterSecureStorage? secureStorage,
    DeviceInfoPlugin? deviceInfo,
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final FlutterSecureStorage _secureStorage;
  final DeviceInfoPlugin _deviceInfo;

  Future<String> getOrCreateDeviceId() async {
    final existing = await _secureStorage.read(key: _deviceIdStorageKey);
    if (existing != null && existing.length >= 16) return existing;
    final next = _secureUuidV4();
    await _secureStorage.write(key: _deviceIdStorageKey, value: next);
    return next;
  }

  Future<AuthDeviceMetadata> metadata() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceId = await getOrCreateDeviceId();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    if (!kIsWeb && Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return AuthDeviceMetadata(
        deviceId: deviceId,
        platform: 'ios',
        deviceName: [
          info.name,
          info.model,
        ].where((x) => x.trim().isNotEmpty).join(' '),
        appVersion: appVersion,
      );
    }
    if (!kIsWeb && Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return AuthDeviceMetadata(
        deviceId: deviceId,
        platform: 'android',
        deviceName: [
          info.manufacturer,
          info.model,
        ].where((x) => x.trim().isNotEmpty).join(' '),
        appVersion: appVersion,
      );
    }
    return AuthDeviceMetadata(
      deviceId: deviceId,
      platform: 'android',
      deviceName: 'Unknown device',
      appVersion: appVersion,
    );
  }
}

String _secureUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final text = bytes.map(hex).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(),
);
