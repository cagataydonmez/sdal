import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../application/jobs_action_controller.dart';

const _jobTypes = [
  'Tam Zamanlı',
  'Yarı Zamanlı',
  'Staj',
  'Freelance',
  'Sözleşmeli',
];

const _workModes = ['Uzaktan', 'Ofiste', 'Hibrit'];

class JobsCreatePage extends ConsumerStatefulWidget {
  const JobsCreatePage({super.key});

  @override
  ConsumerState<JobsCreatePage> createState() => _JobsCreatePageState();
}

class _JobsCreatePageState extends ConsumerState<JobsCreatePage> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  String? _selectedJobType;
  String? _selectedWorkMode;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onLinkChanged);
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

  void _onLinkChanged() => setState(() {});

  String _normalizeLink(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    return 'https://$trimmed';
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

  Future<void> _previewLink() async {
    var raw = _linkController.text.trim();
    if (raw.isEmpty) return;
    raw = _normalizeLink(raw);
    if (raw != _linkController.text.trim()) {
      _linkController.text = raw;
      _linkController.selection = TextSelection.fromPosition(
        TextPosition(offset: raw.length),
      );
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL açılamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actionState = ref.watch(jobsActionControllerProvider);
    final isSaving = actionState.isLoading && actionState.scope == 'jobs:create';

    return FeatureScaffold(
      title: l10n.jobsCreateTitle,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _companyController,
            decoration: InputDecoration(
              labelText: l10n.jobsCompanyLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.jobsPositionLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: l10n.jobsLocationLabel,
              hintText: 'İstanbul, Ankara...',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.jobsTypeLabel,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedJobType,
                isDense: true,
                hint: const Text('Seçin'),
                items: _jobTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedJobType = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Çalışma Şekli',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedWorkMode,
                isDense: true,
                hint: const Text('Seçin'),
                items: _workModes
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWorkMode = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.jobsLinkLabel,
                    hintText: 'linkedin.com/jobs/... veya kariyer.net/...',
                    helperText: 'https:// otomatik eklenir',
                    border: const OutlineInputBorder(),
                  ),
                  onEditingComplete: () {
                    final normalized = _normalizeLink(_linkController.text);
                    if (normalized != _linkController.text) {
                      _linkController.text = normalized;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton.outlined(
                  onPressed: _linkController.text.trim().isEmpty ? null : _previewLink,
                  icon: const Icon(Icons.open_in_new_outlined),
                  tooltip: 'Linki önizle',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isSaving ? null : _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_imageFile == null ? 'Görsel ekle (isteğe bağlı)' : 'Görseli değiştir'),
          ),
          if (_imageFile != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover, width: double.infinity),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isSaving ? null : _create,
            icon: const Icon(Icons.check_outlined),
            label: Text(isSaving ? l10n.jobsCreateInProgress : l10n.jobsCreateAction),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isSaving ? null : () => context.pop(),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final company = _companyController.text.trim();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (company.isEmpty || title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şirket, rol ve açıklama gerekli.')),
      );
      return;
    }
    final rawLink = _linkController.text.trim();
    final link = rawLink.isEmpty ? '' : _normalizeLink(rawLink);

    final ok = await ref.read(jobsActionControllerProvider.notifier).createJob(
      company: company,
      title: title,
      description: description,
      location: _locationController.text.trim(),
      jobType: _selectedJobType ?? '',
      workMode: _selectedWorkMode ?? '',
      link: link,
      imageFile: _imageFile,
    );
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? context.l10n.jobsCreateSuccess : context.l10n.jobsCreateFailed),
        ),
      ),
    );
    if (!ok) return;
    if (!mounted) return;
    context.pop();
  }
}
