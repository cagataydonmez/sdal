import 'package:flutter/material.dart';

import '../network/realtime_connection_state.dart';
import '../theme/sdal_theme_tokens.dart';

class RealtimeStatusBanner extends StatelessWidget {
  const RealtimeStatusBanner({
    super.key,
    required this.state,
    required this.connectedLabel,
    required this.reconnectingLabel,
    required this.failedLabel,
    required this.connectingLabel,
    required this.disconnectedLabel,
  });

  final RealtimeConnectionState state;
  final String connectedLabel;
  final String reconnectingLabel;
  final String failedLabel;
  final String connectingLabel;
  final String disconnectedLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final accentColor = switch (state.status) {
      RealtimeConnectionStatus.connected => tokens.success,
      RealtimeConnectionStatus.failed => tokens.danger,
      RealtimeConnectionStatus.reconnecting => tokens.warning,
      RealtimeConnectionStatus.connecting => tokens.warning,
      RealtimeConnectionStatus.disconnected => tokens.warning,
    };
    final backgroundColor = switch (state.status) {
      RealtimeConnectionStatus.connected => tokens.successMuted,
      RealtimeConnectionStatus.failed => tokens.dangerMuted,
      RealtimeConnectionStatus.reconnecting => tokens.warningMuted,
      RealtimeConnectionStatus.connecting => tokens.warningMuted,
      RealtimeConnectionStatus.disconnected => tokens.warningMuted,
    };
    final icon = switch (state.status) {
      RealtimeConnectionStatus.connected => Icons.check_circle_outline,
      RealtimeConnectionStatus.failed => Icons.portable_wifi_off_rounded,
      RealtimeConnectionStatus.reconnecting => Icons.sync_problem_rounded,
      RealtimeConnectionStatus.connecting => Icons.sync_rounded,
      RealtimeConnectionStatus.disconnected =>
        Icons.pause_circle_outline_rounded,
    };
    final label = switch (state.status) {
      RealtimeConnectionStatus.connected => connectedLabel,
      RealtimeConnectionStatus.reconnecting => reconnectingLabel,
      RealtimeConnectionStatus.failed => failedLabel,
      RealtimeConnectionStatus.connecting => connectingLabel,
      RealtimeConnectionStatus.disconnected => disconnectedLabel,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: accentColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
