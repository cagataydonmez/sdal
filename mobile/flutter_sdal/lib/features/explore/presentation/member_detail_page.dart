import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/shell/shell_metadata_repository.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../following/application/following_action_controller.dart';
import '../../stories/presentation/stories_rail.dart';
import '../data/explore_repository.dart';

class MemberDetailPage extends ConsumerWidget {
  const MemberDetailPage({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(memberDetailProvider(memberId));
    final followActionState = ref.watch(followingActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final quickAccess = ref.watch(quickAccessUsersProvider).value;
    final isPinned = (quickAccess ?? const <QuickAccessUser>[]).any(
      (item) => item.id == memberId,
    );
    final isSelf = session?.user?.id == memberId;
    final tokens = Theme.of(context).sdal;

    return FeatureScaffold(
      title: 'Üye detayı',
      child: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 48,
                  color: tokens.foregroundMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'Üye bilgileri yüklenemedi.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        data: (detail) {
          if (detail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      size: 48,
                      color: tokens.foregroundMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Üye bulunamadı.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          final followScope = 'follow:$memberId';
          final followInFlight =
              followActionState.isLoading &&
              followActionState.scope == followScope;
          final isFollowing = detail.summary.following;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              // ── Hero card ─────────────────────────────────────
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accent header strip with large avatar
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.accentMuted,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RemoteAvatar(
                            label: detail.summary.name,
                            imageUrl: config
                                .resolveUrl(detail.summary.photo)
                                .toString(),
                            radius: 44,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.summary.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: tokens.foreground),
                                ),
                                if (detail.summary.handle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${detail.summary.handle}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: tokens.foregroundMuted,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Key facts
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Graduation year – always most prominent
                          if (detail.graduationYear.isNotEmpty)
                            _HighlightChip(
                              icon: Icons.school_outlined,
                              label: '${detail.graduationYear} mezunu',
                              color: tokens.accent,
                              bgColor: tokens.accentMuted,
                            ),
                          if (detail.graduationYear.isNotEmpty)
                            const SizedBox(height: 10),
                          // Job title + company on one line
                          if (detail.title.isNotEmpty ||
                              detail.company.isNotEmpty) ...[
                            _HighlightChip(
                              icon: Icons.work_outline,
                              label: [
                                detail.title,
                                detail.company,
                              ].where((s) => s.isNotEmpty).join(', '),
                              color: tokens.info,
                              bgColor: tokens.infoMuted,
                            ),
                            const SizedBox(height: 10),
                          ],
                          // Profession / university / expertise
                          if (detail.summary.profession.isNotEmpty) ...[
                            _HighlightChip(
                              icon: Icons.person_outline,
                              label: detail.summary.profession,
                              color: tokens.foreground,
                              bgColor: tokens.panelMuted,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (detail.expertise.isNotEmpty)
                            _HighlightChip(
                              icon: Icons.auto_awesome_outlined,
                              label: detail.expertise,
                              color: tokens.foreground,
                              bgColor: tokens.panelMuted,
                            ),
                          // Follow + pin actions
                          if (!isSelf) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: followInFlight
                                  ? null
                                  : () async {
                                      final following = await ref
                                          .read(
                                            followingActionControllerProvider
                                                .notifier,
                                          )
                                          .toggleFollow(memberId);
                                      if (!context.mounted) return;
                                      final actionState = ref.read(
                                        followingActionControllerProvider,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            actionState.message ??
                                                (following == null
                                                    ? context
                                                          .l10n
                                                          .actionFailedGeneric
                                                    : following
                                                    ? 'Takip edildi.'
                                                    : 'Takip bırakıldı.'),
                                          ),
                                        ),
                                      );
                                      if (following == null) return;
                                      ref.invalidate(
                                        memberDetailProvider(memberId),
                                      );
                                      ref.invalidate(latestMembersProvider);
                                      ref.invalidate(suggestionMembersProvider);
                                    },
                              icon: followInFlight
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isFollowing
                                          ? Icons.person_remove_alt_1_rounded
                                          : Icons.person_add_alt_1_rounded,
                                    ),
                              label: Text(
                                followInFlight
                                    ? context.l10n.submitInProgress
                                    : isFollowing
                                    ? context.l10n.unfollowAction
                                    : context.l10n.followAction,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final repository = ref.read(
                                  shellMetadataRepositoryProvider,
                                );
                                final result = isPinned
                                    ? await repository.removeQuickAccessUser(
                                        memberId,
                                      )
                                    : await repository.addQuickAccessUser(
                                        memberId,
                                      );
                                ref.invalidate(quickAccessUsersProvider);
                                if (!context.mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.ok
                                          ? (isPinned
                                                ? 'Hızlı erişimden kaldırıldı.'
                                                : 'Hızlı erişime eklendi.')
                                          : (result.message.isNotEmpty
                                                ? result.message
                                                : 'İşlem tamamlanamadı.'),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                              ),
                              label: Text(
                                isPinned
                                    ? 'Hızlı erişimden kaldır'
                                    : 'Hızlı erişime ekle',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Contact & location details ─────────────────────
              if (detail.summary.city.isNotEmpty ||
                  detail.email.isNotEmpty ||
                  detail.linkedinUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İletişim',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        value: detail.summary.city,
                      ),
                      _InfoRow(icon: Icons.email_outlined, value: detail.email),
                      _InfoRow(icon: Icons.link, value: detail.linkedinUrl),
                    ],
                  ),
                ),
              ],
              // ── Signature ─────────────────────────────────────
              if (detail.signature.isNotEmpty) ...[
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote,
                            size: 18,
                            color: tokens.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'İmza',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        detail.signature,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: tokens.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // ── Stories ───────────────────────────────────────
              const SizedBox(height: 14),
              StoriesRail(
                mode: StoryRailMode.member,
                memberId: memberId,
                title: 'Üyenin hikayeleri',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tokens.foregroundMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
