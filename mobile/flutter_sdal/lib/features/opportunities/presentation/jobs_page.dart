import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
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
  final Map<int, TextEditingController> _applyControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _reviewControllers =
      <int, TextEditingController>{};
  final Map<int, List<JobApplicationItem>> _applicationsByJob =
      <int, List<JobApplicationItem>>{};

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
    for (final controller in _applyControllers.values) {
      controller.dispose();
    }
    for (final controller in _reviewControllers.values) {
      controller.dispose();
    }
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
    return SurfaceCard(
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
    );
  }

  Widget _buildJobCard(JobItem job, AsyncActionState actionState) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final applyController = _applyControllers.putIfAbsent(
      job.id,
      TextEditingController.new,
    );
    final applications =
        _applicationsByJob[job.id] ?? const <JobApplicationItem>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (job.jobType.isNotEmpty) Chip(label: Text(job.jobType)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                job.company,
                if (job.location.isNotEmpty) job.location,
                if (job.posterHandle.isNotEmpty) '@${job.posterHandle}',
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
            ),
            const SizedBox(height: 10),
            Text(_plainText(job.description)),
            if (job.link.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(job.link, style: TextStyle(color: tokens.accent)),
            ],
            const SizedBox(height: 12),
            if (job.myApplicationId > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.infoMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.panelBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.jobsApplicationStatus(
                        _applicationStatusLabel(
                          context,
                          job.myApplicationStatus,
                        ),
                      ),
                    ),
                    if (job.myApplicationDecisionNote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(job.myApplicationDecisionNote),
                    ],
                  ],
                ),
              )
            else ...[
              TextField(
                controller: applyController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.jobsShortNoteLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed:
                      actionState.isLoading &&
                          actionState.scope == 'jobs:apply:${job.id}'
                      ? null
                      : () => _apply(job.id, applyController.text.trim()),
                  child: Text(l10n.jobsApplyAction),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatDate(context, job.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                const Spacer(),
                if (job.posterId == _currentUserId)
                  OutlinedButton(
                    onPressed:
                        actionState.isLoading &&
                            actionState.scope == 'jobs:delete:${job.id}'
                        ? null
                        : () => _delete(job.id),
                    child: Text(l10n.deleteAction),
                  ),
              ],
            ),
            if (job.posterId == _currentUserId) ...[
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => _loadApplications(job.id),
                  child: Text(
                    applications.isEmpty
                        ? l10n.jobsLoadApplicationsAction
                        : l10n.jobsRefreshApplicationsAction,
                  ),
                ),
              ),
              if (applications.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...applications.map((application) {
                  final noteController = _reviewControllers.putIfAbsent(
                    application.id,
                    () => TextEditingController(text: application.decisionNote),
                  );
                  final reviewScope = 'jobs:review:${job.id}:${application.id}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.panelMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.displayName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (application.handle.isNotEmpty)
                            Text(
                              '@${application.handle}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.foregroundMuted),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.jobsApplicationsStatus(
                              _applicationStatusLabel(
                                context,
                                application.status,
                              ),
                            ),
                          ),
                          if (application.coverLetter.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(_plainText(application.coverLetter)),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteController,
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: l10n.jobsReviewNoteLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed:
                                    actionState.isLoading &&
                                        actionState.scope == reviewScope
                                    ? null
                                    : () => _review(
                                        job.id,
                                        application.id,
                                        'reviewed',
                                        noteController.text.trim(),
                                      ),
                                child: Text(l10n.jobsMarkReviewedAction),
                              ),
                              OutlinedButton(
                                onPressed:
                                    actionState.isLoading &&
                                        actionState.scope == reviewScope
                                    ? null
                                    : () => _review(
                                        job.id,
                                        application.id,
                                        'accepted',
                                        noteController.text.trim(),
                                      ),
                                child: Text(l10n.jobsAcceptAction),
                              ),
                              OutlinedButton(
                                onPressed:
                                    actionState.isLoading &&
                                        actionState.scope == reviewScope
                                    ? null
                                    : () => _review(
                                        job.id,
                                        application.id,
                                        'rejected',
                                        noteController.text.trim(),
                                      ),
                                child: Text(l10n.rejectAction),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  int get _currentUserId {
    final session = ref.read(sessionControllerProvider).value;
    return session?.user?.id ?? 0;
  }

  Future<void> _apply(int jobId, String coverLetter) async {
    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .apply(jobId: jobId, coverLetter: coverLetter);
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? context.l10n.jobsApplySuccess
                  : context.l10n.jobsApplyFailed),
        ),
      ),
    );
    if (ok) _load();
  }

  Future<void> _delete(int jobId) async {
    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .deleteJob(jobId);
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? context.l10n.jobsDeleteSuccess
                  : context.l10n.jobsDeleteFailed),
        ),
      ),
    );
    if (ok) _load();
  }

  Future<void> _loadApplications(int jobId) async {
    try {
      final items = await ref
          .read(opportunitiesRepositoryProvider)
          .fetchApplications(jobId);
      if (!mounted) return;
      setState(() => _applicationsByJob[jobId] = items);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı.')));
    }
  }

  Future<void> _review(
    int jobId,
    int applicationId,
    String status,
    String decisionNote,
  ) async {
    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .review(
          jobId: jobId,
          applicationId: applicationId,
          status: status,
          decisionNote: decisionNote,
        );
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? context.l10n.jobsReviewSuccess
                  : context.l10n.jobsReviewFailed),
        ),
      ),
    );
    if (ok) {
      _load();
      _loadApplications(jobId);
    }
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

String _plainText(String raw) {
  return plainTextFromRichContent(raw);
}

String _applicationStatusLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  switch (value.trim().toLowerCase()) {
    case 'accepted':
      return l10n.statusApproved;
    case 'rejected':
      return l10n.statusRejected;
    case 'reviewed':
      return l10n.statusReviewed;
    default:
      return l10n.statusPending;
  }
}

String _formatDate(BuildContext context, String raw) =>
    formatSdalTimestamp(context, raw);
