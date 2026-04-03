import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/feed_repository.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  bool _submittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postDetailProvider(widget.postId));
    final commentsState = ref.watch(postCommentsProvider(widget.postId));
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Gönderi',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          postState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (post) => post == null
                ? const Text('Gönderi bulunamadı.')
                : SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(post.content),
                        if (post.imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              config.resolveUrl(post.imageUrl).toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                await ref
                                    .read(feedRepositoryProvider)
                                    .toggleLike(widget.postId);
                                ref.invalidate(
                                  postDetailProvider(widget.postId),
                                );
                                ref.invalidate(feedItemsProvider);
                              },
                              icon: Icon(
                                post.liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              label: Text('${post.likeCount} beğeni'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: null,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text('${post.commentCount} yorum'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 18),
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
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Yorumun',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _submittingComment ? null : _submitComment,
                    child: Text(
                      _submittingComment ? 'Gönderiliyor...' : 'Yorumu gönder',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Yorumlar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          commentsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (comments) {
              if (comments.isEmpty) {
                return const SurfaceCard(child: Text('Henüz yorum yok.'));
              }
              return Column(
                children: comments
                    .map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.authorName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(comment.text),
                              if (comment.createdAt.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  comment.createdAt,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    setState(() => _submittingComment = true);
    final result = await ref
        .read(feedRepositoryProvider)
        .createComment(postId: widget.postId, comment: comment);
    if (!mounted) return;
    setState(() => _submittingComment = false);
    if (result.ok) {
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
      ref.invalidate(feedItemsProvider);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isNotEmpty ? result.message : 'Yorum gönderilemedi.',
        ),
      ),
    );
  }
}
