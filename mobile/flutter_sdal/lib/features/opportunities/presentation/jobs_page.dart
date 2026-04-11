import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/jobs_action_controller.dart';
import '../data/opportunities_repository.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _jobTypeController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _jobTypeController.dispose();
    _linkController.dispose();
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
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panelRaised,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tokens.panelBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.jobsCreateTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.jobsCreateHelper,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    labelText: l10n.jobsCompanyLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.jobsPositionLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l10n.jobsDescriptionLabel,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: l10n.jobsLocationLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _jobTypeController,
                  decoration: InputDecoration(
                    labelText: l10n.jobsTypeLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: l10n.jobsLinkLabel,
                    hintText: l10n.jobsLinkHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        actionState.isLoading &&
                            actionState.scope == 'jobs:create'
                        ? null
                        : _create,
                    child: Text(
                      actionState.isLoading &&
                              actionState.scope == 'jobs:create'
                          ? l10n.jobsCreateInProgress
                          : l10n.jobsCreateAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.jobsSearchTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.jobsSearchHelper,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            SurfaceCard(child: Text(_error))
          else if (_items.isEmpty)
            SurfaceCard(child: Text(l10n.jobsEmpty))
          else
            ..._items.map((job) => _buildJobCard(job, actionState)),
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
                  _formatDate(job.createdAt),
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

  Future<void> _create() async {
    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .createJob(
          company: _companyController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          jobType: _jobTypeController.text.trim(),
          link: _linkController.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? context.l10n.jobsCreateSuccess
                  : context.l10n.jobsCreateFailed),
        ),
      ),
    );
    if (!ok) return;
    _companyController.clear();
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _jobTypeController.clear();
    _linkController.clear();
    _load();
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

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}
