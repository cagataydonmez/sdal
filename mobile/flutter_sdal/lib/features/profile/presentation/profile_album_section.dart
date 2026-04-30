import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../albums/data/albums_repository.dart';

class ProfileAlbumSection extends ConsumerWidget {
  const ProfileAlbumSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.albumsState,
    required this.onOpenAlbum,
    this.isOwner = false,
    this.onCreateAlbum,
    this.onDeleteAlbum,
  });

  final String title;
  final String subtitle;
  final AsyncValue<List<AlbumCategoryItem>> albumsState;
  final ValueChanged<AlbumCategoryItem> onOpenAlbum;
  final bool isOwner;
  final VoidCallback? onCreateAlbum;
  final ValueChanged<AlbumCategoryItem>? onDeleteAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner && onCreateAlbum != null)
                FilledButton.tonalIcon(
                  onPressed: onCreateAlbum,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Albüm ekle'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          albumsState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(error.toString()),
            data: (albums) {
              if (albums.isEmpty) {
                return _ProfileAlbumEmptyState(
                  isOwner: isOwner,
                  onCreateAlbum: onCreateAlbum,
                );
              }
              return SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: albums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _ProfileAlbumCard(
                    album: albums[index],
                    onOpen: () => onOpenAlbum(albums[index]),
                    onDelete:
                        isOwner &&
                            albums[index].canEdit &&
                            onDeleteAlbum != null
                        ? () => onDeleteAlbum!(albums[index])
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileAlbumEmptyState extends StatelessWidget {
  const _ProfileAlbumEmptyState({required this.isOwner, this.onCreateAlbum});

  final bool isOwner;
  final VoidCallback? onCreateAlbum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.accentMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_stories_rounded, color: tokens.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOwner
                      ? 'Henüz profiline ayrılmış bir anı köşen yok.'
                      : 'Bu profilde henüz paylaşılan bir profil albümü görünmüyor.',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isOwner
                ? 'Yakın arkadaşlar, okul günleri ya da mezuniyet hatıraları için ayrı albümler açabilirsin.'
                : 'Yeni albüm açıldığında burada doğrudan görünür.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.foregroundMuted,
            ),
          ),
          if (isOwner && onCreateAlbum != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onCreateAlbum,
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: const Text('İlk profil albümünü oluştur'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAlbumCard extends ConsumerWidget {
  const _ProfileAlbumCard({
    required this.album,
    required this.onOpen,
    this.onDelete,
  });

  final AlbumCategoryItem album;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    final config = ref.watch(appConfigProvider);
    final preview = album.previews.isEmpty
        ? ''
        : config.resolveUrl(album.previews.first).toString();

    return SizedBox(
      width: 214,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(SdalThemeTokens.radiusXl),
            border: Border.all(color: tokens.panelBorder),
            boxShadow: [
              BoxShadow(
                color: tokens.storyOverlay.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      SdalThemeTokens.radiusLg,
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: preview.isNotEmpty
                          ? SdalNetworkImage(
                              imageUrl: preview,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(
                                SdalThemeTokens.radiusLg,
                              ),
                              enableLightbox: false,
                              cacheWidth: 520,
                              cacheHeight: 390,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    tokens.accentMuted,
                                    tokens.panelRaised,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.photo_library_outlined,
                                size: 34,
                                color: tokens.accent,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(
                          SdalThemeTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        '${album.count} fotoğraf',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: PopupMenuButton<String>(
                        tooltip: 'Albümü yönet',
                        onSelected: (value) {
                          if (value == 'delete') onDelete!();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Albümü sil'),
                          ),
                        ],
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                album.description.isNotEmpty
                    ? album.description
                    : 'Profilde öne çıkan anıları bir arada tutar.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.foregroundMuted,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.lock_open_rounded,
                    size: 16,
                    color: tokens.foregroundMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      album.visibilityScope == 'private'
                          ? 'Özel erişim'
                          : 'Profilde gösteriliyor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: tokens.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
