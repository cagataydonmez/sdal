import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/sdal_network_image.dart';
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
              const SizedBox(height: 24),
            ],
            if (sortedItems.length > 1)
              ...sortedItems.skip(1).map((job) => _buildJobCard(job, actionState)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: job.image.isNotEmpty
                      ? SdalNetworkImage(
                          imageUrl: job.image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorFallback: _buildJobPlaceholder(),
                        )
                      : _buildJobPlaceholder(),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💼', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            'En yeni iş',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: tokens.foregroundOnAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              [
                job.company,
                if (job.location.isNotEmpty) job.location,
                _formatDate(context, job.createdAt),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobPlaceholder() {
    return Container(
      color: Theme.of(context).sdal.panelMuted,
      child: Center(
        child: Icon(
          Icons.work_outline,
          size: 48,
          color: Theme.of(context).sdal.foregroundMuted,
        ),
      ),
    );
  }

  Widget _buildJobCard(JobItem job, AsyncActionState actionState) {
    final tokens = Theme.of(context).sdal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/jobs/${job.id}'),
        child: SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 64,
                  child: job.image.isNotEmpty
                      ? SdalNetworkImage(
                          imageUrl: job.image,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 64,
                          errorFallback: _buildJobPlaceholder(),
                        )
                      : _buildJobPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        job.company,
                        if (job.location.isNotEmpty) job.location,
                        _formatDate(context, job.createdAt),
                      ].join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tokens.foregroundMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (job.jobType.isNotEmpty || job.workMode.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (job.jobType.isNotEmpty)
                            _SmallChip(label: job.jobType),
                          if (job.workMode.isNotEmpty)
                            _SmallChip(label: job.workMode),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
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

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.foregroundMuted,
        ),
      ),
    );
  }
}
