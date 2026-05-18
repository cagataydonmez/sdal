import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/security/step_up_auth_dialog.dart';
import '../models/communication_models.dart';
import '../state/communication_state.dart';

class CommunicationView extends ConsumerWidget {
  const CommunicationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communicationControllerProvider);
    final controller = ref.read(communicationControllerProvider.notifier);
    return AdminStateView<CommunicationSnapshot>(
      state: state.snapshot,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (snapshot) => AdminAdaptiveWorkspace(
        title: 'Toplu Bildirim Oluşturucu',
        header: state.message.isEmpty ? null : Text(state.message),
        listPane: _BroadcastForm(snapshot: snapshot),
        detailPane: _PhonePreview(draft: snapshot.draft),
        actionPane: _BroadcastSummary(snapshot: snapshot),
      ),
    );
  }
}

class _BroadcastForm extends ConsumerWidget {
  const _BroadcastForm({required this.snapshot});

  final CommunicationSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communicationControllerProvider.notifier);
    final draft = snapshot.draft;
    return AdminPanelCard(
      child: ListView(
        children: [
          DropdownButtonFormField<BroadcastTargetSegment>(
            initialValue: draft.segment,
            decoration: const InputDecoration(
              labelText: 'Hedef kitle segmentasyonu',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final segment in BroadcastTargetSegment.values)
                DropdownMenuItem(
                  value: segment,
                  child: Text(broadcastTargetLabel(segment)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.updateDraft(draft.copyWith(segment: value));
              }
            },
          ),
          const SizedBox(height: 10),
          _DraftField(
            label: 'Cohort',
            value: draft.cohort,
            onChanged: (value) =>
                controller.updateDraft(draft.copyWith(cohort: value)),
          ),
          _DraftField(
            label: 'Bildirim başlığı',
            value: draft.title,
            onChanged: (value) =>
                controller.updateDraft(draft.copyWith(title: value)),
          ),
          _DraftField(
            label: 'Gövde',
            value: draft.body,
            maxLines: 4,
            onChanged: (value) =>
                controller.updateDraft(draft.copyWith(body: value)),
          ),
          _DraftField(
            label: 'Görsel URL',
            value: draft.imageUrl,
            onChanged: (value) =>
                controller.updateDraft(draft.copyWith(imageUrl: value)),
          ),
          _DraftField(
            label: 'Deep Link hedefi',
            value: draft.deepLink,
            onChanged: (value) =>
                controller.updateDraft(draft.copyWith(deepLink: value)),
          ),
        ],
      ),
    );
  }
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.draft});

  final BroadcastDraft draft;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Canlı Önizleme'),
              const Divider(),
              Text(draft.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(draft.body),
              const SizedBox(height: 10),
              Chip(label: Text(draft.deepLink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastSummary extends ConsumerWidget {
  const _BroadcastSummary({required this.snapshot});

  final CommunicationSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communicationControllerProvider.notifier);
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Tahmini Alıcı Sayısı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${snapshot.dryRun.estimatedRecipients}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(snapshot.dryRun.validationMessage),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: controller.dryRun,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Bildirimi Test Et (Dry Run)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              final token = await StepUpAuthDialog.confirm(
                context,
                operationLabel: 'Toplu bildirim gönder',
                riskDescription:
                    'Bu işlem seçilen kitleye bildirim gönderecek. Devam etmek için admin şifreni doğrula.',
              );
              if (token != null) await controller.send(token.token);
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Toplu Bildirimi Gönder'),
          ),
        ],
      ),
    );
  }
}
