import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/feed_action_controller.dart';
import '../data/feed_repository.dart';
import 'feed_edit_text_dialog.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  FeedItem? _postOverride;
  final Map<int, FeedComment> _commentOverrides = <int, FeedComment>{};
  bool _refreshFeedOnExit = false;

  @override
  void dispose() {
    if (_refreshFeedOnExit) {
      ref.invalidate(feedItemsProvider);
      ref.invalidate(feedPageProvider);
      ref.invalidate(postDetailProvider(widget.postId));
      ref.invalidate(postCommentsProvider(widget.postId));
    }
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postDetailProvider(widget.postId));
    final commentsState = ref.watch(postCommentsProvider(widget.postId));
    final actionState = ref.watch(feedActionControllerProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final l10n = context.l10n;
    final currentUserId = session?.user?.id;
    final submittingComment =
        actionState.isLoading &&
        actionState.scope == 'comment:${widget.postId}';
    final currentPost = _postOverride ?? postState.value;

    return FeatureScaffold(
      title: l10n.feedPostAction,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          postState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (post) {
              final resolvedPost = _postOverride ?? post;
              return resolvedPost == null
                  ? Text(l10n.feedPostNotFound)
                  : _PostCard(
                      post: resolvedPost,
                      postId: widget.postId,
                      currentUserId: currentUserId,
                      onEdited: _handlePostEdited,
                    );
            },
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
              final resolvedComments = comments
                  .map((comment) => _commentOverrides[comment.id] ?? comment)
                  .toList(growable: false);
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
                children: resolvedComments
                    .map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CommentCard(
                          comment: comment,
                          postId: widget.postId,
                          currentUserId: currentUserId,
                          postAuthorId: currentPost?.authorId,
                          onEdited: _handleCommentEdited,
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

  void _handlePostEdited(FeedEditPostResult result) {
    final current =
        _postOverride ?? ref.read(postDetailProvider(widget.postId)).value;
    if (current == null) return;
    _refreshFeedOnExit = true;
    if (result.imageFile != null || result.removeImage) {
      // Image changed — reload from server
      ref.invalidate(postDetailProvider(widget.postId));
      setState(() {
        _postOverride = null;
      });
    } else {
      setState(() {
        _postOverride = current.copyWith(
          content: result.content,
          updatedAt: DateTime.now().toIso8601String(),
        );
      });
    }
  }

  void _handleCommentEdited(int commentId, String content) {
    final comments = ref.read(postCommentsProvider(widget.postId)).value;
    if (comments == null) return;
    FeedComment? current;
    for (final comment in comments) {
      if (comment.id == commentId) {
        current = comment;
        break;
      }
    }
    if (current == null) return;
    final currentComment = current;
    setState(() {
      _refreshFeedOnExit = true;
      _commentOverrides[commentId] = currentComment.copyWith(
        comment: content,
        updatedAt: DateTime.now().toIso8601String(),
      );
    });
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

// ---------------------------------------------------------------------------
// Post card
// ---------------------------------------------------------------------------

class _PostCard extends ConsumerWidget {
  const _PostCard({
    required this.post,
    required this.postId,
    required this.currentUserId,
    required this.onEdited,
  });

  final FeedItem post;
  final int postId;
  final int? currentUserId;
  final ValueChanged<FeedEditPostResult> onEdited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final isOwner = currentUserId != null && currentUserId == post.authorId;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final canOpen = post.authorId != null && post.authorId! > 0;
                  return InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canOpen
                        ? () => context.push('/members/${post.authorId}')
                        : null,
                    child: Tooltip(
                      message: l10n.openMemberProfileForName(post.authorName),
                      child: Semantics(
                        button: canOpen,
                        enabled: canOpen,
                        label: l10n.openMemberProfileForName(post.authorName),
                        child: RemoteAvatar(
                          label: post.authorName,
                          imageUrl: config.resolveUrl(post.authorPhoto).toString(),
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (post.authorHandle.isNotEmpty)
                      Text(
                        '@${post.authorHandle}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (isOwner)
                _PostMenuButton(
                  postId: postId,
                  currentContent: post.content,
                  currentImageUrl: post.imageUrl.isNotEmpty
                      ? config.resolveUrl(post.imageUrl).toString()
                      : null,
                  onEdited: onEdited,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(plainTextFromRichContent(post.content)),
          if (post.createdAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              formatSdalCreatedLabel(context, post.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (post.updatedAt != null && post.updatedAt!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              formatSdalEditedLabel(context, post.updatedAt!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (post.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            SdalNetworkImage(
              imageUrl: config.resolveUrl(post.imageUrl).toString(),
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
                      .toggleLike(postId);
                },
                icon: Icon(
                  post.liked ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(l10n.feedLikesCount(post.likeCount)),
              ),
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(l10n.feedCommentsCount(post.commentCount)),
              ),
            ],
          ),
          if (post.likeCount > 0) ...[
            const SizedBox(height: 12),
            _LikedByAvatars(postId: postId),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post menu (edit + delete)
// ---------------------------------------------------------------------------

class _PostMenuButton extends ConsumerStatefulWidget {
  const _PostMenuButton({
    required this.postId,
    required this.currentContent,
    required this.onEdited,
    this.currentImageUrl,
  });

  final int postId;
  final String currentContent;
  final String? currentImageUrl;
  final ValueChanged<FeedEditPostResult> onEdited;

  @override
  ConsumerState<_PostMenuButton> createState() => _PostMenuButtonState();
}

class _PostMenuButtonState extends ConsumerState<_PostMenuButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      onSelected: (value) async {
        if (value == 'edit') {
          await _showEditSheet();
        } else if (value == 'delete') {
          await _confirmDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(l10n.feedPostEditTitle),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l10n.feedPostDeleteTitle),
        ),
      ],
    );
  }

  Future<void> _showEditSheet() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<FeedEditPostResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FeedEditPostSheet(
        initialContent: plainTextFromRichContent(widget.currentContent),
        currentImageUrl: widget.currentImageUrl,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .editPost(
          postId: widget.postId,
          content: result.content,
          imageFile: result.imageFile,
          removeImage: result.removeImage,
        );
    if (!mounted) return;
    if (ok) {
      widget.onEdited(result);
    } else {
      final nextState = ref.read(feedActionControllerProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(nextState.message ?? l10n.feedPostEditFailed),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.feedPostDeleteTitle),
        content: Text(l10n.feedPostDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .deletePost(widget.postId);
    if (!mounted) return;
    if (ok) {
      router.pop();
      return;
    }
    final nextState = ref.read(feedActionControllerProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(nextState.message ?? l10n.feedPostDeleteFailed),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liked-by overlapping avatars
// ---------------------------------------------------------------------------

class _LikedByAvatars extends ConsumerWidget {
  const _LikedByAvatars({required this.postId});

  final int postId;

  static const _avatarRadius = 13.0;
  static const _overlap = 9.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesState = ref.watch(postLikesProvider(postId));
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return likesState.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (likes) {
        if (likes.isEmpty) return const SizedBox.shrink();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _showLikedBySheet(context, ref, likes),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlappingAvatarRow(
                    likes: likes,
                    config: config,
                    avatarRadius: _avatarRadius,
                    overlap: _overlap,
                    borderColor: theme.colorScheme.surface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.feedLikedBy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLikedBySheet(
    BuildContext context,
    WidgetRef ref,
    List<LikeUser> likes,
  ) {
    final config = ref.read(appConfigProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LikedBySheet(likes: likes, config: config),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlapping avatar row (horizontal scroll for many likes)
// ---------------------------------------------------------------------------

class _OverlappingAvatarRow extends StatelessWidget {
  const _OverlappingAvatarRow({
    required this.likes,
    required this.config,
    required this.avatarRadius,
    required this.overlap,
    required this.borderColor,
  });

  final List<LikeUser> likes;
  final dynamic config;
  final double avatarRadius;
  final double overlap;
  final Color borderColor;

  static const _maxVisible = 12;

  @override
  Widget build(BuildContext context) {
    final display = likes.take(_maxVisible).toList();
    final extra = likes.length - display.length;
    final diameter = avatarRadius * 2;
    final step = diameter - overlap;

    final totalItems = display.length + (extra > 0 ? 1 : 0);
    final stackWidth = diameter + (totalItems - 1) * step;

    return SizedBox(
      width: stackWidth,
      height: diameter,
      child: Stack(
        children: [
          for (var i = 0; i < display.length; i++)
            Positioned(
              left: i * step,
              child: _AvatarCircle(
                label: display[i].fullName,
                imageUrl: config.resolveUrl(display[i].avatarUrl).toString(),
                radius: avatarRadius,
                borderColor: borderColor,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: display.length * step,
              child: _ExtraCount(
                count: extra,
                radius: avatarRadius,
                borderColor: borderColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.label,
    required this.imageUrl,
    required this.radius,
    required this.borderColor,
  });

  final String label;
  final String imageUrl;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: RemoteAvatar(
        label: label,
        imageUrl: imageUrl,
        radius: radius,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _ExtraCount extends StatelessWidget {
  const _ExtraCount({
    required this.count,
    required this.radius,
    required this.borderColor,
  });

  final int count;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liked-by bottom sheet
// ---------------------------------------------------------------------------

class _LikedBySheet extends StatelessWidget {
  const _LikedBySheet({required this.likes, required this.config});

  final List<LikeUser> likes;
  final dynamic config;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              children: [
                Text(
                  l10n.feedLikedBy,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: likes.isEmpty
                ? Center(child: Text(l10n.feedLikedByNone))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: likes.length,
                    itemBuilder: (context, index) {
                      final user = likes[index];
                      return ListTile(
                        leading: RemoteAvatar(
                          label: user.fullName,
                          imageUrl: config
                              .resolveUrl(user.avatarUrl)
                              .toString(),
                          radius: 20,
                        ),
                        title: Text(user.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.username.isNotEmpty)
                              Text('@${user.username}'),
                            if (user.graduationYear != null)
                              Text('${user.graduationYear}'),
                          ],
                        ),
                        onTap: user.id > 0
                            ? () {
                                Navigator.of(context).pop();
                                context.push('/members/${user.id}');
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment card
// ---------------------------------------------------------------------------

class _CommentCard extends ConsumerWidget {
  const _CommentCard({
    required this.comment,
    required this.postId,
    required this.currentUserId,
    required this.postAuthorId,
    required this.onEdited,
  });

  final FeedComment comment;
  final int postId;
  final int? currentUserId;
  final int? postAuthorId;
  final void Function(int commentId, String content) onEdited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;

    final isCommentAuthor =
        currentUserId != null && currentUserId == comment.userId;
    final isPostOwner =
        currentUserId != null && currentUserId == postAuthorId;
    final canEdit = isCommentAuthor;
    final canDelete = isCommentAuthor || isPostOwner;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final canOpen =
                      comment.userId != null && comment.userId! > 0;
                  return InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canOpen
                        ? () =>
                            context.push('/members/${comment.userId}')
                        : null,
                    child: Tooltip(
                      message: l10n.openMemberProfileForName(
                        comment.authorName,
                      ),
                      child: Semantics(
                        button: canOpen,
                        enabled: canOpen,
                        label: l10n.openMemberProfileForName(
                          comment.authorName,
                        ),
                        child: RemoteAvatar(
                          label: comment.authorName,
                          imageUrl: config
                              .resolveUrl(comment.authorPhoto)
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.left,
                    ),
                    if (comment.authorHandle.isNotEmpty)
                      Text(
                        '@${comment.authorHandle}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.left,
                      ),
                  ],
                ),
              ),
              if (canDelete)
                _CommentMenuButton(
                  comment: comment,
                  postId: postId,
                  canEdit: canEdit,
                  onEdited: onEdited,
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
              formatSdalCreatedLabel(context, comment.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.left,
            ),
          ],
          if (comment.updatedAt != null && comment.updatedAt!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              formatSdalEditedLabel(context, comment.updatedAt!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment menu (edit + delete)
// ---------------------------------------------------------------------------

class _CommentMenuButton extends ConsumerStatefulWidget {
  const _CommentMenuButton({
    required this.comment,
    required this.postId,
    required this.canEdit,
    required this.onEdited,
  });

  final FeedComment comment;
  final int postId;
  final bool canEdit;
  final void Function(int commentId, String content) onEdited;

  @override
  ConsumerState<_CommentMenuButton> createState() => _CommentMenuButtonState();
}

class _CommentMenuButtonState extends ConsumerState<_CommentMenuButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      onSelected: (value) async {
        if (value == 'edit') {
          await _showEditDialog();
        } else if (value == 'delete') {
          await _confirmDelete();
        }
      },
      itemBuilder: (context) => [
        if (widget.canEdit)
          PopupMenuItem<String>(
            value: 'edit',
            child: Text(l10n.feedCommentEditTitle),
          ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l10n.deleteAction),
        ),
      ],
    );
  }

  Future<void> _showEditDialog() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => FeedEditTextDialog(
        title: l10n.feedCommentEditTitle,
        initialValue: plainTextFromRichContent(widget.comment.text),
        minLines: 2,
        maxLines: 6,
      ),
    );
    if (saved == null || !mounted) return;
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .editComment(
          postId: widget.postId,
          commentId: widget.comment.id,
          comment: saved,
        );
    if (!mounted) return;
    if (ok) {
      widget.onEdited(widget.comment.id, saved);
    } else {
      final nextState = ref.read(feedActionControllerProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(nextState.message ?? l10n.feedCommentEditFailed),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.feedCommentDeleteTitle),
        content: Text(l10n.feedCommentDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .deleteComment(postId: widget.postId, commentId: widget.comment.id);
    if (!mounted) return;
    final nextState = ref.read(feedActionControllerProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          nextState.message ??
              (ok ? l10n.feedCommentDeleted : l10n.feedCommentDeleteFailed),
        ),
      ),
    );
  }
}

