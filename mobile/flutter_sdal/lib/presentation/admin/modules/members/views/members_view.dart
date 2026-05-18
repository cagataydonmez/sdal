import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../models/members_models.dart';
import '../state/members_state.dart';

class MembersView extends ConsumerWidget {
  const MembersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(membersControllerProvider);
    final controller = ref.read(membersControllerProvider.notifier);
    return AdminStateView<List<MemberRecord>>(
      state: state.members,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (members) => AdminAdaptiveWorkspace(
        title: 'Üye Arama ve Sicil Yönetimi',
        listPane: _MembersTable(members: members, selectedId: state.selectedId),
        detailPane: _MemberTimeline(member: state.selectedMember),
        actionPane: _MemberActions(member: state.selectedMember),
      ),
    );
  }
}

class _MembersTable extends ConsumerWidget {
  const _MembersTable({required this.members, required this.selectedId});

  final List<MemberRecord> members;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(membersControllerProvider.notifier);
    return AdminPanelCard(
      child: SingleChildScrollView(
        child: PaginatedDataTable(
          header: const Text('Üyeler'),
          rowsPerPage: members.length < 5 ? members.length : 5,
          columns: const [
            DataColumn(label: Text('İsim')),
            DataColumn(label: Text('E-posta')),
            DataColumn(label: Text('Mezuniyet')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Ceza')),
          ],
          source: _MembersDataSource(
            context: context,
            members: members,
            selectedId: selectedId,
            onSelect: controller.select,
          ),
        ),
      ),
    );
  }
}

class _MembersDataSource extends DataTableSource {
  _MembersDataSource({
    required this.context,
    required this.members,
    required this.selectedId,
    required this.onSelect,
  });

  final BuildContext context;
  final List<MemberRecord> members;
  final String selectedId;
  final ValueChanged<MemberRecord> onSelect;

  @override
  DataRow? getRow(int index) {
    if (index >= members.length) return null;
    final member = members[index];
    return DataRow.byIndex(
      index: index,
      selected: member.id == selectedId,
      onSelectChanged: (_) => onSelect(member),
      cells: [
        DataCell(Text(member.name)),
        DataCell(Text(member.email)),
        DataCell(Text(member.graduationYear)),
        DataCell(Text(member.role)),
        DataCell(Text(memberPenaltyLabel(member.penaltyStatus))),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => members.length;

  @override
  int get selectedRowCount => selectedId.isEmpty ? 0 : 1;
}

class _MemberTimeline extends StatelessWidget {
  const _MemberTimeline({required this.member});

  final MemberRecord? member;

  @override
  Widget build(BuildContext context) {
    final current = member;
    if (current == null) {
      return const AdminDetailPlaceholder(
        icon: Icons.person_search_outlined,
        title: 'Üye seçilmedi',
        message: 'Kullanıcı operasyon zaman çizelgesi için tablodan üye seçin.',
      );
    }
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Kullanıcı Operasyon Zaman Çizelgesi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          for (final event in current.timeline) _TimelineTile(event: event),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final MemberTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const CircleAvatar(radius: 6),
            Container(
              width: 2,
              height: 46,
              color: Theme.of(context).dividerColor,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(event.detail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberActions extends StatelessWidget {
  const _MemberActions({required this.member});

  final MemberRecord? member;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Üye aksiyonları',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(member?.name ?? 'Üye seçilmedi'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: member == null ? null : () {},
            icon: const Icon(Icons.warning_outlined),
            label: const Text('Uyarı ekle'),
          ),
          OutlinedButton.icon(
            onPressed: member == null ? null : () {},
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Geçici askıya al'),
          ),
          FilledButton.icon(
            onPressed: member == null ? null : () {},
            icon: const Icon(Icons.block_outlined),
            label: const Text('Kalıcı ban incelemesi aç'),
          ),
        ],
      ),
    );
  }
}
