import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
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
  });

  final StoryRailMode mode;
  final int? memberId;
  final bool showUpload;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final asyncItems = switch (mode) {
      StoryRailMode.feed => ref.watch(feedStoriesProvider),
      StoryRailMode.mine => ref.watch(myStoriesProvider),
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
            error: (error, _) => Text(error.toString()),
            data: (items) {
              final groups = _buildGroups(items);
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
                          .resolveUrl(groups[index].coverPhoto)
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
      builder: (context) => const _StoryUploadSheet(),
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
              Container(
                width: mediaSize,
                height: mediaSize,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 2),
                  gradient: viewed
                      ? null
                      : LinearGradient(
                          colors: [tokens.storyActive, tokens.accent],
                        ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: icon != null
                      ? DecoratedBox(
                          decoration: BoxDecoration(color: tokens.accentMuted),
                          child: Icon(icon, color: tokens.accent),
                        )
                      : imageUrl.isNotEmpty
                      ? SdalNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: (mediaSize * 2).round(),
                          cacheHeight: (mediaSize * 2).round(),
                          semanticLabel: context.l10n.storiesViewStorySemantic(
                            label,
                          ),
                          errorFallback: _StoryFallback(label: label),
                        )
                      : _StoryFallback(label: label),
                ),
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
    return SizedBox(
      width: MediaQuery.textScalerOf(context).scale(1) > 1.15 ? 94 : 86,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panelMuted,
              borderRadius: const BorderRadius.all(Radius.circular(22)),
            ),
            child: const SizedBox(width: 74, height: 74),
          ),
        ],
      ),
    );
  }
}

class _StoryViewerPage extends ConsumerStatefulWidget {
  const _StoryViewerPage({
    required this.groups,
    required this.initialGroupIndex,
    required this.mode,
  });

  final List<_StoryGroup> groups;
  final int initialGroupIndex;
  final StoryRailMode mode;

  @override
  ConsumerState<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<_StoryViewerPage> {
  Timer? _timer;
  late int _groupIndex;
  int _itemIndex = 0;

  _StoryGroup get _group => widget.groups[_groupIndex];
  StoryItem get _item => _group.items[_itemIndex];

  bool get _allowManage => widget.mode == StoryRailMode.mine;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex;
    _itemIndex = _group.firstUnviewedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateCurrent());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _activateCurrent() {
    _timer?.cancel();
    if (!_allowManage && !_item.viewed) {
      ref.read(storiesRepositoryProvider).markViewed(_item.id).then((_) {
        if (!mounted) return;
        ref.invalidate(feedStoriesProvider);
        if (widget.mode == StoryRailMode.member && _item.author != null) {
          ref.invalidate(memberStoriesProvider(_item.author!.id));
        }
      });
    }
    _timer = Timer(const Duration(seconds: 5), _goNext);
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
    if (mounted) Navigator.of(context).pop();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final imageUrl = config.resolveUrl(_item.mediaUrl).toString();
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: imageUrl.isNotEmpty
                ? SdalNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    semanticLabel: l10n.storiesViewStorySemantic(
                      _group.author.displayName,
                    ),
                    placeholder: DecoratedBox(
                      decoration: BoxDecoration(color: tokens.canvasSubtle),
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
                    tokens.storyOverlay,
                    Colors.transparent,
                    tokens.storyOverlay.withValues(alpha: 0.92),
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
                            for (var i = 0; i < _group.items.length; i++) ...[
                              Expanded(
                                child: Container(
                                  height: 3,
                                  margin: EdgeInsets.only(
                                    right: i == _group.items.length - 1 ? 0 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i <= _itemIndex
                                        ? tokens.foregroundOnAccent
                                        : tokens.foregroundOnAccent.withValues(
                                            alpha: 0.24,
                                          ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        color: tokens.foregroundOnAccent,
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
                              style: TextStyle(
                                color: tokens.foregroundOnAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _item.createdAt,
                              style: TextStyle(
                                color: tokens.foregroundOnAccent.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_allowManage)
                        PopupMenuButton<String>(
                          color: tokens.panelRaised,
                          iconColor: tokens.foregroundOnAccent,
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
                            if (_item.isExpired)
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
                        color: tokens.storyOverlay,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        _item.caption,
                        style: TextStyle(
                          color: tokens.foregroundOnAccent,
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
        ],
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
    if (!mounted || !ok) return;
    ref.invalidate(myStoriesProvider);
    ref.invalidate(feedStoriesProvider);
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
    ref.invalidate(myStoriesProvider);
    ref.invalidate(feedStoriesProvider);
    Navigator.of(context).pop();
  }

  Future<void> _repostStory() async {
    final ok = await ref
        .read(storiesActionControllerProvider.notifier)
        .repostStory(_item.id);
    if (!mounted || !ok) return;
    ref.invalidate(myStoriesProvider);
    ref.invalidate(feedStoriesProvider);
    Navigator.of(context).pop();
  }
}

class _StoryUploadSheet extends ConsumerStatefulWidget {
  const _StoryUploadSheet();

  @override
  ConsumerState<_StoryUploadSheet> createState() => _StoryUploadSheetState();
}

class _StoryUploadSheetState extends ConsumerState<_StoryUploadSheet> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  XFile? _pickedFile;

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
                final file = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (file != null) setState(() => _pickedFile = file);
              },
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _pickedFile == null ? l10n.pickFromGallery : _pickedFile!.name,
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
                              imageFile: File(_pickedFile!.path),
                              caption: _captionController.text.trim(),
                            );
                        if (!context.mounted || !ok) return;
                        ref.invalidate(myStoriesProvider);
                        ref.invalidate(feedStoriesProvider);
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

List<_StoryGroup> _buildGroups(List<StoryItem> items) {
  final grouped = <int, List<StoryItem>>{};
  final authors = <int, StoryAuthor>{};
  for (final item in items) {
    final author = item.author;
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
  String get coverPhoto => items.isEmpty ? author.photo : items.last.mediaUrl;

  int get firstUnviewedIndex {
    final index = items.indexWhere((item) => !item.viewed);
    return index == -1 ? 0 : index;
  }
}
