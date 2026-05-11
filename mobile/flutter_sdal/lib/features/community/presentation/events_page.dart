import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/page_onboarding_card.dart';
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
  final ScrollController _scrollController = ScrollController();
  final List<EventItem> _items = <EventItem>[];

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
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final isAdmin = session?.hasAdminAccess ?? false;
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
                _buildHeroEventCard(heroItem, isAdmin),
                const SizedBox(height: 24),
              ],
              ...otherItems.map((item) => _buildEventCard(item, isAdmin)),
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
                onPressed: () => context.push('/events/create'),
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
    final sorted = [..._items];
    sorted.sort((a, b) {
      final aScore = a.attendCount + a.declineCount;
      final bScore = b.attendCount + b.declineCount;
      return bScore.compareTo(aScore);
    });
    return sorted;
  }

  Widget _buildHeroEventCard(EventItem item, bool isAdmin) {
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
              if (isAdmin)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _EventAdminMenu(
                    item: item,
                    onApprove: (approved) => _approveEvent(item.id, approved: approved),
                    onDelete: () => _deleteEvent(item.id),
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

  Widget _buildEventCard(EventItem item, bool isAdmin) {
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
              if (isAdmin)
                _EventAdminMenu(
                  item: item,
                  onApprove: (approved) => _approveEvent(item.id, approved: approved),
                  onDelete: () => _deleteEvent(item.id),
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
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
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
    if (remaining < 240) _load(reset: false);
  }
}

class _EventAdminMenu extends StatelessWidget {
  const _EventAdminMenu({
    required this.item,
    required this.onApprove,
    required this.onDelete,
    required this.dark,
  });

  final EventItem item;
  final void Function(bool approved) onApprove;
  final VoidCallback onDelete;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: dark ? Colors.white : null,
      ),
      onSelected: (value) {
        if (value == 'approve') onApprove(true);
        if (value == 'reject') onApprove(false);
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (!item.approved)
          const PopupMenuItem<String>(value: 'approve', child: Text('Onayla')),
        if (item.approved)
          const PopupMenuItem<String>(
            value: 'reject',
            child: Text('Yayından kaldır'),
          ),
        const PopupMenuItem<String>(value: 'delete', child: Text('Sil')),
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
