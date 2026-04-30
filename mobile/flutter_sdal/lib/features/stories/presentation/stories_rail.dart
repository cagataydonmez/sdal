import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_models.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/stories_action_controller.dart';
import '../data/stories_repository.dart';

enum StoryRailMode { feed, mine, member }

class StoriesRail extends ConsumerWidget {
  const StoriesRail({
    super.key,
    required this.mode,
    this.memberId,
    this.showUpload = false,
    this.title,
    this.feedType = 'main',
  });

  final StoryRailMode mode;
  final int? memberId;
  final bool showUpload;
  final String? title;
  final String feedType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final sessionUser = ref.watch(sessionControllerProvider).value?.user;
    final asyncItems = switch (mode) {
      StoryRailMode.feed => ref.watch(optimisticFeedStoriesProvider(feedType)),
      StoryRailMode.mine => ref.watch(myActiveStoriesProvider(feedType)),
      StoryRailMode.member => ref.watch(memberStoriesProvider(memberId ?? 0)),
    };

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title ?? l10n.storiesTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (asyncItems.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          asyncItems.when(
            loading: () => _StoryRailList(
              showUpload: showUpload,
              uploadTile: showUpload ? _buildUploadTile(context, ref) : null,
              children: const [
                _StoryPlaceholderTile(),
                _StoryPlaceholderTile(),
              ],
            ),
            error: (error, _) => const ErrorView(compact: true),
            data: (items) {
              final groups = _buildGroups(
                items,
                fallbackAuthor: mode == StoryRailMode.mine
                    ? _storyAuthorFromSession(sessionUser)
                    : null,
              );
              if (groups.isEmpty && !showUpload) {
                return Text(
                  l10n.storiesEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
              return _StoryRailList(
                showUpload: showUpload,
                uploadTile: showUpload ? _buildUploadTile(context, ref) : null,
                children: [
                  for (var index = 0; index < groups.length; index++)
                    _StoryTile(
                      imageUrl: config
                          .resolveUrl(groups[index].author.photo)
                          .toString(),
                      label: groups[index].author.displayName,
                      subtitle: groups[index].unviewedCount > 0
                          ? l10n.storiesNewCount(groups[index].unviewedCount)
                          : l10n.storiesViewed,
                      viewed: groups[index].viewed,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _StoryViewerPage(
                              groups: groups,
                              initialGroupIndex: index,
                              mode: mode,
                              feedType: feedType,
                            ),
                            fullscreenDialog: true,
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _StoryTile(
      icon: Icons.add_a_photo_outlined,
      label: l10n.storiesUploadAction,
      subtitle: l10n.storiesUploadHint,
      viewed: false,
      onTap: () => _openUploadSheet(context, ref),
    );
  }

  Future<void> _openUploadSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StoryUploadSheet(feedType: feedType),
    );
  }
}

class _StoryRailList extends StatelessWidget {
  const _StoryRailList({
    required this.showUpload,
    required this.uploadTile,
    required this.children,
  });

  final bool showUpload;
  final Widget? uploadTile;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final railHeight = textScale > 1.15 ? 138.0 : 118.0;
    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length + (showUpload ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (showUpload && index == 0) {
            return uploadTile ?? const SizedBox.shrink();
          }
          final child = children[index - (showUpload ? 1 : 0)];
          return child;
        },
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.label,
    required this.subtitle,
    required this.viewed,
    required this.onTap,
    this.imageUrl = '',
    this.icon,
  });

  final String label;
  final String subtitle;
  final bool viewed;
  final VoidCallback onTap;
  final String imageUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tileWidth = textScale > 1.15 ? 94.0 : 86.0;
    final mediaSize = textScale > 1.15 ? 78.0 : 74.0;
    final borderColor = viewed ? tokens.storyInactive : tokens.storyActive;
    final ringFillColor = viewed
        ? borderColor.withValues(alpha: 0.12)
        : tokens.storyActive;
    return Semantics(
      button: true,
      label: context.l10n.storiesViewStorySemantic(label),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: tileWidth,
          child: Column(
            children: [
              _StoryHeptagonFrame(
                size: mediaSize,
                borderColor: borderColor,
                fillColor: ringFillColor,
                gradient: viewed
                    ? null
                    : LinearGradient(
                        colors: [tokens.storyActive, tokens.accent],
                      ),
                child: icon != null
                    ? DecoratedBox(
                        decoration: BoxDecoration(color: tokens.accentMuted),
                        child: Icon(icon, color: tokens.accent),
                      )
                    : imageUrl.isNotEmpty
                    ? SdalNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        semanticLabel: context.l10n.storiesViewStorySemantic(
                          label,
                        ),
                        enableLightbox: false,
                        errorFallback: _StoryFallback(label: label),
                      )
                    : _StoryFallback(label: label),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: textScale > 1.15 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                subtitle,
                maxLines: textScale > 1.15 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryFallback extends StatelessWidget {
  const _StoryFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.chatOutgoing, tokens.storyActive],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          label.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: tokens.foregroundOnAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StoryPlaceholderTile extends StatelessWidget {
  const _StoryPlaceholderTile();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final mediaSize = MediaQuery.textScalerOf(context).scale(1) > 1.15
        ? 78.0
        : 74.0;
    return SizedBox(
      width: MediaQuery.textScalerOf(context).scale(1) > 1.15 ? 94 : 86,
      child: Column(
        children: [
          _StoryHeptagonFrame(
            size: mediaSize,
            borderColor: tokens.panelMuted,
            fillColor: tokens.panelMuted,
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

class _StoryHeptagonFrame extends StatelessWidget {
  const _StoryHeptagonFrame({
    required this.size,
    required this.borderColor,
    required this.fillColor,
    required this.child,
    this.gradient,
  });

  final double size;
  final Color borderColor;
  final Color fillColor;
  final Gradient? gradient;
  final Widget child;

  static const double _outerCornerRadius = 4;
  static const double _innerCornerRadius = 3;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StoryHeptagonPainter(
          borderColor: borderColor,
          fillColor: fillColor,
          gradient: gradient,
          cornerRadius: _outerCornerRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_inset),
          child: ClipPath(
            clipper: const _RoundedHeptagonClipper(
              cornerRadius: _innerCornerRadius,
            ),
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}

class _RoundedHeptagonClipper extends CustomClipper<Path> {
  const _RoundedHeptagonClipper({required this.cornerRadius});

  final double cornerRadius;

  @override
  Path getClip(Size size) {
    return _buildRoundedHeptagonPath(size, cornerRadius);
  }

  @override
  bool shouldReclip(covariant _RoundedHeptagonClipper oldClipper) {
    return oldClipper.cornerRadius != cornerRadius;
  }
}

class _StoryHeptagonPainter extends CustomPainter {
  const _StoryHeptagonPainter({
    required this.borderColor,
    required this.fillColor,
    required this.cornerRadius,
    this.gradient,
  });

  final Color borderColor;
  final Color fillColor;
  final double cornerRadius;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildRoundedHeptagonPath(size, cornerRadius);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    if (gradient != null) {
      fillPaint.shader = gradient!.createShader(Offset.zero & size);
    }
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryHeptagonPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.gradient != gradient;
  }
}

class _StoryViewerPage extends ConsumerStatefulWidget {
  const _StoryViewerPage({
    required this.groups,
    required this.initialGroupIndex,
    required this.mode,
    this.feedType = 'main',
  });

  final List<_StoryGroup> groups;
  final int initialGroupIndex;
  final StoryRailMode mode;
  final String feedType;

  @override
  ConsumerState<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<_StoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 5);
  static const _dragDismissThreshold = 120.0;

  late final AnimationController _progressController;
  late int _groupIndex;
  int _itemIndex = 0;
  double _verticalDragOffset = 0;

  _StoryGroup get _group => widget.groups[_groupIndex];
  StoryItem get _item => _group.items[_itemIndex];

  bool get _allowManage => widget.mode == StoryRailMode.mine;

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: _storyDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _goNext();
            }
          });
    _groupIndex = widget.initialGroupIndex;
    _itemIndex = _group.firstUnviewedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateCurrent());
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _activateCurrent() {
    _progressController
      ..stop()
      ..value = 0;
    if (!_allowManage && !_item.viewed) {
      ref.read(storiesRepositoryProvider).markViewed(_item.id).then((_) {
        if (!mounted) return;
        ref.invalidate(feedStoriesProvider(widget.feedType));
        if (widget.mode == StoryRailMode.member && _item.author != null) {
          ref.invalidate(memberStoriesProvider(_item.author!.id));
        }
      });
    }
    _progressController.forward();
    setState(() {});
  }

  void _goNext() {
    if (_itemIndex + 1 < _group.items.length) {
      setState(() => _itemIndex += 1);
      _activateCurrent();
      return;
    }
    if (_groupIndex + 1 < widget.groups.length) {
      setState(() {
        _groupIndex += 1;
        _itemIndex = widget.groups[_groupIndex].firstUnviewedIndex;
      });
      _activateCurrent();
      return;
    }
    _closeViewer();
  }

  void _goPrevious() {
    if (_itemIndex > 0) {
      setState(() => _itemIndex -= 1);
      _activateCurrent();
      return;
    }
    if (_groupIndex > 0) {
      setState(() {
        _groupIndex -= 1;
        _itemIndex = widget.groups[_groupIndex].items.length - 1;
      });
      _activateCurrent();
      return;
    }
    _closeViewer();
  }

  void _closeViewer() {
    _progressController.stop();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final nextOffset = _verticalDragOffset + (details.primaryDelta ?? 0);
    if (nextOffset < 0) return;
    setState(() => _verticalDragOffset = nextOffset);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_verticalDragOffset > _dragDismissThreshold || velocity > 900) {
      _closeViewer();
      return;
    }
    if (_verticalDragOffset != 0) {
      setState(() => _verticalDragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    const storyForeground = Colors.white;
    final storyForegroundMuted = Colors.white.withValues(alpha: 0.78);
    final imageUrl = config.resolveUrl(_item.mediaUrl).toString();
    final dragFactor = (_verticalDragOffset / 320).clamp(0.0, 0.45);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 1 - dragFactor),
          child: Transform.translate(
            offset: Offset(0, _verticalDragOffset),
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl.isNotEmpty
                      ? SdalNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          semanticLabel: l10n.storiesViewStorySemantic(
                            _group.author.displayName,
                          ),
                          enableLightbox: false,
                          placeholder: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.canvasSubtle,
                            ),
                          ),
                          errorFallback: DecoratedBox(
                            decoration: BoxDecoration(color: tokens.canvas),
                          ),
                        )
                      : ColoredBox(color: tokens.canvas),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.62),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  for (
                                    var i = 0;
                                    i < _group.items.length;
                                    i++
                                  ) ...[
                                    Expanded(
                                      child: Container(
                                        height: 4,
                                        margin: EdgeInsets.only(
                                          right: i == _group.items.length - 1
                                              ? 0
                                              : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            SdalThemeTokens.radiusPill,
                                          ),
                                        ),
                                        child: AnimatedBuilder(
                                          animation: _progressController,
                                          builder: (context, _) {
                                            final progress = i < _itemIndex
                                                ? 1.0
                                                : i == _itemIndex
                                                ? _progressController.value
                                                : 0.0;
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: FractionallySizedBox(
                                                widthFactor: progress,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: storyForeground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          SdalThemeTokens
                                                              .radiusPill,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _closeViewer,
                              color: storyForeground,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            RemoteAvatar(
                              label: _group.author.displayName,
                              imageUrl: config
                                  .resolveUrl(_group.author.photo)
                                  .toString(),
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _group.author.displayName,
                                    style: const TextStyle(
                                      color: storyForeground,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _item.createdAt,
                                    style: TextStyle(
                                      color: storyForegroundMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_allowManage)
                              PopupMenuButton<String>(
                                color: tokens.panelRaised,
                                iconColor: storyForeground,
                                onSelected: (value) => _onMenuSelected(value),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.storiesEditTitleAction),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.storiesDeleteAction),
                                  ),
                                  if (_item.isExpiredResolved)
                                    PopupMenuItem(
                                      value: 'repost',
                                      child: Text(l10n.storiesRepostAction),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_item.caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              _item.caption,
                              style: const TextStyle(
                                color: storyForeground,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 108, 0, 120),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: l10n.storiesPreviousStoryHint,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _goPrevious,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: l10n.storiesNextStoryHint,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _goNext,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    switch (value) {
      case 'edit':
        await _editStory();
        break;
      case 'delete':
        await _deleteStory();
        break;
      case 'repost':
        await _repostStory();
        break;
    }
  }

  Future<void> _editStory() async {
    final controller = TextEditingController(text: _item.caption);
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.storiesCaptionDialogTitle),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.l10n.captionLabel,
            hintText: context.l10n.storiesCaptionHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.saveAction),
          ),
        ],
      ),
    );
    if (caption == null) return;
    final ok = await ref
        .read(storiesActionControllerProvider.notifier)
        .editStory(storyId: _item.id, caption: caption);
    if (!mounted || ok == null) return;
    final updated = _item.copyWith(
      caption: caption,
      image: ok.image.isNotEmpty ? ok.image : null,
      variants: ok.variants ?? _item.variants,
    );
    ref.read(myStoryOverlayProvider(widget.feedType).notifier).upsert(updated);
    ref
        .read(feedStoryOverlayProvider(widget.feedType).notifier)
        .upsert(updated);
    unawaited(
      _refreshStoryScopes(ref, widget.feedType, memberId: _item.author?.id),
    );
    Navigator.of(context).pop();
  }

  Future<void> _deleteStory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.storiesDeleteConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await ref
        .read(storiesActionControllerProvider.notifier)
        .deleteStory(_item.id);
    if (!mounted || !deleted) return;
    ref.read(myStoryOverlayProvider(widget.feedType).notifier).remove(_item.id);
    ref
        .read(feedStoryOverlayProvider(widget.feedType).notifier)
        .remove(_item.id);
    unawaited(
      _refreshStoryScopes(ref, widget.feedType, memberId: _item.author?.id),
    );
    Navigator.of(context).pop();
  }

  Future<void> _repostStory() async {
    final result = await ref
        .read(storiesActionControllerProvider.notifier)
        .repostStory(_item.id);
    if (!mounted || result == null) return;
    final optimistic = _buildOptimisticStory(
      mutation: result,
      fallbackId: _item.id,
      caption: _item.caption,
      author: _item.author,
      fallbackImage: _item.image,
    );
    if (optimistic != null) {
      ref
          .read(myStoryOverlayProvider(widget.feedType).notifier)
          .upsert(optimistic);
      ref
          .read(feedStoryOverlayProvider(widget.feedType).notifier)
          .upsert(optimistic);
    }
    unawaited(
      _refreshStoryScopes(ref, widget.feedType, memberId: _item.author?.id),
    );
    Navigator.of(context).pop();
  }
}

class _StoryUploadSheet extends ConsumerStatefulWidget {
  const _StoryUploadSheet({required this.feedType});

  final String feedType;

  @override
  ConsumerState<_StoryUploadSheet> createState() => _StoryUploadSheetState();
}

class _StoryUploadSheetState extends ConsumerState<_StoryUploadSheet> {
  final _captionController = TextEditingController();
  File? _pickedFile;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(storiesActionControllerProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.storiesNewStoryTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () async {
                final file = await pickAndCropImage(
                  context,
                  aspectPreset: CropAspectPreset.story916,
                  title: 'Hikayeyi kırp',
                );
                if (file != null) setState(() => _pickedFile = file);
              },
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _pickedFile == null
                    ? l10n.pickFromGallery
                    : _pickedFile!.path.split('/').last,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.captionLabel,
                hintText: l10n.storiesCaptionHint,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: actionState.isLoading || _pickedFile == null
                    ? null
                    : () async {
                        final ok = await ref
                            .read(storiesActionControllerProvider.notifier)
                            .uploadStory(
                              imageFile: _pickedFile!,
                              caption: _captionController.text.trim(),
                              feedType: widget.feedType,
                            );
                        if (!context.mounted || ok == null) return;
                        final sessionUser = ref
                            .read(sessionControllerProvider)
                            .value
                            ?.user;
                        final optimistic = _buildOptimisticStory(
                          mutation: ok,
                          fallbackId: ok.id ?? 0,
                          caption: _captionController.text.trim(),
                          author: _storyAuthorFromSession(sessionUser),
                        );
                        if (optimistic != null) {
                          ref
                              .read(
                                myStoryOverlayProvider(
                                  widget.feedType,
                                ).notifier,
                              )
                              .upsert(optimistic);
                          ref
                              .read(
                                feedStoryOverlayProvider(
                                  widget.feedType,
                                ).notifier,
                              )
                              .upsert(optimistic);
                        }
                        unawaited(_refreshStoryScopes(ref, widget.feedType));
                        Navigator.of(context).pop();
                      },
                child: Text(
                  actionState.isLoading
                      ? l10n.submitInProgress
                      : l10n.storiesPublishAction,
                ),
              ),
            ),
            if ((actionState.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                actionState.message!,
                style: TextStyle(
                  color: actionState.isError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

StoryAuthor? _storyAuthorFromSession(SessionUser? user) {
  if (user == null || user.id <= 0) return null;
  return StoryAuthor(
    id: user.id,
    handle: user.kadi,
    displayName: user.displayName,
    photo: user.photo,
    verified: user.isVerified,
  );
}

Future<void> _refreshStoryScopes(
  WidgetRef ref,
  String feedType, {
  int? memberId,
}) async {
  ref.invalidate(myStoriesProvider(feedType));
  ref.invalidate(feedStoriesProvider(feedType));
  if (memberId != null && memberId > 0) {
    ref.invalidate(memberStoriesProvider(memberId));
  }
}

StoryItem? _buildOptimisticStory({
  required StoryMutationResult mutation,
  required int fallbackId,
  required String caption,
  StoryAuthor? author,
  String fallbackImage = '',
}) {
  final storyId = mutation.id ?? fallbackId;
  if (storyId <= 0) return null;
  final createdAt = DateTime.now();
  final createdAtIso = createdAt.toIso8601String();
  return StoryItem(
    id: storyId,
    image: mutation.image.isNotEmpty ? mutation.image : fallbackImage,
    caption: caption,
    createdAt: createdAtIso,
    expiresAt: createdAt.add(const Duration(hours: 24)).toIso8601String(),
    isExpired: false,
    viewed: false,
    groupId: null,
    viewCount: 0,
    author: author,
    variants: mutation.variants,
  );
}

List<_StoryGroup> _buildGroups(
  List<StoryItem> items, {
  StoryAuthor? fallbackAuthor,
}) {
  final grouped = <int, List<StoryItem>>{};
  final authors = <int, StoryAuthor>{};
  for (final item in items) {
    final author = item.author ?? fallbackAuthor;
    if (author == null || author.id <= 0) continue;
    grouped.putIfAbsent(author.id, () => <StoryItem>[]).add(item);
    authors[author.id] = author;
  }
  final out = <_StoryGroup>[];
  for (final entry in grouped.entries) {
    final sorted = [...entry.value]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    out.add(_StoryGroup(author: authors[entry.key]!, items: sorted));
  }
  out.sort((a, b) {
    if (a.viewed != b.viewed) return a.viewed ? 1 : -1;
    return b.latestAt.compareTo(a.latestAt);
  });
  return out;
}

class _StoryGroup {
  const _StoryGroup({required this.author, required this.items});

  final StoryAuthor author;
  final List<StoryItem> items;

  bool get viewed => items.every((item) => item.viewed);
  int get unviewedCount => items.where((item) => !item.viewed).length;
  String get latestAt => items.isEmpty ? '' : items.last.createdAt;

  int get firstUnviewedIndex {
    final index = items.indexWhere((item) => !item.viewed);
    return index == -1 ? 0 : index;
  }
}

Path _buildRoundedHeptagonPath(Size size, double cornerRadius) {
  const sides = 7;
  final center = Offset(size.width / 2, size.height / 2);
  final radius = math.min(size.width, size.height) / 2;
  final vertices = List<Offset>.generate(sides, (index) {
    final angle = (-math.pi / 2) + (2 * math.pi * index / sides);
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }, growable: false);

  final path = Path();
  for (var index = 0; index < vertices.length; index++) {
    final current = vertices[index];
    final previous = vertices[(index - 1 + vertices.length) % vertices.length];
    final next = vertices[(index + 1) % vertices.length];

    final toPrevious = previous - current;
    final toNext = next - current;
    final previousLength = toPrevious.distance;
    final nextLength = toNext.distance;
    final inset = math.min(
      cornerRadius,
      math.min(previousLength, nextLength) / 2,
    );

    final entryPoint = current + (toPrevious / previousLength) * inset;
    final exitPoint = current + (toNext / nextLength) * inset;

    if (index == 0) {
      path.moveTo(entryPoint.dx, entryPoint.dy);
    } else {
      path.lineTo(entryPoint.dx, entryPoint.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, exitPoint.dx, exitPoint.dy);
  }
  path.close();
  return path;
}
