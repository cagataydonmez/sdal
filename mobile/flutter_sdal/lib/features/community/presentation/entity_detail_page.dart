import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../groups/data/groups_repository.dart';
import '../data/community_repository.dart';

// ── Entry points ─────────────────────────────────────────────────────────────

class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({super.key, required this.eventId});
  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final futureProvider = FutureProvider.autoDispose<EventDetail?>((ref) async {
      return ref.watch(communityRepositoryProvider).fetchEventDetail(eventId);
    });
    final state = ref.watch(futureProvider);
    return FeatureScaffold(
      title: context.l10n.eventsTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _EntityDetailBody<EventDetail>(
                detail: detail,
                entityType: 'event',
                entityId: eventId,
                isOwner: detail.item.createdBy == (session?.user?.id ?? 0),
                isAdmin: session?.hasAdminAccess ?? false,
                onRefresh: () => ref.invalidate(futureProvider),
                onAddComment: (comment) => ref
                    .read(communityRepositoryProvider)
                    .addEventComment(eventId: eventId, comment: comment),
                onToggleLike: () =>
                    ref.read(communityRepositoryProvider).toggleEventLike(eventId),
                onToggleInteraction: (ac, al) => ref
                    .read(communityRepositoryProvider)
                    .setEventInteractions(eventId: eventId, allowComments: ac, allowLikes: al),
              ),
      ),
    );
  }
}

