import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/security/step_up_auth_dialog.dart';
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

class _MemberActions extends ConsumerStatefulWidget {
  const _MemberActions({required this.member});

  final MemberRecord? member;

  @override
  ConsumerState<_MemberActions> createState() => _MemberActionsState();
}

class _MemberActionsState extends ConsumerState<_MemberActions> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final suspended =
        member?.penaltyStatus == MemberPenaltyStatus.suspended ||
        member?.penaltyStatus == MemberPenaltyStatus.banned;
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
          TextField(
            controller: _reasonController,
            enabled: member != null,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Operasyon gerekçesi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: member == null ? null : _addWarning,
            icon: const Icon(Icons.warning_outlined),
            label: const Text('Uyarı ekle'),
          ),
          OutlinedButton.icon(
            onPressed: member == null
                ? null
                : () => suspended
                      ? _restoreMember(member)
                      : _suspendMember(member),
            icon: Icon(
              suspended
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
            ),
            label: Text(suspended ? 'Askıyı kaldır' : 'Geçici askıya al'),
          ),
          FilledButton.icon(
            onPressed: member == null
                ? null
                : () => _openPermanentBanReview(member),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Kalıcı ban incelemesi aç'),
          ),
        ],
      ),
    );
  }

  String? _validatedReason() {
    final reason = _reasonController.text.trim();
    if (reason.length >= 8) return reason;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerekçe en az 8 karakter olmalı.')),
    );
    return null;
  }

  Future<void> _addWarning() async {
    final reason = _validatedReason();
    if (reason == null) return;
    await ref.read(membersControllerProvider.notifier).addWarning(reason);
    _reasonController.clear();
  }

  Future<void> _suspendMember(MemberRecord member) async {
    final reason = _validatedReason();
    if (reason == null) return;
    final stepUp = await StepUpAuthDialog.confirm(
      context,
      operationLabel: 'Üyeyi askıya alma',
      riskDescription:
          'Bu işlem kullanıcının hesabını askıya alır. Devam etmek için admin şifreni doğrula.',
    );
    if (stepUp == null) return;
    await ref
        .read(membersControllerProvider.notifier)
        .updateSelectedStatus(
          penaltyStatus: MemberPenaltyStatus.suspended,
          backendStatus: 'suspended',
          reason: reason,
          timelineTitle: 'Hesap geçici askıya alındı',
        );
    _reasonController.clear();
  }

  Future<void> _restoreMember(MemberRecord member) async {
    final reason = _validatedReason();
    if (reason == null) return;
    await ref
        .read(membersControllerProvider.notifier)
        .updateSelectedStatus(
          penaltyStatus: MemberPenaltyStatus.clear,
          backendStatus: 'active',
          reason: reason,
          timelineTitle: 'Askı kaldırıldı',
        );
    _reasonController.clear();
  }

  Future<void> _openPermanentBanReview(MemberRecord member) async {
    final reason = _validatedReason();
    if (reason == null) return;
    final stepUp = await StepUpAuthDialog.confirm(
      context,
      operationLabel: 'Kalıcı ban incelemesi',
      riskDescription:
          'Bu işlem hesabı askıya alır ve kalıcı ban incelemesi için kayıt oluşturur.',
    );
    if (stepUp == null) return;
    await ref
        .read(membersControllerProvider.notifier)
        .updateSelectedStatus(
          penaltyStatus: MemberPenaltyStatus.banned,
          backendStatus: 'suspended',
          reason: reason,
          timelineTitle: 'Kalıcı ban incelemesi açıldı',
        );
    _reasonController.clear();
  }
}
