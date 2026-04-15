import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/community_action_controller.dart';
import '../data/community_repository.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startsAtController = TextEditingController();
  final TextEditingController _endsAtController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final List<EventItem> _items = <EventItem>[];
  final Map<int, List<EventComment>> _commentsByEvent =
      <int, List<EventComment>>{};
  final Map<int, TextEditingController> _commentControllers =
      <int, TextEditingController>{};

  File? _imageFile;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(communityActionControllerProvider);
    final isSaving =
        actionState.isLoading && actionState.scope == 'events:create';
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.eventsTitle,
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni etkinlik öner',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Konum',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startsAtController,
                          decoration: const InputDecoration(
                            labelText: 'Başlangıç tarihi',
                            hintText: '2026-04-04T19:30',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _endsAtController,
                          decoration: const InputDecoration(
                            labelText: 'Bitiş tarihi',
                            hintText: '2026-04-04T22:00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _imageFile == null
                          ? 'Kapak görseli ekle'
                          : 'Kapak görselini değiştir',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving ? null : _createEvent,
                      child: Text(
                        isSaving ? 'Gönderiliyor...' : 'Etkinliği gönder',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingInitial)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty && _items.isEmpty)
              SurfaceCard(
                child: ErrorView(
                  message: _error,
                  kind: ErrorViewKind.network,
                  onRetry: () => _load(reset: true),
                ),
              )
            else if (_items.isEmpty)
              SurfaceCard(
                child: EmptyStateView(
                  icon: Icons.event_busy_outlined,
                  title: l10n.eventsEmptyTitle,
                  message: l10n.eventsEmptyMessage,
                  actionLabel: l10n.refreshAction,
                  onAction: () => _load(reset: true),
                ),
              )
            else
              ..._items.map(_buildEventCard),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(EventItem item) {
    final comments = _commentsByEvent[item.id] ?? const <EventComment>[];
    final commentController = _commentControllers.putIfAbsent(
      item.id,
      TextEditingController.new,
    );
    final actionState = ref.watch(communityActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final isAdmin = session?.hasAdminAccess ?? false;
    final respondingScope = 'events:respond:${item.id}';
    final commentingScope = 'events:comment:${item.id}';
    final visibilityScope = 'events:visibility:${item.id}';
    final notifyScope = 'events:notify:${item.id}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'approve') {
                        await _approveEvent(item.id, approved: true);
                        return;
                      }
                      if (value == 'reject') {
                        await _approveEvent(item.id, approved: false);
                        return;
                      }
                      if (value == 'delete') {
                        await _deleteEvent(item.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!item.approved)
                        const PopupMenuItem<String>(
                          value: 'approve',
                          child: Text('Onayla'),
                        ),
                      if (item.approved)
                        const PopupMenuItem<String>(
                          value: 'reject',
                          child: Text('Yayından kaldır'),
                        ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Sil'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.image.isNotEmpty) ...[
              SdalNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                width: double.infinity,
                borderRadius: BorderRadius.circular(16),
                errorFallback: const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
            ],
            Text(_plainText(item.description)),
            const SizedBox(height: 10),
            Text(
              _eventMeta(context, item),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).sdal.foregroundMuted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text('Katılacağım (${item.attendCount})'),
                  selected: item.myResponse == 'attend',
                  onSelected:
                      actionState.isLoading &&
                          actionState.scope == respondingScope
                      ? null
                      : (_) => _respond(item.id, 'attend'),
                ),
                FilterChip(
                  label: Text('Katılamam (${item.declineCount})'),
                  selected: item.myResponse == 'decline',
                  onSelected:
                      actionState.isLoading &&
                          actionState.scope == respondingScope
                      ? null
                      : (_) => _respond(item.id, 'decline'),
                ),
              ],
            ),
            if (item.canManageResponses) ...[
              const SizedBox(height: 12),
              _VisibilityCard(
                item: item,
                saving:
                    actionState.isLoading &&
                    actionState.scope == visibilityScope,
                onSave: (showCounts, showAttendees, showDecliners) =>
                    _saveVisibility(
                      item.id,
                      showCounts,
                      showAttendees,
                      showDecliners,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        actionState.isLoading &&
                            actionState.scope == notifyScope
                        ? null
                        : () => _notify(item.id, 'invite'),
                    child: const Text('Davet bildirimi'),
                  ),
                  OutlinedButton(
                    onPressed:
                        actionState.isLoading &&
                            actionState.scope == notifyScope
                        ? null
                        : () => _notify(item.id, 'reminder'),
                    child: const Text('Hatırlatma'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Yorum ekle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed:
                    actionState.isLoading &&
                        actionState.scope == commentingScope
                    ? null
                    : () => _addComment(item.id),
                child: const Text('Yorum gönder'),
              ),
            ),
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                if (comment.verified)
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: Theme.of(context).sdal.info,
                                  ),
                              ],
                            ),
                            Text(
                              formatSdalTimestamp(context, comment.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).sdal.foregroundMuted,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(_plainText(comment.comment)),
                          ],
                        ),
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

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _createEvent() async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          startsAt: _startsAtController.text.trim(),
          endsAt: _endsAtController.text.trim(),
          imageFile: _imageFile,
        );
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Etkinlik gönderildi.' : 'Etkinlik oluşturulamadı.'),
        ),
      ),
    );
    if (!ok) return;
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _startsAtController.clear();
    _endsAtController.clear();
    setState(() => _imageFile = null);
    _load(reset: true);
  }

  Future<void> _respond(int eventId, String response) async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .respond(eventId: eventId, response: response);
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Etkinlik yanıtın kaydedildi.' : 'İşlem başarısız oldu.'),
        ),
      ),
    );
    if (ok) _load(reset: true);
  }

  Future<void> _addComment(int eventId) async {
    final controller = _commentControllers[eventId]!;
    final comment = controller.text.trim();
    if (comment.isEmpty) return;
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .addComment(eventId: eventId, comment: comment);
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Yorum gönderildi.' : 'Yorum gönderilemedi.'),
        ),
      ),
    );
    if (!ok) return;
    controller.clear();
    final comments = await ref
        .read(communityRepositoryProvider)
        .fetchEventComments(eventId);
    if (!mounted) return;
    setState(() => _commentsByEvent[eventId] = comments);
  }

  Future<void> _saveVisibility(
    int eventId,
    bool showCounts,
    bool showAttendees,
    bool showDecliners,
  ) async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .updateVisibility(
          eventId: eventId,
          showCounts: showCounts,
          showAttendeeNames: showAttendees,
          showDeclinerNames: showDecliners,
        );
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? 'Görünürlük ayarları kaydedildi.'
                  : 'İşlem başarısız oldu.'),
        ),
      ),
    );
    if (ok) _load(reset: true);
  }

  Future<void> _notify(int eventId, String mode) async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .notifyAudience(eventId: eventId, mode: mode);
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Bildirim gönderildi.' : 'Bildirim gönderilemedi.'),
        ),
      ),
    );
  }

  Future<void> _approveEvent(int eventId, {required bool approved}) async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .approveEvent(eventId: eventId, approved: approved);
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? (approved
                        ? 'Etkinlik onaylandı.'
                        : 'Etkinlik yayından kaldırıldı.')
                  : 'İşlem başarısız oldu.'),
        ),
      ),
    );
    if (ok) _load(reset: true);
  }

  Future<void> _deleteEvent(int eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinlik silinsin mi?'),
        content: const Text(
          'Bu işlem etkinliği ve ilişkili yorum/yanıtları kaldırır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .deleteEvent(eventId);
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Etkinlik silindi.' : 'Etkinlik silinemedi.'),
        ),
      ),
    );
    if (ok) _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoadingInitial = true;
        _hasMore = true;
        _error = '';
      });
    } else {
      if (_isLoadingInitial || _isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final page = await ref
          .read(communityRepositoryProvider)
          .fetchEvents(offset: reset ? 0 : _items.length);
      final comments = <int, List<EventComment>>{};
      for (final item in page.items) {
        comments[item.id] = await ref
            .read(communityRepositoryProvider)
            .fetchEventComments(item.id);
      }
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _commentsByEvent.addAll(comments);
        _hasMore = page.hasMore;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingInitial || _isLoadingMore) {
      return;
    }
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 240) {
      _load(reset: false);
    }
  }
}

