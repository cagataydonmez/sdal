import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/feature_scaffold.dart';
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
    return FeatureScaffold(
      title: 'Albümler',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/albums/upload'),
        label: const Text('Yükle'),
        icon: const Icon(Icons.upload_rounded),
      ),
      child: ListView(
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
                        onPressed: () => context.push('/albums/${category.id}'),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 16),
            if (_latest.isEmpty)
              const SurfaceCard(child: Text('Henüz albüm fotoğrafı yok.'))
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _latest
                    .map(
                      (photo) => GestureDetector(
                        onTap: () => context.push('/albums/photo/${photo.id}'),
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(_thumbUrl(photo.fileName)),
                              fit: BoxFit.cover,
                              onError: (_, _) {},
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (_hasMore) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: FilledButton.tonal(
                  onPressed: _isLoadingMore ? null : () => _load(reset: false),
                  child: Text(
                    _isLoadingMore ? 'Yükleniyor...' : 'Daha fazla fotoğraf',
                  ),
                ),
              ),
            ],
          ],
        ],
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

String _thumbUrl(String fileName) =>
    '/api/media/kucukresim?width=240&file=${Uri.encodeComponent(fileName)}';
