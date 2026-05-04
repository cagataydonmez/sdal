import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../../networking/data/networking_repository.dart';
import '../../opportunities/data/opportunities_repository.dart';
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
  final Map<int, bool> _followOverrides = <int, bool>{};
  final Set<int> _followingInFlightIds = <int>{};

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
      child: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            PageOnboardingCard(
              id: 'explore-main',
              icon: Icons.explore_outlined,
              title: 'Keşfet’i değerli yapan şey bağlantı bağlamı.',
              message:
                  'Yeni üyeleri, önerilen kişileri ve fırsat akışını birlikte oku. Birini takip etmek, sonra yeniden bulmanı kolaylaştırır.',
            ),
            const SizedBox(height: 20),
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
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return SizedBox(
                            width: 260,
                            child: _MemberCard(
                              member: item,
                              compact: false,
                              isFollowed: _isMemberFollowed(item),
                              followInFlight: _followingInFlightIds.contains(
                                item.id,
                              ),
                              onTap: () => context.push('/members/${item.id}'),
                              imageUrl: config
                                  .resolveUrl(item.photo)
                                  .toString(),
                              onFollow: () => _toggleFollowMember(item),
                              onViewMap: _isTeacherMember(item.graduationYear)
                                  ? () => context.push('/network/teachers/${item.id}/map')
                                  : null,
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
                                      isFollowed: _isMemberFollowed(item),
                                      followInFlight: _followingInFlightIds
                                          .contains(item.id),
                                      onTap: () =>
                                          context.push('/members/${item.id}'),
                                      imageUrl: config
                                          .resolveUrl(item.photo)
                                          .toString(),
                                      onFollow: () => _toggleFollowMember(item),
                                      onViewMap: _isTeacherMember(item.graduationYear)
                                          ? () => context.push('/network/teachers/${item.id}/map')
                                          : null,
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
                                    isFollowed: _isMemberFollowed(item),
                                    followInFlight: _followingInFlightIds
                                        .contains(item.id),
                                    onTap: () =>
                                        context.push('/members/${item.id}'),
                                    imageUrl: config
                                        .resolveUrl(item.photo)
                                        .toString(),
                                    onFollow: () => _toggleFollowMember(item),
                                    onViewMap: _isTeacherMember(item.graduationYear)
                                        ? () => context.push('/network/teachers/${item.id}/map')
                                        : null,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
              },
            ),
            const SizedBox(height: 20),
            const _ExploreOpportunitySection(),
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
                        isFollowed: _isMemberFollowed(member),
                        followInFlight: _followingInFlightIds.contains(
                          member.id,
                        ),
                        onTap: () => context.push('/members/${member.id}'),
                        imageUrl: config.resolveUrl(member.photo).toString(),
                        onFollow: () => _toggleFollowMember(member),
                        onViewMap: _isTeacherMember(member.graduationYear)
                            ? () => context.push('/network/teachers/${member.id}/map')
                            : null,
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

  Future<void> _toggleFollowMember(MemberSummary member) async {
    final memberId = member.id;
    if (_followingInFlightIds.contains(memberId)) {
      return;
    }
    final currentFollowing = _isMemberFollowed(member);
    setState(() => _followingInFlightIds.add(memberId));
    final result = await ref.read(exploreRepositoryProvider).follow(memberId);
    if (!mounted) return;
    final payload = asJsonMap(result.rawData);
    final nextFollowing = asBool(payload['following']) ?? !currentFollowing;
    setState(() {
      _followingInFlightIds.remove(memberId);
      if (result.ok) {
        _followOverrides[memberId] = nextFollowing;
      }
    });
    if (result.ok) {
      ref.invalidate(latestMembersProvider);
      ref.invalidate(suggestionMembersProvider);
      ref.invalidate(directoryMembersProvider(_directoryQuery));
      return;
    }
    final message = result.message.isNotEmpty
        ? result.message
        : context.l10n.actionFailedGeneric;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isMemberFollowed(MemberSummary member) {
    return _followOverrides[member.id] ?? member.following;
  }

  Future<void> _refreshPage() async {
    setState(_followOverrides.clear);
    ref.invalidate(latestMembersProvider);
    ref.invalidate(suggestionMembersProvider);
    ref.invalidate(directoryMembersProvider(_directoryQuery));
    await Future.wait([
      ref.read(latestMembersProvider.future),
      ref.read(suggestionMembersProvider.future),
      ref.read(directoryMembersProvider(_directoryQuery).future),
    ]);
  }
}

