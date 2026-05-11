import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/jobs_action_controller.dart';
import '../data/opportunities_repository.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _searchLocationController =
      TextEditingController();
  final TextEditingController _searchJobTypeController =
      TextEditingController();

  List<JobItem> _items = const <JobItem>[];
  bool _isLoading = true;
  String _error = '';
  bool _filterExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchLocationController.dispose();
    _searchJobTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final actionState = ref.watch(jobsActionControllerProvider);
    final sortedItems = _getSortedItems();

    return FeatureScaffold(
      title: l10n.jobsTitle,
      background: FeatureScaffoldBackground.utility,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageOnboardingCard(
            id: 'jobs-main',
            icon: Icons.work_outline,
            title: 'Fırsatlar net bilgiyle hızlı değer üretir.',
            message:
                'İlan paylaşırken şirket, rol, konum ve başvuru linkini açık yaz. Arama alanıyla SDAL ağı içindeki uygun fırsatları süzebilirsin.',
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: ExpansionTile(
              initiallyExpanded: _filterExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _filterExpanded = expanded);
              },
              title: Text(
                l10n.jobsSearchTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                l10n.jobsSearchHelper,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.foregroundMuted,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: l10n.jobsSearchLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchLocationController,
                        decoration: InputDecoration(
                          labelText: l10n.jobsLocationFilterLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchJobTypeController,
                        decoration: InputDecoration(
                          labelText: l10n.jobsTypeFilterLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: _load,
                          child: Text(l10n.jobsApplyFiltersAction),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            SurfaceCard(child: Text(_error))
          else if (_items.isEmpty)
            SurfaceCard(child: Text(l10n.jobsEmpty))
          else ...[
            if (sortedItems.isNotEmpty) ...[
              _buildHeroJobCard(sortedItems.first, actionState),
              const SizedBox(height: 16),
            ],
            ...sortedItems.map((job) => _buildJobCard(job, actionState)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/jobs/create'),
              icon: const Icon(Icons.add_outlined),
              label: Text(l10n.jobsCreateAction),
            ),
          ),
        ],
      ),
    );
  }

  List<JobItem> _getSortedItems() {
    final sorted = List<JobItem>.from(_items);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Widget _buildHeroJobCard(JobItem job, AsyncActionState actionState) {
    final tokens = Theme.of(context).sdal;
    return GestureDetector(
      onTap: () => context.push('/jobs/${job.id}'),
      child: SurfaceCard(
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    tokens.accent.withValues(alpha: 0.6),
                    tokens.accent.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '💼 En yeni iş',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(JobItem job, AsyncActionState actionState) {
    final tokens = Theme.of(context).sdal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/jobs/${job.id}'),
        child: SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        job.company,
                        if (job.location.isNotEmpty) job.location,
                      ].join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tokens.foregroundMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(context, job.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tokens.foregroundMuted),
                    ),
                  ],
                ),
              ),
              if (job.jobType.isNotEmpty) ...[
                const SizedBox(width: 8),
                Chip(label: Text(job.jobType)),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final items = await ref
          .read(opportunitiesRepositoryProvider)
          .fetchJobs(
            search: _searchController.text.trim(),
            location: _searchLocationController.text.trim(),
            jobType: _searchJobTypeController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

String _formatDate(BuildContext context, String raw) =>
    formatSdalTimestamp(context, raw);
