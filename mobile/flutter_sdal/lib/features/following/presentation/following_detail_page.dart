import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/following_detail_repository.dart';

class FollowingDetailPage extends ConsumerWidget {
  const FollowingDetailPage({
    super.key,
    required this.memberId,
    required this.sectionKey,
  });

  final int memberId;
  final String sectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section =
        FollowingDetailSection.fromKey(sectionKey) ??
        FollowingDetailSection.following;
    final detailState = ref.watch(
      followingDetailSectionProvider((
        memberId: memberId,
        sectionKey: section.key,
      )),
    );
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: section.label,
      child: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SurfaceCard(
              child: ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(
                  followingDetailSectionProvider((
                    memberId: memberId,
                    sectionKey: section.key,
                  )),
                ),
                kind: ErrorViewKind.network,
              ),
            ),
          ),
        ),
        data: (detail) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                followingDetailSectionProvider((
                  memberId: memberId,
                  sectionKey: section.key,
                )),
              );
              await ref.read(
                followingDetailSectionProvider((
                  memberId: memberId,
                  sectionKey: section.key,
                )).future,
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                SurfaceCard(
                  child: Row(
                    children: [
                      RemoteAvatar(
                        label: detail.member.name,
                        imageUrl: config
                            .resolveUrl(detail.member.photo)
                            .toString(),
                        radius: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.member.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (detail.member.handle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '@${detail.member.handle}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (detail.member.verified ||
                                detail.member.role.trim().toLowerCase() !=
                                    'user') ...[
                              const SizedBox(height: 6),
                              MemberBadgeStrip(
                                verified: detail.member.verified,
                                role: detail.member.role,
                                graduationYear: detail.member.graduationYear,
                                compact: true,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              detail.title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).sdal.foregroundMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (detail.items.isEmpty)
                  SurfaceCard(
                    child: Text(
                      'Bu bölüm için gösterilecek kayıt bulunmuyor.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else if (section.key == FollowingDetailSection.photos.key)
                  _PhotoGrid(items: detail.items)
                else
                  ...detail.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DetailListCard(item: item),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailListCard extends ConsumerWidget {
  const _DetailListCard({required this.item});

  final FollowingDetailItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;

    return SurfaceCard(
      onTap: item.hasRoute ? () => context.push(item.route) : null,
      tooltip: item.hasRoute ? 'Detayı aç' : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 56,
                height: 56,
                child: SdalNetworkImage(
                  imageUrl: config.resolveUrl(item.image).toString(),
                  borderRadius: BorderRadius.circular(16),
                  enableLightbox: false,
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tokens.panelMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.list_alt_rounded,
                color: tokens.foregroundMuted,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (item.meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.meta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.foregroundMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.hasRoute)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                color: tokens.foregroundMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.items});

  final List<FollowingDetailItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720
            ? 3
            : constraints.maxWidth > 480
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((item) {
                return SizedBox(
                  width: width,
                  child: SurfaceCard(
                    onTap: item.hasRoute
                        ? () => context.push(item.route)
                        : null,
                    tooltip: item.hasRoute ? 'Fotoğrafı aç' : null,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.2,
                          child: SdalNetworkImage(
                            imageUrl: config.siteBaseUri
                                .resolve(_thumbPath(item.image))
                                .toString(),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            semanticLabel: item.title,
                            enableLightbox: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (item.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (item.meta.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.meta,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

String _thumbPath(String fileName) =>
    '/api/media/kucukresim?width=480&file=${Uri.encodeComponent(fileName)}';
