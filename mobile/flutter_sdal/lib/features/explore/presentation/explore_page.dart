import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/explore_repository.dart';

class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsState = ref.watch(suggestionMembersProvider);
    final directoryState = ref.watch(directoryMembersProvider);
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Keşfet',
      actions: [
        IconButton(
          onPressed: () {
            ref.invalidate(suggestionMembersProvider);
            ref.invalidate(directoryMembersProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Öneriler', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          suggestionsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) => items.isEmpty
                ? const SurfaceCard(child: Text('Şu anda öneri yok.'))
                : SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return SizedBox(
                          width: 220,
                          child: _MemberCard(
                            member: item,
                            onTap: () => context.push('/members/${item.id}'),
                            imageUrl: config.resolveUrl(item.photo).toString(),
                            onFollow: () async {
                              await ref
                                  .read(exploreRepositoryProvider)
                                  .follow(item.id);
                              ref.invalidate(suggestionMembersProvider);
                              ref.invalidate(directoryMembersProvider);
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text('Üye rehberi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          directoryState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) => Column(
              children: items
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MemberCard(
                        member: member,
                        onTap: () => context.push('/members/${member.id}'),
                        imageUrl: config.resolveUrl(member.photo).toString(),
                        onFollow: () async {
                          await ref
                              .read(exploreRepositoryProvider)
                              .follow(member.id);
                          ref.invalidate(directoryMembersProvider);
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onTap,
    required this.imageUrl,
    required this.onFollow,
  });

  final MemberSummary member;
  final VoidCallback onTap;
  final String imageUrl;
  final Future<void> Function() onFollow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RemoteAvatar(label: member.name, imageUrl: imageUrl, radius: 28),
            const SizedBox(height: 12),
            Text(member.name, style: Theme.of(context).textTheme.titleMedium),
            if (member.handle.isNotEmpty)
              Text(
                '@${member.handle}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (member.profession.isNotEmpty || member.city.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  member.profession,
                  member.city,
                ].where((part) => part.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onFollow, child: const Text('Takip et')),
          ],
        ),
      ),
    );
  }
}
