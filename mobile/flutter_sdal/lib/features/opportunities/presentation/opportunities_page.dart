import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../../explore/data/explore_repository.dart';
import '../data/opportunities_repository.dart';

class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
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
    return FeatureScaffold(
      title: 'Fırsatlar',
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tab in const <(String, String)>[
                  ('all', 'Tümü'),
                  ('now', 'Şimdi'),
                  ('networking', 'Networking'),
                  ('jobs', 'İşler'),
                  ('updates', 'Güncellemeler'),
                ])
                  ChoiceChip(
                    label: Text(tab.$2),
                    selected: _activeTab == tab.$1,
                    onSelected: (_) {
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
              SurfaceCard(child: Text(_error))
            else if (_items.isEmpty)
              const SurfaceCard(child: Text('Şu anda gösterilecek fırsat yok.'))
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(_priorityLabel(item.priorityBucket)),
                            ),
                            Chip(label: Text(_categoryLabel(item.category))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (item.summary.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(item.summary),
                        ],
                        if (item.whyNow.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            item.whyNow,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).sdal.foregroundMuted,
                                ),
                          ),
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
                        if (item.targetHref.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          if (item.isMemberSuggestion) ...[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () =>
                                      context.push('/members/${item.memberId}'),
                                  child: Text(item.targetLabel),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      _followingInFlightIds.contains(
                                        item.memberId,
                                      )
                                      ? null
                                      : () => _toggleFollowSuggestion(item),
                                  icon:
                                      _followingInFlightIds.contains(
                                        item.memberId,
                                      )
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _isMemberFollowed(item)
                                              ? Icons
                                                    .person_remove_alt_1_rounded
                                              : Icons.person_add_alt_1_rounded,
                                        ),
                                  label: Text(
                                    _followingInFlightIds.contains(
                                          item.memberId,
                                        )
                                        ? context.l10n.submitInProgress
                                        : _isMemberFollowed(item)
                                        ? context.l10n.unfollowAction
                                        : context.l10n.followAction,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            SelectableText(
                              '${item.targetLabel}: ${item.targetHref}',
                              style: TextStyle(
                                color: Theme.of(context).sdal.info,
                              ),
                            ),
                        ] else if (item.isMemberSuggestion) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.tonal(
                                onPressed: () =>
                                    context.push('/members/${item.memberId}'),
                                child: const Text('Profili aç'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _followingInFlightIds.contains(
                                      item.memberId,
                                    )
                                    ? null
                                    : () => _toggleFollowSuggestion(item),
                                icon:
                                    _followingInFlightIds.contains(
                                      item.memberId,
                                    )
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _isMemberFollowed(item)
                                            ? Icons.person_remove_alt_1_rounded
                                            : Icons.person_add_alt_1_rounded,
                                      ),
                                label: Text(
                                  _followingInFlightIds.contains(item.memberId)
                                      ? context.l10n.submitInProgress
                                      : _isMemberFollowed(item)
                                      ? context.l10n.unfollowAction
                                      : context.l10n.followAction,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (_hasMore) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: FilledButton.tonal(
                  onPressed: _isLoadingMore ? null : () => _load(reset: false),
                  child: Text(
                    _isLoadingMore ? 'Yükleniyor...' : 'Daha fazla yükle',
                  ),
                ),
              ),
            ],
          ],
        ),
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

String _priorityLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'now':
      return 'Öncelikli';
    case 'soon':
      return 'Yakında';
    default:
      return 'Takip et';
  }
}

String _categoryLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'jobs':
      return 'İş';
    case 'networking':
      return 'Networking';
    default:
      return 'Güncelleme';
  }
}
