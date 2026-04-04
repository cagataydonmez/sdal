import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/groups_action_controller.dart';
import '../data/groups_repository.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(groupDetailProvider(groupId));
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Grup detayi',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(groupDetailProvider(groupId)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Grup bulunamadi.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(groupDetailProvider(groupId).future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.group.coverImage.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            config
                                .resolveUrl(detail.group.coverImage)
                                .toString(),
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              detail.group.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: detail.group.visibility == 'members_only'
                                  ? const Color(0xFFFFF0D5)
                                  : const Color(0xFFE5F7ED),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                detail.group.visibility == 'members_only'
                                    ? 'Ozel'
                                    : 'Herkese acik',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (detail.group.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(detail.group.description),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DetailChip(
                            label: '${detail.group.membersCount} uye',
                          ),
                          if (detail.myRole.isNotEmpty)
                            _DetailChip(label: detail.myRole),
                          if (detail.group.showContactHint)
                            const _DetailChip(label: 'Yoneticiler gorunur'),
                        ],
                      ),
                      if (detail.accessDenied &&
                          detail.accessMessage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          detail.accessMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed: () => _toggleJoin(context, ref, groupId),
                            child: Text(_detailJoinLabel(detail)),
                          ),
                          if (detail.isInvited)
                            FilledButton.tonal(
                              onPressed: () => _respondInvite(
                                context,
                                ref,
                                action: 'reject',
                              ),
                              child: const Text('Daveti reddet'),
                            ),
                          if (detail.canManage && !detail.accessDenied)
                            FilledButton.tonal(
                              onPressed: () =>
                                  _openSettingsSheet(context, ref, detail),
                              child: const Text('Ayarlar'),
                            ),
                          if (detail.canManage && !detail.accessDenied)
                            OutlinedButton(
                              onPressed: () => _pickCover(context, ref),
                              child: const Text('Kapak guncelle'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (detail.managers.isNotEmpty) ...[
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yoneticiler',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        for (final manager in detail.managers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PersonRow(person: manager),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (detail.accessDenied)
                  _buildAccessLimited(context, detail)
                else ...[
                  if (detail.canReviewRequests &&
                      detail.joinRequests.isNotEmpty) ...[
                    _RequestsCard(groupId: groupId, items: detail.joinRequests),
                    const SizedBox(height: 16),
                  ],
                  if (detail.pendingInvites.isNotEmpty) ...[
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bekleyen davetler',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          for (final invite in detail.pendingInvites)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PersonRow(person: invite),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Paylasimlar',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (detail.isMember || detail.canManage)
                              FilledButton.tonal(
                                onPressed: () =>
                                    _openPostSheet(context, ref, groupId),
                                child: const Text('Paylas'),
                              ),
                          ],
                        ),
                        if (detail.posts.isEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Henuz grup paylasimi yok.'),
                        ] else ...[
                          const SizedBox(height: 12),
                          for (final post in detail.posts) ...[
                            _GroupPostTile(post: post),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Etkinlikler',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (detail.canManage)
                              FilledButton.tonal(
                                onPressed: () =>
                                    _openEventSheet(context, ref, groupId),
                                child: const Text('Etkinlik ekle'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (detail.groupEvents.isEmpty)
                          const Text('Bu grup icin planlanmis etkinlik yok.')
                        else
                          for (final event in detail.groupEvents) ...[
                            _GroupEventTile(
                              event: event,
                              canDelete: detail.canManage,
                              onDelete: () =>
                                  _deleteEvent(context, ref, event.id),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Duyurular',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (detail.canManage)
                              FilledButton.tonal(
                                onPressed: () => _openAnnouncementSheet(
                                  context,
                                  ref,
                                  groupId,
                                ),
                                child: const Text('Duyuru ekle'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (detail.groupAnnouncements.isEmpty)
                          const Text('Bu grup icin duyuru yok.')
                        else
                          for (final item in detail.groupAnnouncements) ...[
                            _GroupAnnouncementTile(
                              item: item,
                              canDelete: detail.canManage,
                              onDelete: () =>
                                  _deleteAnnouncement(context, ref, item.id),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uyeler',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        for (final member in detail.members)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PersonRow(person: member),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessLimited(BuildContext context, GroupDetail detail) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Icerik uyeler icin acik',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            detail.accessMessage.isNotEmpty
                ? detail.accessMessage
                : 'Bu grubun icerigini gormek icin uyelik onayi gerekli.',
          ),
        ],
      ),
    );
  }
}

String _detailJoinLabel(GroupDetail detail) {
  if (detail.isMember) return 'Gruptan ayril';
  if (detail.isPending) return 'Talebi geri cek';
  if (detail.isInvited) return 'Daveti kabul et';
  return 'Katilim istegi gonder';
}

Future<void> _toggleJoin(
  BuildContext context,
  WidgetRef ref,
  int groupId,
) async {
  await ref.read(groupsActionControllerProvider.notifier).toggleJoin(groupId);
  ref.invalidate(groupsListProvider);
  ref.invalidate(groupDetailProvider(groupId));
}

Future<void> _respondInvite(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final notifier = ref.read(groupsActionControllerProvider.notifier);
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final ok = await notifier.respondToInvite(groupId: groupId, action: action);
  if (!ok) return;
  ref.invalidate(groupsListProvider);
  ref.invalidate(groupDetailProvider(groupId));
}

Future<void> _pickCover(BuildContext context, WidgetRef ref) async {
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) return;
  final ok = await ref
      .read(groupsActionControllerProvider.notifier)
      .uploadCover(groupId: groupId, imageFile: File(file.path));
  if (!ok) return;
  ref.invalidate(groupsListProvider);
  ref.invalidate(groupDetailProvider(groupId));
}

Future<void> _deleteEvent(
  BuildContext context,
  WidgetRef ref,
  int eventId,
) async {
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final ok = await ref
      .read(groupsActionControllerProvider.notifier)
      .deleteEvent(groupId: groupId, eventId: eventId);
  if (!ok) return;
  ref.invalidate(groupDetailProvider(groupId));
}

Future<void> _deleteAnnouncement(
  BuildContext context,
  WidgetRef ref,
  int announcementId,
) async {
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final ok = await ref
      .read(groupsActionControllerProvider.notifier)
      .deleteAnnouncement(groupId: groupId, announcementId: announcementId);
  if (!ok) return;
  ref.invalidate(groupDetailProvider(groupId));
}

Future<void> _openSettingsSheet(
  BuildContext context,
  WidgetRef ref,
  GroupDetail detail,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SettingsSheet(detail: detail),
  );
}

Future<void> _openPostSheet(BuildContext context, WidgetRef ref, int groupId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PostSheet(groupId: groupId),
  );
}

Future<void> _openEventSheet(BuildContext context, WidgetRef ref, int groupId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EventSheet(groupId: groupId),
  );
}

Future<void> _openAnnouncementSheet(
  BuildContext context,
  WidgetRef ref,
  int groupId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AnnouncementSheet(groupId: groupId),
  );
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

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

class _PersonRow extends ConsumerWidget {
  const _PersonRow({required this.person});

  final GroupPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Row(
      children: [
        RemoteAvatar(
          label: person.displayName,
          imageUrl: config.resolveUrl(person.photo).toString(),
          radius: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.displayName),
              if (person.handle.isNotEmpty)
                Text(
                  '@${person.handle}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (person.role.isNotEmpty) _DetailChip(label: person.role),
      ],
    );
  }
}

class _RequestsCard extends ConsumerWidget {
  const _RequestsCard({required this.groupId, required this.items});

  final int groupId;
  final List<GroupPerson> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Katilim istekleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _PersonRow(person: item)),
                  FilledButton.tonal(
                    onPressed: () async {
                      final ok = await ref
                          .read(groupsActionControllerProvider.notifier)
                          .reviewJoinRequest(
                            groupId: groupId,
                            requestId: item.id,
                            action: 'reject',
                          );
                      if (ok) ref.invalidate(groupDetailProvider(groupId));
                    },
                    child: const Text('Reddet'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final ok = await ref
                          .read(groupsActionControllerProvider.notifier)
                          .reviewJoinRequest(
                            groupId: groupId,
                            requestId: item.id,
                            action: 'approve',
                          );
                      if (ok) ref.invalidate(groupDetailProvider(groupId));
                    },
                    child: const Text('Onayla'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupPostTile extends ConsumerWidget {
  const _GroupPostTile({required this.post});

  final GroupPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RemoteAvatar(
                  label: post.author.displayName,
                  imageUrl: config.resolveUrl(post.author.photo).toString(),
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(post.author.displayName)),
                Text(
                  post.createdAt,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(post.content),
            ],
            if (post.image.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  config.resolveUrl(post.image).toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _DetailChip(label: '${post.likeCount} begeni'),
                _DetailChip(label: '${post.commentCount} yorum'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupEventTile extends StatelessWidget {
  const _GroupEventTile({
    required this.event,
    required this.canDelete,
    required this.onDelete,
  });

  final GroupEventItem event;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (event.description.isNotEmpty) Text(event.description),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Konum: ${event.location}'),
            ],
            if (event.startsAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Baslangic: ${event.startsAt}'),
            ],
            if (event.endsAt.isNotEmpty) Text('Bitis: ${event.endsAt}'),
          ],
        ),
      ),
    );
  }
}

class _GroupAnnouncementTile extends StatelessWidget {
  const _GroupAnnouncementTile({
    required this.item,
    required this.canDelete,
    required this.onDelete,
  });

  final GroupAnnouncementItem item;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (item.body.isNotEmpty) Text(item.body),
            const SizedBox(height: 8),
            Text(item.createdAt, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.detail});

  final GroupDetail detail;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  late String _visibility = widget.detail.group.visibility;
  late bool _showContactHint = widget.detail.group.showContactHint;

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
          Text('Grup ayarlari', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Herkese acik')),
              DropdownMenuItem(
                value: 'members_only',
                child: Text('Yalnizca uyeler'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _visibility = value ?? 'public'),
            decoration: const InputDecoration(labelText: 'Gorunurluk'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showContactHint,
            onChanged: (value) => setState(() => _showContactHint = value),
            title: const Text('Yoneticileri uye olmayanlara da goster'),
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
                          .updateSettings(
                            groupId: widget.detail.group.id,
                            visibility: _visibility,
                            showContactHint: _showContactHint,
                          );
                      if (!context.mounted || !ok) return;
                      ref.invalidate(
                        groupDetailProvider(widget.detail.group.id),
                      );
                      ref.invalidate(groupsListProvider);
                      Navigator.of(context).pop();
                    },
              child: Text(state.isLoading ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostSheet extends ConsumerStatefulWidget {
  const _PostSheet({required this.groupId});

  final int groupId;

  @override
  ConsumerState<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends ConsumerState<_PostSheet> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _imageFile;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsActionControllerProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni paylasim',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Grup icin bir not veya guncelleme yaz',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final file = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (file != null) setState(() => _imageFile = file);
              },
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _imageFile == null ? 'Gorsel ekle' : _imageFile!.name,
              ),
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
                            .createPost(
                              groupId: widget.groupId,
                              content: _contentController.text.trim(),
                              imageFile: _imageFile == null
                                  ? null
                                  : File(_imageFile!.path),
                            );
                        if (!context.mounted || !ok) return;
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        Navigator.of(context).pop();
                      },
                child: Text(state.isLoading ? 'Gonderiliyor...' : 'Paylas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({required this.groupId});

  final int groupId;

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _startsAtController = TextEditingController();
  final _endsAtController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsActionControllerProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Baslik'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Aciklama'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Konum'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startsAtController,
              decoration: const InputDecoration(labelText: 'Baslangic tarihi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endsAtController,
              decoration: const InputDecoration(labelText: 'Bitis tarihi'),
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
                            .createEvent(
                              groupId: widget.groupId,
                              title: _titleController.text.trim(),
                              description: _descriptionController.text.trim(),
                              location: _locationController.text.trim(),
                              startsAt: _startsAtController.text.trim(),
                              endsAt: _endsAtController.text.trim(),
                            );
                        if (!context.mounted || !ok) return;
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        Navigator.of(context).pop();
                      },
                child: Text(
                  state.isLoading ? 'Kaydediliyor...' : 'Etkinlik ekle',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementSheet extends ConsumerStatefulWidget {
  const _AnnouncementSheet({required this.groupId});

  final int groupId;

  @override
  ConsumerState<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends ConsumerState<_AnnouncementSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
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
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Baslik'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Icerik'),
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
                          .createAnnouncement(
                            groupId: widget.groupId,
                            title: _titleController.text.trim(),
                            body: _bodyController.text.trim(),
                          );
                      if (!context.mounted || !ok) return;
                      ref.invalidate(groupDetailProvider(widget.groupId));
                      Navigator.of(context).pop();
                    },
              child: Text(state.isLoading ? 'Kaydediliyor...' : 'Duyuru ekle'),
            ),
          ),
        ],
      ),
    );
  }
}
