import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/state/async_action_state.dart';
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
    final actionState = ref.watch(jobsActionControllerProvider);

    return FeatureScaffold(
      title: 'İş ilanları',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni iş ilanı',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    labelText: 'Şirket',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Pozisyon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Konum',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _jobTypeController,
                  decoration: const InputDecoration(
                    labelText: 'İş tipi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Başvuru linki',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
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
                          ? 'Kaydediliyor...'
                          : 'İlanı yayınla',
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
                Text('İlan ara', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Arama',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Konum filtresi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchJobTypeController,
                  decoration: const InputDecoration(
                    labelText: 'İş tipi filtresi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Filtreleri uygula'),
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
            const SurfaceCard(child: Text('Henüz iş ilanı yok.'))
          else
            ..._items.map((job) => _buildJobCard(job, actionState)),
        ],
      ),
    );
  }

  Widget _buildJobCard(JobItem job, AsyncActionState actionState) {
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
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Text(_plainText(job.description)),
            if (job.link.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                job.link,
                style: const TextStyle(color: Colors.blue),
              ),
            ],
            const SizedBox(height: 12),
            if (job.myApplicationId > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Başvuru durumu: ${_applicationStatusLabel(job.myApplicationStatus)}',
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
                decoration: const InputDecoration(
                  labelText: 'Kısa başvuru notu',
                  border: OutlineInputBorder(),
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
                  child: const Text('Başvur'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatDate(job.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                const Spacer(),
                if (job.posterId == _currentUserId)
                  OutlinedButton(
                    onPressed:
                        actionState.isLoading &&
                            actionState.scope == 'jobs:delete:${job.id}'
                        ? null
                        : () => _delete(job.id),
                    child: const Text('Sil'),
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
                        ? 'Başvuruları yükle'
                        : 'Başvuruları yenile',
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
                        color: const Color(0xFFF4F7FA),
                        borderRadius: BorderRadius.circular(14),
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
                                  ?.copyWith(color: Colors.black54),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'Durum: ${_applicationStatusLabel(application.status)}',
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
                            decoration: const InputDecoration(
                              labelText: 'Karar notu',
                              border: OutlineInputBorder(),
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
                                child: const Text('İncelemede'),
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
                                child: const Text('Kabul et'),
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
                                child: const Text('Reddet'),
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
    final session = ref.read(sessionControllerProvider).valueOrNull;
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
              (ok ? 'İş ilanı yayınlandı.' : 'İlan oluşturulamadı.'),
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
              (ok ? 'Başvuru gönderildi.' : 'Başvuru gönderilemedi.'),
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
          state.message ?? (ok ? 'İlan silindi.' : 'İlan silinemedi.'),
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
              (ok ? 'Başvuru güncellendi.' : 'Başvuru güncellenemedi.'),
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
  return raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();
}

String _applicationStatusLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'accepted':
      return 'Kabul edildi';
    case 'rejected':
      return 'Reddedildi';
    case 'reviewed':
      return 'İncelendi';
    default:
      return 'Beklemede';
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
