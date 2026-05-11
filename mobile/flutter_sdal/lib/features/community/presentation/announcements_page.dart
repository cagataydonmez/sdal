import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
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

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AnnouncementItem> _items = <AnnouncementItem>[];

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
    _bodyController.dispose();
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
    final otherItems = sortedItems.length > 1 ? sortedItems.skip(1).toList() : [];

    return FeatureScaffold(
      title: l10n.announcementsTitle,
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const PageOnboardingCard(
              id: 'announcements-main',
              icon: Icons.campaign_outlined,
              title: 'Duyurular topluluğun resmi nabzı.',
              message:
                  'Önemli gelişmeleri buradan takip et; duyuru önerilerin incelenir ve uygun olduğunda tüm SDAL topluluğuyla paylaşılır.',
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
                  icon: Icons.campaign_outlined,
                  title: l10n.announcementsEmptyTitle,
                  message: l10n.announcementsEmptyMessage,
                  actionLabel: l10n.refreshAction,
                  onAction: () => _load(reset: true),
                ),
              )
            else ...[
              if (heroItem != null) ...[
                _buildHeroAnnouncementCard(heroItem, isAdmin),
                const SizedBox(height: 24),
              ],
              ...otherItems.map((item) => _buildAnnouncementCard(item, isAdmin)),
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
                onPressed: () => context.push('/announcements/create'),
                icon: const Icon(Icons.add_outlined),
                label: const Text('Yeni duyuru öner'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AnnouncementItem> _getSortedItems() {
    final sorted = [..._items];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Widget _buildHeroAnnouncementCard(AnnouncementItem item, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _buildAnnouncementImage(item),
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
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
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
                      color: Theme.of(context).sdal.accent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '📢',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'En yeni duyuru',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .sdal
                                .foregroundOnAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/announcements/${item.id}'),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_outward,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _metaLine(context, item.createdAt, item.creatorHandle, item.approved),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).sdal.foregroundMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _plainText(item.body),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'approve') {
                        await _approveAnnouncement(item.id, approved: true);
                        return;
                      }
                      if (value == 'reject') {
                        await _approveAnnouncement(item.id, approved: false);
                        return;
                      }
                      if (value == 'delete') {
                        await _deleteAnnouncement(item.id);
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
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(AnnouncementItem item, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/announcements/${item.id}'),
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 100,
                      height: 64,
                      child: _buildAnnouncementImage(item),
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
                          _metaLine(context, item.createdAt, item.creatorHandle, item.approved),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).sdal.foregroundMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'approve') {
                          await _approveAnnouncement(item.id, approved: true);
                          return;
                        }
                        if (value == 'reject') {
                          await _approveAnnouncement(item.id, approved: false);
                          return;
                        }
                        if (value == 'delete') {
                          await _deleteAnnouncement(item.id);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementImage(AnnouncementItem item) {
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
          Icons.campaign_outlined,
          size: 64,
          color: Theme.of(context).sdal.foregroundMuted,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await pickAndCropImage(
      context,
      source: source,
      aspectPreset: CropAspectPreset.wide169,
      title: 'Duyuru görselini hazırla',
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = picked);
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve içerik gerekli.')),
      );
      return;
    }
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .createAnnouncement(title: title, body: body, imageFile: _imageFile);
    if (!mounted) return;
    final actionState = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ??
              (ok ? 'Duyuru gönderildi.' : 'Duyuru gönderilemedi.'),
        ),
      ),
    );
    if (!ok) return;
    _titleController.clear();
    _bodyController.clear();
    setState(() => _imageFile = null);
    _load(reset: true);
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
          .fetchAnnouncements(offset: reset ? 0 : _items.length);
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

  Future<void> _approveAnnouncement(
    int announcementId, {
    required bool approved,
  }) async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .approveAnnouncement(
          announcementId: announcementId,
          approved: approved,
        );
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? (approved
                        ? 'Duyuru onaylandı.'
                        : 'Duyuru yayından kaldırıldı.')
                  : 'İşlem başarısız oldu.'),
        ),
      ),
    );
    if (ok) _load(reset: true);
  }

  Future<void> _deleteAnnouncement(int announcementId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyuru silinsin mi?'),
        content: const Text('Bu işlem duyuruyu kalıcı olarak kaldırır.'),
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
        .deleteAnnouncement(announcementId);
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Duyuru silindi.' : 'Duyuru silinemedi.'),
        ),
      ),
    );
    if (ok) _load(reset: true);
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

String _plainText(String raw) {
  return plainTextFromRichContent(raw);
}

String _metaLine(
  BuildContext context,
  String createdAt,
  String handle,
  bool approved,
) {
  final parts = <String>[];
  if (createdAt.isNotEmpty) {
    parts.add(formatSdalTimestamp(context, createdAt));
  }
  if (handle.isNotEmpty) parts.add('@$handle');
  if (!approved) parts.add('Onay bekliyor');
  return parts.join(' · ');
}
