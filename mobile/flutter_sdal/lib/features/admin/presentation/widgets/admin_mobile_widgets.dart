import 'package:flutter/material.dart';

import '../../../../core/theme/sdal_theme_tokens.dart';

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
    this.tone = AdminTone.info,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final colors = AdminToneColors.from(context, tone);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(tokens.cardRadius * .7),
                ),
                child: Icon(icon, color: colors.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.foregroundMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                AdminStatusChip(label: badge!, tone: tone),
              ],
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, color: tokens.foregroundMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminAttentionCard extends StatelessWidget {
  const AdminAttentionCard({
    super.key,
    required this.label,
    required this.count,
    required this.onTap,
    this.tone = AdminTone.warning,
  });

  final String label;
  final int count;
  final VoidCallback onTap;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AdminToneColors.from(context, tone);
    final tokens = Theme.of(context).sdal;
    return Card(
      color: colors.muted,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward, color: colors.foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({
    super.key,
    required this.label,
    this.tone = AdminTone.info,
  });

  final String label;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AdminToneColors.from(context, tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 38, color: tokens.foregroundMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

enum AdminTone { info, success, warning, danger, accent }

class AdminToneColors {
  const AdminToneColors({required this.foreground, required this.muted});

  final Color foreground;
  final Color muted;

  factory AdminToneColors.from(BuildContext context, AdminTone tone) {
    final tokens = Theme.of(context).sdal;
    return switch (tone) {
      AdminTone.info => AdminToneColors(
        foreground: tokens.info,
        muted: tokens.infoMuted,
      ),
      AdminTone.success => AdminToneColors(
        foreground: tokens.success,
        muted: tokens.successMuted,
      ),
      AdminTone.warning => AdminToneColors(
        foreground: tokens.warning,
        muted: tokens.warningMuted,
      ),
      AdminTone.danger => AdminToneColors(
        foreground: tokens.danger,
        muted: tokens.dangerMuted,
      ),
      AdminTone.accent => AdminToneColors(
        foreground: tokens.accent,
        muted: tokens.accentMuted,
      ),
    };
  }
}

AdminTone adminToneFromString(String value) {
  return switch (value.trim().toLowerCase()) {
    'success' => AdminTone.success,
    'warning' => AdminTone.warning,
    'danger' => AdminTone.danger,
    'accent' => AdminTone.accent,
    _ => AdminTone.info,
  };
}
