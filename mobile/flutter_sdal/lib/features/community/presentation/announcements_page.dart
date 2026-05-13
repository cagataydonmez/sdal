import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/media/pick_cropped_image.dart';
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
import '../../feed/application/feed_action_controller.dart';
import '../data/community_repository.dart';

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<AnnouncementItem> _items = <AnnouncementItem>[];
  final List<AnnouncementItem> _draftItems = <AnnouncementItem>[];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showDrafts = false;
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
    final userId = session?.user?.id ?? 0;
    final isAdmin = session?.hasAdminAccess ?? false;
    final l10n = context.l10n;
    final sortedItems = _getSortedItems();
    final heroItem = sortedItems.isNotEmpty ? sortedItems.first : null;
    final otherItems = sortedItems.length > 1
        ? sortedItems.skip(1).toList()
        : <AnnouncementItem>[];

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
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Yayınlanan'),
                  selected: !_showDrafts,
                  onSelected: (selected) => setState(() => _showDrafts = false),
                ),
                FilterChip(
                  label: const Text('Taslaklar'),
                  selected: _showDrafts,
                  onSelected: (selected) => setState(() => _showDrafts = true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoadingInitial)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty && _getSortedItems().isEmpty)
              SurfaceCard(
                child: ErrorView(
                  message: _error,
                  kind: ErrorViewKind.network,
                  onRetry: () => _load(reset: true),
                ),
              )
            else if (_getSortedItems().isEmpty)
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
                _buildHeroCard(heroItem, isAdmin, userId),
                const SizedBox(height: 24),
              ],
              ...otherItems.map((item) => _buildCard(item, isAdmin, userId)),
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
                  final result = await context.push('/announcements/create');
                  if (mounted && result == true) _load(reset: true);
                },
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
    final items = _showDrafts ? _draftItems : _items;
    final sorted = [...items];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<void> _openAnnouncementDetail(int announcementId) async {
    await context.push('/announcements/$announcementId');
    if (mounted) _load(reset: true);
  }

  Widget _buildHeroCard(AnnouncementItem item, bool isAdmin, int userId) {
    final isOwner = item.createdBy == userId;
    return GestureDetector(
      onTap: () => _openAnnouncementDetail(item.id),
      child: Column(
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
                        color: Theme.of(
                          context,
                        ).sdal.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📢', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            'En yeni duyuru',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).sdal.foregroundOnAccent,
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
                  child: _AnnouncementAdminMenu(
                    item: item,
                    isOwner: isOwner,
                    onApprove: (approved) =>
                        _approveAnnouncement(item.id, approved: approved),
                    onEdit: () => _editAnnouncement(item),
                    onDelete: () => _deleteAnnouncement(item.id),
                    dark: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _metaLine(
                context,
                item.createdAt,
                item.creatorHandle,
                item.approved,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).sdal.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AnnouncementItem item, bool isAdmin, int userId) {
    final isOwner = item.createdBy == userId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openAnnouncementDetail(item.id),
        child: SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
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
                      _metaLine(
                        context,
                        item.createdAt,
                        item.creatorHandle,
                        item.approved,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).sdal.foregroundMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isAdmin || isOwner)
                _AnnouncementAdminMenu(
                  item: item,
                  isOwner: isOwner,
                  onApprove: (approved) =>
                      _approveAnnouncement(item.id, approved: approved),
                  onEdit: () => _editAnnouncement(item),
                  onDelete: () => _deleteAnnouncement(item.id),
                  dark: false,
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
          size: 40,
          color: Theme.of(context).sdal.foregroundMuted,
        ),
      ),
    );
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

  Future<void> _editAnnouncement(AnnouncementItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _AnnouncementEditDialog(item: item, onSave: () => _load(reset: true)),
    );
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
      final approved = await ref
          .read(communityRepositoryProvider)
          .fetchAnnouncements(
            offset: reset ? 0 : _items.length,
            status: 'published',
          );
      final drafts = await ref
          .read(communityRepositoryProvider)
          .fetchAnnouncements(
            offset: reset ? 0 : _draftItems.length,
            status: 'drafts',
          );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(approved.items);
          _draftItems
            ..clear()
            ..addAll(drafts.items);
        } else {
          _items.addAll(approved.items);
          _draftItems.addAll(drafts.items);
        }
        _hasMore = approved.hasMore || drafts.hasMore;
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

class _AnnouncementAdminMenu extends StatelessWidget {
  const _AnnouncementAdminMenu({
    required this.item,
    required this.isOwner,
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
    required this.dark,
  });

  final AnnouncementItem item;
  final bool isOwner;
  final void Function(bool approved) onApprove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: dark ? Colors.white : null),
      onSelected: (value) {
        if (value == 'approve') onApprove(true);
        if (value == 'reject') onApprove(false);
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (!item.approved && !isOwner)
          const PopupMenuItem<String>(value: 'approve', child: Text('Onayla')),
        if (item.approved && !isOwner)
          const PopupMenuItem<String>(
            value: 'reject',
            child: Text('Yayından kaldır'),
          ),
        if (isOwner)
          const PopupMenuItem<String>(value: 'edit', child: Text('Düzenle')),
        const PopupMenuItem<String>(value: 'delete', child: Text('Sil')),
      ],
    );
  }
}

class _AnnouncementEditDialog extends ConsumerStatefulWidget {
  const _AnnouncementEditDialog({required this.item, required this.onSave});

  final AnnouncementItem item;
  final VoidCallback onSave;

  @override
  ConsumerState<_AnnouncementEditDialog> createState() =>
      _AnnouncementEditDialogState();
}

class _AnnouncementEditDialogState
    extends ConsumerState<_AnnouncementEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  File? _imageFile;
  bool _showInFeed = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _bodyController = TextEditingController(text: widget.item.body);
    _showInFeed = widget.item.approved;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(communityActionControllerProvider);
    final isSaving =
        actionState.isLoading && actionState.scope == 'announcements:edit';

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Duyuruyu Düzenle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bodyController,
                enabled: !isSaving,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'İçerik',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isSaving
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _imageFile == null
                      ? (widget.item.image.isNotEmpty
                            ? 'Görsel değiştir'
                            : 'Görsel ekle')
                      : 'Görsel değiştir',
                ),
              ),
              if (_imageFile != null || widget.item.image.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, height: 200, fit: BoxFit.cover)
                      : Image.network(
                          widget.item.image,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hemen yayınla'),
                subtitle: Text(
                  _showInFeed
                      ? 'Duyuru taslak yerine yayınlanmış olarak kaydedilecek'
                      : 'Duyuru taslak olarak kaydedilecek, detay sayfasından yayınlayabilirsiniz',
                ),
                value: _showInFeed,
                onChanged: isSaving
                    ? null
                    : (v) => setState(() => _showInFeed = v),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: isSaving ? null : _save,
                    child: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                  ),
                ],
              ),
            ],
          ),
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve içerik gerekli.')),
      );
      return;
    }
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .editAnnouncement(
          announcementId: widget.item.id,
          title: title,
          body: body,
          imageFile: _imageFile,
          approved: _showInFeed,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Duyuru güncellendi.' : 'Güncellenemedi.')),
    );
    if (ok) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSave();
    }
  }
}

String _metaLine(
  BuildContext context,
  String createdAt,
  String handle,
  bool approved,
) {
  final parts = <String>[];
  if (createdAt.isNotEmpty) parts.add(formatSdalTimestamp(context, createdAt));
  if (handle.isNotEmpty) parts.add('@$handle');
  if (!approved) parts.add('Onay bekliyor');
  return parts.join(' · ');
}