class _VisibilityCard extends StatefulWidget {
  const _VisibilityCard({
    required this.item,
    required this.saving,
    required this.onSave,
  });

  final EventItem item;
  final bool saving;
  final Future<void> Function(bool, bool, bool) onSave;

  @override
  State<_VisibilityCard> createState() => _VisibilityCardState();
}

class _VisibilityCardState extends State<_VisibilityCard> {
  late bool showCounts;
  late bool showAttendees;
  late bool showDecliners;

  @override
  void initState() {
    super.initState();
    showCounts = widget.item.visibility.showCounts;
    showAttendees = widget.item.visibility.showAttendeeNames;
    showDecliners = widget.item.visibility.showDeclinerNames;
  }

  @override
  void didUpdateWidget(covariant _VisibilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.visibility.showCounts !=
            widget.item.visibility.showCounts ||
        oldWidget.item.visibility.showAttendeeNames !=
            widget.item.visibility.showAttendeeNames ||
        oldWidget.item.visibility.showDeclinerNames !=
            widget.item.visibility.showDeclinerNames) {
      showCounts = widget.item.visibility.showCounts;
      showAttendees = widget.item.visibility.showAttendeeNames;
      showDecliners = widget.item.visibility.showDeclinerNames;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eventVisibilityTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.eventVisibilityHelper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.eventVisibilityShowCounts),
            subtitle: Text(l10n.eventVisibilityShowCountsHint),
            value: showCounts,
            onChanged: widget.saving
                ? null
                : (value) => setState(() => showCounts = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.eventVisibilityShowAttendees),
            subtitle: Text(l10n.eventVisibilityShowAttendeesHint),
            value: showAttendees,
            onChanged: widget.saving
                ? null
                : (value) => setState(() => showAttendees = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.eventVisibilityShowDecliners),
            subtitle: Text(l10n.eventVisibilityShowDeclinersHint),
            value: showDecliners,
            onChanged: widget.saving
                ? null
                : (value) => setState(() => showDecliners = value),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: widget.saving
                  ? null
                  : () =>
                        widget.onSave(showCounts, showAttendees, showDecliners),
              child: Text(
                widget.saving
                    ? l10n.submitInProgress
                    : l10n.eventVisibilitySaveAction,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _plainText(String raw) {
  return plainTextFromRichContent(raw);
}

String _eventMeta(BuildContext context, EventItem item) {
  final parts = <String>[];
  if (item.location.isNotEmpty) parts.add(item.location);
  if (item.startsAt.isNotEmpty) {
    parts.add(formatSdalTimestamp(context, item.startsAt));
  }
  if (item.creatorHandle.isNotEmpty) parts.add('@${item.creatorHandle}');
  if (!item.approved) parts.add('Onay bekliyor');
  return parts.join(' · ');
}
