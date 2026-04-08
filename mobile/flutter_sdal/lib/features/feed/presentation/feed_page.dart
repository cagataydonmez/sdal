import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../stories/data/stories_repository.dart';
import '../../stories/presentation/stories_rail.dart';
import '../application/feed_action_controller.dart';
import '../data/feed_repository.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final List<FeedItem> _items = <FeedItem>[];
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int? _nextCursor;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(feedQueryProvider);
    final feedState = ref.watch(feedPageProvider);
    final onlineMembersState = ref.watch(onlineMembersProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider).valueOrNull;

    ref.listen<FeedQuery>(feedQueryProvider, (previous, next) {
      if (previous == next || !mounted) return;
      setState(() {
        _items.clear();
        _hasMore = true;
        _nextCursor = null;
        _isLoadingMore = false;
      });
    });
    ref.listen<AsyncValue<FeedPageData>>(feedPageProvider, (previous, next) {
      next.whenData((page) {
        if (!mounted) return;
        setState(() {
          _items
            ..clear()
            ..addAll(page.items);
          _hasMore = page.hasMore;
          _nextCursor = page.nextCursor;
          _isLoadingMore = false;
        });
      });
    });

    return FeatureScaffold(
      title: _feedPageTitle(context, query.feedType),
      background: FeatureScaffoldBackground.editorial,
      actions: [
        IconButton(
          tooltip: l10n.refreshAction,
          onPressed: () {
            ref.invalidate(feedItemsProvider);
            ref.invalidate(feedPageProvider);
            ref.invalidate(onlineMembersProvider);
            ref.invalidate(feedStoriesProvider(query.feedType.apiValue));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.feedPostAction),
      ),
      child: feedState.when(
        loading: () => _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildFeedList(
                context: context,
                ref: ref,
                query: query,
                onlineMembersState: onlineMembersState,
                config: config,
                l10n: l10n,
                session: session,
              ),
        error: (error, _) => _items.isEmpty
            ? ErrorView(
                onRetry: () {
                  ref.invalidate(feedPageProvider);
                  ref.invalidate(onlineMembersProvider);
                },
              )
            : _buildFeedList(
                context: context,
                ref: ref,
                query: query,
                onlineMembersState: onlineMembersState,
                config: config,
                l10n: l10n,
                session: session,
              ),
        data: (_) => _buildFeedList(
          context: context,
          ref: ref,
          query: query,
          onlineMembersState: onlineMembersState,
          config: config,
          l10n: l10n,
          session: session,
        ),
      ),
    );
  }

  Widget _buildFeedList({
    required BuildContext context,
    required WidgetRef ref,
    required FeedQuery query,
    required AsyncValue<List<FeedOnlineMember>> onlineMembersState,
    required dynamic config,
    required dynamic l10n,
    required dynamic session,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(feedPageProvider);
        ref.invalidate(onlineMembersProvider);
        await ref.read(feedPageProvider.future);
        await ref.read(onlineMembersProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + 4,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FeedControlsCard(query: query);
          }
          if (index == 1) {
            return _OnlineMembersCard(
              state: onlineMembersState,
              imageUrlFor: (photo) => config.resolveUrl(photo).toString(),
            );
          }
          if (index == 2) {
            return StoriesRail(
              mode: StoryRailMode.feed,
              showUpload: true,
              title: _storiesTitleForFeedType(context, query.feedType),
              feedType: query.feedType.apiValue,
            );
          }
          if (index == _items.length + 3) {
            if (_items.isEmpty) {
              return _FeedEmptyState(
                onCompose: () => _openComposer(context, ref),
              );
            }
            if (!_hasMore) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.center,
              child: FilledButton.tonal(
                onPressed: _isLoadingMore ? null : () => _loadMore(query),
                child: Text(
                  _isLoadingMore
                      ? context.l10n.submitInProgress
                      : context.l10n.albumsLoadMore,
                ),
              ),
            );
          }
          final item = _items[index - 3];
          final canOpenAuthorProfile =
              item.authorId != null && item.authorId! > 0;
          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/posts/${item.id}'),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: canOpenAuthorProfile
                            ? () => context.push('/members/${item.authorId}')
                            : null,
                        child: Tooltip(
                          message: l10n.openMemberProfileForName(
                            item.authorName,
                          ),
                          child: Semantics(
                            button: canOpenAuthorProfile,
                            enabled: canOpenAuthorProfile,
                            label: l10n.openMemberProfileForName(
                              item.authorName,
                            ),
                            child: RemoteAvatar(
                              label: item.authorName,
                              imageUrl: config
                                  .resolveUrl(item.authorPhoto)
                                  .toString(),
                              radius: 24,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.authorName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (item.authorHandle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '@${item.authorHandle}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (session?.user?.id != null &&
                          session!.user!.id == item.authorId)
                        _FeedPostMenuButton(
                          onDelete: () async {
                            final ok = await ref
                                .read(feedActionControllerProvider.notifier)
                                .deletePost(item.id);
                            if (!context.mounted) return;
                            final actionState = ref.read(
                              feedActionControllerProvider,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  actionState.message ??
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
                  Text(
                    item.content.isEmpty
                        ? l10n.feedEmptyContent
                        : plainTextFromRichContent(item.content),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (item.imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SdalNetworkImage(
                      imageUrl: config.resolveUrl(item.imageUrl).toString(),
                      borderRadius: BorderRadius.circular(18),
                      semanticLabel: item.authorName,
                      cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                          .round(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _MetricPill(
                        icon: item.liked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: '${item.likeCount}',
                        active: item.liked,
                        onTap: () async {
                          await ref
                              .read(feedActionControllerProvider.notifier)
                              .toggleLike(item.id);
                        },
                      ),
                      const SizedBox(width: 10),
                      _MetricPill(
                        icon: Icons.chat_bubble_outline,
                        label: '${item.commentCount}',
                        onTap: () => context.push('/posts/${item.id}'),
                      ),
                      const Spacer(),
                      Text(
                        item.createdAt,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadMore(FeedQuery query) async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .fetchFeedPage(
            feedType: query.feedType,
            filter: query.filter,
            cursor: _nextCursor,
            offset: _nextCursor == null ? _items.length : 0,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daha fazla gönderi yüklenemedi.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).sdal.accentMuted
              : Theme.of(context).sdal.panelMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Theme.of(context).sdal.accent : null,
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _OnlineMembersCard extends StatelessWidget {
  const _OnlineMembersCard({required this.state, required this.imageUrlFor});

  final AsyncValue<List<FeedOnlineMember>> state;
  final String Function(String photo) imageUrlFor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();
        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Şu an çevrimiçi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: members.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: member.id <= 0
                          ? null
                          : () => context.push('/members/${member.id}'),
                      child: Tooltip(
                        message: l10n.openMemberProfileForName(member.name),
                        child: Semantics(
                          button: member.id > 0,
                          enabled: member.id > 0,
                          label: l10n.openMemberProfileForName(member.name),
                          child: ExcludeSemantics(
                            child: SizedBox(
                              width: 72,
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      RemoteAvatar(
                                        label: member.name,
                                        imageUrl: imageUrlFor(member.photo),
                                        radius: 24,
                                        excludeFromSemantics: true,
                                      ),
                                      Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).sdal.success,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).sdal.panel,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    member.handle.isNotEmpty
                                        ? '@${member.handle}'
                                        : member.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _openComposer(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ComposerSheet(),
  );
}

class _ComposerSheet extends ConsumerStatefulWidget {
  const _ComposerSheet();

  @override
  ConsumerState<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends ConsumerState<_ComposerSheet> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedImage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(feedActionControllerProvider);
    final query = ref.watch(feedQueryProvider);
    final l10n = context.l10n;
    final submitting =
        actionState.isLoading && actionState.scope == 'createPost';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.feedComposerTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _feedComposerContextLabel(context, query.feedType),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).sdal.foregroundMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.feedComposerHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_selectedImage!.path),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.pickFromGallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: submitting ? null : _submit,
                    child: Text(
                      submitting ? l10n.shareInProgress : l10n.shareAction,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (!mounted) return;
    setState(() => _selectedImage = file);
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    final l10n = context.l10n;
    final ok = await ref
        .read(feedActionControllerProvider.notifier)
        .createPost(
          content: content,
          feedType: ref.read(feedQueryProvider).feedType.apiValue,
          imageFile: _selectedImage == null ? null : File(_selectedImage!.path),
        );
    if (!mounted) return;
    final nextState = ref.read(feedActionControllerProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextState.message ?? (ok ? l10n.postShared : l10n.postShareFailed),
        ),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tokens.accentMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dynamic_feed_outlined,
              size: 32,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz gönderi yok',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'İlk paylaşımı yapan sen ol — topluluk seni duyuyor.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.foregroundMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCompose,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('İlk gönderiyi paylaş'),
          ),
        ],
      ),
    );
  }
}

class _FeedControlsCard extends ConsumerWidget {
  const _FeedControlsCard({required this.query});

  final FeedQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).sdal;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<FeedType>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(
                value: FeedType.main,
                label: Text(_feedTypeLabel(context, FeedType.main)),
                icon: const Icon(Icons.dynamic_feed_outlined),
              ),
              ButtonSegment(
                value: FeedType.community,
                label: Text(_feedTypeLabel(context, FeedType.community)),
                icon: const Icon(Icons.groups_2_outlined),
              ),
            ],
            selected: {query.feedType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              ref.read(feedQueryProvider.notifier).state = query.copyWith(
                feedType: selection.first,
              );
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in FeedFilter.values) ...[
                  _FeedFilterChip(
                    label: _feedFilterLabel(context, filter),
                    selected: query.filter == filter,
                    onTap: () {
                      ref.read(feedQueryProvider.notifier).state = query
                          .copyWith(filter: filter);
                    },
                  ),
                  if (filter != FeedFilter.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedFilterChip extends StatelessWidget {
  const _FeedFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? tokens.accentMuted : tokens.panelMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tokens.accent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? tokens.accent : null,
          ),
        ),
      ),
    );
  }
}

String _feedPageTitle(BuildContext context, FeedType feedType) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (feedType) {
    FeedType.main => context.l10n.feedTitle,
    FeedType.community => isTurkish ? 'Topluluk Akışı' : 'Community Feed',
  };
}

String _storiesTitleForFeedType(BuildContext context, FeedType feedType) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (feedType) {
    FeedType.main => isTurkish ? 'Ana Akış Hikayeleri' : 'Main Feed Stories',
    FeedType.community =>
      isTurkish ? 'Topluluk hikayeleri' : 'Community stories',
  };
}

String _feedComposerContextLabel(BuildContext context, FeedType feedType) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (feedType) {
    FeedType.main =>
      isTurkish
          ? 'Paylaşım ana akışta yayınlanacak.'
          : 'This post will be published in the main feed.',
    FeedType.community =>
      isTurkish
          ? 'Paylaşım topluluk akışında yayınlanacak.'
          : 'This post will be published in the community feed.',
  };
}

String _feedTypeLabel(BuildContext context, FeedType feedType) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (feedType) {
    FeedType.main => isTurkish ? 'Ana Akış' : 'Main Feed',
    FeedType.community => isTurkish ? 'Topluluk' : 'Community',
  };
}

String _feedFilterLabel(BuildContext context, FeedFilter filter) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (filter) {
    FeedFilter.latest => isTurkish ? 'En Yeni' : 'Newest',
    FeedFilter.popular => isTurkish ? 'Popüler' : 'Popular',
    FeedFilter.following => isTurkish ? 'Takip Ettiklerim' : 'Following',
  };
}
