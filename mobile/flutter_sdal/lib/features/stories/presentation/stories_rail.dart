import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/remote_avatar.dart';
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
    this.title = 'Hikayeler',
  });

  final StoryRailMode mode;
  final int? memberId;
  final bool showUpload;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
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
                  title,
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
                  'Henuz aktif hikaye yok.',
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
                          ? '${groups[index].unviewedCount} yeni'
                          : 'Goruldu',
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
    return _StoryTile(
      icon: Icons.add_a_photo_outlined,
      label: 'Hikaye ekle',
      subtitle: '24 saat gorunur',
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
    return SizedBox(
      height: 116,
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
    final borderColor = viewed
        ? const Color(0xFFD5DEE8)
        : const Color(0xFF1E7BC8);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor, width: 2),
                gradient: viewed
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF1E7BC8), Color(0xFF6ED2FF)],
                      ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: icon != null
                    ? DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF4FF),
                        ),
                        child: Icon(icon, color: const Color(0xFF0D4C7D)),
                      )
                    : imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _StoryFallback(label: label),
                      )
                    : _StoryFallback(label: label),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF133A5E), Color(0xFF1E7BC8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          label.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
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
    return const SizedBox(
      width: 86,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFE2EAF2),
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: SizedBox(width: 74, height: 74),
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
    final imageUrl = config.resolveUrl(_item.mediaUrl).toString();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Colors.black),
                  )
                : const ColoredBox(color: Colors.black),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
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
                                        ? Colors.white
                                        : Colors.white24,
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
                        color: Colors.white,
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
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _item.createdAt,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      if (_allowManage)
                        PopupMenuButton<String>(
                          color: const Color(0xFF10263A),
                          iconColor: Colors.white,
                          onSelected: (value) => _onMenuSelected(value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Basligi duzenle'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Hikayeyi sil'),
                            ),
                            if (_item.isExpired)
                              const PopupMenuItem(
                                value: 'repost',
                                child: Text('Yeniden paylas'),
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
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        _item.caption,
                        style: const TextStyle(
                          color: Colors.white,
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goPrevious,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goNext,
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
        title: const Text('Hikaye basligi'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Kisa bir aciklama ekle'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
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
        title: const Text('Hikaye silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yeni hikaye', style: Theme.of(context).textTheme.titleLarge),
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
                _pickedFile == null ? 'Galeriden sec' : _pickedFile!.name,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Aciklama',
                hintText: 'Hikayene kisa bir not ekle',
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
                  actionState.isLoading ? 'Yukleniyor...' : 'Hikayeyi paylas',
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
