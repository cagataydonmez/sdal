import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';

class AlbumCategoryPage extends ConsumerStatefulWidget {
  const AlbumCategoryPage({super.key, required this.categoryId});

  final int categoryId;

  @override
  ConsumerState<AlbumCategoryPage> createState() => _AlbumCategoryPageState();
}

class _AlbumCategoryPageState extends ConsumerState<AlbumCategoryPage> {
  AlbumCategoryDetail? _detail;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return FeatureScaffold(
      title: _detail?.title ?? 'Albüm',
      actions: [
        if (_detail?.canEdit ?? false)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editAlbum();
              }
              if (value == 'delete') {
                _deleteAlbum();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Albümü düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Albümü sil')),
            ],
          ),
      ],
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error.isNotEmpty)
              SurfaceCard(child: Text(_error))
            else if (_detail == null)
              const SurfaceCard(child: Text('Albüm bulunamadı.'))
            else ...[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _detail!.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_detail!.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_detail!.description),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${_detail!.total} fotoğraf • ${_detail!.visibilityScope}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_detail!.canUpload) ...[
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () async {
                          await context.push(
                            '/albums/upload?albumId=${widget.categoryId}',
                          );
                          if (mounted) _load(reset: true);
                        },
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Bu albüme fotoğraf yükle'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 820
                      ? 4
                      : constraints.maxWidth > 560
                      ? 3
                      : 2;
                  const spacing = 10.0;
                  final itemWidth =
                      (constraints.maxWidth - (spacing * (columns - 1))) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: _detail!.photos
                        .map(
                          (photo) => InkWell(
                            onTap: () =>
                                context.push('/albums/photo/${photo.id}'),
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: itemWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    height: itemWidth,
                                    child: Stack(
                                      children: [
                                        if (photo.groupCount > 1) ...[
                                          Positioned.fill(
                                            top: 8,
                                            left: 8,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                          Positioned.fill(
                                            top: 4,
                                            left: 4,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surfaceContainer,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ],
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: SdalNetworkImage(
                                              imageUrl: _photoMediaUrl(
                                                config,
                                                photo.media,
                                                width: 640,
                                                fallbackFileName:
                                                    photo.fileName,
                                              ),
                                              lightboxImageUrl: _photoMediaUrl(
                                                config,
                                                photo.media,
                                                width: 2200,
                                                fallbackFileName:
                                                    photo.fileName,
                                              ),
                                              fit: BoxFit.contain,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              enableLightbox: false,
                                              cacheWidth: (itemWidth * 2)
                                                  .round(),
                                              cacheHeight: (itemWidth * 2)
                                                  .round(),
                                            ),
                                          ),
                                        ),
                                        if (photo.groupCount > 1)
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.58,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${photo.groupCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    photo.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  Text(
                                    '${photo.likeCount} beğeni • ${photo.commentCount} yorum',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              if (_detail!.hasMore) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: FilledButton.tonal(
                    onPressed: _isLoadingMore
                        ? null
                        : () => _load(reset: false),
                    child: Text(
                      _isLoadingMore ? 'Yükleniyor...' : 'Daha fazla göster',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      if (_isLoadingMore || !(_detail?.hasMore ?? false)) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final nextPage = reset ? 1 : (_detail?.page ?? 1) + 1;
      final detail = await ref
          .read(albumsRepositoryProvider)
          .fetchCategoryDetail(widget.categoryId, page: nextPage);
      if (!mounted) return;
      setState(() {
        if (reset || _detail == null) {
          _detail = detail;
        } else {
          _detail = AlbumCategoryDetail(
            id: detail.id,
            title: detail.title,
            description: detail.description,
            photos: [..._detail!.photos, ...detail.photos],
            page: detail.page,
            pages: detail.pages,
            total: detail.total,
            visibilityScope: detail.visibilityScope,
            cohortYear: detail.cohortYear,
            albumType: detail.albumType,
            canUpload: detail.canUpload,
            canEdit: detail.canEdit,
            coverMode: detail.coverMode,
            coverFileName: detail.coverFileName,
            allowedMembers: detail.allowedMembers,
            allowedGroups: detail.allowedGroups,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _editAlbum() async {
    await context.push('/albums/${widget.categoryId}/edit');
    if (mounted) await _load(reset: true);
  }

  Future<void> _deleteAlbum() async {
    final detail = _detail;
    if (detail == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${detail.title} silinsin mi?'),
        content: const Text('Albüm ve erişim ayarları kaldırılacak.'),
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
        .deleteAlbum(detail.id);
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
      context.pop();
    }
  }
}

String _photoMediaUrl(
  AppConfig config,
  AlbumPhotoMedia media, {
  required int width,
  required String fallbackFileName,
}) {
  final preferred = width >= 1400
      ? (media.lightboxUrl.isNotEmpty ? media.lightboxUrl : media.displayUrl)
      : (media.thumbnailUrl.isNotEmpty ? media.thumbnailUrl : media.displayUrl);
  final path = preferred.isNotEmpty
      ? preferred
      : '/api/media/kucukresim?width=$width&file=${Uri.encodeComponent(fallbackFileName)}';
  return config.siteBaseUri.resolve(path).toString();
}
