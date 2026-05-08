import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../feed/data/feed_repository.dart';
import '../application/stories_action_controller.dart';
import '../data/stories_repository.dart';

class ExpiredStoriesPage extends ConsumerStatefulWidget {
  const ExpiredStoriesPage({super.key, this.initialFeedType = FeedType.main});

  final FeedType initialFeedType;

  @override
  ConsumerState<ExpiredStoriesPage> createState() => _ExpiredStoriesPageState();
}

class _ExpiredStoriesPageState extends ConsumerState<ExpiredStoriesPage> {
  late FeedType _feedType = widget.initialFeedType;

  @override
  Widget build(BuildContext context) {
    final feedType = _feedType.apiValue;
    final storiesState = ref.watch(myExpiredStoriesProvider(feedType));
    final actionState = ref.watch(storiesActionControllerProvider);
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: _pageTitle(context, _feedType),
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(myStoriesProvider(feedType)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _FeedTypePicker(
              value: _feedType,
              onChanged: (next) => setState(() => _feedType = next),
            ),
          ),
          Expanded(
            child: storiesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: const ErrorView(),
                ),
              ),
              data: (stories) {
                if (stories.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_emptyTitle(context, _feedType)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: stories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = stories[index];
                    final reposting =
                        actionState.isLoading &&
                        actionState.scope == 'stories:repost:${item.id}';
                    return SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  width: 72,
                                  height: 96,
                                  child: item.mediaUrl.isNotEmpty
                                      ? SdalNetworkImage(
                                          imageUrl: config
                                              .resolveUrl(item.mediaUrl)
                                              .toString(),
                                          fit: BoxFit.cover,
                                          enableLightbox: false,
                                          errorFallback: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).dividerColor,
                                            ),
                                          ),
                                        )
                                      : DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.caption.isNotEmpty
                                          ? item.caption
                                          : 'Başlıksız hikaye',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    if (item.createdAt.isNotEmpty)
                                      Text(
                                        'Paylaşıldı: ${formatSdalTimestamp(context, item.createdAt)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (item.expiresAt.isNotEmpty)
                                      Text(
                                        'Süresi doldu: ${formatSdalTimestamp(context, item.expiresAt)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: reposting
                                ? null
                                : () => _repostStory(
                                    context,
                                    ref,
                                    item.id,
                                    feedType,
                                  ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              reposting ? 'Yayınlanıyor...' : 'Tekrar yayınla',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _repostStory(
    BuildContext context,
    WidgetRef ref,
    int storyId,
    String feedType,
  ) async {
    final ok = await ref
        .read(storiesActionControllerProvider.notifier)
        .repostStory(storyId);
    if (!context.mounted) return;

    final actionState = ref.read(storiesActionControllerProvider);
    if (ok != null) {
      final current = ref.read(myExpiredStoriesProvider(feedType)).value;
      StoryItem? source;
      if (current != null) {
        for (final item in current) {
          if (item.id == storyId) {
            source = item;
            break;
          }
        }
      }
      final optimistic = _buildOptimisticRepostStory(
        mutation: ok,
        storyId: storyId,
        source: source,
      );
      if (optimistic != null) {
        ref.read(myStoryOverlayProvider(feedType).notifier).upsert(optimistic);
        ref
            .read(feedStoryOverlayProvider(feedType).notifier)
            .upsert(optimistic);
      }
      unawaited(_refreshStories(ref, feedType, memberId: source?.author?.id));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ??
              (ok != null
                  ? 'Hikaye yeniden yayınlandı.'
                  : 'Hikaye yeniden yayınlanamadı.'),
        ),
      ),
    );
  }
}

class _FeedTypePicker extends StatelessWidget {
  const _FeedTypePicker({required this.value, required this.onChanged});

  final FeedType value;
  final ValueChanged<FeedType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FeedType>(
      segments: const [
        ButtonSegment<FeedType>(value: FeedType.main, label: Text('Ana Akış')),
        ButtonSegment<FeedType>(
          value: FeedType.community,
          label: Text('Topluluk'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        onChanged(selection.first);
      },
    );
  }
}

String _pageTitle(BuildContext context, FeedType feedType) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (feedType) {
    FeedType.main =>
      isTurkish
          ? 'Süresi Dolan Ana Akış Hikayeleri'
          : 'Expired Main Feed Stories',
    FeedType.community =>
      isTurkish
          ? 'Süresi Dolan Topluluk Hikayeleri'
          : 'Expired Community Stories',
  };
}

String _emptyTitle(BuildContext context, FeedType feedType) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (feedType) {
    FeedType.main =>
      isTurkish
          ? 'Süresi dolmuş ana akış hikayesi bulunmuyor.'
          : 'No expired main feed stories.',
    FeedType.community =>
      isTurkish
          ? 'Süresi dolmuş topluluk hikayesi bulunmuyor.'
          : 'No expired community stories.',
  };
}

Future<void> _refreshStories(
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

StoryItem? _buildOptimisticRepostStory({
  required StoryMutationResult mutation,
  required int storyId,
  required StoryItem? source,
}) {
  final nextId = mutation.id ?? storyId;
  if (nextId <= 0) return null;
  final createdAt = DateTime.now();
  return StoryItem(
    id: nextId,
    image: mutation.image.isNotEmpty ? mutation.image : (source?.image ?? ''),
    caption: source?.caption ?? '',
    createdAt: createdAt.toIso8601String(),
    expiresAt: createdAt.add(const Duration(hours: 24)).toIso8601String(),
    isExpired: false,
    viewed: false,
    groupId: source?.groupId,
    viewCount: 0,
    author: source?.author,
    variants: mutation.variants ?? source?.variants,
  );
}
