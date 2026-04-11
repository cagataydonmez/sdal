import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
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
    final session = ref.watch(sessionControllerProvider).value;
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
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (post) => post == null
                ? Text(l10n.feedPostNotFound)
                : SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final canOpenAuthorProfile =
                                    post.authorId != null && post.authorId! > 0;
                                return InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: canOpenAuthorProfile
                                      ? () => context.push(
                                          '/members/${post.authorId}',
                                        )
                                      : null,
                                  child: Tooltip(
                                    message: l10n.openMemberProfileForName(
                                      post.authorName,
                                    ),
                                    child: Semantics(
                                      button: canOpenAuthorProfile,
                                      enabled: canOpenAuthorProfile,
                                      label: l10n.openMemberProfileForName(
                                        post.authorName,
                                      ),
                                      child: RemoteAvatar(
                                        label: post.authorName,
                                        imageUrl: config
                                            .resolveUrl(post.authorPhoto)
                                            .toString(),
                                        radius: 22,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                                  if (!context.mounted) return;
                                  if (ok) {
                                    context.pop();
                                    return;
                                  }
                                  final nextState = ref.read(
                                    feedActionControllerProvider,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        nextState.message ??
                                            (ok
                                                ? l10n.feedPostDeleted
                                                : l10n.feedPostDeleteFailed),
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
                              label: Text(l10n.feedLikesCount(post.likeCount)),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: null,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text(
                                l10n.feedCommentsCount(post.commentCount),
                              ),
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
                  l10n.feedCommentAddTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.feedCommentFieldLabel,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: submittingComment ? null : _submitComment,
                    child: Text(
                      submittingComment
                          ? l10n.submitInProgress
                          : l10n.feedCommentSubmitAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.feedCommentsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          commentsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (comments) {
              if (comments.isEmpty) {
                return SurfaceCard(
                  child: EmptyStateView(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: l10n.feedCommentsEmptyTitle,
                    message: l10n.feedCommentsEmptyMessage,
                    compact: true,
                  ),
                );
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
                                  Builder(
                                    builder: (context) {
                                      final canOpenAuthorProfile =
                                          comment.userId != null &&
                                          comment.userId! > 0;
                                      return InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: canOpenAuthorProfile
                                            ? () => context.push(
                                                '/members/${comment.userId}',
                                              )
                                            : null,
                                        child: Tooltip(
                                          message: l10n
                                              .openMemberProfileForName(
                                                comment.authorName,
                                              ),
                                          child: Semantics(
                                            button: canOpenAuthorProfile,
                                            enabled: canOpenAuthorProfile,
                                            label: l10n
                                                .openMemberProfileForName(
                                                  comment.authorName,
                                                ),
                                            child: RemoteAvatar(
                                              label: comment.authorName,
                                              imageUrl: config
                                                  .resolveUrl(
                                                    comment.authorPhoto,
                                                  )
                                                  .toString(),
                                              radius: 18,
                                              excludeFromSemantics: true,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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
                                  if (session?.user?.id != null &&
                                      session!.user!.id == comment.userId)
                                    PopupMenuButton<String>(
                                      tooltip: l10n.moreActions,
                                      onSelected: (value) async {
                                        if (value != 'delete') return;
                                        final approved = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              l10n.feedCommentDeleteTitle,
                                            ),
                                            content: Text(
                                              l10n.feedCommentDeleteMessage,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: Text(l10n.cancelAction),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: Text(l10n.deleteAction),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (approved != true ||
                                            !context.mounted) {
                                          return;
                                        }
                                        final ok = await ref
                                            .read(
                                              feedActionControllerProvider
                                                  .notifier,
                                            )
                                            .deleteComment(
                                              postId: widget.postId,
                                              commentId: comment.id,
                                            );
                                        if (!context.mounted) return;
                                        final nextState = ref.read(
                                          feedActionControllerProvider,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              nextState.message ??
                                                  (ok
                                                      ? l10n.feedCommentDeleted
                                                      : l10n.feedCommentDeleteFailed),
                                            ),
                                          ),
                                        );
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(l10n.deleteAction),
                                        ),
                                      ],
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
    final l10n = context.l10n;
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
      SnackBar(
        content: Text(actionState.message ?? l10n.feedCommentSubmitFailed),
      ),
    );
  }
}

class _FeedPostMenuButton extends StatelessWidget {
  const _FeedPostMenuButton({required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      onSelected: (value) async {
        if (value != 'delete') return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.feedPostDeleteTitle),
            content: Text(l10n.feedPostDeleteMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancelAction),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.deleteAction),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l10n.feedPostDeleteTitle),
        ),
      ],
    );
  }
}
