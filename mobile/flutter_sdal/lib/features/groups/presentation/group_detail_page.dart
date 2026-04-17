import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../explore/data/explore_repository.dart';
import '../application/groups_action_controller.dart';
import '../data/groups_repository.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(groupDetailProvider(groupId));
    final postsState = ref.watch(groupPostsProvider(groupId));
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final currentUserId = session?.user?.id ?? 0;
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.groupDetailTitle,
      background: FeatureScaffoldBackground.editorial,
      actions: [
        IconButton(
          onPressed: () {
            ref.invalidate(groupDetailProvider(groupId));
            ref.invalidate(groupPostsProvider(groupId));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const ErrorView(),
        data: (detail) {
          if (detail == null) {
            return Center(child: Text(l10n.groupNotFound));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(groupId));
              ref.invalidate(groupPostsProvider(groupId));
              await ref.read(groupDetailProvider(groupId).future);
              await ref.read(groupPostsProvider(groupId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _GroupHeroSection(
                  detail: detail,
                  coverUrl: detail.group.coverImage.isNotEmpty
                      ? config.resolveUrl(detail.group.coverImage).toString()
                      : '',
                  onToggleJoin: () => _toggleJoin(context, ref, groupId),
                  onRejectInvite: detail.isInvited
                      ? () => _respondInvite(context, ref, action: 'reject')
                      : null,
                  onOpenSettings: detail.canManage && !detail.accessDenied
                      ? () => _openSettingsSheet(context, ref, detail)
                      : null,
                  onOpenInvite: detail.canManage && !detail.accessDenied
                      ? () => _openInviteSheet(
                          context,
                          ref,
                          groupId,
                          excludedIds: {
                            ...detail.members.map((item) => item.id),
                            ...detail.pendingInvites.map((item) => item.id),
                          },
                        )
                      : null,
                  onUpdateCover: detail.canManage && !detail.accessDenied
                      ? () => _pickCover(context, ref)
                      : null,
                ),
                const SizedBox(height: 16),
                if (detail.managers.isNotEmpty) ...[
                  _SectionCard(
                    title: l10n.groupManagersTitle,
                    child: Column(
                      children: [
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
                  if (detail.canManage ||
                      detail.canReviewRequests ||
                      detail.pendingInvites.isNotEmpty) ...[
                    _AdminPanel(detail: detail, groupId: groupId),
                    const SizedBox(height: 16),
                  ],
                  _SectionCard(
                    title: l10n.groupPostsTitle,
                    subtitle: l10n.groupPostsHelper,
                    trailing: (detail.isMember || detail.canManage)
                        ? FilledButton.tonal(
                            onPressed: () =>
                                _openPostSheet(context, ref, groupId),
                            child: Text(l10n.groupCreatePostAction),
                          )
                        : null,
                    child: postsState.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => const ErrorView(compact: true),
                      data: (posts) => posts.isEmpty
                          ? Text(l10n.groupNoPosts)
                          : Column(
                              children: [
                                for (final post in posts) ...[
                                  _GroupPostTile(post: post),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TimelineSection(
                    detail: detail,
                    onAddEvent: detail.canManage
                        ? () => _openEventSheet(context, ref, groupId)
                        : null,
                    onAddAnnouncement: detail.canManage
                        ? () => _openAnnouncementSheet(context, ref, groupId)
                        : null,
                    onDeleteEvent: (eventId) =>
                        _deleteEvent(context, ref, eventId),
                    onDeleteAnnouncement: (announcementId) =>
                        _deleteAnnouncement(context, ref, announcementId),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: l10n.groupMembersTitle,
                    subtitle: l10n.groupMembersHelper,
                    child: Column(
                      children: [
                        for (final member in detail.members)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MemberRow(
                              person: member,
                              canChangeRole:
                                  member.id != currentUserId &&
                                  (detail.myRole == 'owner' ||
                                      detail.myRole == 'admin'),
                              onRoleChanged: (role) async {
                                final ok = await ref
                                    .read(
                                      groupsActionControllerProvider.notifier,
                                    )
                                    .changeRole(
                                      groupId: groupId,
                                      userId: member.id,
                                      role: role,
                                    );
                                if (ok) {
                                  ref.invalidate(groupDetailProvider(groupId));
                                  ref.invalidate(groupPostsProvider(groupId));
                                }
                              },
                            ),
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
    final l10n = context.l10n;
    return _SectionCard(
      title: l10n.groupContentMembersOnlyTitle,
      child: Text(
        detail.accessMessage.isNotEmpty
            ? detail.accessMessage
            : l10n.groupContentMembersOnlyBody,
      ),
    );
  }
}

String _detailJoinLabel(BuildContext context, GroupDetail detail) {
  final l10n = context.l10n;
  if (detail.isMember) return l10n.groupDetailLeaveAction;
  if (detail.isPending) return l10n.groupDetailWithdrawRequestAction;
  if (detail.isInvited) return l10n.groupDetailAcceptInviteAction;
  return l10n.groupDetailJoinAction;
}

Future<void> _toggleJoin(
  BuildContext context,
  WidgetRef ref,
  int groupId,
) async {
  final detail = ref.read(groupDetailProvider(groupId)).value;
  final membershipStatus = detail?.membershipStatus ?? '';
  final notifier = ref.read(groupsActionControllerProvider.notifier);
  if (membershipStatus == 'member') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruptan ayrılsın mı?'),
        content: const Text(
          'Üyeliğiniz kaldırılacak. Daha sonra tekrar katılım isteği göndermeniz gerekebilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final status = await notifier.leaveGroup(groupId);
    if (status == null) return;
  } else {
    final status = await notifier.toggleJoin(groupId);
    if (status == null) return;
  }
  ref.invalidate(groupsListProvider);
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(groupPostsProvider(groupId));
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
  ref.invalidate(groupPostsProvider(groupId));
}

Future<void> _pickCover(BuildContext context, WidgetRef ref) async {
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final file = await pickAndCropImage(
    context,
    source: ImageSource.gallery,
    aspectPreset: CropAspectPreset.wide169,
    imageQuality: 94,
    maxWidth: 2600,
    title: 'Grup kapağını kırp',
  );
  if (file == null) return;
  final ok = await ref
      .read(groupsActionControllerProvider.notifier)
      .uploadCover(groupId: groupId, imageFile: file);
  if (!ok) return;
  ref.invalidate(groupsListProvider);
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(groupPostsProvider(groupId));
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

Future<void> _openInviteSheet(
  BuildContext context,
  WidgetRef ref,
  int groupId, {
  required Set<int> excludedIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _InviteMembersSheet(groupId: groupId, excludedIds: excludedIds),
  );
}

class _GroupHeroSection extends StatelessWidget {
  const _GroupHeroSection({
    required this.detail,
    required this.coverUrl,
    required this.onToggleJoin,
    this.onRejectInvite,
    this.onOpenSettings,
    this.onOpenInvite,
    this.onUpdateCover,
  });

  final GroupDetail detail;
  final String coverUrl;
  final VoidCallback onToggleJoin;
  final VoidCallback? onRejectInvite;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInvite;
  final VoidCallback? onUpdateCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelRaised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl.isNotEmpty) ...[
              SdalNetworkImage(
                imageUrl: coverUrl,
                height: 210,
                width: double.infinity,
                borderRadius: BorderRadius.circular(20),
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 18),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.group.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (detail.group.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          detail.group.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(
                  background: detail.group.visibility == 'members_only'
                      ? tokens.warningMuted
                      : tokens.successMuted,
                  foreground: detail.group.visibility == 'members_only'
                      ? tokens.warning
                      : tokens.success,
                  label: detail.group.visibility == 'members_only'
                      ? l10n.groupVisibilityPrivate
                      : l10n.groupVisibilityPublic,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(
                  label: l10n.groupsMembersCount(detail.group.membersCount),
                ),
                if (detail.myRole.isNotEmpty) _DetailChip(label: detail.myRole),
                if (detail.group.showContactHint)
                  _DetailChip(label: l10n.groupManagersVisible),
              ],
            ),
            if (detail.accessDenied && detail.accessMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                detail.accessMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: onToggleJoin,
                  child: Text(_detailJoinLabel(context, detail)),
                ),
                if (onRejectInvite != null)
                  FilledButton.tonal(
                    onPressed: onRejectInvite,
                    child: Text(l10n.groupRejectInviteAction),
                  ),
                if (onOpenSettings != null)
                  FilledButton.tonal(
                    onPressed: onOpenSettings,
                    child: Text(l10n.groupSettingsAction),
                  ),
                if (onOpenInvite != null)
                  OutlinedButton(
                    onPressed: onOpenInvite,
                    child: Text(l10n.groupInviteMembersAction),
                  ),
                if (onUpdateCover != null)
                  OutlinedButton(
                    onPressed: onUpdateCover,
                    child: Text(l10n.groupUpdateCoverAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AdminPanel extends ConsumerWidget {
  const _AdminPanel({required this.detail, required this.groupId});

  final GroupDetail detail;
  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded:
              detail.joinRequests.isNotEmpty ||
              detail.pendingInvites.isNotEmpty,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            l10n.groupAdminPanelTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(
            l10n.groupAdminPanelHelper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          children: [
            const SizedBox(height: 8),
            if (detail.canReviewRequests && detail.joinRequests.isNotEmpty) ...[
              _RequestsCard(groupId: groupId, items: detail.joinRequests),
              const SizedBox(height: 12),
            ],
            if (detail.pendingInvites.isNotEmpty) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.panelMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.panelBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.groupPendingInvitesTitle,
                        style: Theme.of(context).textTheme.titleMedium,
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.detail,
    required this.onDeleteEvent,
    required this.onDeleteAnnouncement,
    this.onAddEvent,
    this.onAddAnnouncement,
  });

  final GroupDetail detail;
  final VoidCallback? onAddEvent;
  final VoidCallback? onAddAnnouncement;
  final ValueChanged<int> onDeleteEvent;
  final ValueChanged<int> onDeleteAnnouncement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return _SectionCard(
      title: l10n.groupTimelineTitle,
      subtitle: l10n.groupTimelineHelper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.groupEventsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onAddEvent != null)
                FilledButton.tonal(
                  onPressed: onAddEvent,
                  child: Text(l10n.groupAddEventAction),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (detail.groupEvents.isEmpty)
            Text(l10n.groupNoEvents)
          else
            for (final event in detail.groupEvents) ...[
              _GroupEventTile(
                event: event,
                canDelete: detail.canManage,
                onDelete: () => onDeleteEvent(event.id),
              ),
              const SizedBox(height: 12),
            ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(color: tokens.panelBorder),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.groupAnnouncementsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onAddAnnouncement != null)
                FilledButton.tonal(
                  onPressed: onAddAnnouncement,
                  child: Text(l10n.groupAddAnnouncementAction),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (detail.groupAnnouncements.isEmpty)
            Text(l10n.groupNoAnnouncements)
          else
            for (final item in detail.groupAnnouncements) ...[
              _GroupAnnouncementTile(
                item: item,
                canDelete: detail.canManage,
                onDelete: () => onDeleteAnnouncement(item.id),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
        border: Border.all(color: tokens.panelBorder),
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.person,
    required this.canChangeRole,
    required this.onRoleChanged,
  });

  final GroupPerson person;
  final bool canChangeRole;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(child: _PersonRow(person: person)),
        if (canChangeRole)
          PopupMenuButton<String>(
            onSelected: onRoleChanged,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'member',
                child: Text(l10n.groupRoleMakeMember),
              ),
              PopupMenuItem(
                value: 'moderator',
                child: Text(l10n.groupRoleMakeModerator),
              ),
              PopupMenuItem(
                value: 'owner',
                child: Text(l10n.groupRoleMakeOwner),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.more_horiz),
            ),
          ),
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
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupJoinRequestsTitle,
              style: Theme.of(context).textTheme.titleMedium,
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
                      child: Text(l10n.rejectAction),
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
                      child: Text(l10n.approveAction),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteMembersSheet extends ConsumerStatefulWidget {
  const _InviteMembersSheet({required this.groupId, required this.excludedIds});

  final int groupId;
  final Set<int> excludedIds;

  @override
  ConsumerState<_InviteMembersSheet> createState() =>
      _InviteMembersSheetState();
}

class _InviteMembersSheetState extends ConsumerState<_InviteMembersSheet> {
  final _searchController = TextEditingController();
  final Set<int> _selectedIds = <int>{};
  List<MemberSummary> _results = const <MemberSummary>[];
  bool _loading = false;
  int _searchToken = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    final token = ++_searchToken;
    if (query.isEmpty) {
      setState(() {
        _results = const <MemberSummary>[];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final items = await ref
        .read(exploreRepositoryProvider)
        .fetchMembers(term: query);
    if (!mounted || token != _searchToken) return;
    setState(() {
      _results = items
          .where((item) => !widget.excludedIds.contains(item.id))
          .toList(growable: false);
      _loading = false;
    });
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
            l10n.groupInviteMembersAction,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: l10n.groupInviteSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.groupSelectedCount(_selectedIds.length)),
          ],
          SizedBox(
            height: 260,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _results[index];
                final selected = _selectedIds.contains(item.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (value) {
                    setState(() {
                      if (value ?? false) {
                        _selectedIds.add(item.id);
                      } else {
                        _selectedIds.remove(item.id);
                      }
                    });
                  },
                  title: Text(item.name),
                  subtitle: item.handle.isNotEmpty
                      ? Text('@${item.handle}')
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isLoading || _selectedIds.isEmpty
                  ? null
                  : () async {
                      final sent = await ref
                          .read(groupsActionControllerProvider.notifier)
                          .inviteMembers(
                            groupId: widget.groupId,
                            userIds: _selectedIds.toList(growable: false),
                          );
                      if (!context.mounted || sent == null) return;
                      ref.invalidate(groupDetailProvider(widget.groupId));
                      ref.invalidate(groupsListProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.groupInvitesSent(sent))),
                      );
                      Navigator.of(context).pop();
                    },
              child: Text(
                state.isLoading
                    ? l10n.submitInProgress
                    : l10n.groupInviteMembersAction,
              ),
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
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.panelBorder),
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
              SdalNetworkImage(
                imageUrl: config.resolveUrl(post.image).toString(),
                borderRadius: BorderRadius.circular(16),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _DetailChip(label: l10n.groupLikesCount(post.likeCount)),
                _DetailChip(label: l10n.groupCommentsCount(post.commentCount)),
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
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.panelBorder),
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
              Text(l10n.groupEventLocationValue(event.location)),
            ],
            if (event.startsAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l10n.groupEventStartsAtValue(event.startsAt)),
            ],
            if (event.endsAt.isNotEmpty)
              Text(l10n.groupEventEndsAtValue(event.endsAt)),
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
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.panelBorder),
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
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.groupSettingsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            items: [
              DropdownMenuItem(
                value: 'public',
                child: Text(l10n.groupVisibilityPublicOption),
              ),
              DropdownMenuItem(
                value: 'members_only',
                child: Text(l10n.groupVisibilityMembersOnlyOption),
              ),
            ],
            onChanged: (value) =>
                setState(() => _visibility = value ?? 'public'),
            decoration: InputDecoration(labelText: l10n.groupVisibilityLabel),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.groupVisibilityHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showContactHint,
            onChanged: (value) => setState(() => _showContactHint = value),
            title: Text(l10n.groupManagersVisibilityTitle),
            subtitle: Text(l10n.groupManagersVisibilityHint),
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
              child: Text(
                state.isLoading ? l10n.submitInProgress : l10n.saveAction,
              ),
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
  File? _imageFile;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsActionControllerProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupNewPostTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.groupsDescriptionLabel,
                hintText: l10n.groupPostHint,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final file = await pickAndCropImage(
                  context,
                  source: ImageSource.gallery,
                  aspectPreset: CropAspectPreset.portrait45,
                  imageQuality: 92,
                  maxWidth: 2200,
                  title: 'Gönderi görselini kırp',
                );
                if (file != null) setState(() => _imageFile = file);
              },
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _imageFile == null
                    ? l10n.groupAddImageAction
                    : _imageFile!.path.split('/').last,
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
                              imageFile: _imageFile,
                            );
                        if (!context.mounted || !ok) return;
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        ref.invalidate(groupPostsProvider(widget.groupId));
                        Navigator.of(context).pop();
                      },
                child: Text(
                  state.isLoading
                      ? l10n.submitInProgress
                      : l10n.groupCreatePostAction,
                ),
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
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupNewEventTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.groupEventTitleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.groupEventDescriptionLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.groupEventLocationLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startsAtController,
              decoration: InputDecoration(
                labelText: l10n.groupEventStartsAtLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endsAtController,
              decoration: InputDecoration(
                labelText: l10n.groupEventEndsAtLabel,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.groupEventScheduleHint,
              style: Theme.of(context).textTheme.bodySmall,
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
                        ref.invalidate(groupPostsProvider(widget.groupId));
                        Navigator.of(context).pop();
                      },
                child: Text(
                  state.isLoading
                      ? l10n.submitInProgress
                      : l10n.groupCreateEventAction,
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
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.groupNewAnnouncementTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.groupAnnouncementTitleLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.groupAnnouncementBodyLabel,
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
                          .createAnnouncement(
                            groupId: widget.groupId,
                            title: _titleController.text.trim(),
                            body: _bodyController.text.trim(),
                          );
                      if (!context.mounted || !ok) return;
                      ref.invalidate(groupDetailProvider(widget.groupId));
                      ref.invalidate(groupPostsProvider(widget.groupId));
                      Navigator.of(context).pop();
                    },
              child: Text(
                state.isLoading
                    ? l10n.submitInProgress
                    : l10n.groupCreateAnnouncementAction,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