class AnnouncementDetailPage extends ConsumerWidget {
  const AnnouncementDetailPage({super.key, required this.announcementId});
  final int announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final futureProvider = FutureProvider.autoDispose<AnnouncementDetail?>((ref) async {
      return ref.watch(communityRepositoryProvider).fetchAnnouncementDetail(announcementId);
    });
    final state = ref.watch(futureProvider);
    return FeatureScaffold(
      title: context.l10n.announcementsTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _EntityDetailBody<AnnouncementDetail>(
                detail: detail,
                entityType: 'announcement',
                entityId: announcementId,
                isOwner: detail.item.createdBy == (session?.user?.id ?? 0),
                isAdmin: session?.hasAdminAccess ?? false,
                onRefresh: () => ref.invalidate(futureProvider),
                onAddComment: (comment) => ref
                    .read(communityRepositoryProvider)
                    .addAnnouncementComment(announcementId: announcementId, comment: comment),
                onToggleLike: () => ref
                    .read(communityRepositoryProvider)
                    .toggleAnnouncementLike(announcementId),
                onToggleInteraction: (ac, al) => ref
                    .read(communityRepositoryProvider)
                    .setAnnouncementInteractions(
                      announcementId: announcementId,
                      allowComments: ac,
                      allowLikes: al,
                    ),
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
    final futureProvider = FutureProvider.autoDispose<GroupEventDetail?>((ref) async {
      return ref.watch(groupsRepositoryProvider).fetchGroupEventDetail(
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
        error: (_, __) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _GroupEntityBody(
                title: detail.event.title,
                body: detail.event.description,
                image: '',
                creatorHandle: detail.event.creatorHandle,
                createdAt: detail.event.createdAt,
                extraMeta: _buildEventMeta(detail.event),
                comments: detail.comments,
                likeCount: detail.likeCount,
                liked: detail.liked,
                allowComments: detail.allowComments,
                allowLikes: detail.allowLikes,
                canManage: detail.canManage,
                onRefresh: () => ref.invalidate(futureProvider),
                onAddComment: (comment) => ref
                    .read(groupsRepositoryProvider)
                    .addGroupEventComment(groupId: groupId, eventId: eventId, comment: comment),
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

  List<String> _buildEventMeta(GroupEventItem e) {
    final parts = <String>[];
    if (e.location.isNotEmpty) parts.add('📍 ${e.location}');
    if (e.startsAt.isNotEmpty) parts.add('🗓 ${e.startsAt}');
    if (e.endsAt.isNotEmpty) parts.add('⏱ ${e.endsAt}');
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
    final futureProvider = FutureProvider.autoDispose<GroupAnnouncementDetail?>((ref) async {
      return ref.watch(groupsRepositoryProvider).fetchGroupAnnouncementDetail(
        groupId: groupId,
        announcementId: announcementId,
        canManage: canManage,
      );
    });
    final state = ref.watch(futureProvider);
    return FeatureScaffold(
      title: 'Duyuru',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const ErrorView(),
        data: (detail) => detail == null
            ? const ErrorView()
            : _GroupEntityBody(
                title: detail.announcement.title,
                body: detail.announcement.body,
                image: '',
                creatorHandle: detail.announcement.creatorHandle,
                createdAt: detail.announcement.createdAt,
                extraMeta: const [],
                comments: detail.comments,
                likeCount: detail.likeCount,
                liked: detail.liked,
                allowComments: detail.allowComments,
                allowLikes: detail.allowLikes,
                canManage: detail.canManage,
                onRefresh: () => ref.invalidate(futureProvider),
                onAddComment: (comment) => ref
                    .read(groupsRepositoryProvider)
                    .addGroupAnnouncementComment(
                      groupId: groupId,
                      announcementId: announcementId,
                      comment: comment,
                    ),
                onToggleLike: () => ref
                    .read(groupsRepositoryProvider)
                    .toggleGroupAnnouncementLike(groupId: groupId, announcementId: announcementId),
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
  });

  final T detail;
  final String entityType;
  final int entityId;
  final bool isOwner;
  final bool isAdmin;
  final VoidCallback onRefresh;
  final Future<dynamic> Function(String comment) onAddComment;
  final Future<dynamic> Function() onToggleLike;
  final Future<dynamic> Function(bool? allowComments, bool? allowLikes) onToggleInteraction;

  @override
  ConsumerState<_EntityDetailBody<T>> createState() => _EntityDetailBodyState<T>();
}

class _EntityDetailBodyState<T> extends ConsumerState<_EntityDetailBody<T>> {
  late bool _liked;
  late int _likeCount;
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
  List<EntityComment> get _comments => widget.detail is EventDetail
      ? (widget.detail as EventDetail).comments
      : (widget.detail as AnnouncementDetail).comments;

  @override
  void initState() {
    super.initState();
    _liked = widget.detail is EventDetail
        ? (widget.detail as EventDetail).liked
        : (widget.detail as AnnouncementDetail).liked;
    _likeCount = widget.detail is EventDetail
        ? (widget.detail as EventDetail).likeCount
        : (widget.detail as AnnouncementDetail).likeCount;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isEvent ? tokens.warningMuted : tokens.successMuted,
                        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
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
                  ],
                ),
                const SizedBox(height: 12),
                Text(_title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  [
                    if (_createdAt.isNotEmpty) formatSdalTimestamp(context, _createdAt),
                    if (_creatorHandle.isNotEmpty) '@$_creatorHandle',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
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
                if (isEvent) _buildEventExtras(context),
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
          // Owner interaction settings
          if (widget.isOwner || widget.isAdmin) ...[
            const SizedBox(height: 12),
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
                  Text('Henüz yorum yok.', style: TextStyle(color: tokens.foregroundMuted))
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
    if (ev.startsAt.isNotEmpty) parts.add('🗓 ${formatSdalTimestamp(context, ev.startsAt)}');
    if (ev.endsAt.isNotEmpty) parts.add('⏱ ${formatSdalTimestamp(context, ev.endsAt)}');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(parts.join('\n'), style: Theme.of(context).textTheme.bodyMedium),
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
    required this.onRefresh,
    required this.onAddComment,
    required this.onToggleLike,
    required this.onToggleInteraction,
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
  final VoidCallback onRefresh;
  final Future<dynamic> Function(String comment) onAddComment;
  final Future<dynamic> Function() onToggleLike;
  final Future<dynamic> Function(bool? allowComments, bool? allowLikes) onToggleInteraction;

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
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
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
                Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  [
                    if (widget.createdAt.isNotEmpty) formatSdalTimestamp(context, widget.createdAt),
                    if (widget.creatorHandle.isNotEmpty) '@${widget.creatorHandle}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
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
                  Text(plainTextFromRichContent(widget.body), style: Theme.of(context).textTheme.bodyLarge),
                ],
                if (widget.extraMeta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...widget.extraMeta.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
                  )),
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
                    child: Text('Yorumlar kapalı.', style: TextStyle(color: tokens.foregroundMuted)),
                  ),
                if (widget.comments.isEmpty)
                  Text('Henüz yorum yok.', style: TextStyle(color: tokens.foregroundMuted))
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
  State<_InteractionSettingsCard> createState() => _InteractionSettingsCardState();
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
          Text('Etkileşim ayarları', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Kimler yorum veya beğeni yapabilsin?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yorumlara izin ver'),
            value: _allowComments,
            onChanged: _saving ? null : (v) => setState(() => _allowComments = v),
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
                      child: Text(comment.displayName, style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (comment.verified)
                      Icon(Icons.verified_rounded, size: 14, color: Theme.of(context).sdal.info),
                  ],
                ),
                Text(
                  formatSdalTimestamp(context, comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
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
                      child: Text(comment.displayName, style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (comment.verified)
                      Icon(Icons.verified_rounded, size: 14, color: tokens.info),
                  ],
                ),
                Text(
                  formatSdalTimestamp(context, comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
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
