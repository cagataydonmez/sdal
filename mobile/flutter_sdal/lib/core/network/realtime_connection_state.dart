enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class RealtimeConnectionState {
  const RealtimeConnectionState({
    required this.status,
    this.message,
    this.attempt = 0,
  });

  final RealtimeConnectionStatus status;
  final String? message;
  final int attempt;

  const RealtimeConnectionState.disconnected()
    : status = RealtimeConnectionStatus.disconnected,
      message = null,
      attempt = 0;
}
