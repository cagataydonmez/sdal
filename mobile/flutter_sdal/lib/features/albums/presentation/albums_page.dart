import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/albums_repository.dart';

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  List<AlbumCategoryItem> _categories = const <AlbumCategoryItem>[];
  final List<AlbumLatestPhoto> _latest = <AlbumLatestPhoto>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    return FeatureScaffold(
      title: l10n.albumsTitle,
      background: FeatureScaffoldBackground.immersive,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/albums/upload'),
        label: Text(l10n.albumsUploadAction),
        icon: const Icon(Icons.upload_rounded),
      ),
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
            else ...[
              SurfaceCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories
                      .map(
                        (category) => ActionChip(
                          label: Text('${category.title} (${category.count})'),
                          onPressed: () =>
                              context.push('/albums/${category.id}'),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 16),
              if (_latest.isEmpty)
                SurfaceCard(child: Text(l10n.albumsEmpty))
              else
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
                        for (var index = 0; index < _latest.length; index++)
                          SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: Semantics(
                              button: true,
                              label: l10n.albumsOpenPhotoSemantic(
                                '${index + 1}',
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => context.push(
                                  '/albums/photo/${_latest[index].id}',
                                ),
                                child: SdalNetworkImage(
                                  imageUrl: config.siteBaseUri
                                      .resolve(
                                        _thumbPath(_latest[index].fileName),
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
                    onPressed: _isLoadingMore
                        ? null
                        : () => _load(reset: false),
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
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = '';
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final repo = ref.read(albumsRepositoryProvider);
      final categories = reset ? await repo.fetchCategories() : _categories;
      final latest = await repo.fetchLatest(offset: reset ? 0 : _latest.length);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (reset) {
          _latest
            ..clear()
            ..addAll(latest.items);
        } else {
          _latest.addAll(latest.items);
        }
        _hasMore = latest.hasMore;
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
}

String _thumbPath(String fileName) =>
    '/api/media/kucukresim?width=240&file=${Uri.encodeComponent(fileName)}';
