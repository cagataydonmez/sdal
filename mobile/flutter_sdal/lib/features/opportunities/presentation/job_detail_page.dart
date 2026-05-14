import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/state/async_action_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../community/presentation/entity_action_menu.dart';
import '../application/jobs_action_controller.dart';
import '../data/opportunities_repository.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.jobId});

  final int jobId;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  late final FutureProvider<JobItem?> _jobProvider;

  @override
  void initState() {
    super.initState();
    _jobProvider = FutureProvider.autoDispose<JobItem?>((ref) async {
      return ref.read(opportunitiesRepositoryProvider).fetchJob(widget.jobId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_jobProvider);
    final actionState = ref.watch(jobsActionControllerProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.jobsTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (job) => job == null
            ? const ErrorView()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_jobProvider),
                child: _JobDetailContent(
                  job: job,
                  jobId: widget.jobId,
                  isOwner: job.posterId == (session?.user?.id ?? 0),
                  isAdmin: session?.hasAdminAccess ?? false,
                  actionState: actionState,
                  l10n: l10n,
                  ref: ref,
                  onRefresh: () => ref.invalidate(_jobProvider),
                ),
              ),
      ),
    );
  }
}

class _JobDetailContent extends ConsumerStatefulWidget {
  const _JobDetailContent({
    required this.job,
    required this.jobId,
    required this.isOwner,
    required this.isAdmin,
    required this.actionState,
    required this.l10n,
    required this.ref,
    required this.onRefresh,
  });

  final JobItem job;
  final int jobId;
  final bool isOwner;
  final bool isAdmin;
  final AsyncActionState actionState;
  final AppLocalizations l10n;
  final WidgetRef ref;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_JobDetailContent> createState() => _JobDetailContentState();
}

