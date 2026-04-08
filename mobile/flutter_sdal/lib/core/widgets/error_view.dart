import 'package:flutter/material.dart';
import '../l10n/context_l10n.dart';
import '../theme/sdal_theme_tokens.dart';

enum ErrorViewKind { generic, network }

/// A friendly, on-brand error state. Never shows raw exception strings.
/// Provides a retry button when [onRetry] is supplied.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
    this.kind = ErrorViewKind.generic,
    this.actionLabel,
  });

  final String? message;
  final VoidCallback? onRetry;
  final bool compact;
  final ErrorViewKind kind;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final l10n = context.l10n;
    final title =
        message != null &&
            message!.isNotEmpty &&
            !message!.startsWith('Exception')
        ? message!
        : switch (kind) {
            ErrorViewKind.network => l10n.errorNetworkTitle,
            ErrorViewKind.generic => l10n.errorGenericTitle,
          };
    final supportingText = switch (kind) {
      ErrorViewKind.network => l10n.errorNetworkMessage,
      ErrorViewKind.generic => l10n.errorGenericMessage,
    };
    final icon = switch (kind) {
      ErrorViewKind.network => Icons.wifi_off_rounded,
      ErrorViewKind.generic => Icons.error_outline_rounded,
    };
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 40 : 56,
          height: compact ? 40 : 56,
          decoration: BoxDecoration(
            color: tokens.dangerMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: compact ? 20 : 28, color: tokens.danger),
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          title,
          style:
              (compact
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(color: tokens.foreground),
          textAlign: TextAlign.center,
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            supportingText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
            textAlign: TextAlign.center,
          ),
        ],
        if (onRetry != null) ...[
          SizedBox(height: compact ? 12 : 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(actionLabel ?? l10n.retryAction),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: content,
      ),
    );
  }
}
