import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';

class AlbumPhotoPage extends ConsumerStatefulWidget {
  const AlbumPhotoPage({super.key, required this.photoId});

  final int photoId;

  @override
  ConsumerState<AlbumPhotoPage> createState() => _AlbumPhotoPageState();
}

class _AlbumPhotoPageState extends ConsumerState<AlbumPhotoPage> {
  final TextEditingController _commentController = TextEditingController();
  AlbumPhotoDetail? _photo;
  List<AlbumComment> _comments = const <AlbumComment>[];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(albumsActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;

    return FeatureScaffold(
      title: _photo?.title ?? 'Fotoğraf',
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
          else if (_photo == null)
            const SurfaceCard(child: Text('Fotoğraf bulunamadı.'))
          else ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      '/api/media/kucukresim?width=1200&file=${Uri.encodeComponent(_photo!.fileName)}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _photo!.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_photo!.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_plainText(_photo!.description)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(_photo!.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yorum ekle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Yorum',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed:
                          actionState.isLoading &&
                              actionState.scope ==
                                  'albums:comment:${widget.photoId}'
                          ? null
                          : _submitComment,
                      child: Text(
                        actionState.isLoading &&
                                actionState.scope ==
                                    'albums:comment:${widget.photoId}'
                            ? 'Gönderiliyor...'
                            : 'Yorumu gönder',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_comments.isEmpty)
              const SurfaceCard(child: Text('Henüz yorum yok.'))
            else
              ..._comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RemoteAvatar(
                          label: comment.displayName,
                          imageUrl: config.resolveUrl(comment.photo).toString(),
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      comment.displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  if (comment.verified)
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: tokens.info,
                                    ),
                                ],
                              ),
                              Text(
                                _formatDate(comment.date),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.foregroundMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(_plainText(comment.comment)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .addComment(photoId: widget.photoId, comment: comment);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Yorum gönderildi.' : 'Yorum gönderilemedi.'),
        ),
      ),
    );
    if (!ok) return;
    _commentController.clear();
    final comments = await ref
        .read(albumsRepositoryProvider)
        .fetchComments(widget.photoId);
    if (!mounted) return;
    setState(() => _comments = comments);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final repo = ref.read(albumsRepositoryProvider);
      final photo = await repo.fetchPhotoDetail(widget.photoId);
      final comments = await repo.fetchComments(widget.photoId);
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _comments = comments;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

String _plainText(String raw) {
  return plainTextFromRichContent(raw);
}

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}
