import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
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
  bool _hasMore = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    return FeatureScaffold(
      title: _detail?.title ?? l10n.albumTitleFallback,
      background: FeatureScaffoldBackground.immersive,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            SurfaceCard(child: Text(_error))
          else if (_detail == null)
            SurfaceCard(child: Text(l10n.albumsCategoryMissing))
          else ...[
            if (_detail!.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SurfaceCard(child: Text(_detail!.description)),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 720
                    ? 4
                    : constraints.maxWidth > 520
                    ? 3
                    : 2;
                final spacing = 10.0;
                final itemWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (var index = 0; index < _detail!.photos.length; index++)
                      SizedBox(
                        width: itemWidth,
                        height: itemWidth,
                        child: Semantics(
                          button: true,
                          label: l10n.albumsOpenPhotoSemantic('${index + 1}'),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.push(
                              '/albums/photo/${_detail!.photos[index].id}',
                            ),
                            child: SdalNetworkImage(
                              imageUrl: config.siteBaseUri
                                  .resolve(
                                    '/api/media/kucukresim?width=260&file=${Uri.encodeComponent(_detail!.photos[index].fileName)}',
                                  )
                                  .toString(),
                              borderRadius: BorderRadius.circular(18),
                              cacheWidth: (itemWidth * 2).round(),
                              cacheHeight: (itemWidth * 2).round(),
                              semanticLabel: l10n.albumsOpenPhotoSemantic(
                                '${index + 1}',
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_hasMore) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: FilledButton.tonal(
                  onPressed: _isLoadingMore ? null : _loadMore,
                  child: Text(
                    _isLoadingMore
                        ? l10n.submitInProgress
                        : l10n.albumsLoadMore,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _hasMore = true;
    });
    try {
      final detail = await ref
          .read(albumsRepositoryProvider)
          .fetchCategoryDetail(widget.categoryId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _hasMore = detail.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    final detail = _detail;
    if (detail == null || _isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = await ref
          .read(albumsRepositoryProvider)
          .fetchCategoryDetail(widget.categoryId, page: detail.page + 1);
      if (!mounted) return;
      setState(() {
        _detail = AlbumCategoryDetail(
          id: nextPage.id,
          title: nextPage.title,
          description: nextPage.description,
          photos: [...detail.photos, ...nextPage.photos],
          page: nextPage.page,
          pages: nextPage.pages,
        );
        _hasMore = nextPage.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Daha fazla yüklenemedi.')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }
}
