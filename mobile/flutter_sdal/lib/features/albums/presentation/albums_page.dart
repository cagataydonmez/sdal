import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  AlbumsDashboardData? _dashboard;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Albümler',
      background: FeatureScaffoldBackground.immersive,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showActions,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Albüm işlemleri'),
      ),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error.isNotEmpty)
              SurfaceCard(child: Text(_error))
            else if (_dashboard == null)
              const SurfaceCard(child: Text('Albüm verisi alınamadı.'))
            else ...[
              if (_dashboard!.latest.isNotEmpty)
                _AlbumBarSection(
                  title: 'En yeni fotoğraflar',
                  subtitle:
                      'Son eklenen 10 fotoğraf. Sağa kaydırarak göz atabilirsin.',
                  items: _dashboard!.latest,
                ),
              if (_dashboard!.popular.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AlbumBarSection(
                  title: 'En çok görüntülenenler',
                  subtitle: 'En çok bakılan fotoğraflar.',
                  items: _dashboard!.popular,
                ),
              ],
              const SizedBox(height: 16),
              _AlbumCategorySection(
                title: 'Albüm kategorileri',
                items: _dashboard!.categories,
                onDelete: _deleteAlbum,
              ),
              if (_dashboard!.mine.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AlbumCategorySection(
                  title: 'Albümün ve profil albümlerin',
                  items: _dashboard!.mine,
                  compact: true,
                  onDelete: _deleteAlbum,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final dashboard = await ref
          .read(albumsRepositoryProvider)
          .fetchDashboard();
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showActions() async {
    final dashboard = _dashboard;
    if (dashboard == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_rounded),
              title: const Text('Fotoğraf yükle'),
              subtitle: const Text('Ana sayfadan girince önce albüm seçersin.'),
              onTap: () {
                Navigator.of(context).pop();
                this.context.push('/albums/upload');
              },
            ),
            if (dashboard.canCreateAlbum)
              ListTile(
                leading: const Icon(Icons.photo_album_outlined),
                title: const Text('Albüm oluştur'),
                subtitle: Text(
                  dashboard.canManageCategories
                      ? 'Genel, cohort veya profil albümü oluştur.'
                      : 'Profilinde görünecek yeni albüm oluştur.',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  this.context.push(
                    dashboard.canManageCategories
                        ? '/albums/new'
                        : '/albums/new?profile=1',
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (mounted) {
      ref.invalidate(albumsDashboardProvider);
      await _load();
    }
  }

  Future<void> _deleteAlbum(AlbumCategoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.title} silinsin mi?'),
        content: const Text('Albüm kaldırılacak. Bu işlem geri alınamaz.'),
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
        .read(albumsActionControllerProvider.notifier)
        .deleteAlbum(item.id);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Albüm silindi.' : 'Albüm silinemedi.'),
        ),
      ),
    );
    if (ok) {
      ref.invalidate(albumsDashboardProvider);
      ref.invalidate(myAlbumsProvider);
      await _load();
    }
  }
}

class _AlbumBarSection extends ConsumerWidget {
  const _AlbumBarSection({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<AlbumPhotoCard> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => context.push('/albums/photo/${item.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 98,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 98,
                          height: 98,
                          child: SdalNetworkImage(
                            imageUrl: config.siteBaseUri
                                .resolve(_thumbPath(item.fileName, width: 220))
                                .toString(),
                            borderRadius: BorderRadius.circular(18),
                            fit: BoxFit.cover,
                            cacheWidth: 220,
                            cacheHeight: 220,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          item.categoryTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumCategorySection extends StatelessWidget {
  const _AlbumCategorySection({
    required this.title,
    required this.items,
    this.compact = false,
    this.onDelete,
  });

  final String title;
  final List<AlbumCategoryItem> items;
  final bool compact;
  final Future<void> Function(AlbumCategoryItem item)? onDelete;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/albums/${item.id}'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (!compact || item.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.description.isNotEmpty
                                    ? item.description
                                    : _albumMeta(item),
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.canEdit && onDelete != null)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  onDelete!(item);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Albümü sil'),
                                ),
                              ],
                            ),
                          Text(
                            '${item.count}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            'fotoğraf',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _albumMeta(AlbumCategoryItem item) {
    if (item.isCohortAlbum && item.cohortYear.isNotEmpty) {
      return '${item.cohortYear} cohortu';
    }
    if (item.isProfileAlbum) return 'Profil albümü';
    if (item.visibilityScope == 'custom' || item.visibilityScope == 'private') {
      return 'Özel erişim';
    }
    return 'Genel albüm';
  }
}

String _thumbPath(String fileName, {int width = 240}) =>
    '/api/media/kucukresim?width=$width&file=${Uri.encodeComponent(fileName)}';
