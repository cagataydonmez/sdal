import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../networking/data/networking_repository.dart';
import '../data/explore_repository.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  String _suggestionTelemetryKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(networkingRepositoryProvider)
            .trackTelemetry(
              const NetworkingTelemetryEvent(
                eventName: 'network_explore_viewed',
                sourceSurface: 'explore_page',
              ),
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final latestState = ref.watch(latestMembersProvider);
    final suggestionsState = ref.watch(suggestionMembersProvider);
    final directoryState = ref.watch(directoryMembersProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.exploreTitle,
      background: FeatureScaffoldBackground.editorial,
      actions: [
        IconButton(
          onPressed: () {
            ref.invalidate(latestMembersProvider);
            ref.invalidate(suggestionMembersProvider);
            ref.invalidate(directoryMembersProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('En Yeni Uyeler', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          latestState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return SizedBox(
                          width: 260,
                          child: _MemberCard(
                            member: item,
                            compact: false,
                            onTap: () => context.push('/members/${item.id}'),
                            imageUrl: config.resolveUrl(item.photo).toString(),
                            onFollow: () async {
                              await ref
                                  .read(exploreRepositoryProvider)
                                  .follow(item.id);
                              ref.invalidate(latestMembersProvider);
                              ref.invalidate(suggestionMembersProvider);
                              ref.invalidate(directoryMembersProvider);
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.exploreSuggestionsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          suggestionsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) {
              _trackExploreSuggestions(items);
              return items.isEmpty
                  ? SurfaceCard(child: Text(l10n.exploreNoSuggestions))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 640;
                        if (compact) {
                          return SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return SizedBox(
                                  width: constraints.maxWidth.clamp(
                                    240.0,
                                    300.0,
                                  ),
                                  child: _MemberCard(
                                    member: item,
                                    compact: false,
                                    onTap: () =>
                                        context.push('/members/${item.id}'),
                                    imageUrl: config
                                        .resolveUrl(item.photo)
                                        .toString(),
                                    onFollow: () async {
                                      await ref
                                          .read(exploreRepositoryProvider)
                                          .follow(item.id);
                                      ref.invalidate(latestMembersProvider);
                                      ref.invalidate(suggestionMembersProvider);
                                      ref.invalidate(directoryMembersProvider);
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final item in items)
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: _MemberCard(
                                  member: item,
                                  compact: false,
                                  onTap: () =>
                                      context.push('/members/${item.id}'),
                                  imageUrl: config
                                      .resolveUrl(item.photo)
                                      .toString(),
                                  onFollow: () async {
                                    await ref
                                        .read(exploreRepositoryProvider)
                                        .follow(item.id);
                                    ref.invalidate(latestMembersProvider);
                                    ref.invalidate(suggestionMembersProvider);
                                    ref.invalidate(directoryMembersProvider);
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    );
            },
          ),
          const SizedBox(height: 20),
          Text(
            l10n.exploreDirectoryTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          directoryState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) => Column(
              children: items
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MemberCard(
                        member: member,
                        compact: true,
                        onTap: () => context.push('/members/${member.id}'),
                        imageUrl: config.resolveUrl(member.photo).toString(),
                        onFollow: () async {
                          await ref
                              .read(exploreRepositoryProvider)
                              .follow(member.id);
                          ref.invalidate(latestMembersProvider);
                          ref.invalidate(directoryMembersProvider);
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  void _trackExploreSuggestions(List<MemberSummary> items) {
    final key = items.map((item) => item.id).join(',');
    if (key.isEmpty || key == _suggestionTelemetryKey) return;
    _suggestionTelemetryKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(networkingRepositoryProvider)
            .trackTelemetry(
              NetworkingTelemetryEvent(
                eventName: 'network_explore_suggestions_loaded',
                sourceSurface: 'explore_page',
                entityType: 'suggestion_batch',
                metadata: {'suggestion_count': items.length},
              ),
            ),
      );
    });
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onTap,
    required this.imageUrl,
    required this.onFollow,
    required this.compact,
  });

  final MemberSummary member;
  final VoidCallback onTap;
  final String imageUrl;
  final Future<void> Function() onFollow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RemoteAvatar(
                  label: member.name,
                  imageUrl: imageUrl,
                  radius: compact ? 24 : 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (member.handle.isNotEmpty)
              Text(
                '@${member.handle}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (member.profession.isNotEmpty || member.city.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  member.profession,
                  member.city,
                ].where((part) => part.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (member.graduationYear.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${member.graduationYear} mezunu',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onFollow,
              child: Text(context.l10n.followAction),
            ),
          ],
        ),
      ),
    );
  }
}
