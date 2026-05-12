import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/opportunities_repository.dart';

final _applicationDetailProvider = FutureProvider.autoDispose
    .family<JobApplicationItem?, (int, int)>((ref, ids) {
  final (jobId, appId) = ids;
  return ref
      .read(opportunitiesRepositoryProvider)
      .fetchApplicationDetail(jobId: jobId, applicationId: appId);
});

class JobApplicationDetailPage extends ConsumerWidget {
  const JobApplicationDetailPage({
    super.key,
    required this.jobId,
    required this.applicationId,
    this.jobTitle = '',
  });

  final int jobId;
  final int applicationId;
  final String jobTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_applicationDetailProvider((jobId, applicationId)));

    return FeatureScaffold(
      title: 'Başvuru Detayı',
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (app) =>
            app == null ? const ErrorView() : _ApplicationBody(app: app),
      ),
    );
  }
}

class _ApplicationBody extends StatelessWidget {
  const _ApplicationBody({required this.app});

  final JobApplicationItem app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Applicant header
        SurfaceCard(
          child: Row(
            children: [
              _avatar(app.photo, app.displayName),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (app.handle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${app.handle}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _StatusBadge(isPending: app.isPending),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Application details card
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Başvuru Bilgileri',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              if (app.city.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'İl',
                  value: app.city,
                ),
              if (app.contactChannel.isNotEmpty)
                _InfoRow(
                  icon: _channelIcon(app.contactChannel),
                  label: app.contactChannel,
                  value: app.contactValue,
                ),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Başvuru tarihi',
                value: _formatDate(context, app.createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/messages/new?userId=${app.applicantId}',
                ),
                icon: const Icon(Icons.message_outlined),
                label: const Text('Mesaj gönder'),
              ),
            ),
            if (app.cvLink.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchUrl(app.cvLink),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('CV\'yi aç'),
                ),
              ),
            ],
          ],
        ),

        if (app.coverLetter.isNotEmpty) ...[
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Başvuru notu', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Text(plainTextFromRichContent(app.coverLetter)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatar(String photo, String name) {
    if (photo.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        child: ClipOval(
          child: SdalNetworkImage(
            imageUrl: photo,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(radius: 30, child: Text(initials));
  }

  String _formatDate(BuildContext context, String date) {
    if (date.isEmpty) return '';
    try {
      return formatSdalTimestamp(context, date);
    } catch (_) {
      return date;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'E-posta':
        return Icons.email_outlined;
      case 'Telefon':
        return Icons.phone_outlined;
      case 'SMS':
        return Icons.sms_outlined;
      case 'WhatsApp':
        return Icons.chat_outlined;
      case 'LinkedIn':
        return Icons.work_outline;
      default:
        return Icons.contact_page_outlined;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPending});

  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPending
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
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
