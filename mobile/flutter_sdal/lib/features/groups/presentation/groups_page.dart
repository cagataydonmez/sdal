import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/groups_action_controller.dart';
import '../data/groups_repository.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(groupsListProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    return FeatureScaffold(
      title: l10n.groupsTitle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.groupsNewGroupAction),
      ),
      child: groupsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorView(onRetry: () => ref.invalidate(groupsListProvider)),
        data: (groups) => RefreshIndicator(
          onRefresh: () => ref.refresh(groupsListProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: groups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final group = groups[index];
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/groups/${group.id}'),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (group.coverImage.isNotEmpty) ...[
                        SdalNetworkImage(
                          imageUrl: config
                              .resolveUrl(group.coverImage)
                              .toString(),
                          height: 164,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(18),
                          errorFallback: const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          _VisibilityBadge(visibility: group.visibility),
                        ],
                      ),
                      if (group.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(group.description),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            label: l10n.groupsMembersCount(group.membersCount),
                          ),
                          if (group.membershipStatus == 'pending')
                            _MetaChip(label: l10n.groupsPendingApproval),
                          if (group.membershipStatus == 'invited')
                            _MetaChip(label: l10n.groupsInvitePending),
                          if (group.myRole.isNotEmpty)
                            _MetaChip(label: group.myRole),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                context.push('/groups/${group.id}'),
                            child: Text(l10n.groupsOpenAction),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () =>
                                _toggleJoin(context, ref, group.id),
                            child: Text(
                              _joinLabel(context, group.membershipStatus),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _toggleJoin(
  BuildContext context,
  WidgetRef ref,
  int groupId,
) async {
  final groups = ref.read(groupsListProvider).value ?? const <GroupListItem>[];
  GroupListItem? group;
  for (final item in groups) {
    if (item.id == groupId) {
      group = item;
      break;
    }
  }
  final notifier = ref.read(groupsActionControllerProvider.notifier);
  final isMember = group?.membershipStatus == 'member';
  String? status;
  if (isMember) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gruptan ayrılsın mı?'),
        content: const Text('Bu işlem grup üyeliğinizi sonlandırır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    status = await notifier.leaveGroup(groupId);
  } else {
    status = await notifier.toggleJoin(groupId);
  }
  if (status == null) return;
  ref.invalidate(groupsListProvider);
  if (!context.mounted) return;
  if (status.isEmpty) {
    final message = ref.read(groupsActionControllerProvider).message;
    if ((message ?? '').isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message!)));
    }
  }
}

String _joinLabel(BuildContext context, String membershipStatus) {
  final l10n = context.l10n;
  switch (membershipStatus) {
    case 'member':
      return l10n.groupsLeaveAction;
    case 'pending':
      return l10n.groupsWithdrawRequestAction;
    case 'invited':
      return l10n.groupsAcceptInviteAction;
    default:
      return l10n.groupsJoinAction;
  }
}

Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CreateGroupSheet(),
  );
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsActionControllerProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.groupsNewGroupTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.groupsNameLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(labelText: l10n.groupsDescriptionLabel),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      final ok = await ref
                          .read(groupsActionControllerProvider.notifier)
                          .createGroup(
                            name: _nameController.text.trim(),
                            description: _descriptionController.text.trim(),
                          );
                      if (!context.mounted || !ok) return;
                      ref.invalidate(groupsListProvider);
                      Navigator.of(context).pop();
                    },
              child: Text(
                state.isLoading ? l10n.groupsCreating : l10n.createAction,
              ),
            ),
          ),
          if ((state.message ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              state.message!,
              style: TextStyle(
                color: state.isError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).sdal.panelMuted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});

  final String visibility;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final membersOnly = visibility == 'members_only';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: membersOnly ? tokens.warningMuted : tokens.successMuted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          membersOnly ? 'Özel' : 'Herkese açık',
          style: TextStyle(
            color: membersOnly ? tokens.warning : tokens.success,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
