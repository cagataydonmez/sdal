import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/opportunities_repository.dart';

class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
  final List<OpportunityItem> _items = <OpportunityItem>[];
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
                          SelectableText(
                            '${item.targetLabel}: ${item.targetHref}',
                            style: TextStyle(
                              color: Theme.of(context).sdal.info,
                            ),
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
