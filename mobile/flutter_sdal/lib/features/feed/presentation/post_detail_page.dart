import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/feed_action_controller.dart';
import '../data/feed_repository.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postDetailProvider(widget.postId));
    final commentsState = ref.watch(postCommentsProvider(widget.postId));
    final actionState = ref.watch(feedActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final l10n = context.l10n;
    final submittingComment =
        actionState.isLoading &&
        actionState.scope == 'comment:${widget.postId}';

    return FeatureScaffold(
      title: l10n.feedPostAction,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap:
                                  post.authorId == null || post.authorId! <= 0
                                  ? null
                                  : () => context.push(
                                      '/members/${post.authorId}',
                                    ),
                              child: RemoteAvatar(
                                label: post.authorName,
                                imageUrl: config
                                    .resolveUrl(post.authorPhoto)
                                    .toString(),
                                radius: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  if (post.authorHandle.isNotEmpty)
                                    Text(
                                      '@${post.authorHandle}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            if (session?.user?.id != null &&
                                session!.user!.id == post.authorId)
                              _FeedPostMenuButton(
                                onDelete: () async {
                                  final ok = await ref
                                      .read(
                                        feedActionControllerProvider.notifier,
                                      )
                                      .deletePost(widget.postId);
                                  if (!mounted) return;
                                  if (ok) {
                                    context.pop();
                                  }
                                  final nextState = ref.read(
                                    feedActionControllerProvider,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        nextState.message ??
                                            (ok
                                                ? 'Gönderi silindi.'
                                                : 'Gönderi silinemedi.'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(plainTextFromRichContent(post.content)),
                        if (post.imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          SdalNetworkImage(
                            imageUrl: config
                                .resolveUrl(post.imageUrl)
                                .toString(),
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(18),
                            errorFallback: const SizedBox.shrink(),
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
                                    .read(feedActionControllerProvider.notifier)
                                    .toggleLike(widget.postId);
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
                    onPressed: submittingComment ? null : _submitComment,
                    child: Text(
                      submittingComment ? 'Gönderiliyor...' : 'Yorumu gönder',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: comments
                    .map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap:
                                        comment.userId == null ||
                                            comment.userId! <= 0
                                        ? null
                                        : () => context.push(
                                            '/members/${comment.userId}',
                                          ),
                                    child: RemoteAvatar(
                                      label: comment.authorName,
                                      imageUrl: config
                                          .resolveUrl(comment.authorPhoto)
                                          .toString(),
                                      radius: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.authorName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          textAlign: TextAlign.left,
                                        ),
                                        if (comment.authorHandle.isNotEmpty)
                                          Text(
                                            '@${comment.authorHandle}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            textAlign: TextAlign.left,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                plainTextFromRichContent(comment.text),
                                textAlign: TextAlign.left,
                              ),
                              if (comment.createdAt.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  comment.createdAt,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.left,
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
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .createComment(postId: widget.postId, comment: comment);
    if (!mounted) return;
    if (ok) {
      _commentController.clear();
      return;
    }
    final actionState = ref.read(feedActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(actionState.message ?? 'Yorum gönderilemedi.')),
    );
  }
}

class _FeedPostMenuButton extends StatelessWidget {
  const _FeedPostMenuButton({required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value != 'delete') return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Gönderiyi sil'),
            content: const Text(
              'Bu gönderi kalıcı olarak silinecek. Devam etmek istiyor musun?',
            ),
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
        if (confirmed == true) {
          await onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'delete', child: Text('Gönderiyi sil')),
      ],
    );
  }
}
