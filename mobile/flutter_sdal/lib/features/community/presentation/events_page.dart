import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/community_action_controller.dart';
import '../data/community_repository.dart';
import '../../feed/application/feed_action_controller.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<EventItem> _items = <EventItem>[];
  final List<EventItem> _draftItems = <EventItem>[];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _error = '';
  bool _showDrafts = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final isAdmin = session?.hasAdminAccess ?? false;
    final userId = session?.user?.id ?? 0;
    final l10n = context.l10n;
    final sortedItems = _getSortedItems();
    final heroItem = sortedItems.isNotEmpty ? sortedItems.first : null;
    final otherItems =
        sortedItems.length > 1 ? sortedItems.skip(1).toList() : <EventItem>[];

    return FeatureScaffold(
      title: l10n.eventsTitle,
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const PageOnboardingCard(
              id: 'events-main',
              icon: Icons.event_outlined,
              title: 'Etkinlikler topluluğa öneriyle başlar.',
              message:
                  'Etkinlik önerirken başlık, zaman, konum ve kapak görselini net ver. Yayına alınan etkinliklerde yanıtlar ve yorumlar burada görünür.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    selected: !_showDrafts,
                    label: const Text('Yayınlanan'),
                    onSelected: (_) => setState(() => _showDrafts = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    selected: _showDrafts,
                    label: const Text('Taslaklar'),
                    onSelected: (_) => setState(() => _showDrafts = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
            else ...[
              if (heroItem != null) ...[
                _buildHeroEventCard(heroItem, isAdmin, userId),
                const SizedBox(height: 24),
              ],
              ...otherItems.map((item) => _buildEventCard(item, isAdmin, userId)),
            ],
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await context.push('/events/create');
                  if (mounted) _load(reset: true);
                },
                icon: const Icon(Icons.add_outlined),
                label: const Text('Yeni etkinlik öner'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<EventItem> _getSortedItems() {
    final items = _showDrafts ? _draftItems : _items;
    final sorted = [...items];
    sorted.sort((a, b) {
      final aScore = a.attendCount + a.declineCount;
      final bScore = b.attendCount + b.declineCount;
      return bScore.compareTo(aScore);
    });
    return sorted;
  }

  Widget _buildHeroEventCard(EventItem item, bool isAdmin, int userId) {
    final isOwner = item.createdBy == userId;
    return GestureDetector(
      onTap: () => context.push('/events/${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildEventImage(item),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).sdal.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            '${item.attendCount} katılacak',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).sdal.foregroundOnAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin || isOwner)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _EventAdminMenu(
                    item: item,
                    onApprove: (approved) => _approveEvent(item.id, approved: approved),
                    onDelete: () => _deleteEvent(item.id),
                    onEdit: isOwner ? () => _editEvent(item) : null,
                    isOwner: isOwner,
                    dark: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _eventMeta(context, item),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).sdal.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventItem item, bool isAdmin, int userId) {
    final isOwner = item.createdBy == userId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/events/${item.id}'),
        child: SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 64,
                  child: _buildEventImage(item),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _eventMeta(context, item),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).sdal.foregroundMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '${item.attendCount}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).sdal.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'katılacak',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).sdal.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAdmin || isOwner)
                _EventAdminMenu(
                  item: item,
                  onApprove: (approved) => _approveEvent(item.id, approved: approved),
                  onDelete: () => _deleteEvent(item.id),
                  onEdit: isOwner ? () => _editEvent(item) : null,
                  isOwner: isOwner,
                  dark: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventImage(EventItem item) {
    if (item.image.isNotEmpty) {
      return SdalNetworkImage(
        imageUrl: item.image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorFallback: _buildPlaceholderImage(),
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Theme.of(context).sdal.panelMuted,
      child: Center(
        child: Icon(
          Icons.event_outlined,
          size: 40,
          color: Theme.of(context).sdal.foregroundMuted,
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

  Future<void> _editEvent(EventItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EventEditDialog(event: item),
    );
    if (result == null || !mounted) return;

    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .editEvent(
          eventId: item.id,
          title: result['title'] ?? '',
          description: result['description'] ?? '',
          location: result['location'] ?? '',
          startsAt: result['startsAt'] ?? '',
          endsAt: result['endsAt'] ?? '',
          imageFile: result['imageFile'] as File?,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Etkinlik güncellendi.' : 'Etkinlik düzenlenemedi.',
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
      final publishedPage = await ref
          .read(communityRepositoryProvider)
          .fetchEvents(offset: reset ? 0 : _items.length, approved: true);
      final draftPage = await ref
          .read(communityRepositoryProvider)
          .fetchEvents(offset: reset ? 0 : _draftItems.length, approved: false);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(publishedPage.items);
          _draftItems
            ..clear()
            ..addAll(draftPage.items);
        } else {
          _items.addAll(publishedPage.items);
          _draftItems.addAll(draftPage.items);
        }
        _hasMore = publishedPage.hasMore;
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
    if (remaining < 240) _load(reset: false);
  }
}

class _EventAdminMenu extends StatelessWidget {
  const _EventAdminMenu({
    required this.item,
    required this.onApprove,
    required this.onDelete,
    required this.dark,
    this.onEdit,
    this.isOwner = false,
  });

  final EventItem item;
  final void Function(bool approved) onApprove;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final bool dark;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: dark ? Colors.white : null,
      ),
      onSelected: (value) {
        if (value == 'edit' && onEdit != null) onEdit!();
        if (value == 'approve') onApprove(true);
        if (value == 'reject') onApprove(false);
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (isOwner) ...[
          const PopupMenuItem<String>(value: 'edit', child: Text('Düzenle')),
          const PopupMenuItem<String>(value: 'delete', child: Text('Sil')),
        ] else ...[
          if (!item.approved)
            const PopupMenuItem<String>(value: 'approve', child: Text('Onayla')),
          if (item.approved)
            const PopupMenuItem<String>(
              value: 'reject',
              child: Text('Yayından kaldır'),
            ),
          const PopupMenuItem<String>(value: 'delete', child: Text('Sil')),
        ],
      ],
    );
  }
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
    _descriptionController = TextEditingController(text: plainTextFromRichContent(widget.event.description));
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
                    ? Image.file(
                        _imageFile!,
                        height: 150,
                        fit: BoxFit.cover,
                      )
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

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final datetime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => controller.text = datetime.toIso8601String().substring(0, 16));
  }
}
