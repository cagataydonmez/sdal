import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/session/session_controller.dart';
import '../../community/presentation/entity_action_menu.dart';
import '../application/jobs_action_controller.dart';
import '../../feed/application/feed_action_controller.dart';
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
  List<JobItem> _draftItems = const <JobItem>[];
  bool _isLoading = true;
  String _error = '';
  bool _filterExpanded = false;
  bool _showDrafts = false;

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
    final session = ref.watch(sessionControllerProvider).value;
    final userId = session?.user?.id ?? 0;
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
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Yayınlanan'),
                selected: !_showDrafts,
                onSelected: (selected) => setState(() => _showDrafts = false),
              ),
              FilterChip(
                label: const Text('Taslaklar'),
                selected: _showDrafts,
                onSelected: (selected) => setState(() => _showDrafts = true),
              ),
            ],
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.foregroundMuted),
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
          else if (_getSortedItems().isEmpty)
            SurfaceCard(child: Text(l10n.jobsEmpty))
          else ...[
            if (sortedItems.isNotEmpty) ...[
              _buildHeroJobCard(sortedItems.first, actionState, userId),
              const SizedBox(height: 24),
            ],
            if (sortedItems.length > 1)
              ...sortedItems
                  .skip(1)
                  .map((job) => _buildJobCard(job, actionState, userId)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final result = await context.push('/jobs/create');
                if (mounted && result == true) _load();
              },
              icon: const Icon(Icons.add_outlined),
              label: Text(l10n.jobsCreateAction),
            ),
          ),
        ],
      ),
    );
  }

  List<JobItem> _getSortedItems() {
    final items = _showDrafts ? _draftItems : _items;
    final sorted = List<JobItem>.from(items);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<void> _openJobDetail(int jobId) async {
    await context.push('/jobs/$jobId');
    if (mounted) _load();
  }

  Widget _buildHeroJobCard(
    JobItem job,
    AsyncActionState actionState,
    int userId,
  ) {
    final tokens = Theme.of(context).sdal;
    final isOwner = job.posterId == userId;
    return GestureDetector(
      onTap: () => _openJobDetail(job.id),
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
                      style: Theme.of(context).textTheme.headlineSmall
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.foregroundOnAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _JobOwnerMenu(
                    job: job,
                    onEdit: () => _editJob(job),
                    onUnpublish: () => _unpublishJob(job.id),
                    onDelete: () => _deleteJob(job.id),
                    dark: true,
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
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

  Widget _buildJobCard(JobItem job, AsyncActionState actionState, int userId) {
    final tokens = Theme.of(context).sdal;
    final isOwner = job.posterId == userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openJobDetail(job.id),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
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
              if (isOwner)
                _JobOwnerMenu(
                  job: job,
                  onEdit: () => _editJob(job),
                  onUnpublish: () => _unpublishJob(job.id),
                  onDelete: () => _deleteJob(job.id),
                  dark: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editJob(JobItem job) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _JobEditDialog(job: job, onSave: () => _load()),
    );
  }

  Future<void> _unpublishJob(int jobId) async {
    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .setJobPublished(jobId: jobId, publish: false);
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? 'İş ilanı taslaklara alındı.'
                  : 'İş ilanı yayından kaldırılamadı.'),
        ),
      ),
    );
    if (ok) _load();
  }

  Future<void> _deleteJob(int jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlan silinsin mi?'),
        content: const Text('Bu işlem ilanı kalıcı olarak kaldırır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final published = await ref
          .read(opportunitiesRepositoryProvider)
          .fetchJobs(
            search: _searchController.text.trim(),
            location: _searchLocationController.text.trim(),
            jobType: _searchJobTypeController.text.trim(),
            status: 'published',
          );
      final drafts = await ref
          .read(opportunitiesRepositoryProvider)
          .fetchJobs(
            search: _searchController.text.trim(),
            location: _searchLocationController.text.trim(),
            jobType: _searchJobTypeController.text.trim(),
            status: 'drafts',
          );
      if (!mounted) return;
      setState(() {
        _items = published;
        _draftItems = drafts;
      });
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
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: tokens.foregroundMuted),
      ),
    );
  }
}

class _JobOwnerMenu extends StatelessWidget {
  const _JobOwnerMenu({
    required this.job,
    required this.onEdit,
    required this.onUnpublish,
    required this.onDelete,
    required this.dark,
  });

  final JobItem job;
  final VoidCallback onEdit;
  final VoidCallback onUnpublish;
  final VoidCallback onDelete;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return EntityActionMenu(
      kind: EntityActionKind.job,
      dark: dark,
      onEdit: () async => onEdit(),
      onUnpublish: () async => onUnpublish(),
      onDelete: () async => onDelete(),
    );
  }
}

class _JobEditDialog extends ConsumerStatefulWidget {
  const _JobEditDialog({required this.job, required this.onSave});

  final JobItem job;
  final VoidCallback onSave;

  @override
  ConsumerState<_JobEditDialog> createState() => _JobEditDialogState();
}

class _JobEditDialogState extends ConsumerState<_JobEditDialog> {
  late final TextEditingController _companyController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _linkController;
  late String _selectedJobType;
  late String _selectedWorkMode;
  File? _imageFile;
  late bool _showInFeed;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController(text: widget.job.company);
    _titleController = TextEditingController(text: widget.job.title);
    _descriptionController = TextEditingController(
      text: widget.job.description,
    );
    _locationController = TextEditingController(text: widget.job.location);
    _linkController = TextEditingController(text: widget.job.link);
    _selectedJobType = widget.job.jobType;
    _selectedWorkMode = widget.job.workMode;
    _showInFeed = widget.job.showInFeed;
  }

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(feedActionControllerProvider);
    final isSaving =
        actionState.isLoading &&
        actionState.scope == 'edit-job:${widget.job.id}';

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'İlanı Düzenle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _companyController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Şirket',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Pozisyon',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                enabled: !isSaving,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Konum',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _linkController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Başvuru Linki',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isSaving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _imageFile == null
                      ? (widget.job.image.isNotEmpty
                            ? 'Görseli değiştir'
                            : 'Görsel ekle')
                      : 'Görseli değiştir',
                ),
              ),
              if (_imageFile != null || widget.job.image.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, height: 200, fit: BoxFit.cover)
                      : Image.network(
                          widget.job.image,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hemen yayınla'),
                subtitle: Text(
                  _showInFeed
                      ? 'İlan taslak yerine yayınlanmış olarak kaydedilecek'
                      : 'İlan taslak olarak kaydedilecek, detay sayfasından yayınlayabilirsiniz',
                ),
                value: _showInFeed,
                onChanged: isSaving
                    ? null
                    : (v) => setState(() => _showInFeed = v),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: isSaving ? null : _save,
                    child: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await pickAndCropImage(
      context,
      source: ImageSource.gallery,
      aspectPreset: CropAspectPreset.wide169,
      title: 'İlan görselini hazırla',
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = picked);
  }

  Future<void> _save() async {
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .editJob(
          jobId: widget.job.id,
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          jobType: _selectedJobType,
          workMode: _selectedWorkMode,
          link: _linkController.text.trim(),
          imageFile: _imageFile,
          showInFeed: _showInFeed,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'İlan güncellendi.' : 'Güncellenemedi.')),
    );
    if (ok) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSave();
    }
  }
}
