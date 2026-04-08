import 'package:flutter/material.dart';
import '../l10n/context_l10n.dart';
import '../theme/sdal_theme_tokens.dart';

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.canvas, tokens.panelRaised, tokens.accentMuted],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: tokens.panelBorder.withValues(alpha: 0.9),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.foreground.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(29.5),
                    child: Image.asset('icon.png', width: 180, height: 180),
                  ),
                ),
                const SizedBox(height: 18),
                CircularProgressIndicator(color: tokens.accent),
                const SizedBox(height: 18),
                Text(
                  context.l10n.splashPreparing,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: tokens.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusScaffold extends StatelessWidget {
  const StatusScaffold({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(message),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
