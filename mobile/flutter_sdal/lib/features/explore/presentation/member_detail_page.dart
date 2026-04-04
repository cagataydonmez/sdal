import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../stories/presentation/stories_rail.dart';
import '../data/explore_repository.dart';

class MemberDetailPage extends ConsumerWidget {
  const MemberDetailPage({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(memberDetailProvider(memberId));
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Üye detayı',
      child: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Üye bulunamadı.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RemoteAvatar(
                          label: detail.summary.name,
                          imageUrl: config
                              .resolveUrl(detail.summary.photo)
                              .toString(),
                          radius: 30,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.summary.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (detail.summary.handle.isNotEmpty)
                                Text('@${detail.summary.handle}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(label: 'Meslek', value: detail.summary.profession),
                    _InfoRow(label: 'Şehir', value: detail.summary.city),
                    _InfoRow(label: 'Şirket', value: detail.company),
                    _InfoRow(label: 'Unvan', value: detail.title),
                    _InfoRow(label: 'Uzmanlık', value: detail.expertise),
                    _InfoRow(label: 'Mezuniyet', value: detail.graduationYear),
                    _InfoRow(label: 'E-posta', value: detail.email),
                    _InfoRow(label: 'LinkedIn', value: detail.linkedinUrl),
                    if (detail.signature.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'İmza',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(detail.signature),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StoriesRail(
                mode: StoryRailMode.member,
                memberId: memberId,
                title: 'Uyenin hikayeleri',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