class _JobDetailContentState extends ConsumerState<_JobDetailContent> {
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.job.image.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SdalNetworkImage(
                    imageUrl: widget.job.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.job.jobType.isNotEmpty ||
                  widget.job.workMode.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    if (widget.job.jobType.isNotEmpty)
                      Chip(label: Text(widget.job.jobType)),
                    if (widget.job.workMode.isNotEmpty)
                      Chip(label: Text(widget.job.workMode)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                widget.job.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.job.company,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.job.location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '📍 ${widget.job.location}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (widget.job.posterHandle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '@${widget.job.posterHandle}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _formatDate(context, widget.job.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
              ),
              if (widget.job.isEdited) ...[
                const SizedBox(height: 4),
                Text(
                  '(düzenlendi)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (widget.isOwner || widget.isAdmin) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/jobs/${widget.jobId}/applications',
                        extra: {'jobTitle': widget.job.title},
                      ),
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: const Text('Başvuranlar'),
                    ),
                    EntityActionMenu(
                      kind: EntityActionKind.job,
                      onEdit: _showEditDialog,
                      onUnpublish: _unpublishJob,
                      onDelete: _deleteJob,
                      child: const Chip(
                        label: Text('Diğer'),
                        avatar: Icon(Icons.more_horiz, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('İş Tanımı', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(_plainText(widget.job.description)),
            ],
          ),
        ),
        if (widget.job.link.isNotEmpty) ...[
          const SizedBox(height: 20),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Başvuru Linki',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _launchUrl(widget.job.link),
                  child: Row(
                    children: [
                      if (_isLinkedIn(widget.job.link)) ...[
                        _LinkedInIcon(),
                        const SizedBox(width: 8),
                      ] else if (_isKariyer(widget.job.link)) ...[
                        _KariyerIcon(),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          widget.job.link,
                          style: TextStyle(
                            color: tokens.accent,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.job.myApplicationId > 0) ...[
          const SizedBox(height: 20),
          SurfaceCard(
            child: Row(
              children: [
                Icon(
                  widget.job.myApplicationStatus == 'pending'
                      ? Icons.hourglass_top_outlined
                      : Icons.check_circle_outline,
                  size: 20,
                  color: widget.job.myApplicationStatus == 'pending'
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Başvuru durumu: ${_applicationStatusLabel(context, widget.job.myApplicationStatus)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ] else if (!widget.isOwner && !widget.isAdmin) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(
                '/jobs/${widget.jobId}/apply',
                extra: {'jobTitle': widget.job.title},
              ),
              icon: const Icon(Icons.send_outlined),
              label: Text(widget.l10n.jobsApplyAction),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showEditDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _JobEditDialog(job: widget.job),
    );
    if (result != null && mounted) {
      final success = await widget.ref
          .read(jobsActionControllerProvider.notifier)
          .editJob(
            jobId: widget.jobId,
            title: result['title'] ?? '',
            company: result['company'] ?? '',
            description: result['description'] ?? '',
            location: result['location'] ?? '',
            jobType: result['jobType'] ?? '',
            workMode: result['workMode'] ?? '',
            link: result['link'] ?? '',
            imageFile: result['imageFile'] as File?,
          );
      if (success && mounted) {
        widget.onRefresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İlan güncellendi')));
      }
    }
  }

  Future<void> _unpublishJob() async {
    final success = await widget.ref
        .read(jobsActionControllerProvider.notifier)
        .setJobPublished(jobId: widget.jobId, publish: false);
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteJob() async {
    final success = await widget.ref
        .read(jobsActionControllerProvider.notifier)
        .deleteJob(widget.jobId);
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  String _formatDate(BuildContext context, String date) {
    if (date.isEmpty) return '';
    try {
      return formatSdalTimestamp(context, date);
    } catch (_) {
      return date;
    }
  }

  String _plainText(String richContent) {
    return plainTextFromRichContent(richContent);
  }

  String _applicationStatusLabel(BuildContext context, String status) {
    return status == 'pending' ? 'Beklemede' : 'İncelendi';
  }

  bool _isLinkedIn(String url) => url.contains('linkedin.com');

  bool _isKariyer(String url) => url.contains('kariyer.net');

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URL açılamadı')));
      }
    }
  }
}

class _LinkedInIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF0A66C2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'in',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _KariyerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Job edit dialog ──────────────────────────────────────────────────────────

class _JobEditDialog extends StatefulWidget {
  const _JobEditDialog({required this.job});
  final JobItem job;

  @override
  State<_JobEditDialog> createState() => _JobEditDialogState();
}

class _JobEditDialogState extends State<_JobEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _jobTypeController;
  late TextEditingController _workModeController;
  late TextEditingController _linkController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _companyController = TextEditingController(text: widget.job.company);
    _descriptionController = TextEditingController(
      text: plainTextFromRichContent(widget.job.description),
    );
    _locationController = TextEditingController(text: widget.job.location);
    _jobTypeController = TextEditingController(text: widget.job.jobType);
    _workModeController = TextEditingController(text: widget.job.workMode);
    _linkController = TextEditingController(text: widget.job.link);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _jobTypeController.dispose();
    _workModeController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İlanı Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Şirket'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'İş Tanımı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Konum'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jobTypeController,
              decoration: const InputDecoration(
                labelText: 'İş Türü (örn. Full-time)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workModeController,
              decoration: const InputDecoration(
                labelText: 'Çalışma Şekli (örn. Remote)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(labelText: 'Başvuru Linki'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imageFile != null
                    ? Image.file(_imageFile!, height: 160, fit: BoxFit.cover)
                    : Image.network(
                        widget.job.image,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'title': _titleController.text,
            'company': _companyController.text,
            'description': _descriptionController.text,
            'location': _locationController.text,
            'jobType': _jobTypeController.text,
            'workMode': _workModeController.text,
            'link': _linkController.text,
            'imageFile': _imageFile,
          }),
          child: const Text('Kaydet'),
        ),
      ],
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
}
