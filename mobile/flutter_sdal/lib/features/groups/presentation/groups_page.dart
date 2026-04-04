import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/groups_action_controller.dart';
import '../data/groups_repository.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(groupsListProvider);
    final config = ref.watch(appConfigProvider);
    return FeatureScaffold(
      title: 'Gruplar',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(groupsListProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Yeni grup'),
      ),
      child: groupsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (groups) => RefreshIndicator(
          onRefresh: () => ref.refresh(groupsListProvider.future),
          child: ListView.separated(
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            config.resolveUrl(group.coverImage).toString(),
                            height: 164,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
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
                          _MetaChip(label: '${group.membersCount} uye'),
                          if (group.membershipStatus == 'pending')
                            const _MetaChip(label: 'Onay bekliyor'),
                          if (group.membershipStatus == 'invited')
                            const _MetaChip(label: 'Davet bekliyor'),
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
                            child: const Text('Ac'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () =>
                                _toggleJoin(context, ref, group.id),
                            child: Text(_joinLabel(group.membershipStatus)),
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
  final status = await ref
      .read(groupsActionControllerProvider.notifier)
      .toggleJoin(groupId);
  ref.invalidate(groupsListProvider);
  if (!context.mounted) return;
  if (status == null) {
    final message = ref.read(groupsActionControllerProvider).message;
    if ((message ?? '').isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message!)));
    }
  }
}

String _joinLabel(String membershipStatus) {
  switch (membershipStatus) {
    case 'member':
      return 'Ayril';
    case 'pending':
      return 'Talebi cek';
    case 'invited':
      return 'Daveti kabul et';
    default:
      return 'Katil';
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yeni grup', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Grup adi'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Aciklama'),
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
              child: Text(state.isLoading ? 'Olusturuluyor...' : 'Olustur'),
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
        color: const Color(0xFFF0F5FA),
        borderRadius: BorderRadius.circular(999),
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
    final membersOnly = visibility == 'members_only';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: membersOnly ? const Color(0xFFFFF0D5) : const Color(0xFFE5F7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(membersOnly ? 'Ozel' : 'Herkese acik'),
      ),
    );
  }
}
