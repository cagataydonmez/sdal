import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../../admin/application/admin_action_controller.dart';
import '../../admin/data/admin_repository.dart';

class AdminWorkspacePage extends ConsumerWidget {
  const AdminWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final accessState = ref.watch(adminAccessProvider);
    final summaryState = ref.watch(adminSummaryProvider);
    final requestNotificationsState = ref.watch(
      adminRequestNotificationsProvider,
    );
    final siteControlsState = ref.watch(adminSiteControlsProvider);

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
        child: Center(child: Text(error.toString())),
      ),
      data: (access) {
        final requestItems =
            requestNotificationsState.asData?.value ??
            const <AdminRequestNotificationItem>[];
        final pendingRequestCount = requestItems.fold<int>(
          0,
          (sum, item) => sum + item.pendingCount,
        );
        final summary = summaryState.asData?.value;
        final siteControls = siteControlsState.asData?.value;

        return FeatureScaffold(
          title: 'Yönetim',
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: () {
                ref.invalidate(adminAccessProvider);
                ref.invalidate(adminSummaryProvider);
                ref.invalidate(adminRequestNotificationsProvider);
                ref.invalidate(adminSiteControlsProvider);
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
            padding: const EdgeInsets.all(20),
            children: [
              _WorkspaceHeroCard(
                eyebrow: 'Admin çalışma alanı',
                title: 'Uygulamayı tek ekrandan yönet',
                description:
                    'Teknik detaylar yerine iş kuyruklarını, modülleri ve kritik durumları öne çıkarır.',
                badges: [
                  _HeroBadge(
                    icon: Icons.pending_actions_outlined,
                    label: '$pendingRequestCount bekleyen talep',
                  ),
                  _HeroBadge(
                    icon: Icons.groups_outlined,
                    label:
                        '${summary?.counts['users'] ?? 0} üye · ${summary?.counts['pendingUsers'] ?? 0} onay bekliyor',
                  ),
                  _HeroBadge(
                    icon: Icons.dashboard_customize_outlined,
                    label: siteControls == null
                        ? 'Modül durumu yükleniyor'
                        : '${siteControls.openModuleCount}/${siteControls.totalModuleCount} modül açık',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _WorkspaceNavCard(
                    title: 'Talepler',
                    summary:
                        'Üyelik, mezuniyet yılı değişikliği ve öğretmen ağı incelemeleri.',
                    countLabel: '$pendingRequestCount bekleyen iş',
                    icon: Icons.assignment_turned_in_outlined,
                    tone: _WorkspaceTone.success,
                    onTap: () => context.go('/admin/requests'),
                  ),
                  _WorkspaceNavCard(
                    title: 'İçerik güvenliği',
                    summary:
                        'Post, yorum, hikâye, grup ve mesaj denetimini tek yerden aç.',
                    countLabel:
                        '${summary?.counts['posts'] ?? 0} gönderi · ${summary?.counts['messages'] ?? 0} mesaj',
                    icon: Icons.shield_outlined,
                    tone: _WorkspaceTone.warning,
                    onTap: () => context.go('/admin/content'),
                  ),
                  _WorkspaceNavCard(
                    title: 'Üyeler ve roller',
                    summary:
                        'Admin atama, mod kurma ve cohort bazlı yetki dağıtımı.',
                    countLabel: access.rootStatus?.hasRoot == true
                        ? 'Root hazır'
                        : 'Root kontrol et',
                    icon: Icons.manage_accounts_outlined,
                    tone: _WorkspaceTone.info,
                    onTap: () => context.go('/admin/management'),
                  ),
                  _WorkspaceNavCard(
                    title: 'Modül yönetimi',
                    summary:
                        'Site açıklığı, bakım mesajı, modül erişimi ve menü görünürlüğü.',
                    countLabel: siteControls?.siteOpen == true
                        ? 'Site açık'
                        : 'Bakım modu açık',
                    icon: Icons.tune_outlined,
                    tone: _WorkspaceTone.accent,
                    onTap: () => context.go('/admin/modules'),
                  ),
                  _WorkspaceNavCard(
                    title: 'API monitörü',
                    summary:
                        'Seçili üye üzerinden canlı endpoint akışlarını izle.',
                    countLabel: 'Canlı izleme aracı',
                    icon: Icons.radar_outlined,
                    tone: _WorkspaceTone.info,
                    onTap: () => context.go('/admin/api-monitor'),
                  ),
                  _WorkspaceNavCard(
                    title: 'Gelişmiş araçlar',
                    summary:
                        'Operasyonlar, loglar, deneyler, diller ve veritabanı işleri.',
                    countLabel: 'Yüksek etki / yüksek risk',
                    icon: Icons.build_outlined,
                    tone: _WorkspaceTone.danger,
                    onTap: () => context.go('/admin/operations'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AsyncSurfaceCard<List<AdminRequestNotificationItem>>(
                title: 'Bugünün kuyruk özeti',
                asyncValue: requestNotificationsState,
                builder: (items) {
                  if (items.isEmpty) {
                    return const Text(
                      'Açık bekleyen talep yok. Kuyruk temiz görünüyor.',
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items.take(6))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MetricRow(
                            label: item.label,
                            value: '${item.pendingCount}',
                            hint: item.categoryKey,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _AsyncSurfaceCard<AdminSiteControlsSnapshot>(
                title: 'Yayın durumu',
                asyncValue: siteControlsState,
                builder: (controls) {
                  final visibleModules = controls.menuVisibility.entries
                      .where((entry) => entry.value)
                      .length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricRow(
                        label: 'Site durumu',
                        value: controls.siteOpen ? 'Açık' : 'Kapalı',
                        hint: controls.maintenanceMessage.isEmpty
                            ? 'Bakım mesajı yok'
                            : 'Bakım mesajı hazır',
                      ),
                      const SizedBox(height: 10),
                      _MetricRow(
                        label: 'Varsayılan giriş',
                        value: controls.defaultLandingPage.isEmpty
                            ? '/new/feed'
                            : controls.defaultLandingPage,
                        hint: '$visibleModules modül menüde görünür',
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/admin/modules'),
                          icon: const Icon(Icons.tune_outlined),
                          label: const Text('Modül ayarlarını aç'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
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
              _WorkspaceHeroCard(
                eyebrow: 'Moderasyon çalışma alanı',
                title: scopedYears.isEmpty
                    ? 'Kapsam bekleyen moderatör'
                    : 'Cohort bazlı moderasyon masası',
                description: scopedYears.isEmpty
                    ? 'Yetkilerin açık, ancak henüz mezuniyet yılı kapsam ataması tanımlanmamış.'
                    : 'Yalnızca ${_formatYears(scopedYears)} cohortları içindeki üye ve içerikleri görebilir, inceleyebilir ve karar verebilirsin.',
                badges: [
                  _HeroBadge(
                    icon: Icons.school_outlined,
                    label: scopedYears.isEmpty
                        ? 'Cohort ataması yok'
                        : 'Cohort: ${scopedYears.join(', ')}',
                  ),
                  _HeroBadge(
                    icon: Icons.assignment_late_outlined,
                    label: '$requestTotal talep',
                  ),
                  _HeroBadge(
                    icon: Icons.verified_user_outlined,
                    label: '$verificationTotal doğrulama',
                  ),
                  _HeroBadge(
                    icon: Icons.shield_outlined,
                    label: '$contentTotal içerik kaydı',
                  ),
                ],
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
                        onTap: () => context.go('/admin/content'),
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
                      id: item.id,
                      approve: true,
                    ),
                    onReject: (item) => _reviewMemberRequest(
                      context,
                      ref,
                      id: item.id,
                      approve: false,
                    ),
                    canModerate: _hasAnyPermission(permissions, const [
                      'requests.moderate',
                    ]),
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
                  ),
                ),
              if (canReviewVerification) const SizedBox(height: 16),
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).sdal.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
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
  });

  final List<AdminRequestQueueItem> items;
  final String emptyMessage;
  final ValueChanged<AdminRequestQueueItem> onApprove;
  final ValueChanged<AdminRequestQueueItem> onReject;
  final bool canModerate;

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
                subtitle:
                    '${item.requesterName} · @${item.requesterHandle} · ${item.createdAt}',
                status: item.status,
                canModerate: canModerate,
                onApprove: () => onApprove(item),
                onReject: () => onReject(item),
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
  });

  final List<AdminVerificationQueueItem> items;
  final String emptyMessage;
  final ValueChanged<AdminVerificationQueueItem> onApprove;
  final ValueChanged<AdminVerificationQueueItem> onReject;
  final bool canModerate;

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
                subtitle:
                    '@${item.requesterHandle} · ${item.graduationYear} · ${item.createdAt}',
                status: item.status,
                canModerate: canModerate,
                onApprove: () => onApprove(item),
                onReject: () => onReject(item),
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
  });

  final String title;
  final String subtitle;
  final String status;
  final bool canModerate;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
                            ? entry.item.createdAt
                            : '@${entry.item.authorHandle} · ${entry.item.createdAt}',
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

String _formatYears(List<String> years) {
  if (years.length <= 3) return years.join(', ');
  return '${years.take(3).join(', ')} ve ${years.length - 3} cohort daha';
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
  required int id,
  required bool approve,
}) async {
  final ok = await ref
      .read(adminActionControllerProvider.notifier)
      .reviewMemberRequest(id: id, status: approve ? 'approved' : 'rejected');
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'Talep güncellendi.' : 'Talep güncellenemedi.'),
    ),
  );
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Doğrulama talebi güncellendi.' : 'İşlem tamamlanamadı.',
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('İçeriği kaldır'),
      content: const Text(
        'Bu işlem geri alınmaz. Gerçekten kaldırmak istiyor musun?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Kaldır'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final ok = await ref
      .read(adminActionControllerProvider.notifier)
      .deleteContent(type: type, id: id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'İçerik kaldırıldı.' : 'İçerik kaldırılamadı.'),
    ),
  );
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
