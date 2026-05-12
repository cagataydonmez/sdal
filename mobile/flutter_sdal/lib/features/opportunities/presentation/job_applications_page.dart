import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../data/opportunities_repository.dart';

final _applicationsProvider = FutureProvider.autoDispose
    .family<List<JobApplicationItem>, int>((ref, jobId) {
  return ref.read(opportunitiesRepositoryProvider).fetchApplications(jobId);
});

class JobApplicationsPage extends ConsumerWidget {
  const JobApplicationsPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  final int jobId;
  final String jobTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_applicationsProvider(jobId));

    return FeatureScaffold(
      title: 'Başvurular',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Henüz başvuru yok.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_applicationsProvider(jobId)),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return _ApplicationTile(
                  item: item,
                  onTap: () => context.push(
                    '/jobs/$jobId/applications/${item.id}',
                    extra: {'jobTitle': jobTitle},
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.item, required this.onTap});

  final JobApplicationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPending = item.isPending;
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: _Avatar(photo: item.photo, displayName: item.displayName),
      title: Text(
        item.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item.handle.isNotEmpty ? '@${item.handle}' : '',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _StatusChip(isPending: isPending),
          const SizedBox(height: 4),
          Text(
            _formatDate(context, item.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, String date) {
    if (date.isEmpty) return '';
    try {
      return formatSdalTimestamp(context, date);
    } catch (_) {
      return date;
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo, required this.displayName});

  final String photo;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (photo.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        child: ClipOval(
          child: SdalNetworkImage(
            imageUrl: photo,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(radius: 22, child: Text(initials));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPending});

  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPending
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPending ? 'Beklemede' : 'İncelendi',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isPending
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
