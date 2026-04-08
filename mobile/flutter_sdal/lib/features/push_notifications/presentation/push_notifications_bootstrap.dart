import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/session_models.dart';
import '../application/push_notifications_service.dart';

class PushNotificationsBootstrap extends ConsumerStatefulWidget {
  const PushNotificationsBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushNotificationsBootstrap> createState() =>
      _PushNotificationsBootstrapState();
}

class _PushNotificationsBootstrapState
    extends ConsumerState<PushNotificationsBootstrap> {
  ProviderSubscription<AsyncValue<SessionSnapshot>>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    final service = ref.read(pushNotificationsServiceProvider);
    unawaited(service.initialize());
    final snapshot = ref.read(sessionControllerProvider).valueOrNull;
    if (snapshot != null) {
      unawaited(service.syncSession(snapshot));
    }
    _sessionSubscription = ref.listenManual(sessionControllerProvider, (
      _,
      next,
    ) {
      final session = next.valueOrNull;
      if (session != null) {
        unawaited(
          ref.read(pushNotificationsServiceProvider).syncSession(session),
        );
      }
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
