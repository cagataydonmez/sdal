import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_models.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/notification_route_mapper.dart';
import '../data/push_notifications_repository.dart';

const _pushChannelId = 'sdal_notifications';
const _pushChannelName = 'SDAL Notifications';
const _pushChannelDescription = 'Bildirimler ve ağ merkezi uyarıları';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  try {
    if (Firebase.apps.isEmpty) {
      final options = _firebaseOptionsFromEnvironment();
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (err) {
    debugPrint('push background firebase init skipped: $err');
  }
}

class PushNotificationsService {
  PushNotificationsService(this.ref);

  final Ref ref;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _initialized = false;
  bool _firebaseReady = false;
  bool _localNotificationsReady = false;
  String? _currentToken;
  int? _registeredUserId;
  String? _registeredToken;

  Future<void> initialize() async {
    if (_initialized || !(Platform.isAndroid || Platform.isIOS)) return;
    _initialized = true;

    _firebaseReady = await _ensureFirebaseReady();
    if (!_firebaseReady) return;

    await _initializeLocalNotifications();

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((token) {
          _currentToken = token.trim();
          unawaited(_syncActiveSession(force: true));
        });

    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      await _clearRegistration();
      return;
    }

    _currentToken = (await FirebaseMessaging.instance.getToken())?.trim();

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _persistPendingRoute(initialMessage);
    }

    await _syncActiveSession(force: true);
  }

  Future<void> syncSession(SessionSnapshot snapshot) async {
    if (!_firebaseReady) return;
    if (!snapshot.isAuthenticated) {
      await _clearRegistration();
      return;
    }
    await _syncActiveSession(force: false, snapshotOverride: snapshot);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }

  Future<void> _syncActiveSession({
    required bool force,
    SessionSnapshot? snapshotOverride,
  }) async {
    final snapshot =
        snapshotOverride ?? ref.read(sessionControllerProvider).value;
    if (snapshot == null) return;
    if (!snapshot.isAuthenticated) {
      await _clearRegistration();
      return;
    }
    final userId = snapshot.user?.id ?? 0;
    final token = _currentToken?.trim().isNotEmpty == true
        ? _currentToken!.trim()
        : (await FirebaseMessaging.instance.getToken())?.trim();
    if (token == null || token.isEmpty) return;
    if (!force && _registeredUserId == userId && _registeredToken == token) {
      await _openPendingRouteIfAny();
      return;
    }
    final repository = await ref.read(
      pushNotificationsRepositoryProvider.future,
    );
    final installationId = await repository.store.readInstallationId();
    final result = await repository.registerDevice(
      installationId: installationId,
      platform: Platform.isIOS ? 'ios' : 'android',
      pushToken: token,
      locale: Platform.localeName,
    );
    if (result.ok) {
      _registeredUserId = userId;
      _registeredToken = token;
      _currentToken = token;
      await repository.store.saveLastToken(token);
      await _openPendingRouteIfAny();
    }
  }

  Future<void> _clearRegistration() async {
    try {
      final repository = await ref.read(
        pushNotificationsRepositoryProvider.future,
      );
      final installationId = await repository.store.readInstallationId();
      final pushToken =
          _registeredToken ??
          _currentToken ??
          await repository.store.readLastToken() ??
          '';
      await repository.unregisterDevice(
        installationId: installationId,
        pushToken: pushToken,
      );
    } catch (err) {
      debugPrint('push unregister skipped: $err');
    }
    _registeredUserId = null;
    _registeredToken = null;
  }

  Future<bool> _ensureFirebaseReady() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      final options = _firebaseOptionsFromEnvironment();
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      return true;
    } catch (err) {
      debugPrint('push firebase init skipped: $err');
      return false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload?.trim();
        if (route != null && route.isNotEmpty) {
          _openRoute(route);
        }
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _pushChannelId,
        _pushChannelName,
        description: _pushChannelDescription,
        importance: Importance.high,
      ),
    );
    _localNotificationsReady = true;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);
    if (!_localNotificationsReady) return;
    final route = _extractRoute(message);
    await _localNotifications.show(
      id: message.hashCode,
      title: _messageTitle(message),
      body: _messageBody(message),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _pushChannelId,
          _pushChannelName,
          channelDescription: _pushChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);
    final route = _extractRoute(message);
    if (route != null) {
      _openRoute(route);
      return;
    }
    await _persistPendingRoute(message);
  }

  Future<void> _persistPendingRoute(RemoteMessage message) async {
    final repository = await ref.read(
      pushNotificationsRepositoryProvider.future,
    );
    await repository.store.savePendingRoute(_extractRoute(message));
  }

  Future<void> _openPendingRouteIfAny() async {
    final repository = await ref.read(
      pushNotificationsRepositoryProvider.future,
    );
    final route = await repository.store.takePendingRoute();
    if (route != null && route.isNotEmpty) {
      _openRoute(route);
    }
  }

  void _openRoute(String route) {
    final normalized = route.trim();
    if (normalized.isEmpty) return;
    final router = ref.read(appRouterProvider);
    final current = router.routeInformationProvider.value.uri.toString();
    if (current == normalized) return;
    router.push(normalized);
  }

  String? _extractRoute(RemoteMessage message) {
    final route =
        mapNotificationWebRouteToApp(message.data['route'] ?? '') ??
        mapNotificationWebRouteToApp(message.data['href'] ?? '');
    return route?.trim().isEmpty == true ? null : route;
  }

  String _messageTitle(RemoteMessage message) {
    final title = message.notification?.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return 'SDAL Bildirim';
  }

  String _messageBody(RemoteMessage message) {
    final body = message.notification?.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    final dataBody = message.data['body']?.toString().trim();
    if (dataBody != null && dataBody.isNotEmpty) return dataBody;
    return 'Yeni bir bildirimin var.';
  }
}

FirebaseOptions? _firebaseOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('SDAL_FIREBASE_API_KEY');
  const projectId = String.fromEnvironment('SDAL_FIREBASE_PROJECT_ID');
  const messagingSenderId = String.fromEnvironment(
    'SDAL_FIREBASE_MESSAGING_SENDER_ID',
  );
  if (apiKey.isEmpty || projectId.isEmpty || messagingSenderId.isEmpty) {
    return null;
  }
  if (Platform.isAndroid) {
    const appId = String.fromEnvironment('SDAL_FIREBASE_ANDROID_APP_ID');
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: String.fromEnvironment('SDAL_FIREBASE_STORAGE_BUCKET'),
    );
  }
  if (Platform.isIOS) {
    const appId = String.fromEnvironment('SDAL_FIREBASE_IOS_APP_ID');
    const iosBundleId = String.fromEnvironment('SDAL_FIREBASE_IOS_BUNDLE_ID');
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: String.fromEnvironment('SDAL_FIREBASE_STORAGE_BUCKET'),
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
    );
  }
  return null;
}

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((
  ref,
) {
  final service = PushNotificationsService(ref);
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
