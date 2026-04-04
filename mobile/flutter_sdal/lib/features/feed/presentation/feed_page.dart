import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../stories/presentation/stories_rail.dart';
import '../application/feed_action_controller.dart';
import '../data/feed_repository.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedItemsProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.feedTitle,
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(feedItemsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.feedPostAction),
      ),
      child: feedState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(feedItemsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length + 1,
            separatorBuilder: (_, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const StoriesRail(
                  mode: StoryRailMode.feed,
                  title: 'Topluluktan hikayeler',
                );
              }
              final item = items[index - 1];
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/posts/${item.id}'),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RemoteAvatar(
                            label: item.authorName,
                            imageUrl: config
                                .resolveUrl(item.authorPhoto)
                                .toString(),
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.authorName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (item.authorHandle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${item.authorHandle}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.content.isEmpty
                            ? l10n.feedEmptyContent
                            : item.content,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (item.imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            config.resolveUrl(item.imageUrl).toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
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
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFE7EA) : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? const Color(0xFFB42318) : null,
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
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
                child: Text('Seçilen görsel: ${_selectedImage!.name}'),
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
          feedType: 'main',
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
