import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/admin_theme.dart';
import '../../../core/security/step_up_auth_dialog.dart';
import '../models/moderation_models.dart';
import '../state/moderation_state.dart';

class ModerationView extends ConsumerWidget {
  const ModerationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(moderationControllerProvider);
    final controller = ref.read(moderationControllerProvider.notifier);
    return AdminStateView<List<ModerationItem>>(
      state: queue.items,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (_) => AdminAdaptiveWorkspace(
        title: 'Birleşik Moderasyon Kuyruğu',
        header: queue.message.isEmpty ? null : Text(queue.message),
        listPane: _ModerationList(queue: queue, controller: controller),
        detailPane: _ModerationDetail(item: queue.selectedItem),
        actionPane: _ModerationActions(item: queue.selectedItem),
      ),
    );
  }
}

class _ModerationList extends StatelessWidget {
  const _ModerationList({required this.queue, required this.controller});

  final ModerationQueueState queue;
  final ModerationController controller;

  @override
  Widget build(BuildContext context) {
    final items = queue.visibleItems;
    return AdminPanelCard(
      child: Column(
        children: [
          AdminFilterBar(
            searchLabel: 'İçerik, yazar veya rapor nedeni ara',
            onSearchChanged: controller.updateSearch,
            filters: [
              const FilterChip(
                label: Text('Kritik'),
                selected: false,
                onSelected: null,
              ),
              const FilterChip(
                label: Text('Cohort'),
                selected: false,
                onSelected: null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? AdminEmptyPanel(onResetFilters: controller.resetFilters)
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = item.id == queue.selectedId;
                      return ListTile(
                        selected: selected,
                        enabled: !item.isLockedByOther || selected,
                        leading: Icon(
                          Icons.flag_outlined,
                          color: adminSeverityColor(
                            context,
                            moderationSeverityValue(item.severity),
                          ),
                        ),
                        title: Text(item.title, maxLines: 2),
                        subtitle: Text(
                          '${moderationContentTypeLabel(item.type)} · ${item.authorName} · ${moderationSeverityLabel(item.severity)}',
                        ),
                        trailing: item.lock == null
                            ? const Icon(Icons.lock_open_outlined)
                            : const Icon(Icons.lock_outline),
                        onTap: () => controller.selectItem(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModerationDetail extends StatelessWidget {
  const _ModerationDetail({required this.item});

  final ModerationItem? item;

  @override
  Widget build(BuildContext context) {
    final current = item;
    if (current == null) {
      return const AdminDetailPlaceholder(
        icon: Icons.shield_outlined,
        title: 'İçerik seçilmedi',
        message: 'İnceleme detaylarını görmek için kuyruktan bir kayıt seçin.',
      );
    }
    final detail = AdminPanelCard(
      child: ListView(
        children: [
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(moderationContentTypeLabel(current.type))),
              Chip(label: Text(moderationSeverityLabel(current.severity))),
              Chip(label: Text(policyCategoryLabel(current.violationCategory))),
            ],
          ),
          const SizedBox(height: 12),
          Text(current.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(current.body),
          const Divider(height: 28),
          Text('Raporlayanlar', style: Theme.of(context).textTheme.titleMedium),
          for (final reporter in current.reporters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_search_outlined),
              title: Text(reporter.name),
              subtitle: Text(reporter.reason),
            ),
        ],
      ),
    );
    if (!current.isLockedByOther) return detail;
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Opacity(opacity: 0.55, child: detail),
        ),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Moderatör ${current.lock!.moderatorName} inceliyor'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModerationActions extends ConsumerStatefulWidget {
  const _ModerationActions({required this.item});

  final ModerationItem? item;

  @override
  ConsumerState<_ModerationActions> createState() => _ModerationActionsState();
}

class _ModerationActionsState extends ConsumerState<_ModerationActions> {
  final _reasonController = TextEditingController();
  PolicyCategory _category = PolicyCategory.spam;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item == null) {
      return const AdminDetailPlaceholder(
        icon: Icons.rule_outlined,
        title: 'Aksiyon bekleniyor',
        message: 'Karar formları kayıt seçilince açılır.',
      );
    }
    final disabled = item.isLockedByOther;
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'İlgili kullanıcı ve karar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(item.authorName),
            subtitle: Text(item.authorRiskLabel),
          ),
          DropdownButtonFormField<PolicyCategory>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Politika kategorisi',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final category in PolicyCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(policyCategoryLabel(category)),
                ),
            ],
            onChanged: disabled
                ? null
                : (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            enabled: !disabled,
            decoration: const InputDecoration(
              labelText: 'Zorunlu gerekçe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _DecisionButton(
            label: 'Onayla ve Kapat',
            icon: Icons.check_circle_outline,
            color: Colors.green.shade700,
            disabled: disabled,
            onPressed: () => _submit(ModerationActionType.approve),
          ),
          _DecisionButton(
            label: 'İçeriği Kaldır',
            icon: Icons.remove_circle_outline,
            color: Colors.orange.shade800,
            disabled: disabled,
            onPressed: () => _submit(ModerationActionType.removeContent),
          ),
          _DecisionButton(
            label: 'Kullanıcıyı Yasakla',
            icon: Icons.block_outlined,
            color: Theme.of(context).colorScheme.error,
            disabled: disabled,
            onPressed: () => _submit(ModerationActionType.banUser),
          ),
          _DecisionButton(
            label: 'Üst Kurula Eskale Et',
            icon: Icons.escalator_warning_outlined,
            color: Theme.of(context).colorScheme.primary,
            disabled: disabled,
            onPressed: () => _submit(ModerationActionType.escalate),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(ModerationActionType actionType) async {
    final item = widget.item;
    if (item == null) return;
    final reason = _reasonController.text.trim();
    if (reason.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerekçe en az 8 karakter olmalı.')),
      );
      return;
    }
    final needsStepUp = actionType != ModerationActionType.approve;
    final stepUp = needsStepUp
        ? await StepUpAuthDialog.confirm(
            context,
            operationLabel: 'Kritik moderasyon işlemi',
            riskDescription:
                'Bu işlem içerik veya kullanıcı durumunu değiştirir. Devam etmek için admin şifreni doğrula.',
          )
        : null;
    if (needsStepUp && stepUp == null) return;
    final decision = ModerationDecision(
      itemId: item.id,
      actionType: actionType,
      policyCategory: _category,
      reason: reason,
      securityToken: stepUp?.token ?? '',
    );
    await ref
        .read(moderationControllerProvider.notifier)
        .submitDecision(decision);
    _reasonController.clear();
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: disabled ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
