import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../application/jobs_action_controller.dart';

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
  final TextEditingController _jobTypeController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _jobTypeController.dispose();
    _linkController.dispose();
    super.dispose();
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
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _jobTypeController,
            decoration: InputDecoration(
              labelText: l10n.jobsTypeLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: l10n.jobsLinkLabel,
              hintText: l10n.jobsLinkHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isSaving ? null : _create,
            icon: const Icon(Icons.check_outlined),
            label: Text(
              isSaving ? l10n.jobsCreateInProgress : l10n.jobsCreateAction,
            ),
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
        const SnackBar(
          content: Text('Şirket, rol ve açıklama gerekli.'),
        ),
      );
      return;
    }
    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .createJob(
          company: company,
          title: title,
          description: description,
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
    if (!mounted) return;
    context.pop();
  }
}