class _ExploreOpportunitySection extends ConsumerStatefulWidget {
  const _ExploreOpportunitySection();

  @override
  ConsumerState<_ExploreOpportunitySection> createState() =>
      _ExploreOpportunitySectionState();
}

class _ExploreOpportunitySectionState
    extends ConsumerState<_ExploreOpportunitySection> {
  final List<OpportunityItem> _items = <OpportunityItem>[];
  final Map<int, bool> _followOverrides = <int, bool>{};
  final Set<int> _followingInFlightIds = <int>{};
  String _activeTab = 'all';
  String _cursor = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.opportunitiesTitle,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.exploreOpportunitySectionTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.exploreOpportunitySectionDescription,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(label: Text('${_items.length}')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tab in <(String, String)>[
                ('all', l10n.opportunitiesTabAll),
                ('now', l10n.opportunitiesTabNow),
                ('networking', l10n.opportunitiesTabNetworking),
                ('jobs', l10n.opportunitiesTabJobs),
                ('updates', l10n.opportunitiesTabUpdates),
              ])
                ChoiceChip(
                  label: Text(tab.$2),
                  selected: _activeTab == tab.$1,
                  onSelected: (_) {
                    if (_activeTab == tab.$1) return;
                    setState(() => _activeTab = tab.$1);
                    _load(reset: true);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            ErrorView(compact: true, kind: ErrorViewKind.network)
          else if (_items.isEmpty)
            EmptyStateView(
              icon: Icons.auto_awesome_outlined,
              title: l10n.opportunitiesEmptyTitle,
              message: l10n.opportunitiesEmptyDescription,
              actionLabel: _activeTab == 'jobs'
                  ? l10n.jobsTitle
                  : _activeTab == 'updates'
                  ? l10n.notificationsTitle
                  : l10n.networkingTitle,
              onAction: () {
                if (_activeTab == 'jobs') {
                  context.push('/jobs');
                  return;
                }
                if (_activeTab == 'updates') {
                  context.push('/notifications');
                  return;
                }
                context.push('/network/hub');
              },
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 880;
                final cardWidth = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in _items)
                      SizedBox(
                        width: cardWidth,
                        child: _OpportunityCard(
                          item: item,
                          isFollowed: _isMemberFollowed(item),
                          followInFlight: _followingInFlightIds.contains(
                            item.memberId,
                          ),
                          onOpenMember: item.memberId > 0
                              ? () => context.push('/members/${item.memberId}')
                              : null,
                          onFollow: item.isMemberSuggestion
                              ? () => _toggleFollowSuggestion(item)
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          if (_hasMore) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: _isLoadingMore ? null : () => _load(reset: false),
                child: Text(
                  _isLoadingMore
                      ? l10n.opportunitiesLoading
                      : l10n.opportunitiesLoadMoreAction,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = '';
        _cursor = '';
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final page = await ref
          .read(opportunitiesRepositoryProvider)
          .fetchOpportunityInbox(tab: _activeTab, cursor: reset ? '' : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  bool _isMemberFollowed(OpportunityItem item) {
    return _followOverrides[item.memberId] ?? item.memberFollowing;
  }

  Future<void> _toggleFollowSuggestion(OpportunityItem item) async {
    if (!item.isMemberSuggestion ||
        _followingInFlightIds.contains(item.memberId)) {
      return;
    }

    final currentFollowing = _isMemberFollowed(item);
    setState(() => _followingInFlightIds.add(item.memberId));
    final result = await ref
        .read(exploreRepositoryProvider)
        .follow(item.memberId);
    if (!mounted) return;

    final payload = asJsonMap(result.rawData);
    final nextFollowing = asBool(payload['following']) ?? !currentFollowing;
    setState(() {
      _followingInFlightIds.remove(item.memberId);
      if (result.ok) {
        _followOverrides[item.memberId] = nextFollowing;
      }
    });

    final message = result.message.isNotEmpty
        ? result.message
        : (result.ok
              ? (nextFollowing ? 'Takip edildi.' : 'Takip bırakıldı.')
              : context.l10n.actionFailedGeneric);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.item,
    required this.isFollowed,
    required this.followInFlight,
    this.onOpenMember,
    this.onFollow,
  });

  final OpportunityItem item;
  final bool isFollowed;
  final bool followInFlight;
  final VoidCallback? onOpenMember;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).textTheme.bodySmall;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_priorityLabel(context, item.priorityBucket))),
              Chip(label: Text(_categoryLabel(context, item.category))),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          if (item.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.summary),
          ],
          if (item.whyNow.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.whyNow, style: muted),
          ],
          if (item.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.reasons
                  .map((reason) => Chip(label: Text(reason)))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          if (item.isMemberSuggestion && onOpenMember != null) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonal(
                  onPressed: onOpenMember,
                  child: Text(
                    item.targetLabel.isNotEmpty
                        ? item.targetLabel
                        : l10n.openAction,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: followInFlight ? null : onFollow,
                  icon: followInFlight
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isFollowed
                              ? Icons.person_remove_alt_1_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                  label: Text(
                    followInFlight
                        ? l10n.submitInProgress
                        : isFollowed
                        ? l10n.unfollowAction
                        : l10n.followAction,
                  ),
                ),
              ],
            ),
          ] else if (item.targetHref.isNotEmpty) ...[
            SelectableText(item.targetHref),
          ],
        ],
      ),
    );
  }
}

