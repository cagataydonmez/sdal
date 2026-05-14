import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../explore/data/explore_repository.dart';
import '../../feed/application/feed_action_controller.dart';
import '../../community/presentation/entity_action_menu.dart';
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
                  onToggleJoin: detail.group.isCohortGroup
                      ? null
                      : () => _toggleJoin(context, ref, groupId),
                  onRejectInvite:
                      !detail.group.isCohortGroup && detail.isInvited
                      ? () => _respondInvite(context, ref, action: 'reject')
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
                  if (!detail.group.isCohortGroup &&
                      detail.canManage &&
                      !detail.accessDenied) ...[
                    _AdminPanel(
                      detail: detail,
                      groupId: groupId,
                      onOpenSettings: () =>
                          _openSettingsSheet(context, ref, detail),
                      onOpenInvite: () => _openInviteSheet(
                        context,
                        ref,
                        groupId,
                        excludedIds: {
                          ...detail.members.map((item) => item.id),
                          ...detail.pendingInvites.map((item) => item.id),
                        },
                      ),
                    ),
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
                                  _GroupPostTile(
                                    post: post,
                                    groupId: groupId,
                                    canManage: detail.canManage,
                                  ),
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
                    onOpenEvent: (eventId) =>
                        context.push('/groups/$groupId/events/$eventId'),
                    onDeleteEvent: (eventId) =>
                        _deleteEvent(context, ref, eventId),
                    onEditEvent: detail.canManage
                        ? (event) => _openEventSheet(
                            context,
                            ref,
                            groupId,
                            existing: event,
                          )
                        : null,
                    onUnpublishEvent: (eventId) =>
                        _unpublishEvent(context, ref, eventId),
                    onOpenAnnouncement: (announcementId) => context.push(
                      '/groups/$groupId/announcements/$announcementId',
                    ),
                    onDeleteAnnouncement: (announcementId) =>
                        _deleteAnnouncement(context, ref, announcementId),
                    onEditAnnouncement: detail.canManage
                        ? (announcement) => _openAnnouncementSheet(
                            context,
                            ref,
                            groupId,
                            existing: announcement,
                          )
                        : null,
                    onUnpublishAnnouncement: (announcementId) =>
                        _unpublishAnnouncement(context, ref, announcementId),
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
    aspectPreset: CropAspectPreset.wide169,
    title: 'Grup kapağını hazırla',
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

Future<void> _unpublishEvent(
  BuildContext context,
  WidgetRef ref,
  int eventId,
) async {
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final ok = await ref
      .read(groupsActionControllerProvider.notifier)
      .setEventPublished(groupId: groupId, eventId: eventId, publish: false);
  if (!ok) return;
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(groupPostsProvider(groupId));
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

Future<void> _unpublishAnnouncement(
  BuildContext context,
  WidgetRef ref,
  int announcementId,
) async {
  final route = GoRouterState.of(context);
  final groupId = int.tryParse(route.pathParameters['groupId'] ?? '') ?? 0;
  if (groupId <= 0) return;
  final ok = await ref
      .read(groupsActionControllerProvider.notifier)
      .setAnnouncementPublished(
        groupId: groupId,
        announcementId: announcementId,
        publish: false,
      );
  if (!ok) return;
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(groupPostsProvider(groupId));
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

Future<void> _openEventSheet(
  BuildContext context,
  WidgetRef ref,
  int groupId, {
  GroupEventItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EventSheet(groupId: groupId, existing: existing),
  );
}

Future<void> _openAnnouncementSheet(
  BuildContext context,
  WidgetRef ref,
  int groupId, {
  GroupAnnouncementItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _AnnouncementSheet(groupId: groupId, existing: existing),
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
    this.onToggleJoin,
    this.onRejectInvite,
    this.onUpdateCover,
  });

  final GroupDetail detail;
  final String coverUrl;
  final VoidCallback? onToggleJoin;
  final VoidCallback? onRejectInvite;
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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    SdalNetworkImage(
                      imageUrl: coverUrl,
                      height: 210,
                      width: double.infinity,
                      borderRadius: BorderRadius.zero,
                      fit: BoxFit.cover,
                    ),
                    if (detail.group.isCohortGroup)
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: _CohortYearBadge(
                          cohortYear: detail.group.cohortYear,
                        ),
                      ),
                  ],
                ),
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
            if (onToggleJoin != null ||
                onRejectInvite != null ||
                onUpdateCover != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (onToggleJoin != null)
                    FilledButton(
                      onPressed: onToggleJoin,
                      child: Text(_detailJoinLabel(context, detail)),
                    ),
                  if (onRejectInvite != null)
                    FilledButton.tonal(
                      onPressed: onRejectInvite,
                      child: Text(l10n.groupRejectInviteAction),
                    ),
                  if (onUpdateCover != null)
                    OutlinedButton(
                      onPressed: onUpdateCover,
                      child: Text(l10n.groupUpdateCoverAction),
                    ),
                ],
              ),
            ],
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
  const _AdminPanel({
    required this.detail,
    required this.groupId,
    this.onOpenSettings,
    this.onOpenInvite,
  });

  final GroupDetail detail;
  final int groupId;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final approvalSettingsState = ref.watch(
      groupContentApprovalSettingsProvider(groupId),
    );
    final approvalsState = ref.watch(groupContentApprovalsProvider(groupId));
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
            if (onOpenSettings != null || onOpenInvite != null) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
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
                ],
              ),
              const SizedBox(height: 12),
            ],
            _GroupContentApprovalPanel(
              groupId: groupId,
              settingsState: approvalSettingsState,
              approvalsState: approvalsState,
            ),
            const SizedBox(height: 12),
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

