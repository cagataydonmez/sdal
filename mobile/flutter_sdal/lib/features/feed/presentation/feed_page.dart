import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/feed_repository.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedItemsProvider);
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Ana Akış',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(feedItemsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Gönderi'),
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
            itemCount: items.length,
            separatorBuilder: (_, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = items[index];
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
                            ? 'Bu gönderi içerik taşımıyor.'
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
                                  .read(feedRepositoryProvider)
                                  .toggleLike(item.id);
                              ref.invalidate(feedItemsProvider);
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

Future<void> _openComposer(BuildContext context, WidgetRef ref) async {
  final contentController = TextEditingController();
  final picker = ImagePicker();
  XFile? selectedImage;
  bool submitting = false;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                  'Yeni gönderi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Ne paylaşmak istiyorsun?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Seçilen görsel: ${selectedImage!.name}'),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 92,
                                  maxWidth: 1800,
                                );
                                if (!context.mounted) return;
                                setSheetState(() => selectedImage = file);
                              },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeriden seç'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                setSheetState(() => submitting = true);
                                final content = contentController.text.trim();
                                final repo = ref.read(feedRepositoryProvider);
                                final result = selectedImage == null
                                    ? await repo.createPost(content: content)
                                    : await repo.createPostWithImage(
                                        content: content,
                                        feedType: 'main',
                                        imageFile: File(selectedImage!.path),
                                      );
                                if (!context.mounted) return;
                                setSheetState(() => submitting = false);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.message.isNotEmpty
                                          ? result.message
                                          : (result.ok
                                                ? 'Gönderi paylaşıldı.'
                                                : 'Gönderi paylaşılamadı.'),
                                    ),
                                  ),
                                );
                                if (result.ok) {
                                  ref.invalidate(feedItemsProvider);
                                }
                              },
                        child: Text(submitting ? 'Paylaşılıyor...' : 'Paylaş'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    contentController.dispose();
  }
}
