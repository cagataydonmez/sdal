import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/skeleton_view.dart';
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
  final _queryController = TextEditingController();
  final _yearController = TextEditingController();
  final _cityController = TextEditingController();
  DirectoryMembersQuery _directoryQuery = const DirectoryMembersQuery();

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
  void dispose() {
    _queryController.dispose();
    _yearController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestState = ref.watch(latestMembersProvider);
    final suggestionsState = ref.watch(suggestionMembersProvider);
    final directoryState = ref.watch(directoryMembersProvider(_directoryQuery));
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.exploreTitle,
      background: FeatureScaffoldBackground.editorial,
      actions: [
        IconButton(
          tooltip: l10n.refreshAction,
          onPressed: () {
            ref.invalidate(latestMembersProvider);
            ref.invalidate(suggestionMembersProvider);
            ref.invalidate(directoryMembersProvider(_directoryQuery));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.exploreLatestMembersTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          latestState.when(
            loading: () => const _ExploreCarouselSkeleton(),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
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
            loading: () => const _ExploreGridSkeleton(),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (items) {
              _trackExploreSuggestions(items);
              return items.isEmpty
                  ? SurfaceCard(
                      child: EmptyStateView(
                        icon: Icons.person_search_outlined,
                        title: l10n.exploreSuggestionsEmptyTitle,
                        message: l10n.exploreSuggestionsEmptyMessage,
                        actionLabel: l10n.refreshAction,
                        onAction: () {
                          ref.invalidate(latestMembersProvider);
                          ref.invalidate(suggestionMembersProvider);
                        },
                      ),
                    )
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
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.exploreDirectoryFiltersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    labelText: l10n.exploreSearchLabel,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.exploreGraduationYearLabel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: l10n.profileEditCityLabel,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _directoryQuery = DirectoryMembersQuery(
                            query: _queryController.text.trim(),
                            year: _yearController.text.trim(),
                            city: _cityController.text.trim(),
                            page: 1,
                          );
                        });
                      },
                      child: Text(l10n.exploreApplyFiltersAction),
                    ),
                    TextButton(
                      onPressed: () {
                        _queryController.clear();
                        _yearController.clear();
                        _cityController.clear();
                        setState(() {
                          _directoryQuery = const DirectoryMembersQuery();
                        });
                      },
                      child: Text(l10n.exploreClearFiltersAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          directoryState.when(
            loading: () => const _ExploreDirectorySkeleton(),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (items) => Column(
              children: [
                ...items.map(
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
                        ref.invalidate(
                          directoryMembersProvider(_directoryQuery),
                        );
                      },
                    ),
                  ),
                ),
                if (items.isNotEmpty)
                  Row(
                    children: [
                      TextButton(
                        onPressed: _directoryQuery.page > 1
                            ? () => setState(() {
                                _directoryQuery = DirectoryMembersQuery(
                                  query: _directoryQuery.query,
                                  year: _directoryQuery.year,
                                  city: _directoryQuery.city,
                                  page: _directoryQuery.page - 1,
                                );
                              })
                            : null,
                        child: Text(l10n.previousAction),
                      ),
                      const Spacer(),
                      Text(l10n.explorePageLabel(_directoryQuery.page)),
                      const Spacer(),
                      TextButton(
                        onPressed: items.length >= 20
                            ? () => setState(() {
                                _directoryQuery = DirectoryMembersQuery(
                                  query: _directoryQuery.query,
                                  year: _directoryQuery.year,
                                  city: _directoryQuery.city,
                                  page: _directoryQuery.page + 1,
                                );
                              })
                            : null,
                        child: Text(l10n.nextAction),
                      ),
                    ],
                  ),
              ],
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

class _ExploreCarouselSkeleton extends StatelessWidget {
  const _ExploreCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => const SizedBox(
          width: 260,
          child: _MemberCardSkeleton(compact: false),
        ),
      ),
    );
  }
}

class _ExploreGridSkeleton extends StatelessWidget {
  const _ExploreGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return const _ExploreCarouselSkeleton();
        }
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            4,
            (_) => SizedBox(
              width: cardWidth,
              child: const _MemberCardSkeleton(compact: false),
            ),
          ),
        );
      },
    );
  }
}

class _ExploreDirectorySkeleton extends StatelessWidget {
  const _ExploreDirectorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _MemberCardSkeleton(compact: true),
        SizedBox(height: 12),
        _MemberCardSkeleton(compact: true),
        SizedBox(height: 12),
        _MemberCardSkeleton(compact: true),
      ],
    );
  }
}

class _MemberCardSkeleton extends StatelessWidget {
  const _MemberCardSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(
                height: compact ? 48 : 56,
                width: compact ? 48 : 56,
                shape: BoxShape.circle,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SkeletonLines(
                  widthFactors: [0.62, 0.36],
                  lineHeight: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonLines(widthFactors: [0.48, 0.72, 0.38]),
          const SizedBox(height: 12),
          const SkeletonBox(width: 110, height: 40),
        ],
      ),
    );
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
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.openMemberProfileForName(member.name),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: l10n.openMemberProfileForName(member.name),
          child: SurfaceCard(
            semanticContainer: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RemoteAvatar(
                      label: member.name,
                      imageUrl: imageUrl,
                      radius: compact ? 24 : 28,
                      excludeFromSemantics: true,
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
                    l10n.memberGraduationYearValue(member.graduationYear),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onFollow,
                  child: Text(l10n.followAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
