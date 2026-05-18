import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/admin_action_controller.dart';
import '../data/admin_repository.dart';

class AdminAppModulePage extends ConsumerStatefulWidget {
  const AdminAppModulePage({super.key, required this.moduleKey});

  final String moduleKey;

  @override
  ConsumerState<AdminAppModulePage> createState() => _AdminAppModulePageState();
}

class _AdminAppModulePageState extends ConsumerState<AdminAppModulePage> {
  final _searchController = TextEditingController();
  final _userIdController = TextEditingController();
  final _cohortController = TextEditingController();

  String _query = '';
  String _userId = '';
  String _cohort = '';

  @override
  void dispose() {
    _searchController.dispose();
    _userIdController.dispose();
    _cohortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _moduleSpecByKey(widget.moduleKey);
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final actionState = ref.watch(adminActionControllerProvider);

    if (user == null || !user.hasAdminAccess) {
      return FeatureScaffold(
        title: spec.title,
        child: const Center(
          child: Text('Bu alan yalnızca admin hesapları için açık.'),
        ),
      );
    }

    return FeatureScaffold(
      title: spec.title,
      actions: [
        IconButton(
          tooltip: 'Yönetim ana sayfasına dön',
          onPressed: () => context.go('/admin'),
          icon: const Icon(Icons.dashboard_outlined),
        ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: () => ref.invalidate(adminAppModuleContentProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      background: FeatureScaffoldBackground.utility,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ModuleHeader(spec: spec),
          const SizedBox(height: 16),
          _ModulePlanCard(spec: spec),
          const SizedBox(height: 16),
          _ModuleFilterCard(
            searchController: _searchController,
            userIdController: _userIdController,
            cohortController: _cohortController,
            onApply: () {
              setState(() {
                _query = _searchController.text.trim();
                _userId = _userIdController.text.trim();
                _cohort = _cohortController.text.trim();
              });
            },
            onClear: () {
              setState(() {
                _searchController.clear();
                _userIdController.clear();
                _cohortController.clear();
                _query = '';
                _userId = '';
                _cohort = '';
              });
            },
          ),
          const SizedBox(height: 16),
          if (spec.dataSections.isEmpty)
            _RolloutStatusCard(spec: spec)
          else
            for (final section in spec.dataSections)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ModuleDataSection(
                  section: section,
                  query: AdminModuleContentQuery(
                    moduleKey: section.queryKey,
                    query: _query,
                    userId: _userId,
                    cohort: _cohort,
                    limit: section.limit,
                  ),
                  approvalType: section.approvalType,
                  workflowType: section.workflowType,
                  isBusy: actionState.isLoading,
                ),
              ),
        ],
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.spec});

  final _ModuleSpec spec;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: tokens.infoMuted,
            foregroundColor: tokens.info,
            child: Icon(spec.icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(spec.description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulePlanCard extends StatelessWidget {
  const _ModulePlanCard({required this.spec});

  final _ModuleSpec spec;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yönetim kapsamı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          for (final item in spec.operations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          if (spec.relatedAdminRoute != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go(spec.relatedAdminRoute!),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('İlgili mevcut admin ekranını aç'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleFilterCard extends StatelessWidget {
  const _ModuleFilterCard({
    required this.searchController,
    required this.userIdController,
    required this.cohortController,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController searchController;
  final TextEditingController userIdController;
  final TextEditingController cohortController;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filtreler', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Metin veya kullanıcı adı ara',
              prefixIcon: Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApply(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: userIdController,
                  decoration: const InputDecoration(
                    labelText: 'Üye ID',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => onApply(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: cohortController,
                  decoration: const InputDecoration(
                    labelText: 'Cohort / mezuniyet yılı',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => onApply(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Uygula'),
              ),
              TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleDataSection extends ConsumerWidget {
  const _ModuleDataSection({
    required this.section,
    required this.query,
    required this.approvalType,
    required this.workflowType,
    required this.isBusy,
  });

  final _ModuleDataSectionSpec section;
  final AdminModuleContentQuery query;
  final String approvalType;
  final String workflowType;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAppModuleContentProvider(query));
    return SurfaceCard(
      child: state.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text(error.toString()),
        data: (preview) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${preview.total} kayıt'),
              ],
            ),
            const SizedBox(height: 12),
            if (preview.items.isEmpty)
              const Text('Bu filtrelerle kayıt bulunamadı.')
            else
              for (final item in preview.items)
                _ModuleContentCard(
                  item: item,
                  deleteType: section.deleteType,
                  approvalType: approvalType,
                  workflowType: workflowType,
                  isBusy: isBusy,
                  onDeleted: () =>
                      ref.invalidate(adminAppModuleContentProvider),
                ),
          ],
        ),
      ),
    );
  }
}

class _ModuleContentCard extends ConsumerWidget {
  const _ModuleContentCard({
    required this.item,
    required this.deleteType,
    required this.approvalType,
    required this.workflowType,
    required this.isBusy,
    required this.onDeleted,
  });

  final AdminModerationItem item;
  final String deleteType;
  final String approvalType;
  final String workflowType;
  final bool isBusy;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    final directViewRoute = switch (deleteType) {
      'post' => '/posts/${item.id}',
      'group' => '/groups/${item.id}',
      'album_photo' => '/albums/photo/${item.id}',
      _ => '',
    };
    final approvalViewRoute = switch (approvalType) {
      'event' => '/events/${item.id}',
      'announcement' => '/announcements/${item.id}',
      'job' => '/jobs/${item.id}',
      _ => '',
    };
    final memberViewRoute = item.typeLabel == 'Üye'
        ? '/members/${item.id}'
        : '';
    final viewRoute = directViewRoute.isNotEmpty
        ? directViewRoute
        : (approvalViewRoute.isNotEmpty ? approvalViewRoute : memberViewRoute);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteAvatar(
                label: item.authorName,
                imageUrl: config.resolveUrl(item.authorAvatar).toString(),
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        item.typeLabel,
                        item.authorHandle.isEmpty
                            ? item.authorName
                            : '@${item.authorHandle}',
                        _timestamp(context, item.createdAt),
                      ].where((part) => part.trim().isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            SdalNetworkImage(
              imageUrl: item.imageUrl,
              height: 150,
              width: double.infinity,
              borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
              semanticLabel: '${item.typeLabel} görseli',
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: viewRoute.isEmpty
                    ? null
                    : () => context.push(viewRoute),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('İzle'),
              ),
              const Spacer(),
              if (deleteType.isNotEmpty)
                TextButton.icon(
                  onPressed: isBusy
                      ? null
                      : () async {
                          final ok = await _confirmDelete(context);
                          if (ok != true || !context.mounted) return;
                          final deleted = await ref
                              .read(adminActionControllerProvider.notifier)
                              .deleteContent(
                                type: deleteType,
                                id: item.id,
                                reason: 'Admin modül sayfasından kaldırıldı',
                              );
                          if (deleted) onDeleted();
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Sil'),
                ),
              if (approvalType.isNotEmpty) ...[
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => _reviewApproval(context, ref, 'rejected'),
                  child: const Text('Reddet'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () => _reviewApproval(context, ref, 'approved'),
                  child: const Text('Onayla'),
                ),
              ],
              if (workflowType.isNotEmpty) ...[
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => _reviewWorkflow(context, ref, 'rejected'),
                  child: const Text('Reddet'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () => _reviewWorkflow(context, ref, 'approved'),
                  child: const Text('Onayla'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reviewApproval(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .reviewContentApproval(
            entityType: approvalType,
            id: item.id,
            status: status,
          );
      onDeleted();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'İçerik onaylandı.' : 'İçerik reddedildi.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _reviewWorkflow(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final controller = ref.read(adminActionControllerProvider.notifier);
    final ok = switch (workflowType) {
      'member_request' => await controller.reviewMemberRequest(
        id: item.id,
        status: status,
      ),
      'verification_request' => await controller.reviewVerificationRequest(
        id: item.id,
        status: status == 'approved' ? 'approved' : 'rejected',
      ),
      'teacher_link' => await controller.reviewTeacherNetworkLink(
        id: item.id,
        status: status == 'approved' ? 'confirmed' : 'rejected',
      ),
      _ => false,
    };
    if (ok) onDeleted();
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (status == 'approved'
                    ? 'Kayıt onaylandı.'
                    : 'Kayıt reddedildi.')
              : (actionState.message ?? 'İşlem tamamlanamadı.'),
        ),
      ),
    );
  }
}

class _RolloutStatusCard extends StatelessWidget {
  const _RolloutStatusCard({required this.spec});

  final _ModuleSpec spec;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uygulama sırası',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Bu modül için ayrı yönetim sayfası oluşturuldu. Veri listesi ve düzenleme aksiyonları sonraki dilimde ilgili API kontratıyla bağlanacak.',
          ),
          if (spec.relatedAdminRoute != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go(spec.relatedAdminRoute!),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Mevcut admin akışına git'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kaydı sil'),
      content: const Text('Bu işlem geri alınamaz. Devam edilsin mi?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
}

String _timestamp(BuildContext context, String raw) =>
    raw.isEmpty ? '' : formatSdalTimestamp(context, raw);

_ModuleSpec _moduleSpecByKey(String key) =>
    _moduleSpecs[key] ?? _moduleSpecs['feed']!;

final _moduleSpecs = <String, _ModuleSpec>{
  'feed': _ModuleSpec(
    key: 'feed',
    title: 'Akış yönetimi',
    description:
        'Post, yorum ve hikayeleri görsel önizlemeyle izle, filtrele ve gerektiğinde kaldır.',
    icon: Icons.dynamic_feed_outlined,
    relatedAdminRoute: '/admin/content',
    operations: const [
      'Post, hikaye ve yorum listeleri',
      'Metin, üye ID ve cohort bazlı filtreleme',
      'Avatar ve içerik görseliyle gerçek kart önizlemesi',
      'Post, hikaye ve yorum silme',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Postlar',
        queryKey: 'feed_posts',
        deleteType: 'post',
        icon: Icons.article_outlined,
      ),
      _ModuleDataSectionSpec(
        title: 'Hikayeler',
        queryKey: 'feed_stories',
        deleteType: 'story',
        icon: Icons.auto_stories_outlined,
      ),
      _ModuleDataSectionSpec(
        title: 'Yorumlar',
        queryKey: 'feed_comments',
        deleteType: 'comment',
        icon: Icons.mode_comment_outlined,
      ),
    ],
  ),
  'groups': _ModuleSpec(
    key: 'groups',
    title: 'Gruplar yönetimi',
    description:
        'Grup kartlarını kapak görseli ve sahip avatarıyla izle; üye veya cohort kapsamına indir.',
    icon: Icons.groups_outlined,
    relatedAdminRoute: '/admin/content',
    operations: const [
      'Grup listesi ve kapak görseli',
      'Sahip avatarı, kullanıcı adı ve oluşturulma tarihi',
      'Metin, sahip üye ID ve cohort filtreleri',
      'Grup silme',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Gruplar',
        queryKey: 'groups',
        deleteType: 'group',
        icon: Icons.groups_2_outlined,
      ),
    ],
  ),
  'albums': _ModuleSpec(
    key: 'albums',
    title: 'Albümler yönetimi',
    description:
        'Albüm kategori ve fotoğraflarını gerçek görsellerle yönetme ekranı.',
    icon: Icons.photo_library_outlined,
    relatedAdminRoute: '/admin/operations',
    operations: const [
      'Kategori oluşturma, düzenleme ve silme',
      'Fotoğraf onay, taşıma, toplu işlem ve yorum silme',
      'Fotoğraf, yükleyen üye ve cohort filtreleri',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Fotoğraflar',
        queryKey: 'album_photos',
        deleteType: 'album_photo',
        icon: Icons.photo_outlined,
      ),
    ],
  ),
  'events': _ModuleSpec(
    key: 'events',
    title: 'Etkinlikler yönetimi',
    description:
        'Etkinlik içeriklerini, başvuruları ve yayın durumlarını yönetme ekranı.',
    icon: Icons.event_outlined,
    relatedAdminRoute: '/admin/content',
    operations: const ['Onay kuyruğu', 'Yayın/düzenleme', 'Cohort kapsamı'],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Etkinlikler',
        queryKey: 'events',
        deleteType: '',
        approvalType: 'event',
        icon: Icons.event_available_outlined,
      ),
    ],
  ),
  'announcements': _ModuleSpec(
    key: 'announcements',
    title: 'Duyurular yönetimi',
    description:
        'Duyuru oluşturma, onay ve yayın akışlarını tek ekranda yönetme.',
    icon: Icons.campaign_outlined,
    relatedAdminRoute: '/admin/content',
    operations: const [
      'Onay kuyruğu',
      'Yayın/düzenleme',
      'Hedef kitle filtreleri',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Duyurular',
        queryKey: 'announcements',
        deleteType: '',
        approvalType: 'announcement',
        icon: Icons.campaign_outlined,
      ),
    ],
  ),
  'jobs': _ModuleSpec(
    key: 'jobs',
    title: 'İş ilanları yönetimi',
    description:
        'İş ilanları, başvurular ve işveren içeriklerini yönetme ekranı.',
    icon: Icons.work_outline,
    relatedAdminRoute: '/admin/content',
    operations: const ['İlan onayı', 'Başvuru izleme', 'Üye/cohort filtreleri'],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'İş ilanları',
        queryKey: 'jobs',
        deleteType: '',
        approvalType: 'job',
        icon: Icons.work_outline,
      ),
    ],
  ),
  'networking': _ModuleSpec(
    key: 'networking',
    title: 'Ağ yönetimi',
    description:
        'Takip, bağlantı, mesajlaşma ve keşif ilişkilerini izleme ekranı.',
    icon: Icons.hub_outlined,
    relatedAdminRoute: '/admin/api-monitor',
    operations: const [
      'Takip ilişkileri — kim kimi takip ediyor',
      'Bağlantı istekleri — gönderilen/alınan durum takibi',
      'Üye ID ve cohort filtresi',
      'Takip ilişkisi kaldırma',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Takip ilişkileri',
        queryKey: 'follows',
        deleteType: 'follow',
        icon: Icons.people_outline,
      ),
      _ModuleDataSectionSpec(
        title: 'Bağlantı istekleri',
        queryKey: 'connection_requests',
        deleteType: '',
        icon: Icons.handshake_outlined,
      ),
    ],
  ),
  'teachers_network': _ModuleSpec(
    key: 'teachers_network',
    title: 'Öğretmen ağı yönetimi',
    description: 'Öğretmen hesapları ve öğretmen-mezun bağlantılarını yönetme.',
    icon: Icons.school_outlined,
    relatedAdminRoute: '/admin/teacher-network',
    operations: const [
      'Bağlantı onayı',
      'Öğretmen hesabı doğrulama',
      'Avatarlı eşleşme önizlemesi',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Öğretmen-mezun bağlantıları',
        queryKey: 'teacher_network_links',
        deleteType: '',
        workflowType: 'teacher_link',
        icon: Icons.school_outlined,
      ),
    ],
  ),
  'following': _ModuleSpec(
    key: 'following',
    title: 'Takip yönetimi',
    description:
        'Üye takip akışlarını ve takip edilen içerikleri yönetme ekranı.',
    icon: Icons.favorite_border,
    relatedAdminRoute: '/admin/api-monitor',
    operations: const [
      'Tüm takip ilişkileri listesi',
      'Üye ID ve cohort filtresi ile daralt',
      'Takip ilişkisini kaldırma',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Takip ilişkileri',
        queryKey: 'follows',
        deleteType: 'follow',
        icon: Icons.favorite_outlined,
      ),
    ],
  ),
  'messenger': _ModuleSpec(
    key: 'messenger',
    title: 'Mesajlar yönetimi',
    description: 'Özel mesaj ve canlı sohbet moderasyonu.',
    icon: Icons.chat_bubble_outline,
    relatedAdminRoute: '/admin/content',
    operations: const ['Mesaj izleme', 'Sohbet silme', 'Üye/cohort filtreleri'],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Canlı sohbet mesajları',
        queryKey: 'chat_messages',
        deleteType: 'chat_message',
        icon: Icons.forum_outlined,
      ),
      _ModuleDataSectionSpec(
        title: 'Özel mesajlar',
        queryKey: 'direct_messages',
        deleteType: 'direct_message',
        icon: Icons.mark_chat_unread_outlined,
      ),
    ],
  ),
  'notifications': _ModuleSpec(
    key: 'notifications',
    title: 'Bildirimler yönetimi',
    description: 'Toplu bildirim, push dağıtımı ve deney ayarları.',
    icon: Icons.notifications_outlined,
    relatedAdminRoute: '/admin/notifications',
    operations: const [
      'Toplu bildirim',
      'Görsel önizleme',
      'Push teslimat takibi',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Toplu bildirim geçmişi',
        queryKey: 'broadcasts',
        deleteType: '',
        icon: Icons.campaign_outlined,
      ),
    ],
  ),
  'explore': _ModuleSpec(
    key: 'explore',
    title: 'Keşfet yönetimi',
    description: 'Üye keşfi, arama ve görünürlük kurallarını yönetme ekranı.',
    icon: Icons.explore_outlined,
    relatedAdminRoute: '/admin/management',
    operations: const [
      'Üye görünürlüğü',
      'Avatarlı liste',
      'Cohort ve rol filtreleri',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Keşif üye listesi',
        queryKey: 'members',
        deleteType: '',
        icon: Icons.explore_outlined,
      ),
    ],
  ),
  'profile': _ModuleSpec(
    key: 'profile',
    title: 'Profil yönetimi',
    description: 'Üye profilleri, doğrulama, fotoğraf ve hesap güvenliği.',
    icon: Icons.person_outline,
    relatedAdminRoute: '/admin/management',
    operations: const [
      'Profil düzenleme',
      'Avatar önizleme',
      'Doğrulama ve güvenlik',
    ],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Profiller',
        queryKey: 'members',
        deleteType: '',
        icon: Icons.person_search_outlined,
      ),
    ],
  ),
  'requests': _ModuleSpec(
    key: 'requests',
    title: 'Talepler yönetimi',
    description: 'Üyelik, doğrulama ve öğretmen ağı taleplerini yönetme.',
    icon: Icons.pending_actions_outlined,
    relatedAdminRoute: '/admin/requests',
    operations: const ['Talep onayı', 'Kanıt görseli', 'Cohort kapsamı'],
    dataSections: const [
      _ModuleDataSectionSpec(
        title: 'Üye talepleri',
        queryKey: 'member_requests',
        deleteType: '',
        workflowType: 'member_request',
        icon: Icons.pending_actions_outlined,
      ),
      _ModuleDataSectionSpec(
        title: 'Doğrulama talepleri',
        queryKey: 'verification_requests',
        deleteType: '',
        workflowType: 'verification_request',
        icon: Icons.verified_user_outlined,
      ),
    ],
  ),
};

class _ModuleSpec {
  const _ModuleSpec({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.operations,
    this.relatedAdminRoute,
    this.dataSections = const <_ModuleDataSectionSpec>[],
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final List<String> operations;
  final String? relatedAdminRoute;
  final List<_ModuleDataSectionSpec> dataSections;
}

class _ModuleDataSectionSpec {
  const _ModuleDataSectionSpec({
    required this.title,
    required this.queryKey,
    required this.deleteType,
    required this.icon,
    this.approvalType = '',
    this.workflowType = '',
  });

  final String title;
  final String queryKey;
  final String deleteType;
  final IconData icon;
  final String approvalType;
  final String workflowType;
  int get limit => 20;
}