const _groupApprovalTypes = <String>[
  'group_post',
  'group_event',
  'group_announcement',
];

String _groupApprovalLabel(String type) {
  switch (type) {
    case 'group_post':
      return 'Post';
    case 'group_event':
      return 'Etkinlik';
    case 'group_announcement':
      return 'Duyuru';
    default:
      return type;
  }
}

class _GroupContentApprovalPanel extends ConsumerWidget {
  const _GroupContentApprovalPanel({
    required this.groupId,
    required this.settingsState,
    required this.approvalsState,
  });

  final int groupId;
  final AsyncValue<List<GroupContentApprovalSetting>> settingsState;
  final AsyncValue<List<GroupContentApprovalItem>> approvalsState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'İçerik onayı',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            settingsState.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (settings) => Column(
                children: [
                  for (final type in _groupApprovalTypes)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_groupApprovalLabel(type)),
                      value:
                          settings
                              .where((item) => item.entityType == type)
                              .lastOrNull
                              ?.approvalRequired ??
                          false,
                      onChanged: (value) async {
                        final result = await ref
                            .read(groupsRepositoryProvider)
                            .updateContentApprovalSetting(
                              groupId: groupId,
                              entityType: type,
                              approvalRequired: value,
                            );
                        ref.invalidate(
                          groupContentApprovalSettingsProvider(groupId),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.ok
                                  ? 'Onay ayarı kaydedildi.'
                                  : 'Onay ayarı kaydedilemedi.',
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            approvalsState.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (items) {
                if (items.isEmpty) return const Text('Bekleyen içerik yok.');
                return Column(
                  children: [
                    for (final item in items)
                      _GroupApprovalTile(groupId: groupId, item: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupApprovalTile extends ConsumerWidget {
  const _GroupApprovalTile({required this.groupId, required this.item});

  final int groupId;
  final GroupContentApprovalItem item;

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String status, {
    bool askNote = false,
  }) async {
    var note = '';
    if (askNote) {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İnceleme notu'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Not'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Gönder'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (value == null) return;
      note = value;
    }
    final result = await ref
        .read(groupsRepositoryProvider)
        .reviewContentApproval(
          groupId: groupId,
          entityType: item.entityType,
          entityId: item.id,
          status: status,
          note: note,
        );
    ref.invalidate(groupContentApprovalsProvider(groupId));
    ref.invalidate(groupDetailProvider(groupId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'İnceleme kaydedildi.' : 'İşlem başarısız.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).sdal;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.panelRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.typeLabel} · ${item.title}'),
          if (item.body.trim().isNotEmpty)
            Text(
              item.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    _review(context, ref, 'changes_requested', askNote: true),
                child: const Text('Düzenleme iste'),
              ),
              TextButton(
                onPressed: () =>
                    _review(context, ref, 'rejected', askNote: true),
                child: const Text('Reddet'),
              ),
              FilledButton(
                onPressed: () => _review(context, ref, 'approved'),
                child: const Text('Onayla'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.detail,
    required this.onOpenEvent,
    required this.onDeleteEvent,
    required this.onEditEvent,
    required this.onUnpublishEvent,
    required this.onOpenAnnouncement,
    required this.onDeleteAnnouncement,
    required this.onEditAnnouncement,
    required this.onUnpublishAnnouncement,
    this.onAddEvent,
    this.onAddAnnouncement,
  });

  final GroupDetail detail;
  final VoidCallback? onAddEvent;
  final VoidCallback? onAddAnnouncement;
  final ValueChanged<int> onOpenEvent;
  final ValueChanged<int> onDeleteEvent;
  final ValueChanged<GroupEventItem>? onEditEvent;
  final ValueChanged<int> onUnpublishEvent;
  final ValueChanged<int> onOpenAnnouncement;
  final ValueChanged<int> onDeleteAnnouncement;
  final ValueChanged<GroupAnnouncementItem>? onEditAnnouncement;
  final ValueChanged<int> onUnpublishAnnouncement;

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
                onOpen: () => onOpenEvent(event.id),
                onEdit: onEditEvent == null ? null : () => onEditEvent!(event),
                onUnpublish: () => onUnpublishEvent(event.id),
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
                onOpen: () => onOpenAnnouncement(item.id),
                onEdit: onEditAnnouncement == null
                    ? null
                    : () => onEditAnnouncement!(item),
                onUnpublish: () => onUnpublishAnnouncement(item.id),
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

class _GroupPostTile extends ConsumerStatefulWidget {
  const _GroupPostTile({
    required this.post,
    required this.groupId,
    required this.canManage,
  });

  final GroupPost post;
  final int groupId;
  final bool canManage;

  @override
  ConsumerState<_GroupPostTile> createState() => _GroupPostTileState();
}

class _GroupPostTileState extends ConsumerState<_GroupPostTile> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
    _likeCount = widget.post.likeCount;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    await ref
        .read(feedActionControllerProvider.notifier)
        .toggleLikeForPost(widget.post.id);
    if (!mounted) return;
    final actionState = ref.read(feedActionControllerProvider);
    if (actionState.isError) {
      setState(() {
        _liked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    final post = widget.post;

    if (post.isEntityPost) {
      final isEvent =
          post.postType == 'group_event' || post.postType == 'event';
      final kind = isEvent
          ? EntityActionKind.groupEvent
          : EntityActionKind.groupAnnouncement;
      final lines = post.content
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      final titleLine = lines.isNotEmpty ? lines.first : '';
      final excerptLines = lines.skip(1).join(' ');
      final entityId = post.entityId ?? post.id;
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isEvent) {
            context.push('/groups/${widget.groupId}/events/$entityId');
          } else {
            context.push('/groups/${widget.groupId}/announcements/$entityId');
          }
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isEvent ? tokens.warningMuted : tokens.successMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEvent
                  ? tokens.warning.withAlpha(60)
                  : tokens.success.withAlpha(60),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEvent ? '📅' : '📢',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (titleLine.isNotEmpty)
                            Text(
                              titleLine,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          if (excerptLines.isNotEmpty)
                            Text(
                              excerptLines,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (widget.canManage && post.entityId != null) ...[
                      EntityActionMenu(
                        kind: kind,
                        onUnpublish: () async {
                          final ok = isEvent
                              ? await ref
                                    .read(
                                      groupsActionControllerProvider.notifier,
                                    )
                                    .setEventPublished(
                                      groupId: widget.groupId,
                                      eventId: post.entityId!,
                                      publish: false,
                                    )
                              : await ref
                                    .read(
                                      groupsActionControllerProvider.notifier,
                                    )
                                    .setAnnouncementPublished(
                                      groupId: widget.groupId,
                                      announcementId: post.entityId!,
                                      publish: false,
                                    );
                          if (ok) {
                            ref.invalidate(groupPostsProvider(widget.groupId));
                          }
                        },
                        onDelete: () async {
                          final ok = isEvent
                              ? await ref
                                    .read(
                                      groupsActionControllerProvider.notifier,
                                    )
                                    .deleteEvent(
                                      groupId: widget.groupId,
                                      eventId: post.entityId!,
                                    )
                              : await ref
                                    .read(
                                      groupsActionControllerProvider.notifier,
                                    )
                                    .deleteAnnouncement(
                                      groupId: widget.groupId,
                                      announcementId: post.entityId!,
                                    );
                          if (ok) {
                            ref.invalidate(groupPostsProvider(widget.groupId));
                          }
                        },
                      ),
                    ] else
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isEvent ? tokens.warning : tokens.success,
                      ),
                  ],
                ),
                if (post.image.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SdalNetworkImage(
                    imageUrl: post.image,
                    height: 150,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(14),
                    fit: BoxFit.cover,
                    errorFallback: const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/posts/${post.id}'),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (post.author.handle.isNotEmpty)
                          Text(
                            '@${post.author.handle}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    post.createdAt,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _PostMetricPill(
                    icon: _liked ? Icons.favorite : Icons.favorite_border,
                    label: '$_likeCount',
                    active: _liked,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 8),
                  _PostMetricPill(
                    icon: Icons.chat_bubble_outline,
                    label: '${post.commentCount}',
                    onTap: () => context.push('/posts/${post.id}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMetricPill extends StatelessWidget {
  const _PostMetricPill({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return InkWell(
      borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? tokens.accentMuted : tokens.panelRaised,
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? tokens.accent : null),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
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
    required this.onOpen,
    this.onEdit,
    required this.onUnpublish,
    required this.onDelete,
  });

  final GroupEventItem event;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback onUnpublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: DecoratedBox(
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
                      EntityActionMenu(
                        kind: EntityActionKind.groupEvent,
                        onEdit: onEdit == null ? null : () async => onEdit!(),
                        onUnpublish: () async => onUnpublish(),
                        onDelete: () async => onDelete(),
                      ),
                  ],
                ),
                if (event.image.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SdalNetworkImage(
                    imageUrl: event.image,
                    height: 150,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    fit: BoxFit.cover,
                    errorFallback: const SizedBox.shrink(),
                  ),
                ],
                if (event.description.isNotEmpty) Text(event.description),
                if (event.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l10n.groupEventLocationValue(event.location)),
                ],
                if (event.startsAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.groupEventStartsAtValue(
                      formatSdalTimestamp(context, event.startsAt),
                    ),
                  ),
                ],
                if (event.endsAt.isNotEmpty)
                  Text(
                    l10n.groupEventEndsAtValue(
                      formatSdalTimestamp(context, event.endsAt),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupAnnouncementTile extends StatelessWidget {
  const _GroupAnnouncementTile({
    required this.item,
    required this.canDelete,
    required this.onOpen,
    this.onEdit,
    required this.onUnpublish,
    required this.onDelete,
  });

  final GroupAnnouncementItem item;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback onUnpublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: DecoratedBox(
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
                      EntityActionMenu(
                        kind: EntityActionKind.groupAnnouncement,
                        onEdit: onEdit == null ? null : () async => onEdit!(),
                        onUnpublish: () async => onUnpublish(),
                        onDelete: () async => onDelete(),
                      ),
                  ],
                ),
                if (item.image.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SdalNetworkImage(
                    imageUrl: item.image,
                    height: 150,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    fit: BoxFit.cover,
                    errorFallback: const SizedBox.shrink(),
                  ),
                ],
                if (item.body.isNotEmpty) Text(item.body),
                const SizedBox(height: 8),
                Text(
                  formatSdalTimestamp(context, item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CohortYearBadge extends StatelessWidget {
  const _CohortYearBadge({required this.cohortYear});

  final String cohortYear;

  @override
  Widget build(BuildContext context) {
    final label = cohortYear == '9999' ? 'Öğretmenler' : cohortYear;
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.4,
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
                  aspectPreset: CropAspectPreset.portrait45,
                  title: 'Gönderi görselini hazırla',
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
  const _EventSheet({required this.groupId, this.existing});

  final int groupId;
  final GroupEventItem? existing;

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _startsAtController = TextEditingController();
  final _endsAtController = TextEditingController();
  File? _imageFile;
  bool _publishNow = true;
  bool _showInFeed = true;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _titleController.text = existing.title;
    _descriptionController.text = existing.description;
    _locationController.text = existing.location;
    _startsAtController.text = existing.startsAt;
    _endsAtController.text = existing.endsAt;
  }

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
              _isEditing ? 'Etkinliği düzenle' : l10n.groupNewEventTitle,
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
              readOnly: true,
              onTap: state.isLoading
                  ? null
                  : () => _pickDateTime(_startsAtController),
              decoration: InputDecoration(
                labelText: l10n.groupEventStartsAtLabel,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endsAtController,
              readOnly: true,
              onTap: state.isLoading
                  ? null
                  : () => _pickDateTime(_endsAtController),
              decoration: InputDecoration(
                labelText: l10n.groupEventEndsAtLabel,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.groupEventScheduleHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _imageFile == null && widget.existing?.image.isEmpty != false
                    ? 'Görsel ekle'
                    : 'Görsel değiştir',
              ),
            ),
            if (_imageFile != null ||
                (widget.existing?.image.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                SdalNetworkImage(
                  imageUrl: widget.existing!.image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  errorFallback: const SizedBox.shrink(),
                ),
            ],
            if (!_isEditing) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hemen yayınla'),
                subtitle: Text(
                  _publishNow
                      ? 'Etkinlik yayın akışına hazırlanacak'
                      : 'Etkinlik taslaklara kaydedilecek',
                ),
                value: _publishNow,
                onChanged: state.isLoading
                    ? null
                    : (v) => setState(() => _publishNow = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Topluluk akışında göster'),
                subtitle: const Text('Etkinlik ana akışta herkese görünsün'),
                value: _showInFeed,
                onChanged: state.isLoading || !_publishNow
                    ? null
                    : (v) => setState(() => _showInFeed = v),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final controller = ref.read(
                          groupsActionControllerProvider.notifier,
                        );
                        final ok = _isEditing
                            ? await controller.updateEvent(
                                groupId: widget.groupId,
                                eventId: widget.existing!.id,
                                title: _titleController.text.trim(),
                                description: _descriptionController.text.trim(),
                                location: _locationController.text.trim(),
                                startsAt: _startsAtController.text.trim(),
                                endsAt: _endsAtController.text.trim(),
                                imageFile: _imageFile,
                              )
                            : await controller.createEvent(
                                groupId: widget.groupId,
                                title: _titleController.text.trim(),
                                description: _descriptionController.text.trim(),
                                location: _locationController.text.trim(),
                                startsAt: _startsAtController.text.trim(),
                                endsAt: _endsAtController.text.trim(),
                                imageFile: _imageFile,
                                showInFeed: _showInFeed,
                                publish: _publishNow,
                              );
                        if (!context.mounted || !ok) return;
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        ref.invalidate(groupPostsProvider(widget.groupId));
                        Navigator.of(context).pop();
                      },
                child: Text(
                  state.isLoading
                      ? l10n.submitInProgress
                      : _isEditing
                      ? 'Etkinliği kaydet'
                      : l10n.groupCreateEventAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await pickAndCropImage(
      context,
      source: ImageSource.gallery,
      aspectPreset: CropAspectPreset.wide169,
      title: 'Etkinlik görselini hazırla',
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = picked);
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => controller.text = value.toIso8601String());
  }
}

class _AnnouncementSheet extends ConsumerStatefulWidget {
  const _AnnouncementSheet({required this.groupId, this.existing});

  final int groupId;
  final GroupAnnouncementItem? existing;

  @override
  ConsumerState<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends ConsumerState<_AnnouncementSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  File? _imageFile;
  bool _publishNow = true;
  bool _showInFeed = true;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _titleController.text = existing.title;
    _bodyController.text = existing.body;
  }

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isEditing
                    ? 'Duyuruyu düzenle'
                    : l10n.groupNewAnnouncementTitle,
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _imageFile == null && widget.existing?.image.isEmpty != false
                    ? 'Görsel ekle'
                    : 'Görsel değiştir',
              ),
            ),
            if (_imageFile != null ||
                (widget.existing?.image.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                SdalNetworkImage(
                  imageUrl: widget.existing!.image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  errorFallback: const SizedBox.shrink(),
                ),
            ],
            if (!_isEditing) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hemen yayınla'),
                subtitle: Text(
                  _publishNow
                      ? 'Duyuru yayın akışına hazırlanacak'
                      : 'Duyuru taslaklara kaydedilecek',
                ),
                value: _publishNow,
                onChanged: state.isLoading
                    ? null
                    : (v) => setState(() => _publishNow = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Topluluk akışında göster'),
                subtitle: const Text('Duyuru ana akışta herkese görünsün'),
                value: _showInFeed,
                onChanged: state.isLoading || !_publishNow
                    ? null
                    : (v) => setState(() => _showInFeed = v),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final controller = ref.read(
                          groupsActionControllerProvider.notifier,
                        );
                        final ok = _isEditing
                            ? await controller.updateAnnouncement(
                                groupId: widget.groupId,
                                announcementId: widget.existing!.id,
                                title: _titleController.text.trim(),
                                body: _bodyController.text.trim(),
                                imageFile: _imageFile,
                              )
                            : await controller.createAnnouncement(
                                groupId: widget.groupId,
                                title: _titleController.text.trim(),
                                body: _bodyController.text.trim(),
                                imageFile: _imageFile,
                                showInFeed: _showInFeed,
                                publish: _publishNow,
                              );
                        if (!context.mounted || !ok) return;
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        ref.invalidate(groupPostsProvider(widget.groupId));
                        Navigator.of(context).pop();
                      },
                child: Text(
                  state.isLoading
                      ? l10n.submitInProgress
                      : _isEditing
                      ? 'Duyuruyu kaydet'
                      : l10n.groupCreateAnnouncementAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await pickAndCropImage(
      context,
      source: ImageSource.gallery,
      aspectPreset: CropAspectPreset.wide169,
      title: 'Duyuru görselini hazırla',
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = picked);
  }
}
