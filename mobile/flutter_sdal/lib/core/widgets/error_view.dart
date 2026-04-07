import 'package:flutter/material.dart';
import '../theme/sdal_theme_tokens.dart';

/// A friendly, on-brand error state. Never shows raw exception strings.
/// Provides a retry button when [onRetry] is supplied.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  final String? message;
  final VoidCallback? onRetry;

  /// When true, renders a smaller inline version without full padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
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
          child: Icon(
            Icons.wifi_off_rounded,
            size: compact ? 20 : 28,
            color: tokens.danger,
          ),
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          message != null && message!.isNotEmpty && !message!.startsWith('Exception')
              ? message!
              : 'Bir şeyler ters gitti.',
          style: (compact
                  ? Theme.of(context).textTheme.bodyMedium
                  : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(color: tokens.foreground),
          textAlign: TextAlign.center,
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            'Lütfen bağlantını kontrol et ve tekrar dene.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.foregroundMuted),
            textAlign: TextAlign.center,
          ),
        ],
        if (onRetry != null) ...[
          SizedBox(height: compact ? 12 : 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
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
