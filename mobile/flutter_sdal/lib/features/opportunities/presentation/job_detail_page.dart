import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/jobs_action_controller.dart';
import '../data/opportunities_repository.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.jobId});

  final int jobId;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  late final FutureProvider<JobItem?> _jobProvider;
  final TextEditingController _applyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _jobProvider = FutureProvider.autoDispose<JobItem?>((ref) async {
      return ref.read(opportunitiesRepositoryProvider).fetchJob(widget.jobId);
    });
  }

  @override
  void dispose() {
    _applyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_jobProvider);
    final actionState = ref.watch(jobsActionControllerProvider);
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;

    return FeatureScaffold(
      title: l10n.jobsTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const ErrorView(),
        data: (job) => job == null
            ? const ErrorView()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_jobProvider),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (job.image.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SdalNetworkImage(
                                imageUrl: job.image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (job.jobType.isNotEmpty || job.workMode.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              children: [
                                if (job.jobType.isNotEmpty) Chip(label: Text(job.jobType)),
                                if (job.workMode.isNotEmpty) Chip(label: Text(job.workMode)),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            job.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            job.company,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (job.location.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '📍 ${job.location}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          if (job.posterHandle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${job.posterHandle}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: tokens.foregroundMuted),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            _formatDate(context, job.createdAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: tokens.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İş Tanımı',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(_plainText(job.description)),
                        ],
                      ),
                    ),
                    if (job.link.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Başvuru Linki',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _launchUrl(job.link),
                              child: Row(
                                children: [
                                  if (_isLinkedIn(job.link)) ...[
                                    _LinkedInIcon(),
                                    const SizedBox(width: 8),
                                  ] else if (_isKariyer(job.link)) ...[
                                    _KariyerIcon(),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      job.link,
                                      style: TextStyle(
                                        color: tokens.accent,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (job.myApplicationId > 0)
                      ...[
                        const SizedBox(height: 20),
                        SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.jobsApplicationStatus(
                                  _applicationStatusLabel(
                                    context,
                                    job.myApplicationStatus,
                                  ),
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (job.myApplicationDecisionNote.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(job.myApplicationDecisionNote),
                              ],
                            ],
                          ),
                        ),
                      ]
                    else
                      ...[
                        const SizedBox(height: 20),
                        SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _applyController,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: l10n.jobsShortNoteLabel,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: actionState.isLoading &&
                                          actionState.scope ==
                                              'jobs:apply:${widget.jobId}'
                                      ? null
                                      : () => _apply(job.id),
                                  child: Text(l10n.jobsApplyAction),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
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

  String _plainText(String richContent) {
    return plainTextFromRichContent(richContent);
  }

  String _applicationStatusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Beklemede';
      case 'reviewed':
        return 'İnceleniyor';
      case 'accepted':
        return 'Kabul Edildi';
      case 'approved':
        return 'Kabul Edildi';
      case 'rejected':
        return 'Reddedildi';
      default:
        return status;
    }
  }

  bool _isLinkedIn(String url) =>
      url.contains('linkedin.com');

  bool _isKariyer(String url) =>
      url.contains('kariyer.net');

  Future<void> _apply(int jobId) async {
    final text = _applyController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir not ekleyin')),
        );
      }
      return;
    }

    final ok = await ref
        .read(jobsActionControllerProvider.notifier)
        .apply(jobId: jobId, coverLetter: text);

    if (ok && mounted) {
      _applyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başvurunuz gönderildi')),
      );
      ref.invalidate(_jobProvider);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL açılamadı')),
        );
      }
    }
  }
}

class _LinkedInIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF0A66C2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'in',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _KariyerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
