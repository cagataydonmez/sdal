import 'package:flutter/material.dart';

import '../onboarding/onboarding_hint_store.dart';
import '../theme/sdal_theme_tokens.dart';
import 'surface_card.dart';

class PageOnboardingCard extends StatefulWidget {
  const PageOnboardingCard({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String id;
  final IconData icon;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  State<PageOnboardingCard> createState() => _PageOnboardingCardState();
}

class _PageOnboardingCardState extends State<PageOnboardingCard> {
  bool _loading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final store = await OnboardingHintStore.create();
    final dismissed = await store.isDismissed(widget.id);
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final store = await OnboardingHintStore.create();
    await store.dismiss(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed) return const SizedBox.shrink();

    final tokens = Theme.of(context).sdal;
    final primaryActionLabel = widget.primaryActionLabel;
    final secondaryActionLabel = widget.secondaryActionLabel;

    return SurfaceCard(
      color: tokens.infoMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.panel.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
                ),
                child: Icon(widget.icon, color: tokens.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bu ipucunu kapat',
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if ((primaryActionLabel != null && widget.onPrimaryAction != null) ||
              (secondaryActionLabel != null &&
                  widget.onSecondaryAction != null)) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (primaryActionLabel != null &&
                    widget.onPrimaryAction != null)
                  FilledButton.tonalIcon(
                    onPressed: widget.onPrimaryAction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(primaryActionLabel),
                  ),
                if (secondaryActionLabel != null &&
                    widget.onSecondaryAction != null)
                  TextButton(
                    onPressed: widget.onSecondaryAction,
                    child: Text(secondaryActionLabel),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
