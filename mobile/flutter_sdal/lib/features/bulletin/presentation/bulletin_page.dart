import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/bulletin_repository.dart';

class BulletinPage extends ConsumerStatefulWidget {
  const BulletinPage({super.key, this.initialCategoryId = 0});

  final int initialCategoryId;

  @override
  ConsumerState<BulletinPage> createState() => _BulletinPageState();
}

class _BulletinPageState extends ConsumerState<BulletinPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<BulletinMessage> _items = <BulletinMessage>[];

  BulletinCategoryOption? _gradCategory;
  int _categoryId = 0;
  String _categoryName = 'Genel';
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _isSaving = false;
  bool _hasMore = true;
  bool _canDelete = false;
  String _error = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Panolar',
      actions: [
        IconButton(
          onPressed: _isLoadingInitial ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          if (_gradCategory != null || _categoryId != 0) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Genel'),
                  selected: _categoryId == 0,
                  onSelected: (_) => _changeCategory(0),
                ),
                if (_gradCategory != null)
                  ChoiceChip(
                    label: Text(_gradCategory!.name),
                    selected: _categoryId == _gradCategory!.id,
                    onSelected: (_) => _changeCategory(_gradCategory!.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const PageOnboardingCard(
            id: 'bulletin-main',
            icon: Icons.forum_outlined,
            title: 'Panolar hızlı, yerel ve kısa duyurular içindir.',
            message:
                'Genel pano tüm topluluğa açıktır; mezuniyet panonu seçtiğinde kendi döneminin günlük ihtiyaçlarına ve notlarına odaklanırsın.',
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_categoryName panosuna yaz',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mesaj',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _create,
                    child: Text(
                      _isSaving ? 'Gönderiliyor...' : 'Mesajı paylaş',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panolar yüklenemedi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(_error),
                ],
              ),
            )
          else if (_items.isEmpty)
            const SurfaceCard(child: Text('Bu panoda henüz mesaj yok.'))
          else
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BulletinMessageCard(
                  item: item,
                  canDelete: _canDelete,
                  onDelete: () => _delete(item.id),
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
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_isLoadingMore) return;
    setState(() {
      if (reset) {
        _isLoadingInitial = true;
        _page = 1;
        _items.clear();
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
      _error = '';
    });

    final repository = ref.read(bulletinRepositoryProvider);
    try {
      final data = await repository.fetchBoard(
        categoryId: _categoryId,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _categoryId = data.categoryId;
        _categoryName = data.categoryName;
        _gradCategory = data.gradCategory?.id == 0 ? null : data.gradCategory;
        _canDelete = data.canDelete;
        if (reset) {
          _items
            ..clear()
            ..addAll(data.messages);
        } else {
          _items.addAll(data.messages);
        }
        _hasMore = data.hasMore;
        _page = data.page + 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mesaj yazmadın.')));
      return;
    }
    setState(() => _isSaving = true);
    final result = await ref
        .read(bulletinRepositoryProvider)
        .createMessage(categoryId: _categoryId, message: message);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : 'Mesaj gönderilemedi.',
          ),
        ),
      );
      return;
    }
    _messageController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mesaj paylaşıldı.')));
    await _load(reset: true);
  }

  Future<void> _delete(int messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesaj silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
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
    if (confirmed != true) return;
    final result = await ref
        .read(bulletinRepositoryProvider)
        .deleteMessage(messageId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Mesaj silindi.'
              : (result.message.isNotEmpty
                    ? result.message
                    : 'Silme başarısız.'),
        ),
      ),
    );
    if (result.ok) {
      await _load(reset: true);
    }
  }

  void _changeCategory(int nextCategoryId) {
    if (_categoryId == nextCategoryId) return;
    setState(() {
      _categoryId = nextCategoryId;
      _categoryName = nextCategoryId == 0 ? 'Genel' : _categoryName;
    });
    _load(reset: true);
  }

  void _onScroll() {
    if (_isLoadingInitial || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _load(reset: false);
    }
  }
}

class _BulletinMessageCard extends ConsumerWidget {
  const _BulletinMessageCard({
    required this.item,
    required this.canDelete,
    required this.onDelete,
  });

  final BulletinMessage item;
  final bool canDelete;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final muted = Theme.of(context).sdal.foregroundMuted;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteAvatar(
                label: item.author.displayName,
                imageUrl: config.resolveUrl(item.author.photo).toString(),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.author.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.createdAt == null
                          ? 'Tarih bilgisi yok'
                          : formatSdalDateTime(context, item.createdAt!),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (item.isNew)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).sdal.accentMuted,
                    borderRadius: BorderRadius.circular(
                      SdalThemeTokens.radiusPill,
                    ),
                  ),
                  child: const Text('Yeni'),
                ),
              if (canDelete)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'delete', child: Text('Sil')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(plainTextFromRichContent(item.bodyHtml)),
        ],
      ),
    );
  }
}
