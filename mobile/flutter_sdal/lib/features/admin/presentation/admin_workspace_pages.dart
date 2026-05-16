import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_app_theme.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../../admin/application/admin_action_controller.dart';
import '../../admin/data/admin_repository.dart';
import 'widgets/admin_mobile_widgets.dart';

String _workspaceTimestamp(BuildContext context, String raw) =>
    raw.isEmpty ? '' : formatSdalTimestamp(context, raw);

class AdminWorkspacePage extends ConsumerWidget {
  const AdminWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final accessState = ref.watch(adminEffectiveAccessProvider);
    final summaryState = ref.watch(adminMobileSummaryProvider);

    if (user == null || !user.hasAdminAccess) {
      return _WorkspaceDeniedPage(
        title: 'Yönetim',
        message: 'Bu çalışma alanı yalnızca admin hesapları için açık.',
      );
    }

    return accessState.when(
      loading: () => const FeatureScaffold(
        title: 'Yönetim',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FeatureScaffold(
        title: 'Yönetim',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AdminEmptyState(
              icon: Icons.lock_outline,
              title: 'Yönetim izni doğrulanamadı',
              message: error.toString(),
            ),
          ),
        ),
      ),
      data: (access) {
        return FeatureScaffold(
          title: 'Yönetim',
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: () {
                ref.invalidate(adminEffectiveAccessProvider);
                ref.invalidate(adminMobileSummaryProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Admin oturumunu kapat',
              onPressed: () => _handleAdminLogout(context, ref),
              icon: const Icon(Icons.logout),
            ),
          ],
          background: FeatureScaffoldBackground.utility,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              _AdminCommandHeader(access: access),
              const SizedBox(height: 16),
              summaryState.when(
                loading: () => const _CommandCenterSkeleton(),
                error: (error, _) => AdminEmptyState(
                  icon: Icons.error_outline,
                  title: 'Özet alınamadı',
                  message: error.toString(),
                ),
                data: (summary) => _AdminCommandCenterBody(
                  access: access,
                  summary: summary,
                  isRootAdmin: user.isRootAdmin,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminCommandHeader extends StatelessWidget {
  const _AdminCommandHeader({required this.access});

  final AdminEffectiveAccessSnapshot access;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.accentMuted,
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                ),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Komuta Merkezi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${access.user.name} · ${_roleLabel(access.user.role)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminStatusChip(
                label: '${access.modules.length} modül',
                tone: AdminTone.accent,
              ),
              if (access.permissions.contains('audit.view'))
                const AdminStatusChip(label: 'Denetim açık'),
              if (access.assignableRoles.isNotEmpty)
                AdminStatusChip(
                  label: 'Rol: ${access.assignableRoles.join(', ')}',
                  tone: AdminTone.success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminCommandCenterBody extends StatelessWidget {
  const _AdminCommandCenterBody({
    required this.access,
    required this.summary,
    required this.isRootAdmin,
  });

  final AdminEffectiveAccessSnapshot access;
  final AdminMobileSummarySnapshot summary;
  final bool isRootAdmin;

  @override
  Widget build(BuildContext context) {
    final counts = summary.counts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuickStatsStrip(
          stats: [
            (
              icon: Icons.pending_actions_outlined,
              label: 'Dikkat',
              value:
                  '${summary.attention.fold<int>(0, (sum, item) => sum + item.count)}',
              tone: summary.attention.isEmpty
                  ? _WorkspaceTone.success
                  : _WorkspaceTone.warning,
            ),
            (
              icon: Icons.groups_outlined,
              label: 'Üye',
              value: '${counts['users'] ?? 0}',
              tone: _WorkspaceTone.info,
            ),
            (
              icon: Icons.block_outlined,
              label: 'Askıda',
              value: '${counts['suspendedUsers'] ?? 0}',
              tone: (counts['suspendedUsers'] ?? 0) > 0
                  ? _WorkspaceTone.danger
                  : _WorkspaceTone.success,
            ),
          ],
        ),
        const _SectionLabel('İlgilenilmesi gerekenler'),
        if (summary.attention.isEmpty)
          const AdminEmptyState(
            icon: Icons.task_alt_outlined,
            title: 'Kuyruk sakin',
            message: 'Şu anda acil işlem gerektiren bir yönetim işi yok.',
          )
        else
          for (final item in summary.attention)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminAttentionCard(
                label: item.label,
                count: item.count,
                tone: adminToneFromString(item.tone),
                onTap: () => context.go(item.path),
              ),
            ),
        const _SectionLabel('Görev alanları'),
        for (final module in access.modules.where((item) => item.key != 'home'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AdminSectionCard(
              title: module.label,
              subtitle: _moduleSubtitle(module.key),
              icon: _moduleIcon(module.key),
              badge: _moduleBadge(module.key, counts),
              tone: _moduleTone(module.key),
              onTap: () => context.go(module.path),
            ),
          ),
        if (isRootAdmin) ...[
          const _SectionLabel('Root araçları'),
          AdminSectionCard(
            title: 'Root kontrol merkezi',
            subtitle:
                'Üye aktivite izleme ve yalnızca root yetkisine açık işlemler.',
            icon: Icons.shield_outlined,
            tone: AdminTone.accent,
            onTap: () => context.go('/admin/root'),
          ),
          const SizedBox(height: 10),
          AdminSectionCard(
            title: 'İzin grupları',
            subtitle: 'Rol ve özel izin setlerini düzenle.',
            icon: Icons.admin_panel_settings_outlined,
            tone: AdminTone.accent,
            onTap: () => context.go('/admin/permission-groups'),
          ),
          const SizedBox(height: 10),
          AdminSectionCard(
            title: 'Factory reset',
            subtitle:
                'Yüksek riskli sıfırlama akışı, ayrı doğrulama gerektirir.',
            icon: Icons.delete_forever_outlined,
            tone: AdminTone.danger,
            onTap: () => context.go('/admin/factory-reset'),
          ),
        ],
        if (summary.recentAudit.isNotEmpty) ...[
          const _SectionLabel('Son denetim kayıtları'),
          SurfaceCard(
            child: Column(
              children: [
                for (final item in summary.recentAudit.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AuditPreviewRow(item: item),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/admin/audit'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Denetim kaydını aç'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AuditPreviewRow extends StatelessWidget {
  const _AuditPreviewRow({required this.item});

  final AdminAuditLogItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.history, color: tokens.foregroundMuted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _auditActionLabel(item.action),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.actorLabel} · ${_workspaceTimestamp(context, item.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommandCenterSkeleton extends StatelessWidget {
  const _CommandCenterSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 12),
        LinearProgressIndicator(),
        SizedBox(height: 18),
      ],
    );
  }
}

String _roleLabel(String role) {
  return switch (role.trim().toLowerCase()) {
    'root' => 'Süper admin',
    'admin' => 'Admin',
    'mod' => 'Moderatör',
    _ => 'Üye',
  };
}

String _moduleSubtitle(String key) {
  return switch (key) {
    'users' =>
      'Üye ara, durumları incele, rol ve askıya alma işlemlerini güvenle yönet.',
    'moderation' =>
      'Talepler, doğrulamalar ve topluluk içerikleri için odaklı kuyruk.',
    'notifications' => 'Push durumu, toplu bildirimler ve teslimat sorunları.',
    'audit' => 'Hassas yönetim aksiyonlarını kim, ne zaman, neden yaptı.',
    'settings' =>
      'Site açıklığı, modül görünürlüğü ve pratik yönetim ayarları.',
    _ => 'Yetkine göre açılan hızlı yönetim alanı.',
  };
}

IconData _moduleIcon(String key) {
  return switch (key) {
    'users' => Icons.manage_accounts_outlined,
    'moderation' => Icons.shield_outlined,
    'notifications' => Icons.notifications_active_outlined,
    'audit' => Icons.receipt_long_outlined,
    'settings' => Icons.tune_outlined,
    _ => Icons.dashboard_customize_outlined,
  };
}

AdminTone _moduleTone(String key) {
  return switch (key) {
    'moderation' => AdminTone.warning,
    'notifications' => AdminTone.info,
    'audit' => AdminTone.accent,
    'settings' => AdminTone.success,
    _ => AdminTone.info,
  };
}

String? _moduleBadge(String key, Map<String, int> counts) {
  return switch (key) {
    'users' => '${counts['users'] ?? 0}',
    'moderation' =>
      '${(counts['requests'] ?? 0) + (counts['verificationRequests'] ?? 0)}',
    'audit' => 'log',
    _ => null,
  };
}

String _auditActionLabel(String action) {
  return switch (action) {
    'user_role_changed' => 'Rol değiştirildi',
    'user_suspended' => 'Üye askıya alındı',
    'user_unsuspended' => 'Üye askıdan çıkarıldı',
    'content_review' => 'İçerik incelendi',
    'moderator_permissions_updated' => 'Moderatör yetkisi güncellendi',
    _ => action.replaceAll('_', ' '),
  };
}

class AdminAuditLogPage extends ConsumerWidget {
  const AdminAuditLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditState = ref.watch(adminAuditLogProvider);
    return FeatureScaffold(
      title: 'Denetim kaydı',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () => ref.invalidate(adminAuditLogProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      background: FeatureScaffoldBackground.utility,
      child: auditState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AdminEmptyState(
              icon: Icons.lock_outline,
              title: 'Denetim kaydı açılamadı',
              message: error.toString(),
            ),
          ),
        ),
        data: (snapshot) {
          if (snapshot.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: AdminEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Kayıt yok',
                  message: 'Filtreye uygun yönetim kaydı bulunamadı.',
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: snapshot.items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return SurfaceCard(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${snapshot.total} kayıt · sayfa ${snapshot.page}/${snapshot.pages}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final item = snapshot.items[index - 1];
              return _AuditLogCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.item});

  final AdminAuditLogItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final reason = item.metadata['reason']?.toString().trim() ?? '';
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _auditActionLabel(item.action),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AdminStatusChip(
                label: item.targetType.isEmpty ? 'sistem' : item.targetType,
                tone: AdminTone.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${item.actorLabel} · ${_workspaceTimestamp(context, item.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          if (item.targetId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Hedef: ${item.targetId}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.panelMuted,
                borderRadius: BorderRadius.circular(tokens.cardRadius * .7),
              ),
              child: Text(
                reason,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ModeratorWorkspacePage extends ConsumerWidget {
  const ModeratorWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final accessState = ref.watch(adminAccessProvider);

    if (user == null || (!user.isModerator && !user.hasAdminAccess)) {
      return _WorkspaceDeniedPage(
        title: 'Moderasyon',
        message: 'Bu alan yalnızca moderatör ve admin hesapları için açık.',
      );
    }

    return accessState.when(
      loading: () => const FeatureScaffold(
        title: 'Moderasyon',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FeatureScaffold(
        title: 'Moderasyon',
        child: Center(child: Text(error.toString())),
      ),
      data: (access) {
        final permissions = access.permissions;
        final actionState = ref.watch(adminActionControllerProvider);
        final permissionKeys =
            permissions?.permissionKeys.toSet() ?? const <String>{};
        final scopedYears =
            permissions?.scopedGraduationYears ?? const <String>[];
        final canReviewRequests = _hasAnyPermission(permissions, const [
          'requests.view',
          'requests.moderate',
        ]);
        final canReviewVerification = _hasAnyPermission(permissions, const [
          'requests.view',
          'requests.moderate',
        ]);
        final canViewPosts = _hasAnyPermission(permissions, const [
          'posts.view',
          'posts.delete',
        ]);
        final canViewComments = _hasAnyPermission(permissions, const [
          'posts.view',
          'posts.delete',
        ]);
        final canViewStories = _hasAnyPermission(permissions, const [
          'stories.view',
          'stories.delete',
        ]);
        final requestPreviewState = canReviewRequests
            ? ref.watch(adminMemberRequestPreviewProvider)
            : const AsyncValue.data(
                AdminPreviewList<AdminRequestQueueItem>(
                  total: 0,
                  items: <AdminRequestQueueItem>[],
                ),
              );
        final verificationPreviewState = canReviewVerification
            ? ref.watch(adminVerificationRequestPreviewProvider)
            : const AsyncValue.data(
                AdminPreviewList<AdminVerificationQueueItem>(
                  total: 0,
                  items: <AdminVerificationQueueItem>[],
                ),
              );
        final teacherNetworkLinkPreviewState = canReviewRequests
            ? ref.watch(adminTeacherNetworkLinkPreviewProvider)
            : const AsyncValue.data(
                AdminPreviewList<AdminTeacherNetworkLinkItem>(
                  total: 0,
                  items: <AdminTeacherNetworkLinkItem>[],
                ),
              );
        final postPreviewState = canViewPosts
            ? ref.watch(adminPostPreviewProvider)
            : const AsyncValue.data(
                AdminPreviewList<AdminModerationItem>(
                  total: 0,
                  items: <AdminModerationItem>[],
                ),
              );
        final commentPreviewState = canViewComments
            ? ref.watch(adminCommentPreviewProvider)
            : const AsyncValue.data(
                AdminPreviewList<AdminModerationItem>(
                  total: 0,
                  items: <AdminModerationItem>[],
                ),
              );
        final storyPreviewState = canViewStories
            ? ref.watch(adminStoryPreviewProvider)
            : const AsyncValue.data(
                AdminPreviewList<AdminModerationItem>(
                  total: 0,
                  items: <AdminModerationItem>[],
                ),
              );

        final requestTotal = requestPreviewState.asData?.value.total ?? 0;
        final verificationTotal =
            verificationPreviewState.asData?.value.total ?? 0;
        final teacherNetworkLinkTotal =
            teacherNetworkLinkPreviewState.asData?.value.total ?? 0;
        final contentTotal =
            (postPreviewState.asData?.value.total ?? 0) +
            (commentPreviewState.asData?.value.total ?? 0) +
            (storyPreviewState.asData?.value.total ?? 0);

        return FeatureScaffold(
          title: 'Moderasyon',
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: () {
                ref.invalidate(adminAccessProvider);
                ref.invalidate(adminMemberRequestPreviewProvider);
                ref.invalidate(adminVerificationRequestPreviewProvider);
                ref.invalidate(adminTeacherNetworkLinkPreviewProvider);
                ref.invalidate(adminPostPreviewProvider);
                ref.invalidate(adminCommentPreviewProvider);
                ref.invalidate(adminStoryPreviewProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
          background: FeatureScaffoldBackground.utility,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ModeratorStatusCard(
                scopedYears: scopedYears,
                requestTotal: requestTotal,
                verificationTotal: verificationTotal,
                teacherNetworkLinkTotal: teacherNetworkLinkTotal,
                contentTotal: contentTotal,
              ),
              const SizedBox(height: 16),
              if (permissionKeys.isEmpty)
                SurfaceCard(
                  child: Text(
                    'Bu hesapta aktif moderasyon yetkisi yok. Admin, önce izin anahtarlarını sonra cohort kapsamlarını atamalı.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    if (canReviewRequests)
                      _WorkspaceNavCard(
                        title: 'Talep kuyruğu',
                        summary:
                            'Üyelik ve mezuniyet yılı değişikliği taleplerini hızlı işleyin.',
                        countLabel: '$requestTotal bekleyen kayıt',
                        icon: Icons.assignment_turned_in_outlined,
                        tone: _WorkspaceTone.success,
                        onTap: () => context.go('/admin/requests'),
                      ),
                    if (canReviewVerification)
                      _WorkspaceNavCard(
                        title: 'Doğrulama kuyruğu',
                        summary:
                            'Cohort kapsamındaki profil doğrulama başvurularını inceleyin.',
                        countLabel: '$verificationTotal bekleyen kayıt',
                        icon: Icons.badge_outlined,
                        tone: _WorkspaceTone.info,
                        onTap: () => context.go('/admin/requests'),
                      ),
                    if (canReviewRequests)
                      _WorkspaceNavCard(
                        title: 'Öğretmen ağı',
                        summary:
                            'Mezunların eklediği öğretmen bağlantılarını onaylayın veya reddedin.',
                        countLabel:
                            '$teacherNetworkLinkTotal bekleyen bağlantı',
                        icon: Icons.school_outlined,
                        tone: _WorkspaceTone.info,
                        onTap: () => context.go('/admin/teacher-network'),
                      ),
                    if (user.hasAdminAccess)
                      _WorkspaceNavCard(
                        title: 'Öğretmen hesapları',
                        summary:
                            'Öğretmen olarak kayıtlı hesapları görüntüleyin ve doğrulama durumlarını yönetin.',
                        countLabel: 'Hesap listesi',
                        icon: Icons.manage_accounts_outlined,
                        tone: _WorkspaceTone.accent,
                        onTap: () => context.go('/admin/teacher-accounts'),
                      ),
                    if (contentTotal > 0)
                      _WorkspaceNavCard(
                        title: 'İçerik inceleme',
                        summary:
                            'Post, yorum ve hikâye temizliği için hızlı silme akışlarını aç.',
                        countLabel: '$contentTotal kayıt sırada',
                        icon: Icons.shield_outlined,
                        tone: _WorkspaceTone.warning,
                        onTap: () => context.go('/admin/content'),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              if (canReviewRequests)
                _AsyncSurfaceCard<AdminPreviewList<AdminRequestQueueItem>>(
                  title: 'Bekleyen üye talepleri',
                  asyncValue: requestPreviewState,
                  builder: (preview) => _RequestPreviewList(
                    items: preview.items,
                    emptyMessage:
                        'Senin cohort kapsamında bekleyen üye talebi yok.',
                    onApprove: (item) => _reviewMemberRequest(
                      context,
                      ref,
                      item: item,
                      id: item.id,
                      approve: true,
                    ),
                    onReject: (item) => _reviewMemberRequest(
                      context,
                      ref,
                      item: item,
                      id: item.id,
                      approve: false,
                    ),
                    canModerate: _hasAnyPermission(permissions, const [
                      'requests.moderate',
                    ]),
                    isBusy: actionState.isLoading,
                  ),
                ),
              if (canReviewRequests) const SizedBox(height: 16),
              if (canReviewVerification)
                _AsyncSurfaceCard<AdminPreviewList<AdminVerificationQueueItem>>(
                  title: 'Bekleyen profil doğrulamaları',
                  asyncValue: verificationPreviewState,
                  builder: (preview) => _VerificationPreviewList(
                    items: preview.items,
                    emptyMessage:
                        'Senin cohort kapsamında bekleyen doğrulama yok.',
                    onApprove: (item) => _reviewVerificationRequest(
                      context,
                      ref,
                      id: item.id,
                      approve: true,
                    ),
                    onReject: (item) => _reviewVerificationRequest(
                      context,
                      ref,
                      id: item.id,
                      approve: false,
                    ),
                    canModerate: _hasAnyPermission(permissions, const [
                      'requests.moderate',
                    ]),
                    isBusy: actionState.isLoading,
                  ),
                ),
              if (canReviewVerification) const SizedBox(height: 16),
              if (canReviewRequests)
                _AsyncSurfaceCard<
                  AdminPreviewList<AdminTeacherNetworkLinkItem>
                >(
                  title: 'Bekleyen öğretmen ağı bağlantıları',
                  asyncValue: teacherNetworkLinkPreviewState,
                  builder: (preview) => _TeacherNetworkPreviewList(
                    items: preview.items,
                    emptyMessage:
                        'Senin cohort kapsamında bekleyen öğretmen bağlantısı yok.',
                    onConfirm: (item) => _reviewTeacherNetworkLink(
                      context,
                      ref,
                      id: item.id,
                      status: 'confirmed',
                    ),
                    onFlag: (item) => _reviewTeacherNetworkLink(
                      context,
                      ref,
                      id: item.id,
                      status: 'flagged',
                    ),
                    onReject: (item) => _reviewTeacherNetworkLink(
                      context,
                      ref,
                      id: item.id,
                      status: 'rejected',
                    ),
                    canModerate: _hasAnyPermission(permissions, const [
                      'requests.moderate',
                    ]),
                    isBusy: actionState.isLoading,
                  ),
                ),
              if (canReviewRequests) const SizedBox(height: 16),
              if (contentTotal > 0)
                _ContentModerationCard(
                  postPreviewState: postPreviewState,
                  commentPreviewState: commentPreviewState,
                  storyPreviewState: storyPreviewState,
                  canDeletePosts: _hasAnyPermission(permissions, const [
                    'posts.delete',
                  ]),
                  canDeleteStories: _hasAnyPermission(permissions, const [
                    'stories.delete',
                  ]),
                  onDelete: (type, id) =>
                      _deleteContent(context, ref, type: type, id: id),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Teacher Accounts Management ───────────────────────────────────────────

class AdminTeacherAccountsPage extends ConsumerStatefulWidget {
  const AdminTeacherAccountsPage({super.key});

  @override
  ConsumerState<AdminTeacherAccountsPage> createState() =>
      _AdminTeacherAccountsPageState();
}

class _AdminTeacherAccountsPageState
    extends ConsumerState<AdminTeacherAccountsPage> {
  final _searchController = TextEditingController();
  String _status = '';

  AdminTeacherAccountsQuery get _query => AdminTeacherAccountsQuery(
    q: _searchController.text.trim(),
    status: _status,
    limit: 50,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;

    if (user == null || !user.hasAdminAccess) {
      return const _WorkspaceDeniedPage(
        title: 'Öğretmen Hesapları',
        message: 'Bu alan yalnızca admin hesapları için açık.',
      );
    }

    final accountsState = ref.watch(adminTeacherAccountsProvider(_query));
    final actionState = ref.watch(adminActionControllerProvider);

    return FeatureScaffold(
      title: 'Öğretmen Hesapları',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(adminTeacherAccountsProvider),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Ad, kullanıcı adı veya branş ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, value) in [
                        ('Tümü', ''),
                        ('Bekleyen', 'pending'),
                        ('Doğrulandı', 'verified'),
                        ('Reddedildi', 'rejected'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _status == value,
                            onSelected: (_) => setState(() => _status = value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: accountsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (list) {
                if (list.items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Kayıt bulunamadı.\nÖğretmen olarak kayıtlı ve aktif üye yok.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: list.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = list.items[i];
                    return SurfaceCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            item.name.isNotEmpty
                                ? item.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${item.handle}'),
                            if (item.subject.isNotEmpty)
                              Text(
                                item.subject,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _VerificationStatusChip(
                              status: item.verificationStatus,
                            ),
                            if (!item.isVerified)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(60, 24),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: actionState.isLoading
                                    ? null
                                    : () => ref
                                          .read(
                                            adminActionControllerProvider
                                                .notifier,
                                          )
                                          .verifyUserManually(userId: item.id)
                                          .then((_) {
                                            ref.invalidate(
                                              adminTeacherAccountsProvider,
                                            );
                                          }),
                                child: const Text(
                                  'Onayla',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: item.subject.isNotEmpty,
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
}

class _VerificationStatusChip extends StatelessWidget {
  const _VerificationStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'verified' => ('Doğrulandı', Colors.green),
      'rejected' => ('Reddedildi', Colors.red),
      _ => ('Bekliyor', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────

class AdminTeacherNetworkManagementPage extends ConsumerStatefulWidget {
  const AdminTeacherNetworkManagementPage({super.key});

  @override
  ConsumerState<AdminTeacherNetworkManagementPage> createState() =>
      _AdminTeacherNetworkManagementPageState();
}

class _AdminTeacherNetworkManagementPageState
    extends ConsumerState<AdminTeacherNetworkManagementPage> {
  final _searchController = TextEditingController();
  String _status = 'pending';
  String _relationshipType = '';

  AdminTeacherNetworkLinksQuery get _query => AdminTeacherNetworkLinksQuery(
    status: _status,
    relationshipType: _relationshipType,
    query: _searchController.text.trim(),
    limit: 100,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final accessState = ref.watch(adminAccessProvider);
    final actionState = ref.watch(adminActionControllerProvider);

    if (user == null || !user.hasAdminAccess) {
      return _WorkspaceDeniedPage(
        title: 'Öğretmen ağı',
        message: 'Bu alan yalnızca admin hesapları için açık.',
      );
    }

    return accessState.when(
      loading: () => const FeatureScaffold(
        title: 'Öğretmen ağı',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FeatureScaffold(
        title: 'Öğretmen ağı',
        child: Center(child: Text(error.toString())),
      ),
      data: (access) {
        final permissions = access.permissions;
        final isFullAdmin =
            access.user?.hasAdminAccess == true || access.adminOk;
        final canView =
            isFullAdmin ||
            _hasAnyPermission(permissions, const [
              'requests.view',
              'requests.moderate',
            ]);
        final canModerate =
            isFullAdmin ||
            _hasAnyPermission(permissions, const ['requests.moderate']);
        final linksState = canView
            ? ref.watch(adminTeacherNetworkLinksProvider(_query))
            : const AsyncValue.data(
                AdminPreviewList<AdminTeacherNetworkLinkItem>(
                  total: 0,
                  items: <AdminTeacherNetworkLinkItem>[],
                ),
              );

        return FeatureScaffold(
          title: 'Öğretmen ağı yönetimi',
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: () {
                ref.invalidate(adminTeacherNetworkLinksProvider);
                ref.invalidate(adminTeacherNetworkLinkPreviewProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
          background: FeatureScaffoldBackground.utility,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _WorkspaceHeroCard(
                eyebrow: 'Güven ve bağlantı moderasyonu',
                title: 'Öğretmen bağlantılarını ayrı kuyrukta yönet',
                description:
                    'Mezunların eklediği öğretmen ilişkileri önce bekleyen durumda kalır. Admin onayı güven sinyalini güçlendirir; şüpheli kayıtlar işaretlenebilir veya reddedilebilir.',
                badges: [
                  _HeroBadge(
                    icon: Icons.pending_actions_outlined,
                    label: 'Bekleyen, onaylı ve işaretli kayıtlar',
                  ),
                  _HeroBadge(
                    icon: Icons.school_outlined,
                    label: 'Öğretmen-mezun ilişki bağı',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!canView)
                const SurfaceCard(
                  child: Text(
                    'Bu kuyruğu görmek için requests.view veya requests.moderate izni gerekir.',
                  ),
                )
              else ...[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtreler',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Öğretmen veya mezun ara',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Durum',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Bekleyen'),
                                ),
                                DropdownMenuItem(
                                  value: 'confirmed',
                                  child: Text('Onaylı'),
                                ),
                                DropdownMenuItem(
                                  value: 'flagged',
                                  child: Text('İşaretli'),
                                ),
                                DropdownMenuItem(
                                  value: 'rejected',
                                  child: Text('Reddedilen'),
                                ),
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Tümü'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _status = value ?? 'pending'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _relationshipType,
                              decoration: const InputDecoration(
                                labelText: 'İlişki',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Tümü'),
                                ),
                                DropdownMenuItem(
                                  value: 'taught_in_class',
                                  child: Text('Dersine girdi'),
                                ),
                                DropdownMenuItem(
                                  value: 'advisor',
                                  child: Text('Danışman'),
                                ),
                                DropdownMenuItem(
                                  value: 'mentor',
                                  child: Text('Mentor'),
                                ),
                                DropdownMenuItem(
                                  value: 'club_coach',
                                  child: Text('Kulüp/ekip'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _relationshipType = value ?? '',
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.tune_outlined),
                            label: const Text('Uygula'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AsyncSurfaceCard<
                  AdminPreviewList<AdminTeacherNetworkLinkItem>
                >(
                  title: 'Öğretmen bağlantıları',
                  asyncValue: linksState,
                  builder: (preview) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${preview.total} kayıt'),
                      const SizedBox(height: 12),
                      _TeacherNetworkPreviewList(
                        items: preview.items,
                        emptyMessage: 'Bu filtrelerde öğretmen bağlantısı yok.',
                        onConfirm: (item) => _reviewTeacherNetworkLink(
                          context,
                          ref,
                          id: item.id,
                          status: 'confirmed',
                        ),
                        onFlag: (item) => _reviewTeacherNetworkLink(
                          context,
                          ref,
                          id: item.id,
                          status: 'flagged',
                        ),
                        onReject: (item) => _reviewTeacherNetworkLink(
                          context,
                          ref,
                          id: item.id,
                          status: 'rejected',
                        ),
                        canModerate: canModerate,
                        isBusy: actionState.isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AdminModuleManagementPage extends ConsumerWidget {
  const AdminModuleManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final controlsState = ref.watch(adminSiteControlsProvider);

    if (user == null || !user.hasAdminAccess) {
      return _WorkspaceDeniedPage(
        title: 'Modül yönetimi',
        message: 'Bu alan yalnızca admin hesapları için açık.',
      );
    }

    return FeatureScaffold(
      title: 'Modül yönetimi',
      actions: [
        IconButton(
          tooltip: 'Yönetim ana sayfasına dön',
          onPressed: () => context.go('/admin'),
          icon: const Icon(Icons.dashboard_outlined),
        ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: () => ref.invalidate(adminSiteControlsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      background: FeatureScaffoldBackground.utility,
      child: controlsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (controls) {
          final modules = controls.modules.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _WorkspaceHeroCard(
                eyebrow: 'Kontrol merkezi',
                title: 'Site ve modül erişimini sade şekilde yönet',
                description:
                    'Her değişiklik anında kaydedilir. “Açık” kullanıcı erişimini, “Menüde görünür” ise gezinme görünürlüğünü kontrol eder.',
                badges: [
                  _HeroBadge(
                    icon: Icons.public_outlined,
                    label: controls.siteOpen ? 'Site açık' : 'Site kapalı',
                  ),
                  _HeroBadge(
                    icon: Icons.grid_view_outlined,
                    label:
                        '${controls.openModuleCount}/${controls.totalModuleCount} modül açık',
                  ),
                  _HeroBadge(
                    icon: Icons.login_outlined,
                    label: controls.defaultLandingPage.isEmpty
                        ? '/new/feed'
                        : controls.defaultLandingPage,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Genel yayın durumu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: controls.siteOpen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Site açık'),
                      subtitle: const Text(
                        'Kapattığında tüm kullanıcılar bakım ekranına yönlenir.',
                      ),
                      onChanged: (value) => _saveSiteControls(
                        context,
                        ref,
                        controls,
                        siteOpen: value,
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bakım mesajı'),
                      subtitle: Text(
                        controls.maintenanceMessage.isEmpty
                            ? 'Mesaj tanımlı değil'
                            : controls.maintenanceMessage,
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () =>
                          _editMaintenanceMessage(context, ref, controls),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Varsayılan giriş',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                            '/new/feed',
                            '/new/explore',
                            '/new/notifications',
                            '/new/profile',
                            '/new/messages',
                            '/new/requests',
                          ].map((route) {
                            final selected =
                                controls.defaultLandingPage == route;
                            return ChoiceChip(
                              label: Text(route),
                              selected: selected,
                              onSelected: (value) {
                                if (!value) return;
                                _saveSiteControls(
                                  context,
                                  ref,
                                  controls,
                                  defaultLandingPage: route,
                                );
                              },
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _AppThemePickerCard(controls: controls),
              const SizedBox(height: 16),
              for (final module in modules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _humanizeModuleKey(module.key),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          module.key,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).sdal.foregroundMuted,
                              ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: module.value,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Kullanıcı erişimi açık'),
                          onChanged: (value) {
                            final nextModules = {...controls.modules};
                            nextModules[module.key] = value;
                            _saveSiteControls(
                              context,
                              ref,
                              controls,
                              modules: nextModules,
                            );
                          },
                        ),
                        SwitchListTile.adaptive(
                          value: controls.menuVisibility[module.key] ?? true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Menüde görünür'),
                          onChanged: (value) {
                            final nextVisibility = {...controls.menuVisibility};
                            nextVisibility[module.key] = value;
                            _saveSiteControls(
                              context,
                              ref,
                              controls,
                              menuVisibility: nextVisibility,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceDeniedPage extends StatelessWidget {
  const _WorkspaceDeniedPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/feed'),
                  child: const Text('Akışa dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeroCard extends StatelessWidget {
  const _WorkspaceHeroCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.badges,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<_HeroBadge> badges;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Card(
      color: tokens.panelRaised,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.foregroundMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: badges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.panel,
                        borderRadius: BorderRadius.circular(
                          SdalThemeTokens.radiusLg,
                        ),
                        border: Border.all(color: tokens.panelBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badge.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(badge.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBadge {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

enum _WorkspaceTone { info, success, warning, danger, accent }

class _WorkspaceNavCard extends StatelessWidget {
  const _WorkspaceNavCard({
    required this.title,
    required this.summary,
    required this.countLabel,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String summary;
  final String countLabel;
  final IconData icon;
  final _WorkspaceTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final color = switch (tone) {
      _WorkspaceTone.info => tokens.info,
      _WorkspaceTone.success => tokens.success,
      _WorkspaceTone.warning => tokens.warning,
      _WorkspaceTone.danger => tokens.danger,
      _WorkspaceTone.accent => tokens.accent,
    };
    final muted = switch (tone) {
      _WorkspaceTone.info => tokens.infoMuted,
      _WorkspaceTone.success => tokens.successMuted,
      _WorkspaceTone.warning => tokens.warningMuted,
      _WorkspaceTone.danger => tokens.dangerMuted,
      _WorkspaceTone.accent => tokens.accentMuted,
    };

    return SizedBox(
      width: 330,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: muted,
                        borderRadius: BorderRadius.circular(
                          SdalThemeTokens.radiusMd,
                        ),
                      ),
                      child: Icon(icon, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).sdal.foregroundMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        countLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AsyncSurfaceCard<T> extends StatelessWidget {
  const _AsyncSurfaceCard({
    required this.title,
    required this.asyncValue,
    required this.builder,
  });

  final String title;
  final AsyncValue<T> asyncValue;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          asyncValue.when(
            data: builder,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip({required this.stats});

  final List<({IconData icon, String label, String value, _WorkspaceTone tone})>
  stats;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: tokens.panelBorder),
              Expanded(child: _StatCell(stat: stats[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final ({IconData icon, String label, String value, _WorkspaceTone tone}) stat;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final color = switch (stat.tone) {
      _WorkspaceTone.info => tokens.info,
      _WorkspaceTone.success => tokens.success,
      _WorkspaceTone.warning => tokens.warning,
      _WorkspaceTone.danger => tokens.danger,
      _WorkspaceTone.accent => tokens.accent,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            stat.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tokens.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.foregroundMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ModeratorStatusCard extends StatelessWidget {
  const _ModeratorStatusCard({
    required this.scopedYears,
    required this.requestTotal,
    required this.verificationTotal,
    required this.teacherNetworkLinkTotal,
    required this.contentTotal,
  });

  final List<String> scopedYears;
  final int requestTotal;
  final int verificationTotal;
  final int teacherNetworkLinkTotal;
  final int contentTotal;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final totalPending =
        requestTotal + verificationTotal + teacherNetworkLinkTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: tokens.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Moderasyon kapsamı',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (totalPending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.warningMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$totalPending bekleyen',
                      style: TextStyle(
                        color: tokens.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (scopedYears.isEmpty)
              Text(
                'Cohort ataması yok — admin kapsamını tanımlamalı',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: scopedYears
                    .map(
                      (y) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accentMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          y,
                          style: TextStyle(
                            color: tokens.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusPill(
                  label: 'Talep',
                  count: requestTotal,
                  color: tokens.warning,
                  muted: tokens.warningMuted,
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Doğrulama',
                  count: verificationTotal,
                  color: tokens.info,
                  muted: tokens.infoMuted,
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'İçerik',
                  count: contentTotal,
                  color: tokens.danger,
                  muted: tokens.dangerMuted,
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Öğretmen',
                  count: teacherNetworkLinkTotal,
                  color: tokens.info,
                  muted: tokens.infoMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
    required this.muted,
  });

  final String label;
  final int count;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final panel = Theme.of(context).sdal.panel;
    final fgMuted = Theme.of(context).sdal.foregroundMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: count > 0 ? muted : panel,
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: count > 0 ? color : fgMuted,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: fgMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestPreviewList extends StatelessWidget {
  const _RequestPreviewList({
    required this.items,
    required this.emptyMessage,
    required this.onApprove,
    required this.onReject,
    required this.canModerate,
    required this.isBusy,
  });

  final List<AdminRequestQueueItem> items;
  final String emptyMessage;
  final ValueChanged<AdminRequestQueueItem> onApprove;
  final ValueChanged<AdminRequestQueueItem> onReject;
  final bool canModerate;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text(emptyMessage);
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QueueItemCard(
                title: item.categoryLabel,
                subtitle: [
                  item.requesterName,
                  '@${item.requesterHandle}',
                  if (item.requestedGraduationYear.isNotEmpty)
                    'İstenen yıl: ${_formatGraduationYear(item.requestedGraduationYear)}',
                  _workspaceTimestamp(context, item.createdAt),
                ].where((part) => part.trim().isNotEmpty).join(' · '),
                status: item.status,
                canModerate: canModerate,
                onApprove: isBusy ? null : () => onApprove(item),
                onReject: isBusy ? null : () => onReject(item),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _VerificationPreviewList extends StatelessWidget {
  const _VerificationPreviewList({
    required this.items,
    required this.emptyMessage,
    required this.onApprove,
    required this.onReject,
    required this.canModerate,
    required this.isBusy,
  });

  final List<AdminVerificationQueueItem> items;
  final String emptyMessage;
  final ValueChanged<AdminVerificationQueueItem> onApprove;
  final ValueChanged<AdminVerificationQueueItem> onReject;
  final bool canModerate;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text(emptyMessage);
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QueueItemCard(
                title: item.requesterName,
                subtitle: [
                  '@${item.requesterHandle}',
                  item.isTeacherVerification
                      ? 'Öğretmen doğrulaması'
                      : 'Üye doğrulaması',
                  _formatGraduationYear(item.graduationYear),
                  item.hasProof ? 'Kanıt var' : 'Kanıt yok',
                  _workspaceTimestamp(context, item.createdAt),
                ].where((part) => part.trim().isNotEmpty).join(' · '),
                status: item.status,
                canModerate: canModerate,
                onApprove: isBusy ? null : () => onApprove(item),
                onReject: isBusy ? null : () => onReject(item),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TeacherNetworkPreviewList extends StatelessWidget {
  const _TeacherNetworkPreviewList({
    required this.items,
    required this.emptyMessage,
    required this.onConfirm,
    required this.onFlag,
    required this.onReject,
    required this.canModerate,
    required this.isBusy,
  });

  final List<AdminTeacherNetworkLinkItem> items;
  final String emptyMessage;
  final ValueChanged<AdminTeacherNetworkLinkItem> onConfirm;
  final ValueChanged<AdminTeacherNetworkLinkItem> onFlag;
  final ValueChanged<AdminTeacherNetworkLinkItem> onReject;
  final bool canModerate;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text(emptyMessage);
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QueueItemCard(
                title:
                    '${item.alumniHandle.isNotEmpty ? '@${item.alumniHandle}' : item.alumniName} -> ${item.teacherHandle.isNotEmpty ? '@${item.teacherHandle}' : item.teacherName}',
                subtitle: [
                  _formatTeacherRelationship(item.relationshipType),
                  _formatGraduationYear(item.alumniGraduationYear),
                  'Güven ${(item.confidenceScore * 100).round()}%',
                  if (item.activePairLinkCount > 1) 'Benzer kayıt var',
                  if (item.moderationLabel.isNotEmpty) item.moderationLabel,
                  if (item.notes.isNotEmpty) item.notes,
                  _workspaceTimestamp(context, item.createdAt),
                ].where((part) => part.trim().isNotEmpty).join(' · '),
                status: item.reviewStatus,
                canModerate: canModerate,
                onApprove: isBusy ? null : () => onConfirm(item),
                onReject: isBusy ? null : () => onReject(item),
                extraActions: [
                  TextButton(
                    onPressed: canModerate && !isBusy
                        ? () => onFlag(item)
                        : null,
                    child: const Text('İşaretle'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.canModerate,
    required this.onApprove,
    required this.onReject,
    this.extraActions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final String status;
  final bool canModerate;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelRaised,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusLg),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tokens.warningMuted,
                  borderRadius: BorderRadius.circular(
                    SdalThemeTokens.radiusPill,
                  ),
                ),
                child: Text(status),
              ),
              const Spacer(),
              if (canModerate) ...[
                TextButton(onPressed: onReject, child: const Text('Reddet')),
                const SizedBox(width: 8),
                ...extraActions,
                if (extraActions.isNotEmpty) const SizedBox(width: 8),
                FilledButton(onPressed: onApprove, child: const Text('Onayla')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentModerationCard extends StatelessWidget {
  const _ContentModerationCard({
    required this.postPreviewState,
    required this.commentPreviewState,
    required this.storyPreviewState,
    required this.canDeletePosts,
    required this.canDeleteStories,
    required this.onDelete,
  });

  final AsyncValue<AdminPreviewList<AdminModerationItem>> postPreviewState;
  final AsyncValue<AdminPreviewList<AdminModerationItem>> commentPreviewState;
  final AsyncValue<AdminPreviewList<AdminModerationItem>> storyPreviewState;
  final bool canDeletePosts;
  final bool canDeleteStories;
  final void Function(String type, int id) onDelete;

  @override
  Widget build(BuildContext context) {
    final items = <({String type, AdminModerationItem item, bool canDelete})>[
      ...postPreviewState.asData?.value.items.map(
            (item) => (type: 'post', item: item, canDelete: canDeletePosts),
          ) ??
          const [],
      ...commentPreviewState.asData?.value.items.map(
            (item) => (type: 'comment', item: item, canDelete: canDeletePosts),
          ) ??
          const [],
      ...storyPreviewState.asData?.value.items.map(
            (item) => (type: 'story', item: item, canDelete: canDeleteStories),
          ) ??
          const [],
    ]..sort((left, right) => right.item.id.compareTo(left.item.id));

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hızlı içerik temizliği',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('Cohort kapsamında açık içerik kaydı yok.')
          else
            for (final entry in items.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      SdalThemeTokens.radiusLg,
                    ),
                    border: Border.all(
                      color: Theme.of(context).sdal.panelBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.item.typeLabel} · ${entry.item.authorName}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.item.authorHandle.isEmpty
                            ? _workspaceTimestamp(context, entry.item.createdAt)
                            : '@${entry.item.authorHandle} · ${_workspaceTimestamp(context, entry.item.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).sdal.foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(entry.item.content),
                      if (entry.canDelete) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                onDelete(entry.type, entry.item.id),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Kaldır'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

bool _hasAnyPermission(
  AdminPermissionSnapshot? permissions,
  List<String> keys,
) {
  if (permissions == null) return false;
  if (permissions.isSuperModerator) return true;
  final assigned = permissions.permissionKeys.toSet();
  return keys.any(assigned.contains);
}

String _humanizeModuleKey(String key) {
  return key
      .split('_')
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

Future<void> _reviewMemberRequest(
  BuildContext context,
  WidgetRef ref, {
  required AdminRequestQueueItem item,
  required int id,
  required bool approve,
}) async {
  var graduationYearOverride = '';
  if (approve &&
      item.categoryKey == 'graduation_year_change' &&
      item.requestedGraduationYear.isNotEmpty) {
    final selectedYear = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _GraduationYearApprovalDialog(
        initialYear: item.requestedGraduationYear,
      ),
    );
    if (selectedYear == null || selectedYear.trim().isEmpty) return;
    graduationYearOverride = selectedYear.trim();
  }
  final ok = await ref
      .read(adminActionControllerProvider.notifier)
      .reviewMemberRequest(
        id: id,
        status: approve ? 'approved' : 'rejected',
        graduationYearOverride: graduationYearOverride,
      );
  if (!context.mounted) return;
  if (ok) _refreshModerationWorkspace(ref);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'Talep güncellendi.' : 'Talep güncellenemedi.'),
    ),
  );
}

String _formatGraduationYear(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'teacher' ||
      normalized == '9999' ||
      normalized == 'ogretmen' ||
      normalized == 'öğretmen') {
    return 'Öğretmen';
  }
  return value.trim().isEmpty ? 'Yıl yok' : value.trim();
}

String _formatTeacherRelationship(String value) {
  switch (value.trim()) {
    case 'taught_in_class':
      return 'Derse girdi';
    case 'club_advisor':
      return 'Kulüp danışmanı';
    case 'mentor':
      return 'Mentor';
    case 'other':
      return 'Diğer bağ';
    default:
      return value.trim().isEmpty ? 'Öğretmen bağı' : value.trim();
  }
}

class _GraduationYearApprovalDialog extends StatefulWidget {
  const _GraduationYearApprovalDialog({required this.initialYear});

  final String initialYear;

  @override
  State<_GraduationYearApprovalDialog> createState() =>
      _GraduationYearApprovalDialogState();
}

class _GraduationYearApprovalDialogState
    extends State<_GraduationYearApprovalDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialYear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mezuniyet yılı onayı'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Onaylanacak yıl veya Öğretmen',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}

Future<void> _reviewVerificationRequest(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required bool approve,
}) async {
  final ok = await ref
      .read(adminActionControllerProvider.notifier)
      .reviewVerificationRequest(
        id: id,
        status: approve ? 'approved' : 'rejected',
      );
  if (!context.mounted) return;
  if (ok) _refreshModerationWorkspace(ref);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Doğrulama talebi güncellendi.' : 'İşlem tamamlanamadı.',
      ),
    ),
  );
}

Future<void> _reviewTeacherNetworkLink(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String status,
}) async {
  final ok = await ref
      .read(adminActionControllerProvider.notifier)
      .reviewTeacherNetworkLink(id: id, status: status);
  if (!context.mounted) return;
  if (ok) _refreshModerationWorkspace(ref);
  final actionState = ref.read(adminActionControllerProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Öğretmen ağı bağlantısı güncellendi.'
            : (actionState.message ?? 'İşlem tamamlanamadı.'),
      ),
    ),
  );
}

Future<void> _deleteContent(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required int id,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _DeleteReasonSheet(
      typeLabel: switch (type) {
        'post' => 'gönderi',
        'comment' => 'yorum',
        'story' => 'hikaye',
        _ => type,
      },
    ),
  );
  if (reason == null) return;
  final ok = await ref
      .read(adminActionControllerProvider.notifier)
      .deleteContent(type: type, id: id, reason: reason);
  if (!context.mounted) return;
  if (ok) _refreshModerationWorkspace(ref);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'İçerik kaldırıldı.' : 'İçerik kaldırılamadı.'),
    ),
  );
}

class _DeleteReasonSheet extends StatefulWidget {
  const _DeleteReasonSheet({required this.typeLabel});

  final String typeLabel;

  @override
  State<_DeleteReasonSheet> createState() => _DeleteReasonSheetState();
}

class _DeleteReasonSheetState extends State<_DeleteReasonSheet> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_outline, color: tokens.danger),
              const SizedBox(width: 12),
              Text(
                '${widget.typeLabel.isNotEmpty ? widget.typeLabel[0].toUpperCase() + widget.typeLabel.substring(1) : "İçeriği"} kaldır',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bu işlem geri alınamaz. Devam etmek için bir gerekçe girin.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.foregroundMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'Gerekçe (zorunlu)',
              hintText: 'Örn: Kural ihlali, spam içerik, kullanıcı şikayeti...',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _confirmed,
                activeColor: tokens.danger,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bu içeriği kalıcı olarak kaldırmak istediğimi onaylıyorum.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: tokens.danger),
                onPressed: (_confirmed && _controller.text.trim().isNotEmpty)
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
                child: const Text('Kaldır'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _refreshModerationWorkspace(WidgetRef ref) {
  ref.invalidate(adminMemberRequestPreviewProvider);
  ref.invalidate(adminVerificationRequestPreviewProvider);
  ref.invalidate(adminTeacherNetworkLinkPreviewProvider);
  ref.invalidate(adminTeacherNetworkLinksProvider);
  ref.invalidate(adminRequestNotificationsProvider);
  ref.invalidate(adminPostPreviewProvider);
  ref.invalidate(adminCommentPreviewProvider);
  ref.invalidate(adminStoryPreviewProvider);
  ref.invalidate(adminSummaryProvider);
  ref.invalidate(adminLiveProvider);
}

Future<void> _handleAdminLogout(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(adminRepositoryProvider).logoutFromAdmin();
    ref.invalidate(adminAccessProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Admin oturumu kapatıldı.')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

Future<void> _editMaintenanceMessage(
  BuildContext context,
  WidgetRef ref,
  AdminSiteControlsSnapshot controls,
) async {
  final controller = TextEditingController(text: controls.maintenanceMessage);
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bakım mesajı'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Kullanıcıların göreceği bakım açıklaması',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await _saveSiteControls(
      context,
      ref,
      controls,
      maintenanceMessage: controller.text.trim(),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _saveSiteControls(
  BuildContext context,
  WidgetRef ref,
  AdminSiteControlsSnapshot controls, {
  bool? siteOpen,
  String? maintenanceMessage,
  String? defaultLandingPage,
  Map<String, bool>? modules,
  Map<String, bool>? menuVisibility,
  SdalAppTheme? activeTheme,
}) async {
  try {
    await ref
        .read(adminRepositoryProvider)
        .updateSiteControls(
          siteOpen: siteOpen ?? controls.siteOpen,
          maintenanceMessage: maintenanceMessage ?? controls.maintenanceMessage,
          defaultLandingPage: defaultLandingPage ?? controls.defaultLandingPage,
          modules: modules,
          menuVisibility: menuVisibility,
          moduleMenuOrder: controls.moduleMenuOrder,
          activeTheme: activeTheme,
        );
    ref.invalidate(adminSiteControlsProvider);
    ref.invalidate(sessionControllerProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ayar kaydedildi.')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

// ---------------------------------------------------------------------------
// Theme picker card injected into AdminModuleManagementPage
// ---------------------------------------------------------------------------

class _AppThemePickerCard extends ConsumerStatefulWidget {
  const _AppThemePickerCard({required this.controls});

  final AdminSiteControlsSnapshot controls;

  @override
  ConsumerState<_AppThemePickerCard> createState() =>
      _AppThemePickerCardState();
}

class _AppThemePickerCardState extends ConsumerState<_AppThemePickerCard> {
  late SdalAppTheme _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.controls.activeTheme;
  }

  @override
  void didUpdateWidget(_AppThemePickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving &&
        oldWidget.controls.activeTheme != widget.controls.activeTheme) {
      _selected = widget.controls.activeTheme;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveSiteControls(
        context,
        ref,
        widget.controls,
        activeTheme: _selected,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uygulama teması', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Değişiklik sonraki oturum yenilemesiyle tüm kullanıcılara yansır.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          for (final appTheme in SdalAppTheme.values) ...[
            _ThemeOptionRow(
              appTheme: appTheme,
              selected: _selected == appTheme,
              tokens: tokens,
              onTap: () => setState(() => _selected = appTheme),
            ),
            if (appTheme != SdalAppTheme.values.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected == widget.controls.activeTheme || _saving
                  ? null
                  : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionRow extends StatelessWidget {
  const _ThemeOptionRow({
    required this.appTheme,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final SdalAppTheme appTheme;
  final bool selected;
  final SdalThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.accentMuted : tokens.panelMuted,
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
          border: Border.all(
            color: selected ? tokens.accent : tokens.panelBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Row(
              children: appTheme.swatches
                  .asMap()
                  .entries
                  .map(
                    (e) => Transform.translate(
                      offset: Offset(-e.key * 6.0, 0),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: e.value,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.panel, width: 1.5),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appTheme.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? tokens.accent : tokens.foreground,
                    ),
                  ),
                  Text(
                    appTheme.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: tokens.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
