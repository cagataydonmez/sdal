import 'dart:io';
import 'package:flutter/services.dart';

abstract final class WatchBridgeService {
  static const _channel = MethodChannel('com.sdal/watch');

  /// Pushes the current session cookie to the Apple Watch companion app.
  /// No-op on non-iOS platforms.
  static Future<void> pushSession({
    required String cookie,
    required String baseUrl,
    int userId = 0,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('pushSession', {
        'cookie': cookie,
        'baseUrl': baseUrl,
        'userId': userId,
      });
    } on PlatformException {
      // Best-effort — watch sync failures must never crash the main app.
    }
  }

  static Future<void> clearSession() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('clearSession');
    } on PlatformException {
      // ignored
    }
  }
}
