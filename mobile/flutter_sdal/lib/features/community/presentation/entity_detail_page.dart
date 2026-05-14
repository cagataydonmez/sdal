import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../groups/application/groups_action_controller.dart';
import '../../groups/data/groups_repository.dart';
import '../application/community_action_controller.dart';
import '../data/community_repository.dart';
import '../../feed/application/feed_action_controller.dart';
import 'entity_action_menu.dart';

// ── Entry points ─────────────────────────────────────────────────────────────

class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.eventId});
  final int eventId;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  late final FutureProvider<EventDetail?> _provider;

  @override
  void initState() {
    super.initState();
    _provider = FutureProvider.autoDispose<EventDetail?>((ref) async {
      return ref
          .read(communityRepositoryProvider)
          .fetchEventDetail(widget.eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final session = ref.watch(sessionControllerProvider).value;
    return FeatureScaffold(
      title: context.l10n.eventsTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _EntityDetailBody<EventDetail>(
                detail: detail,
                entityType: 'event',
                entityId: widget.eventId,
                isOwner: detail.item.createdBy == (session?.user?.id ?? 0),
                isAdmin: session?.hasAdminAccess ?? false,
                onRefresh: () => ref.invalidate(_provider),
                onAddComment: (comment) => ref
                    .read(communityRepositoryProvider)
                    .addEventComment(eventId: widget.eventId, comment: comment),
                onToggleLike: () => ref
                    .read(communityRepositoryProvider)
                    .toggleEventLike(widget.eventId),
                onToggleInteraction: (ac, al) => ref
                    .read(communityRepositoryProvider)
                    .setEventInteractions(
                      eventId: widget.eventId,
                      allowComments: ac,
                      allowLikes: al,
                    ),
                onEdit:
                    detail.item.createdBy == (session?.user?.id ?? 0) ||
                        session?.hasAdminAccess == true
                    ? () async {
                        final result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (ctx) =>
                              _EventEditDialog(event: detail.item),
                        );
                        if (result != null && mounted) {
                          final success = await ref
                              .read(feedActionControllerProvider.notifier)
                              .editEvent(
                                eventId: widget.eventId,
                                title: result['title'] ?? '',
                                description: result['description'] ?? '',
                                location: result['location'] ?? '',
                                startsAt: result['startsAt'] ?? '',
                                endsAt: result['endsAt'] ?? '',
                                imageFile: result['imageFile'] as File?,
                              );
                          if (success && context.mounted) {
                            ref.invalidate(_provider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Etkinlik güncellendi'),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                onUnpublish:
                    detail.item.createdBy == (session?.user?.id ?? 0) ||
                        session?.hasAdminAccess == true
                    ? () async {
                        final success = await ref
                            .read(communityActionControllerProvider.notifier)
                            .setEventPublished(
                              eventId: widget.eventId,
                              publish: false,
                            );
                        if (success && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    : null,
                onDelete:
                    detail.item.createdBy == (session?.user?.id ?? 0) ||
                        session?.hasAdminAccess == true
                    ? () async {
                        final success = await ref
                            .read(feedActionControllerProvider.notifier)
                            .deleteEvent(widget.eventId);
                        if (success && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    : null,
              ),
      ),
    );
  }
}

class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({super.key, required this.announcementId});
  final int announcementId;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  late final FutureProvider<AnnouncementDetail?> _provider;

  @override
  void initState() {
    super.initState();
    _provider = FutureProvider.autoDispose<AnnouncementDetail?>((ref) async {
      return ref
          .read(communityRepositoryProvider)
          .fetchAnnouncementDetail(widget.announcementId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final session = ref.watch(sessionControllerProvider).value;
    return FeatureScaffold(
      title: context.l10n.announcementsTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _EntityDetailBody<AnnouncementDetail>(
                detail: detail,
                entityType: 'announcement',
                entityId: widget.announcementId,
                isOwner: detail.item.createdBy == (session?.user?.id ?? 0),
                isAdmin: session?.hasAdminAccess ?? false,
                onRefresh: () => ref.invalidate(_provider),
                onAddComment: (comment) => ref
                    .read(communityRepositoryProvider)
                    .addAnnouncementComment(
                      announcementId: widget.announcementId,
                      comment: comment,
                    ),
                onToggleLike: () => ref
                    .read(communityRepositoryProvider)
                    .toggleAnnouncementLike(widget.announcementId),
                onToggleInteraction: (ac, al) => ref
                    .read(communityRepositoryProvider)
                    .setAnnouncementInteractions(
                      announcementId: widget.announcementId,
                      allowComments: ac,
                      allowLikes: al,
                    ),
                onEdit:
                    detail.item.createdBy == (session?.user?.id ?? 0) ||
                        session?.hasAdminAccess == true
                    ? () async {
                        final result = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (ctx) => _AnnouncementEditDialog(
                            announcement: detail.item,
                          ),
                        );
                        if (result != null && mounted) {
                          final success = await ref
                              .read(feedActionControllerProvider.notifier)
                              .editAnnouncement(
                                announcementId: widget.announcementId,
                                title: result['title'] ?? '',
                                body: result['body'] ?? '',
                              );
                          if (success && context.mounted) {
                            ref.invalidate(_provider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Duyuru güncellendi'),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                onUnpublish:
                    detail.item.createdBy == (session?.user?.id ?? 0) ||
                        session?.hasAdminAccess == true
                    ? () async {
                        final success = await ref
                            .read(communityActionControllerProvider.notifier)
                            .setAnnouncementPublished(
                              announcementId: widget.announcementId,
                              publish: false,
                            );
                        if (success && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    : null,
                onDelete:
                    detail.item.createdBy == (session?.user?.id ?? 0) ||
                        session?.hasAdminAccess == true
                    ? () async {
                        final success = await ref
                            .read(feedActionControllerProvider.notifier)
                            .deleteAnnouncement(widget.announcementId);
                        if (success && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    : null,
              ),
      ),
    );
  }
}

class GroupEventDetailPage extends ConsumerWidget {
  const GroupEventDetailPage({
    super.key,
    required this.groupId,
    required this.eventId,
  });
  final int groupId;
  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(groupDetailProvider(groupId));
    final canManage = detailState.value?.canManage ?? false;
    final futureProvider = FutureProvider.autoDispose<GroupEventDetail?>((
      ref,
    ) async {
      return ref
          .watch(groupsRepositoryProvider)
          .fetchGroupEventDetail(
            groupId: groupId,
            eventId: eventId,
            canManage: canManage,
          );
    });
    final state = ref.watch(futureProvider);
    return FeatureScaffold(
      title: 'Etkinlik',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _GroupEntityBody(
                title: detail.event.title,
                body: detail.event.description,
                image: detail.event.image,
                creatorHandle: detail.event.creatorHandle,
                createdAt: detail.event.createdAt,
                extraMeta: _buildEventMeta(context, detail.event),
                comments: detail.comments,
                likeCount: detail.likeCount,
                liked: detail.liked,
                allowComments: detail.allowComments,
                allowLikes: detail.allowLikes,
                canManage: detail.canManage,
                kind: EntityActionKind.groupEvent,
                onRefresh: () => ref.invalidate(futureProvider),
                onUnpublish: detail.canManage
                    ? () async {
                        final ok = await ref
                            .read(groupsActionControllerProvider.notifier)
                            .setEventPublished(
                              groupId: groupId,
                              eventId: eventId,
                              publish: false,
                            );
                        if (ok && context.mounted) Navigator.pop(context, true);
                      }
                    : null,
                onDelete: detail.canManage
                    ? () async {
                        final ok = await ref
                            .read(groupsActionControllerProvider.notifier)
                            .deleteEvent(groupId: groupId, eventId: eventId);
                        if (ok && context.mounted) Navigator.pop(context, true);
                      }
                    : null,
                onAddComment: (comment) => ref
                    .read(groupsRepositoryProvider)
                    .addGroupEventComment(
                      groupId: groupId,
                      eventId: eventId,
                      comment: comment,
                    ),
                onToggleLike: () => ref
                    .read(groupsRepositoryProvider)
                    .toggleGroupEventLike(groupId: groupId, eventId: eventId),
                onToggleInteraction: (ac, al) => ref
                    .read(groupsRepositoryProvider)
                    .setGroupEventInteractions(
                      groupId: groupId,
                      eventId: eventId,
                      allowComments: ac,
                      allowLikes: al,
                    ),
              ),
      ),
    );
  }

  List<String> _buildEventMeta(BuildContext context, GroupEventItem e) {
    final parts = <String>[];
    if (e.location.isNotEmpty) parts.add('📍 ${e.location}');
    if (e.startsAt.isNotEmpty) {
      parts.add('🗓 ${formatSdalTimestamp(context, e.startsAt)}');
    }
    if (e.endsAt.isNotEmpty) {
      parts.add('⏱ ${formatSdalTimestamp(context, e.endsAt)}');
    }
    return parts;
  }
}

class GroupAnnouncementDetailPage extends ConsumerWidget {
  const GroupAnnouncementDetailPage({
    super.key,
    required this.groupId,
    required this.announcementId,
  });
  final int groupId;
  final int announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(groupDetailProvider(groupId));
    final canManage = detailState.value?.canManage ?? false;
    final futureProvider = FutureProvider.autoDispose<GroupAnnouncementDetail?>(
      (ref) async {
        return ref
            .watch(groupsRepositoryProvider)
            .fetchGroupAnnouncementDetail(
              groupId: groupId,
              announcementId: announcementId,
              canManage: canManage,
            );
      },
    );
    final state = ref.watch(futureProvider);
    return FeatureScaffold(
      title: 'Duyuru',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _GroupEntityBody(
                title: detail.announcement.title,
                body: detail.announcement.body,
                image: detail.announcement.image,
                creatorHandle: detail.announcement.creatorHandle,
                createdAt: detail.announcement.createdAt,
                extraMeta: const [],
                comments: detail.comments,
                likeCount: detail.likeCount,
                liked: detail.liked,
                allowComments: detail.allowComments,
                allowLikes: detail.allowLikes,
                canManage: detail.canManage,
                kind: EntityActionKind.groupAnnouncement,
                onRefresh: () => ref.invalidate(futureProvider),
                onUnpublish: detail.canManage
                    ? () async {
                        final ok = await ref
                            .read(groupsActionControllerProvider.notifier)
                            .setAnnouncementPublished(
                              groupId: groupId,
                              announcementId: announcementId,
                              publish: false,
                            );
                        if (ok && context.mounted) Navigator.pop(context, true);
                      }
                    : null,
                onDelete: detail.canManage
                    ? () async {
                        final ok = await ref
                            .read(groupsActionControllerProvider.notifier)
                            .deleteAnnouncement(
                              groupId: groupId,
                              announcementId: announcementId,
                            );
                        if (ok && context.mounted) Navigator.pop(context, true);
                      }
                    : null,
                onAddComment: (comment) => ref
                    .read(groupsRepositoryProvider)
                    .addGroupAnnouncementComment(
                      groupId: groupId,
                      announcementId: announcementId,
                      comment: comment,
                    ),
                onToggleLike: () => ref
                    .read(groupsRepositoryProvider)
                    .toggleGroupAnnouncementLike(
                      groupId: groupId,
                      announcementId: announcementId,
                    ),
                onToggleInteraction: (ac, al) => ref
                    .read(groupsRepositoryProvider)
                    .setGroupAnnouncementInteractions(
                      groupId: groupId,
                      announcementId: announcementId,
                      allowComments: ac,
                      allowLikes: al,
                    ),
              ),
      ),
    );
  }
}

// ── Shared body for global entities ──────────────────────────────────────────

class _EntityDetailBody<T> extends ConsumerStatefulWidget {
  const _EntityDetailBody({
    required this.detail,
    required this.entityType,
    required this.entityId,
    required this.isOwner,
    required this.isAdmin,
    required this.onRefresh,
    required this.onAddComment,
    required this.onToggleLike,
    required this.onToggleInteraction,
    this.onEdit,
    this.onUnpublish,
    this.onDelete,
  });

  final T detail;
  final String entityType;
  final int entityId;
  final bool isOwner;
  final bool isAdmin;
  final VoidCallback onRefresh;
  final Future<dynamic> Function(String comment) onAddComment;
  final Future<dynamic> Function() onToggleLike;
  final Future<dynamic> Function(bool? allowComments, bool? allowLikes)
  onToggleInteraction;
  final VoidCallback? onEdit;
  final Future<void> Function()? onUnpublish;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_EntityDetailBody<T>> createState() =>
      _EntityDetailBodyState<T>();
}

class _EntityDetailBodyState<T> extends ConsumerState<_EntityDetailBody<T>> {
  late bool _liked;
  late int _likeCount;
  String _myResponse = '';
  late int _attendCount;
  late int _declineCount;
  final _commentController = TextEditingController();
  bool _submitting = false;

  String get _title => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.title
      : (widget.detail as AnnouncementDetail).item.title;
  String get _body => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.description
      : (widget.detail as AnnouncementDetail).item.body;
  String get _image => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.image
      : (widget.detail as AnnouncementDetail).item.image;
  String get _creatorHandle => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.creatorHandle
      : (widget.detail as AnnouncementDetail).item.creatorHandle;
  String get _createdAt => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.createdAt
      : (widget.detail as AnnouncementDetail).item.createdAt;
  bool get _allowComments => widget.detail is EventDetail
      ? (widget.detail as EventDetail).allowComments
      : (widget.detail as AnnouncementDetail).allowComments;
  bool get _allowLikes => widget.detail is EventDetail
      ? (widget.detail as EventDetail).allowLikes
      : (widget.detail as AnnouncementDetail).allowLikes;
  bool get _isEdited => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.isEdited
      : (widget.detail as AnnouncementDetail).item.isEdited;
  List<EntityComment> get _comments => widget.detail is EventDetail
      ? (widget.detail as EventDetail).comments
      : (widget.detail as AnnouncementDetail).comments;
  bool get _approved => widget.detail is EventDetail
      ? (widget.detail as EventDetail).item.approved
      : (widget.detail as AnnouncementDetail).item.approved;

  @override
  void initState() {
    super.initState();
    _liked = widget.detail is EventDetail
        ? (widget.detail as EventDetail).liked
        : (widget.detail as AnnouncementDetail).liked;
    _likeCount = widget.detail is EventDetail
        ? (widget.detail as EventDetail).likeCount
        : (widget.detail as AnnouncementDetail).likeCount;
    if (widget.detail is EventDetail) {
      final ev = (widget.detail as EventDetail).item;
      _myResponse = ev.myResponse;
      _attendCount = ev.attendCount;
      _declineCount = ev.declineCount;
    } else {
      _attendCount = 0;
      _declineCount = 0;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    await widget.onToggleLike();
  }

  Future<void> _respond(String response) async {
    final previous = _myResponse;
    setState(() {
      if (_myResponse == response) {
        if (response == 'attend') _attendCount--;
        if (response == 'decline') _declineCount--;
        _myResponse = '';
      } else {
        if (previous == 'attend') _attendCount--;
        if (previous == 'decline') _declineCount--;
        if (response == 'attend') _attendCount++;
        if (response == 'decline') _declineCount++;
        _myResponse = response;
      }
    });
    await ref
        .read(communityActionControllerProvider.notifier)
        .respond(eventId: widget.entityId, response: response);
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onAddComment(text);
    if (!mounted) return;
    setState(() => _submitting = false);
    _commentController.clear();
    widget.onRefresh();
  }

  Future<void> _togglePublish(bool publish) async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .approveEvent(eventId: widget.entityId, approved: publish);
    if (!mounted) return;
    if (ok) {
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish ? 'Etkinlik yayınlandı.' : 'Etkinlik taslağa geri alındı.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem başarısız oldu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    final isEvent = widget.entityType == 'event';

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isEvent
                            ? tokens.warningMuted
                            : tokens.successMuted,
                        borderRadius: BorderRadius.circular(
                          SdalThemeTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        isEvent ? '📅 Etkinlik' : '📢 Duyuru',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isEvent ? tokens.warning : tokens.success,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.onEdit != null ||
                        widget.onUnpublish != null ||
                        widget.onDelete != null)
                      EntityActionMenu(
                        kind: isEvent
                            ? EntityActionKind.event
                            : EntityActionKind.announcement,
                        onEdit: widget.onEdit == null
                            ? null
                            : () async => widget.onEdit!(),
                        onUnpublish: widget.onUnpublish,
                        onDelete: widget.onDelete == null
                            ? null
                            : () async => widget.onDelete!(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  [
                    if (_createdAt.isNotEmpty)
                      formatSdalTimestamp(context, _createdAt),
                    if (_creatorHandle.isNotEmpty) '@$_creatorHandle',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                if (_image.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SdalNetworkImage(
                    imageUrl: config.resolveUrl(_image).toString(),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    errorFallback: const SizedBox.shrink(),
                  ),
                ],
                if (_body.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    plainTextFromRichContent(_body),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (_isEdited) ...[
                  const SizedBox(height: 8),
                  Text(
                    '(düzenlendi)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.foregroundMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (isEvent) _buildEventExtras(context),
                if (isEvent) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text('Katılacağım ($_attendCount)'),
                        selected: _myResponse == 'attend',
                        onSelected: (_) => _respond('attend'),
                      ),
                      FilterChip(
                        label: Text('Katılamam ($_declineCount)'),
                        selected: _myResponse == 'decline',
                        onSelected: (_) => _respond('decline'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_allowLikes)
                      _InteractionPill(
                        icon: _liked ? Icons.favorite : Icons.favorite_border,
                        label: '$_likeCount',
                        active: _liked,
                        onTap: _toggleLike,
                      ),
                    if (_allowLikes) const SizedBox(width: 8),
                    _InteractionPill(
                      icon: Icons.chat_bubble_outline,
                      label: '${_comments.length}',
                      onTap: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Owner publish/unpublish and interaction settings
          if (widget.isOwner || widget.isAdmin) ...[
            const SizedBox(height: 12),
            if (widget.isOwner && widget.entityType == 'event') ...[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEvent && !_approved) ...[
                      FilledButton(
                        onPressed: () => _togglePublish(true),
                        child: const Text('Yayınla'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Etkinlik taslak olarak kaydedilmiş. Yayınlamak için bu butona basın.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else if (isEvent && _approved) ...[
                      OutlinedButton(
                        onPressed: () => _togglePublish(false),
                        child: const Text('Taslağa geri al'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _InteractionSettingsCard(
              allowComments: _allowComments,
              allowLikes: _allowLikes,
              onSave: widget.onToggleInteraction,
            ),
          ],
          // Comments section
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yorumlar', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (_allowComments) ...[
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Yorum ekle…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _submitting ? null : _submitComment,
                      child: Text(_submitting ? 'Gönderiliyor…' : 'Gönder'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Yorumlar kapalı.',
                      style: TextStyle(color: tokens.foregroundMuted),
                    ),
                  ),
                if (_comments.isEmpty)
                  Text(
                    'Henüz yorum yok.',
                    style: TextStyle(color: tokens.foregroundMuted),
                  )
                else
                  ..._comments.map((c) => _CommentRow(comment: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventExtras(BuildContext context) {
    if (widget.detail is! EventDetail) return const SizedBox.shrink();
    final ev = (widget.detail as EventDetail).item;
    final parts = <String>[];
    if (ev.location.isNotEmpty) parts.add('📍 ${ev.location}');
    if (ev.startsAt.isNotEmpty) {
      parts.add('🗓 ${formatSdalTimestamp(context, ev.startsAt)}');
    }
    if (ev.endsAt.isNotEmpty) {
      parts.add('⏱ ${formatSdalTimestamp(context, ev.endsAt)}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        parts.join('\n'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

// ── Shared body for GROUP entities ───────────────────────────────────────────

class _GroupEntityBody extends ConsumerStatefulWidget {
  const _GroupEntityBody({
    required this.title,
    required this.body,
    required this.image,
    required this.creatorHandle,
    required this.createdAt,
    required this.extraMeta,
    required this.comments,
    required this.likeCount,
    required this.liked,
    required this.allowComments,
    required this.allowLikes,
    required this.canManage,
    required this.kind,
    required this.onRefresh,
    required this.onAddComment,
    required this.onToggleLike,
    required this.onToggleInteraction,
    this.onUnpublish,
    this.onDelete,
  });

  final String title;
  final String body;
  final String image;
  final String creatorHandle;
  final String createdAt;
  final List<String> extraMeta;
  final List<GroupEntityComment> comments;
  final int likeCount;
  final bool liked;
  final bool allowComments;
  final bool allowLikes;
  final bool canManage;
  final EntityActionKind kind;
  final VoidCallback onRefresh;
  final Future<dynamic> Function(String comment) onAddComment;
  final Future<dynamic> Function() onToggleLike;
  final Future<dynamic> Function(bool? allowComments, bool? allowLikes)
  onToggleInteraction;
  final Future<void> Function()? onUnpublish;
  final Future<void> Function()? onDelete;

  @override
  ConsumerState<_GroupEntityBody> createState() => _GroupEntityBodyState();
}

class _GroupEntityBodyState extends ConsumerState<_GroupEntityBody> {
  late bool _liked;
  late int _likeCount;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.liked;
    _likeCount = widget.likeCount;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    await widget.onToggleLike();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onAddComment(text);
    if (!mounted) return;
    setState(() => _submitting = false);
    _commentController.clear();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (widget.onUnpublish != null || widget.onDelete != null)
                      EntityActionMenu(
                        kind: widget.kind,
                        onUnpublish: widget.onUnpublish,
                        onDelete: widget.onDelete,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (widget.createdAt.isNotEmpty)
                      formatSdalTimestamp(context, widget.createdAt),
                    if (widget.creatorHandle.isNotEmpty)
                      '@${widget.creatorHandle}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                if (widget.image.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SdalNetworkImage(
                    imageUrl: widget.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    errorFallback: const SizedBox.shrink(),
                  ),
                ],
                if (widget.body.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    plainTextFromRichContent(widget.body),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (widget.extraMeta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...widget.extraMeta.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.allowLikes)
                      _InteractionPill(
                        icon: _liked ? Icons.favorite : Icons.favorite_border,
                        label: '$_likeCount',
                        active: _liked,
                        onTap: _toggleLike,
                      ),
                    if (widget.allowLikes) const SizedBox(width: 8),
                    _InteractionPill(
                      icon: Icons.chat_bubble_outline,
                      label: '${widget.comments.length}',
                      onTap: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.canManage) ...[
            const SizedBox(height: 12),
            _InteractionSettingsCard(
              allowComments: widget.allowComments,
              allowLikes: widget.allowLikes,
              onSave: widget.onToggleInteraction,
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yorumlar', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (widget.allowComments) ...[
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Yorum ekle…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _submitting ? null : _submitComment,
                      child: Text(_submitting ? 'Gönderiliyor…' : 'Gönder'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Yorumlar kapalı.',
                      style: TextStyle(color: tokens.foregroundMuted),
                    ),
                  ),
                if (widget.comments.isEmpty)
                  Text(
                    'Henüz yorum yok.',
                    style: TextStyle(color: tokens.foregroundMuted),
                  )
                else
                  ...widget.comments.map((c) => _GroupCommentRow(comment: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _InteractionPill extends StatelessWidget {
  const _InteractionPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? tokens.accentMuted : tokens.panelMuted,
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

class _InteractionSettingsCard extends StatefulWidget {
  const _InteractionSettingsCard({
    required this.allowComments,
    required this.allowLikes,
    required this.onSave,
  });

  final bool allowComments;
  final bool allowLikes;
  final Future<dynamic> Function(bool? allowComments, bool? allowLikes) onSave;

  @override
  State<_InteractionSettingsCard> createState() =>
      _InteractionSettingsCardState();
}

class _InteractionSettingsCardState extends State<_InteractionSettingsCard> {
  late bool _allowComments;
  late bool _allowLikes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allowComments = widget.allowComments;
    _allowLikes = widget.allowLikes;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_allowComments, _allowLikes);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etkileşim ayarları',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Kimler yorum veya beğeni yapabilsin?',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yorumlara izin ver'),
            value: _allowComments,
            onChanged: _saving
                ? null
                : (v) => setState(() => _allowComments = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Beğenilere izin ver'),
            value: _allowLikes,
            onChanged: _saving ? null : (v) => setState(() => _allowLikes = v),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({required this.comment});
  final EntityComment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteAvatar(
            label: comment.displayName,
            imageUrl: config.resolveUrl(comment.photo).toString(),
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.displayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (comment.verified)
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Theme.of(context).sdal.info,
                      ),
                  ],
                ),
                Text(
                  formatSdalTimestamp(context, comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(plainTextFromRichContent(comment.comment)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCommentRow extends ConsumerWidget {
  const _GroupCommentRow({required this.comment});
  final GroupEntityComment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteAvatar(
            label: comment.displayName,
            imageUrl: config.resolveUrl(comment.photo).toString(),
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.displayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (comment.verified)
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: tokens.info,
                      ),
                  ],
                ),
                Text(
                  formatSdalTimestamp(context, comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(plainTextFromRichContent(comment.comment)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event edit dialog ────────────────────────────────────────────────────────

class _EventEditDialog extends StatefulWidget {
  const _EventEditDialog({required this.event});
  final EventItem event;

  @override
  State<_EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<_EventEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _startsAtController;
  late TextEditingController _endsAtController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(
      text: plainTextFromRichContent(widget.event.description),
    );
    _locationController = TextEditingController(text: widget.event.location);
    _startsAtController = TextEditingController(text: widget.event.startsAt);
    _endsAtController = TextEditingController(text: widget.event.endsAt);
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
    return AlertDialog(
      title: const Text('Etkinliği Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Konum'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickDateTime(true),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _startsAtController.text.isEmpty
                    ? 'Başlangıç tarihi'
                    : _startsAtController.text,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickDateTime(false),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _endsAtController.text.isEmpty
                    ? 'Bitiş tarihi'
                    : _endsAtController.text,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _imageFile == null
                    ? 'Görsel ${widget.event.image.isEmpty ? 'ekle' : 'değiştir'}'
                    : 'Yeni görsel seçildi',
              ),
            ),
            if (_imageFile != null || widget.event.image.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _imageFile != null
                    ? Image.file(_imageFile!, height: 150, fit: BoxFit.cover)
                    : SizedBox(
                        height: 150,
                        child: SdalNetworkImage(
                          imageUrl: widget.event.image,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'title': _titleController.text,
            'description': _descriptionController.text,
            'location': _locationController.text,
            'startsAt': _startsAtController.text,
            'endsAt': _endsAtController.text,
            'imageFile': _imageFile,
          }),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await pickAndCropImage(
      context,
      source: source,
      aspectPreset: CropAspectPreset.wide169,
      title: 'Etkinlik görselini hazırla',
    );
    if (picked == null) return;
    setState(() => _imageFile = picked);
  }

  Future<void> _pickDateTime(bool isStart) async {
    final controller = isStart ? _startsAtController : _endsAtController;
    final now = DateTime.now();
    final initialDate = controller.text.isEmpty
        ? now.add(Duration(days: isStart ? 0 : 3))
        : DateTime.parse(controller.text);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final datetime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(
      () => controller.text = datetime.toIso8601String().substring(0, 16),
    );
  }
}

// ── Announcement edit dialog ─────────────────────────────────────────────────

class _AnnouncementEditDialog extends StatefulWidget {
  const _AnnouncementEditDialog({required this.announcement});
  final AnnouncementItem announcement;

  @override
  State<_AnnouncementEditDialog> createState() =>
      _AnnouncementEditDialogState();
}

class _AnnouncementEditDialogState extends State<_AnnouncementEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement.title);
    _bodyController = TextEditingController(
      text: plainTextFromRichContent(widget.announcement.body),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Duyuruyu Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'İçerik'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'title': _titleController.text,
            'body': _bodyController.text,
          }),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
