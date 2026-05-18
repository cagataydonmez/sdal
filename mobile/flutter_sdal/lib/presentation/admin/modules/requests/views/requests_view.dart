import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../models/requests_models.dart';
import '../state/requests_state.dart';

class RequestsView extends ConsumerWidget {
  const RequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminRequestsControllerProvider);
    final controller = ref.read(adminRequestsControllerProvider.notifier);
    return AdminStateView<List<AdminRequestItem>>(
      state: state.items,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (items) => AdminAdaptiveWorkspace(
        title: 'Talepler ve Doğrulamalar',
        header: state.message.isEmpty ? null : Text(state.message),
        listPane: _RequestList(items: items, selectedId: state.selectedId),
        detailPane: _RequestDetail(item: state.selectedItem),
        actionPane: const _RequestActions(),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.items, required this.selectedId});

  final List<AdminRequestItem> items;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(adminRequestsControllerProvider.notifier);
    return AdminPanelCard(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            selected: item.id == selectedId,
            leading: const Icon(Icons.assignment_ind_outlined),
            title: Text(item.requesterName),
            subtitle: Text(
              '${adminRequestKindLabel(item.kind)} · ${item.graduationYear} · ${adminRequestStatusLabel(item.status)}',
            ),
            onTap: () => controller.select(item),
          );
        },
      ),
    );
  }
}

class _RequestDetail extends StatelessWidget {
  const _RequestDetail({required this.item});

  final AdminRequestItem? item;

  @override
  Widget build(BuildContext context) {
    final current = item;
    if (current == null) {
      return const AdminDetailPlaceholder(
        icon: Icons.assignment_outlined,
        title: 'Talep seçilmedi',
        message:
            'Belge ve bağlantı önizlemeleri için sol listeden kayıt seçin.',
      );
    }
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            current.requesterName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(current.summary),
          const SizedBox(height: 12),
          Chip(label: Text('Mezuniyet yılı: ${current.graduationYear}')),
          const Divider(height: 28),
          Text(
            'Beyan ve belge önizlemesi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final evidence in current.evidence)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                evidence.kind == 'document'
                    ? Icons.description_outlined
                    : Icons.link,
              ),
              title: Text(evidence.label),
              subtitle: Text(evidence.url),
            ),
        ],
      ),
    );
  }
}

class _RequestActions extends ConsumerStatefulWidget {
  const _RequestActions();

  @override
  ConsumerState<_RequestActions> createState() => _RequestActionsState();
}

class _RequestActionsState extends ConsumerState<_RequestActions> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView(
        children: [
          Text('Karar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Reddetme gerekçesi veya onay notu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _review(AdminRequestStatus.approved),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Doğrula ve Onayla'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _review(AdminRequestStatus.rejected),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reddet (Gerekçe Seçimli)'),
          ),
        ],
      ),
    );
  }

  Future<void> _review(AdminRequestStatus status) async {
    await ref
        .read(adminRequestsControllerProvider.notifier)
        .review(status: status, reason: _reasonController.text.trim());
    _reasonController.clear();
  }
}
