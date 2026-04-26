import 'package:flutter/material.dart';
import '../theme/sdal_theme_tokens.dart';

class MemberBadgeStrip extends StatelessWidget {
  const MemberBadgeStrip({
    super.key,
    required this.verified,
    this.role = '',
    this.graduationYear = '',
    this.compact = false,
  });

  final bool verified;
  final String role;
  final String graduationYear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badges = memberBadgesFor(
      verified: verified,
      role: role,
      graduationYear: graduationYear,
    );
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      children: [
        for (final badge in badges)
          _MemberBadgePill(badge: badge, compact: compact),
      ],
    );
  }
}

List<MemberBadge> memberBadgesFor({
  required bool verified,
  String role = '',
  String graduationYear = '',
}) {
  final normalizedRole = role.trim().toLowerCase();
  final isAdmin = normalizedRole == 'root' || normalizedRole == 'admin';
  final isMod = normalizedRole == 'mod';
  final isTeacher =
      isTeacherCohort(graduationYear) || normalizedRole == 'teacher';
  return <MemberBadge>[
    if (isAdmin) MemberBadge.admin,
    if (isMod) MemberBadge.moderator,
    if (verified && isTeacher) MemberBadge.verifiedTeacher,
    if (verified && !isTeacher) MemberBadge.verifiedMember,
  ];
}

bool isTeacherCohort(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == '9999' ||
      normalized == 'teacher' ||
      normalized == 'ogretmen' ||
      normalized == 'öğretmen';
}

enum MemberBadge { verifiedMember, verifiedTeacher, moderator, admin }

class _MemberBadgePill extends StatelessWidget {
  const _MemberBadgePill({required this.badge, required this.compact});

  final MemberBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final spec = switch (badge) {
      MemberBadge.admin => _BadgeSpec(
        icon: Icons.admin_panel_settings_rounded,
        label: 'Admin',
        foreground: tokens.danger,
        background: tokens.dangerMuted,
      ),
      MemberBadge.moderator => _BadgeSpec(
        icon: Icons.gavel_rounded,
        label: 'Mod',
        foreground: tokens.warning,
        background: tokens.warningMuted,
      ),
      MemberBadge.verifiedTeacher => _BadgeSpec(
        icon: Icons.school_rounded,
        label: 'Doğrulanmış öğretmen',
        foreground: tokens.info,
        background: tokens.infoMuted,
      ),
      MemberBadge.verifiedMember => _BadgeSpec(
        icon: Icons.verified_rounded,
        label: 'Doğrulanmış üye',
        foreground: tokens.success,
        background: tokens.successMuted,
      ),
    };
    return Tooltip(
      message: spec.label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: spec.foreground.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: compact ? 13 : 15, color: spec.foreground),
            if (!compact || badge == MemberBadge.verifiedTeacher) ...[
              SizedBox(width: compact ? 4 : 5),
              Text(
                compact && badge == MemberBadge.verifiedTeacher
                    ? 'Öğretmen'
                    : spec.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: spec.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeSpec {
  const _BadgeSpec({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
}
