import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/feature_scaffold.dart';
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
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: _detail?.title ?? 'Albüm',
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
            const SurfaceCard(child: Text('Kategori bulunamadı.'))
          else ...[
            if (_detail!.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SurfaceCard(child: Text(_detail!.description)),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _detail!.photos
                  .map(
                    (photo) => GestureDetector(
                      onTap: () => context.push('/albums/photo/${photo.id}'),
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(
                              '/api/media/kucukresim?width=260&file=${Uri.encodeComponent(photo.fileName)}',
                            ),
                            fit: BoxFit.cover,
                            onError: (_, _) {},
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final detail = await ref
          .read(albumsRepositoryProvider)
          .fetchCategoryDetail(widget.categoryId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