String _priorityLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  switch (value.trim().toLowerCase()) {
    case 'now':
      return l10n.opportunitiesPriorityNow;
    case 'soon':
      return l10n.opportunitiesPrioritySoon;
    default:
      return l10n.opportunitiesPriorityFollow;
  }
}

String _categoryLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  switch (value.trim().toLowerCase()) {
    case 'jobs':
      return l10n.opportunitiesCategoryJob;
    case 'networking':
      return l10n.opportunitiesCategoryNetworking;
    default:
      return l10n.opportunitiesCategoryUpdate;
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
    required this.isFollowed,
    required this.followInFlight,
    this.onViewMap,
  });

  final MemberSummary member;
  final VoidCallback onTap;
  final String imageUrl;
  final Future<void> Function() onFollow;
  final bool compact;
  final bool isFollowed;
  final bool followInFlight;
  final VoidCallback? onViewMap;

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
                if (member.verified ||
                    member.role.trim().toLowerCase() != 'user') ...[
                  const SizedBox(height: 8),
                  MemberBadgeStrip(
                    verified: member.verified,
                    role: member.role,
                    graduationYear: member.graduationYear,
                    compact: true,
                  ),
                ],
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
                    _formatGraduationYear(context, l10n, member.graduationYear),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: followInFlight
                      ? null
                      : () async {
                          await onFollow();
                        },
                  icon: followInFlight
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isFollowed
                              ? Icons.person_remove_alt_1_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                  label: Text(
                    followInFlight
                        ? l10n.submitInProgress
                        : isFollowed
                        ? l10n.unfollowAction
                        : l10n.followAction,
                  ),
                ),
                if (onViewMap != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onViewMap,
                      icon: const Icon(Icons.hub_outlined, size: 16),
                      label: const Text('Ağ haritasını gör'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isTeacherMember(String graduationYear) {
  final normalized = graduationYear.trim().toLowerCase();
  return normalized == '9999' ||
      normalized == 'teacher' ||
      normalized == 'ogretmen' ||
      normalized == 'öğretmen';
}

String _formatGraduationYear(BuildContext context, dynamic l10n, String value) {
  final isTeacher = _isTeacherMember(value);
  if (isTeacher) {
    return Localizations.localeOf(context).languageCode == 'tr'
        ? 'Öğretmen'
        : 'Teacher';
  }
  return l10n.memberGraduationYearValue(value);
}
