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
    final actionState = ref.watch(communityActionControllerProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final isAdmin = session?.hasAdminAccess ?? false;
    final isSaving =
        actionState.isLoading && actionState.scope == 'announcements:create';
    final l10n = context.l10n;

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
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni duyuru öner',
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
                    controller: _bodyController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'İçerik',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _imageFile == null
                              ? 'Görsel ekle'
                              : 'Görsel değiştir',
                        ),
                      ),
                      if (_imageFile != null)
                        Text(
                          _imageFile!.path.split('/').last,
                          style: TextStyle(
                            color: Theme.of(context).sdal.foregroundMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving ? null : _create,
                      child: Text(
                        isSaving ? 'Gönderiliyor...' : 'Duyuruyu gönder',
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
                  icon: Icons.campaign_outlined,
                  title: l10n.announcementsEmptyTitle,
                  message: l10n.announcementsEmptyMessage,
                  actionLabel: l10n.refreshAction,
                  onAction: () => _load(reset: true),
                ),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push('/announcements/${item.id}'),
                    child: SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (isAdmin)
                            Align(
                              alignment: Alignment.topRight,
                              child: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'approve') {
                                    await _approveAnnouncement(
                                      item.id,
                                      approved: true,
                                    );
                                    return;
                                  }
                                  if (value == 'reject') {
                                    await _approveAnnouncement(
                                      item.id,
                                      approved: false,
                                    );
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
                          Text(_plainText(item.body)),
                          const SizedBox(height: 12),
                          Text(
                            _metaLine(
                              context,
                              item.createdAt,
                              item.creatorHandle,
                              item.approved,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).sdal.foregroundMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
