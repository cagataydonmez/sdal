import 'package:flutter/material.dart';
import '../theme/sdal_theme_tokens.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 44 : 60,
              height: compact ? 44 : 60,
              decoration: BoxDecoration(
                color: tokens.accentMuted,
                borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
              ),
              child: Icon(
                icon,
                size: compact ? 20 : 28,
                color: tokens.accent,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              title,
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleSmall
                          : Theme.of(context).textTheme.titleMedium)
                      ?.copyWith(color: tokens.foreground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 12 : 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
