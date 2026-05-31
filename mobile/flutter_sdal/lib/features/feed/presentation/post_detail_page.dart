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
import '../../explore/data/explore_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../application/feed_action_controller.dart';
import '../data/feed_repository.dart';
import 'feed_edit_text_dialog.dart';
import '../../social/presentation/member_mention_composer.dart';
import '../../social/presentation/social_interaction_widgets.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  final List<MemberSummary> _selectedMentions = <MemberSummary>[];
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
                MemberMentionComposer(
                  controller: _commentController,
                  selectedMembers: _selectedMentions,
                  onSelectedMembersChanged: (members) => setState(() {
                    _selectedMentions
                      ..clear()
                      ..addAll(members);
                  }),
                  labelText: l10n.feedCommentFieldLabel,
                  hintText: l10n.feedCommentFieldLabel,
                  minLines: 2,
                  maxLines: 5,
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
    final comment = composeMentionText(
      _commentController.text,
      _selectedMentions,
    );
    final l10n = context.l10n;
    if (comment.isEmpty) return;
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .createComment(postId: widget.postId, comment: comment);
    if (!mounted) return;
    if (ok) {
      _commentController.clear();
      setState(() => _selectedMentions.clear());
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (post.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            SdalNetworkImage(
              imageUrl: config.resolveUrl(post.imageUrl).toString(),
              lightboxImageUrl: config.resolveUrl(post.lightboxUrl).toString(),
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
                      .toggleLike(post);
                },
                icon: Icon(post.liked ? Icons.favorite : Icons.favorite_border),
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
        SnackBar(content: Text(nextState.message ?? l10n.feedPostEditFailed)),
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
      SnackBar(content: Text(nextState.message ?? l10n.feedPostDeleteFailed)),
    );
  }
}

// ---------------------------------------------------------------------------
// Liked-by overlapping avatars
// ---------------------------------------------------------------------------

class _LikedByAvatars extends ConsumerWidget {
  const _LikedByAvatars({required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesState = ref.watch(postLikesProvider(postId));
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    return likesState.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (likes) {
        if (likes.isEmpty) return const SizedBox.shrink();
        return SocialLikePreviewButton(
          people: likes
              .map(
                (user) => SocialLikePerson(
                  id: user.id,
                  displayName: user.fullName,
                  imageUrl: config.resolveUrl(user.avatarUrl).toString(),
                  subtitle: [
                    if (user.username.isNotEmpty) '@${user.username}',
                    if (user.graduationYear != null) '${user.graduationYear}',
                  ].join(' • '),
                ),
              )
              .toList(growable: false),
          title: l10n.feedLikedBy,
          ctaLabel: l10n.feedLikedBy,
          onUserTap: (context, person) {
            Navigator.of(context).pop();
            if (person.id > 0) {
              context.push('/members/${person.id}');
            }
          },
        );
      },
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

    final isCommentAuthor =
        currentUserId != null && currentUserId == comment.userId;
    final isPostOwner = currentUserId != null && currentUserId == postAuthorId;
    final canEdit = isCommentAuthor;
    final canDelete = isCommentAuthor || isPostOwner;

    return SocialCommentCard(
      authorName: comment.authorName,
      authorHandle: comment.authorHandle,
      authorPhotoUrl: config.resolveUrl(comment.authorPhoto).toString(),
      body: plainTextFromRichContent(comment.text),
      createdLabel: formatSdalCreatedLabel(context, comment.createdAt),
      editedLabel: comment.updatedAt != null && comment.updatedAt!.isNotEmpty
          ? formatSdalEditedLabel(context, comment.updatedAt!)
          : null,
      onAuthorTap: comment.userId != null && comment.userId! > 0
          ? () => context.push('/members/${comment.userId}')
          : null,
      trailing: currentUserId != null
          ? _CommentMenuButton(
              comment: comment,
              postId: postId,
              canEdit: canEdit,
              canDelete: canDelete,
              isOwn: isCommentAuthor,
              onEdited: onEdited,
            )
          : null,
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
    required this.canDelete,
    required this.isOwn,
    required this.onEdited,
  });

  final FeedComment comment;
  final int postId;
  final bool canEdit;
  final bool canDelete;
  final bool isOwn;
  final void Function(int commentId, String content) onEdited;

  @override
  ConsumerState<_CommentMenuButton> createState() => _CommentMenuButtonState();
}

class _CommentMenuButtonState extends ConsumerState<_CommentMenuButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SocialCommentActionMenuButton(
      canEdit: widget.canEdit,
      canDelete: widget.canDelete,
      onEdit: _showEditDialog,
      onDelete: _confirmDelete,
      onReport: widget.isOwn ? null : _reportComment,
      onBlock: widget.isOwn ? null : _blockAuthor,
      editLabel: l10n.feedCommentEditTitle,
      deleteLabel: l10n.deleteAction,
      reportLabel: l10n.reportAction,
      blockLabel: l10n.blockUserAction,
      tooltip: l10n.moreActions,
    );
  }

  Future<void> _reportComment() async {
    await SafetyActions.reportContent(
      context,
      ref,
      submit: (reason) => ref
          .read(safetyRepositoryProvider)
          .reportComment(widget.postId, widget.comment.id, reason),
    );
  }

  Future<void> _blockAuthor() async {
    final userId = widget.comment.userId;
    if (userId == null || userId <= 0) return;
    final blocked = await SafetyActions.blockUser(
      context,
      ref,
      userId: userId,
      displayName: widget.comment.authorName,
    );
    if (blocked && mounted) {
      ref.invalidate(postCommentsProvider(widget.postId));
    }
  }

  Future<void> _showEditDialog() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => SocialEditTextDialog(
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
