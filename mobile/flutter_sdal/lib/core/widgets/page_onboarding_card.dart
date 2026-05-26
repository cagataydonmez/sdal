import 'package:flutter/material.dart';

import '../onboarding/onboarding_hint_store.dart';
import '../theme/sdal_theme_tokens.dart';

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
  bool _dialogScheduled = false;
  bool _dialogOpen = false;

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
    if (!dismissed) _scheduleDialog();
  }

  Future<void> _dismiss() async {
    if (mounted) setState(() => _dismissed = true);
    final store = await OnboardingHintStore.create();
    await store.dismiss(widget.id);
  }

  void _scheduleDialog() {
    if (_dialogScheduled || _dialogOpen || _dismissed) return;
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dismissed || _dialogOpen) return;
      _showOnboardingDialog();
    });
  }

  Future<void> _showOnboardingDialog() async {
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: _PageOnboardingDialog(
          icon: widget.icon,
          title: widget.title,
          message: widget.message,
          primaryActionLabel: widget.primaryActionLabel,
          secondaryActionLabel: widget.secondaryActionLabel,
          onDone: () async {
            await _dismiss();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          onPrimaryAction: widget.onPrimaryAction == null
              ? null
              : () async {
                  await _dismiss();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  widget.onPrimaryAction?.call();
                },
          onSecondaryAction: widget.onSecondaryAction == null
              ? null
              : () async {
                  await _dismiss();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  widget.onSecondaryAction?.call();
                },
        ),
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_dismissed) _scheduleDialog();
    return const SizedBox.shrink();
  }
}

class _PageOnboardingDialog extends StatelessWidget {
  const _PageOnboardingDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.onDone,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
            border: Border.all(color: tokens.panelBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tokens.infoMuted,
                        borderRadius: BorderRadius.circular(
                          SdalThemeTokens.radiusMd,
                        ),
                      ),
                      child: Icon(icon, color: tokens.info),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: tokens.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    if (secondaryActionLabel != null &&
                        onSecondaryAction != null)
                      TextButton(
                        onPressed: onSecondaryAction,
                        child: Text(secondaryActionLabel!),
                      ),
                    if (primaryActionLabel != null && onPrimaryAction != null)
                      FilledButton.tonalIcon(
                        onPressed: onPrimaryAction,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(primaryActionLabel!),
                      ),
                    FilledButton(onPressed: onDone, child: const Text('Tamam')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
