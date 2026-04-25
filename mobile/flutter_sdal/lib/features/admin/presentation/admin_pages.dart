import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'admin_api_monitor_widgets.dart';
import '../application/admin_action_controller.dart';
import '../data/admin_repository.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';

class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    final adminAccessState = ref.watch(adminAccessProvider);
    final summaryState = ref.watch(adminSummaryProvider);
    final liveState = ref.watch(adminLiveProvider);
    final securityState = ref.watch(adminSecurityProvider);
    final requestNotificationsState = ref.watch(
      adminRequestNotificationsProvider,
    );

    if (session == null || user == null || !user.hasAdminAccess) {
      return FeatureScaffold(
        title: 'Admin paneli',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Bu alan yalnızca admin hesapları için açık.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
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

    final moduleEntries = session.siteAccess.modules.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (adminAccessState.isLoading) {
      return const FeatureScaffold(
        title: 'Admin paneli',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (adminAccessState.hasError) {
      return FeatureScaffold(
        title: 'Admin paneli',
        child: Center(child: Text(adminAccessState.error.toString())),
      );
    }
    final adminAccess = adminAccessState.value!;
    if (!adminAccess.canOpenAdminShell) {
      return FeatureScaffold(
        title: 'Admin paneli',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Admin oturumu açık değil. Yönetim yüzeyleri için ikinci adım admin doğrulamasını tamamla.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (adminAccess.rootStatus != null)
                    Text(
                      adminAccess.rootStatus!.hasRoot
                          ? 'Root kullanıcı hazır: @${adminAccess.rootStatus!.rootHandle}'
                          : 'Root kullanıcı henüz oluşturulmamış',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAdminLoginDialog(context, ref),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Admin oturumu aç'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final visibleSections = _visibleAdminSections(adminAccess);

    return FeatureScaffold(
      title: 'Admin paneli',
      actions: [
        IconButton(
          onPressed: () {
            ref.invalidate(adminAccessProvider);
            ref.invalidate(adminSummaryProvider);
            ref.invalidate(adminLiveProvider);
            ref.invalidate(adminSecurityProvider);
            ref.invalidate(adminRequestNotificationsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () => _handleAdminLogout(context, ref),
          icon: const Icon(Icons.logout),
          tooltip: 'Admin oturumunu kapat',
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yönetici özeti',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AdminStatChip(
                      icon: Icons.admin_panel_settings_outlined,
                      label: user.role,
                    ),
                    _AdminStatChip(
                      icon: Icons.verified_user_outlined,
                      label: user.isVerified
                          ? 'Doğrulanmış'
                          : 'Doğrulama bekliyor',
                    ),
                    _AdminStatChip(
                      icon: Icons.home_outlined,
                      label: 'Varsayılan: ${session.defaultHomePath}',
                    ),
                    _AdminStatChip(
                      icon: Icons.settings_ethernet_outlined,
                      label: session.siteAccess.siteOpen
                          ? 'Site açık'
                          : 'Bakım modu',
                    ),
                    if (adminAccess.rootStatus != null)
                      _AdminStatChip(
                        icon: Icons.key_outlined,
                        label: adminAccess.rootStatus!.hasRoot
                            ? 'Root hazır'
                            : 'Root bekleniyor',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AdminAsyncCard(
            title: 'Canlı admin verisi',
            states: [
              summaryState,
              liveState,
              securityState,
              requestNotificationsState,
            ],
            builder: () {
              final summary = summaryState.value!;
              final live = liveState.value!;
              final security = securityState.value!;
              final requestNotifications = requestNotificationsState.value!;
              final pendingRequestCount = requestNotifications.fold<int>(
                0,
                (sum, item) => sum + item.pendingCount,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _AdminStatChip(
                        icon: Icons.groups_outlined,
                        label: '${summary.counts['users'] ?? 0} üye',
                      ),
                      _AdminStatChip(
                        icon: Icons.pending_actions_outlined,
                        label:
                            '${summary.counts['pendingUsers'] ?? 0} bekleyen üye',
                      ),
                      _AdminStatChip(
                        icon: Icons.chat_bubble_outline,
                        label: '${summary.counts['messages'] ?? 0} mesaj',
                      ),
                      _AdminStatChip(
                        icon: Icons.wifi_tethering_outlined,
                        label:
                            '${live.counts['onlineUsers'] ?? 0} çevrim içi üye',
                      ),
                      _AdminStatChip(
                        icon: Icons.assignment_late_outlined,
                        label: '$pendingRequestCount bekleyen talep',
                      ),
                      _AdminStatChip(
                        icon: Icons.security_outlined,
                        label: '${security.totalRejections} validation reddi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (requestNotifications.isNotEmpty) ...[
                    Text(
                      'Talep kuyruğu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final item in requestNotifications.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${item.label}: ${item.pendingCount} bekleyen',
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Son admin aktivitesi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final item in live.activity.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        item.timestamp.isNotEmpty
                            ? '${item.title} · ${item.timestamp}'
                            : item.title,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Yönetim yüzeyleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final section in visibleSections) ...[
            _AdminSectionCard(section: section),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modül durumu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in moduleEntries)
                      Chip(
                        avatar: Icon(
                          entry.value ? Icons.check_circle : Icons.pause_circle,
                          size: 18,
                          color: entry.value
                              ? Theme.of(context).sdal.success
                              : Theme.of(context).sdal.warning,
                        ),
                        label: Text(
                          '${entry.key} · ${entry.value ? 'açık' : 'kapalı'}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionPage extends ConsumerStatefulWidget {
  const AdminSectionPage({super.key, required this.sectionKey});

  final String sectionKey;

  @override
  ConsumerState<AdminSectionPage> createState() => _AdminSectionPageState();
}

class _AdminSectionPageState extends ConsumerState<AdminSectionPage> {
  final _userSearchController = TextEditingController();
  String _userFilter = 'all';
  bool _verifiedOnly = false;
  bool _adminOnly = false;
  bool _withPhotoOnly = false;
  int _userPage = 1;

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconButton buildBackButton() => IconButton(
      tooltip: 'Yönetim ana sayfasına dön',
      onPressed: () => context.go('/admin'),
      icon: const Icon(Icons.arrow_back_outlined),
    );

    final sectionKey = widget.sectionKey;
    final section = _sectionByKey(sectionKey);
    if (section == null) {
      return FeatureScaffold(
        title: 'Admin paneli',
        actions: [buildBackButton()],
        child: const Center(child: Text('Bilinmeyen admin bölümü.')),
      );
    }
    final adminAccessState = ref.watch(adminAccessProvider);
    if (adminAccessState.isLoading) {
      return FeatureScaffold(
        title: section.title,
        actions: [buildBackButton()],
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (adminAccessState.hasError) {
      return FeatureScaffold(
        title: section.title,
        actions: [buildBackButton()],
        child: Center(child: Text(adminAccessState.error.toString())),
      );
    }
    final adminAccess = adminAccessState.value!;
    final visibleSections = _visibleAdminSections(adminAccess);
    final sectionAllowed = visibleSections.any(
      (item) => item.key == sectionKey,
    );
    if (!adminAccess.canOpenAdminShell || !sectionAllowed) {
      return FeatureScaffold(
        title: section.title,
        actions: [buildBackButton()],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Bu admin bölümü için aktif yetki bulunmuyor.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/admin'),
                    child: const Text('Yönetim ana sayfasına dön'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final userPreviewQuery = AdminUserListQuery(
      query: _userSearchController.text.trim(),
      filter: _userFilter,
      verifiedOnly: _verifiedOnly,
      adminOnly: _adminOnly,
      withPhotoOnly: _withPhotoOnly,
      page: _userPage,
    );

    final postPreviewState = sectionKey == 'content'
        ? ref.watch(adminPostPreviewProvider)
        : const AsyncValue<AdminPreviewList<AdminModerationItem>>.data(
            AdminPreviewList(total: 0, items: <AdminModerationItem>[]),
          );
    final commentPreviewState = sectionKey == 'content'
        ? ref.watch(adminCommentPreviewProvider)
        : const AsyncValue<AdminPreviewList<AdminModerationItem>>.data(
            AdminPreviewList(total: 0, items: <AdminModerationItem>[]),
          );
    final storyPreviewState = sectionKey == 'content'
        ? ref.watch(adminStoryPreviewProvider)
        : const AsyncValue<AdminPreviewList<AdminModerationItem>>.data(
            AdminPreviewList(total: 0, items: <AdminModerationItem>[]),
          );
    final memberRequestPreviewState = sectionKey == 'requests'
        ? ref.watch(adminMemberRequestPreviewProvider)
        : const AsyncValue<AdminPreviewList<AdminRequestQueueItem>>.data(
            AdminPreviewList(total: 0, items: <AdminRequestQueueItem>[]),
          );
    final verificationPreviewState = sectionKey == 'requests'
        ? ref.watch(adminVerificationRequestPreviewProvider)
        : const AsyncValue<AdminPreviewList<AdminVerificationQueueItem>>.data(
            AdminPreviewList(total: 0, items: <AdminVerificationQueueItem>[]),
          );
    final userPreviewState = sectionKey == 'management'
        ? ref.watch(adminUserPreviewProvider(userPreviewQuery))
        : const AsyncValue<AdminPreviewList<AdminUserPreviewItem>>.data(
            AdminPreviewList(total: 0, items: <AdminUserPreviewItem>[]),
          );
    final siteControlsState = sectionKey == 'operations'
        ? ref.watch(adminSiteControlsProvider)
        : const AsyncValue<AdminSiteControlsSnapshot>.data(
            AdminSiteControlsSnapshot(
              siteOpen: false,
              maintenanceMessage: '',
              defaultLandingPage: '',
              modules: <String, bool>{},
              menuVisibility: <String, bool>{},
              moduleMenuOrder: <String>[],
              openModuleCount: 0,
              totalModuleCount: 0,
            ),
          );
    final dbBackupsState = sectionKey == 'database'
        ? ref.watch(adminDbBackupsProvider)
        : const AsyncValue<List<AdminDbBackupItem>>.data(<AdminDbBackupItem>[]);
    final dbDriverState = sectionKey == 'database'
        ? ref.watch(adminDbDriverStatusProvider)
        : const AsyncValue<AdminDbDriverStatusSnapshot>.data(
            AdminDbDriverStatusSnapshot(
              currentDriver: '',
              targetDriver: '',
              inProgress: false,
              switchEnabled: false,
              blockerCount: 0,
              blockers: <String>[],
              warnings: <String>[],
              expectedConfirmText: '',
              challengeToken: '',
              requiresSqliteDriftAck: false,
              dataCopySupported: false,
              lastError: '',
            ),
          );
    final languagesState = sectionKey == 'languages'
        ? ref.watch(adminLanguagesProvider)
        : const AsyncValue<List<AdminLanguageItem>>.data(<AdminLanguageItem>[]);
    final languageConfigState = sectionKey == 'languages'
        ? ref.watch(adminLanguageConfigProvider)
        : const AsyncValue<AdminLanguageConfigSnapshot>.data(
            AdminLanguageConfigSnapshot(
              selectionEnabled: true,
              defaultOpen: '',
              defaultClosed: '',
            ),
          );
    final pagesState = sectionKey == 'operations'
        ? ref.watch(adminPagesProvider)
        : const AsyncValue<List<AdminPageItem>>.data(<AdminPageItem>[]);
    final emailCategoriesState = sectionKey == 'operations'
        ? ref.watch(adminEmailCategoriesProvider)
        : const AsyncValue<List<AdminEmailCategoryItem>>.data(
            <AdminEmailCategoryItem>[],
          );
    final emailTemplatesState = sectionKey == 'operations'
        ? ref.watch(adminEmailTemplatesProvider)
        : const AsyncValue<List<AdminEmailTemplateItem>>.data(
            <AdminEmailTemplateItem>[],
          );
    final appLogsState = sectionKey == 'operations'
        ? ref.watch(adminAppLogFilesProvider)
        : const AsyncValue<List<AdminLogFileItem>>.data(<AdminLogFileItem>[]);
    final languagePreviewCode =
        (languageConfigState.value?.defaultOpen ?? '').trim().isNotEmpty
        ? (languageConfigState.value?.defaultOpen ?? '').trim()
        : ((languagesState.value?.isNotEmpty ?? false)
              ? languagesState.value!.first.code
              : '');
    final languageStringsState = sectionKey == 'languages'
        ? ref.watch(adminLanguageStringsProvider(languagePreviewCode))
        : const AsyncValue<List<AdminLanguageStringItem>>.data(
            <AdminLanguageStringItem>[],
          );
    final languageKeysState = sectionKey == 'languages'
        ? ref.watch(adminLanguageKeysProvider)
        : const AsyncValue<List<AdminLanguageKeyItem>>.data(
            <AdminLanguageKeyItem>[],
          );

    return FeatureScaffold(
      title: section.title,
      actions: [
        buildBackButton(),
        if (sectionKey == 'content' ||
            sectionKey == 'requests' ||
            sectionKey == 'management' ||
            sectionKey == 'api-monitor' ||
            sectionKey == 'operations' ||
            sectionKey == 'database' ||
            sectionKey == 'languages')
          IconButton(
            onPressed: () {
              if (sectionKey == 'content') {
                ref.invalidate(adminPostPreviewProvider);
                ref.invalidate(adminCommentPreviewProvider);
                ref.invalidate(adminStoryPreviewProvider);
              }
              if (sectionKey == 'requests') {
                ref.invalidate(adminMemberRequestPreviewProvider);
                ref.invalidate(adminVerificationRequestPreviewProvider);
              }
              if (sectionKey == 'management') {
                ref.invalidate(adminUserPreviewProvider);
              }
              if (sectionKey == 'api-monitor') {
                ref.invalidate(adminUserPreviewProvider);
                ref.invalidate(adminUserApiActivityProvider);
              }
              if (sectionKey == 'operations') {
                ref.invalidate(adminSiteControlsProvider);
                ref.invalidate(adminPagesProvider);
                ref.invalidate(adminEmailCategoriesProvider);
                ref.invalidate(adminEmailTemplatesProvider);
                ref.invalidate(adminAppLogFilesProvider);
              }
              if (sectionKey == 'database') {
                ref.invalidate(adminDbBackupsProvider);
                ref.invalidate(adminDbDriverStatusProvider);
              }
              if (sectionKey == 'languages') {
                ref.invalidate(adminLanguagesProvider);
                ref.invalidate(adminLanguageConfigProvider);
                ref.invalidate(adminLanguageKeysProvider);
                if (languagePreviewCode.isNotEmpty) {
                  ref.invalidate(
                    adminLanguageStringsProvider(languagePreviewCode),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
          ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _adminToneColor(
                        context,
                        section.tone,
                      ).withValues(alpha: 0.18),
                      foregroundColor: _adminToneColor(context, section.tone),
                      child: Icon(section.icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(section.description),
              ],
            ),
          ),
          if (sectionKey == 'content') ...[
            const SizedBox(height: 16),
            _AdminAsyncCard(
              title: 'Canli moderasyon kuyrugu',
              states: [
                postPreviewState,
                commentPreviewState,
                storyPreviewState,
              ],
              builder: () {
                final posts = postPreviewState.value!;
                final comments = commentPreviewState.value!;
                final stories = storyPreviewState.value!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdminPreviewListCard(
                      title: 'Gonderiler',
                      total: posts.total,
                      children: [
                        for (final item in posts.items)
                          _AdminPreviewLine(
                            title: item.authorHandle.isNotEmpty
                                ? '@${item.authorHandle}'
                                : item.authorName,
                            subtitle: item.content,
                            trailing: item.createdAt,
                            action: _AdminDeleteButton(
                              label: 'Gonderiyi sil',
                              onConfirm: () => _handleDeleteAction(
                                context,
                                ref,
                                type: 'post',
                                id: item.id,
                                successMessage: 'Gonderi silindi.',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdminPreviewListCard(
                      title: 'Yorumlar',
                      total: comments.total,
                      children: [
                        for (final item in comments.items)
                          _AdminPreviewLine(
                            title: item.authorHandle.isNotEmpty
                                ? '@${item.authorHandle}'
                                : item.authorName,
                            subtitle: item.content,
                            trailing: item.createdAt,
                            action: _AdminDeleteButton(
                              label: 'Yorumu sil',
                              onConfirm: () => _handleDeleteAction(
                                context,
                                ref,
                                type: 'comment',
                                id: item.id,
                                successMessage: 'Yorum silindi.',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdminPreviewListCard(
                      title: 'Hikayeler',
                      total: stories.total,
                      children: [
                        for (final item in stories.items)
                          _AdminPreviewLine(
                            title: item.authorHandle.isNotEmpty
                                ? '@${item.authorHandle}'
                                : item.authorName,
                            subtitle: item.content,
                            trailing: item.createdAt,
                            action: _AdminDeleteButton(
                              label: 'Hikayeyi sil',
                              onConfirm: () => _handleDeleteAction(
                                context,
                                ref,
                                type: 'story',
                                id: item.id,
                                successMessage: 'Hikaye silindi.',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          if (sectionKey == 'management') ...[
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kullanıcı arama ve filtreler',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı, e-posta veya handle ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setState(() => _userPage = 1),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in const <(String, String)>[
                        ('all', 'Tüm'),
                        ('active', 'Aktif'),
                        ('pending', 'Bekleyen'),
                        ('banned', 'Yasaklı'),
                        ('online', 'Çevrim içi'),
                      ])
                        ChoiceChip(
                          label: Text(filter.$2),
                          selected: _userFilter == filter.$1,
                          onSelected: (_) => setState(() {
                            _userFilter = filter.$1;
                            _userPage = 1;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Doğrulanmış'),
                        selected: _verifiedOnly,
                        onSelected: (value) => setState(() {
                          _verifiedOnly = value;
                          _userPage = 1;
                        }),
                      ),
                      FilterChip(
                        label: const Text('Sadece admin'),
                        selected: _adminOnly,
                        onSelected: (value) => setState(() {
                          _adminOnly = value;
                          _userPage = 1;
                        }),
                      ),
                      FilterChip(
                        label: const Text('Fotoğraflı'),
                        selected: _withPhotoOnly,
                        onSelected: (value) => setState(() {
                          _withPhotoOnly = value;
                          _userPage = 1;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: () => setState(() => _userPage = 1),
                        child: const Text('Uygula'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => setState(() {
                          _userSearchController.clear();
                          _userFilter = 'all';
                          _verifiedOnly = false;
                          _adminOnly = false;
                          _withPhotoOnly = false;
                          _userPage = 1;
                        }),
                        child: const Text('Temizle'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _AdminAsyncCard(
              title: 'Canlı kullanıcı listesi',
              states: [userPreviewState],
              builder: () {
                final users = userPreviewState.value!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdminPreviewListCard(
                      title: 'Kullanıcılar',
                      total: users.total,
                      children: [
                        for (final item in users.items)
                          _AdminPreviewLine(
                            title: item.handle.isNotEmpty
                                ? '@${item.handle}'
                                : item.name,
                            subtitle:
                                '${item.email} · ${item.role} · ${item.engagementScore} puan',
                            trailing: item.graduationYear.isNotEmpty
                                ? item.graduationYear
                                : 'Yıl yok',
                            action: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Detay / tam düzenle',
                                  onPressed: () => _handleUserDetailEdit(
                                    context,
                                    ref,
                                    item.id,
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Mezuniyet yılını güncelle',
                                  onPressed: () => _handleGraduationYearEdit(
                                    context,
                                    ref,
                                    item,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                _AdminDeleteButton(
                                  label: 'Kullanıcıyı sil',
                                  onConfirm: () => _handleMemberDelete(
                                    context,
                                    ref,
                                    id: item.id,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _userPage > 1
                              ? () => setState(() => _userPage -= 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Önceki'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sayfa $_userPage · Toplam ${users.total}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed:
                              users.items.length >= userPreviewQuery.limit
                              ? () => setState(() => _userPage += 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Sonraki'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          if (sectionKey == 'api-monitor') ...[
            const SizedBox(height: 16),
            const AdminApiMonitorSection(),
          ],
          if (sectionKey == 'operations') ...[
            const SizedBox(height: 16),
            _AdminAsyncCard(
              title: 'Canlı operasyon durumu',
              states: [
                siteControlsState,
                pagesState,
                emailCategoriesState,
                emailTemplatesState,
                appLogsState,
              ],
              builder: () {
                final siteControls = siteControlsState.value!;
                final pages = pagesState.value!;
                final emailCategories = emailCategoriesState.value!;
                final emailTemplates = emailTemplatesState.value!;
                final logs = appLogsState.value!;
                return _AdminPreviewListCard(
                  title: 'Site kontrolü',
                  total: siteControls.totalModuleCount,
                  children: [
                    _AdminPreviewLine(
                      title: siteControls.siteOpen ? 'Site açık' : 'Bakım modu',
                      subtitle:
                          'Varsayılan açılış: ${siteControls.defaultLandingPage.isNotEmpty ? siteControls.defaultLandingPage : '/feed'}',
                      trailing:
                          '${siteControls.openModuleCount}/${siteControls.totalModuleCount} modül açık',
                      action: Switch(
                        value: siteControls.siteOpen,
                        onChanged: (value) => _handleSiteOpenToggle(
                          context,
                          ref,
                          siteControls,
                          value,
                        ),
                      ),
                    ),
                    if (siteControls.maintenanceMessage.isNotEmpty)
                      _AdminPreviewLine(
                        title: 'Bakım mesajı',
                        subtitle: siteControls.maintenanceMessage,
                        trailing: '',
                      ),
                    const SizedBox(height: 12),
                    _AdminInlineActionRow(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _handleAddPage(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Sayfa ekle'),
                      ),
                    ),
                    for (final item in pages.take(4))
                      _AdminPreviewLine(
                        title: item.name,
                        subtitle: item.url,
                        trailing: '#${item.sortOrder} · ${item.icon}',
                        action: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sayfayı düzenle',
                              onPressed: () =>
                                  _handleEditPage(context, ref, item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Yukari tasi',
                              onPressed: item.sortOrder > 1
                                  ? () => _handleReorderPage(
                                      context,
                                      ref,
                                      pages,
                                      item,
                                      -1,
                                    )
                                  : null,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Asagi tasi',
                              onPressed: () => _handleReorderPage(
                                context,
                                ref,
                                pages,
                                item,
                                1,
                              ),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            _AdminDeleteButton(
                              label: 'Sayfayi sil',
                              onConfirm: () =>
                                  _handleDeletePage(context, ref, item.id),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    _AdminInlineActionRow(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _handleAddEmailCategory(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('E-posta kategorisi ekle'),
                      ),
                    ),
                    for (final item in emailCategories.take(4))
                      _AdminPreviewLine(
                        title: item.name,
                        subtitle: '${item.type} · ${item.value}',
                        trailing: item.description,
                        action: _AdminDeleteButton(
                          label: 'Kategoriyi sil',
                          onConfirm: () =>
                              _handleDeleteEmailCategory(context, ref, item.id),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _AdminInlineActionRow(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _handleAddEmailTemplate(context, ref),
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('Şablon ekle'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: emailCategories.isEmpty
                                ? null
                                : () => _handleSendBulkEmail(
                                    context,
                                    ref,
                                    emailCategories,
                                    emailTemplates,
                                  ),
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Toplu gonder'),
                          ),
                        ],
                      ),
                    ),
                    for (final item in emailTemplates.take(4))
                      _AdminPreviewLine(
                        title: item.name,
                        subtitle: item.subject,
                        trailing: item.createdAt,
                        action: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Şablonu düzenle',
                              onPressed: () =>
                                  _handleEditEmailTemplate(context, ref, item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            _AdminDeleteButton(
                              label: 'Şablonu sil',
                              onConfirm: () => _handleDeleteEmailTemplate(
                                context,
                                ref,
                                item.id,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (logs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final item in logs.take(4))
                        _AdminPreviewLine(
                          title: item.name,
                          subtitle: '${item.size} byte',
                          trailing: item.modifiedAt,
                          action: IconButton(
                            tooltip: 'Icerigi gor',
                            onPressed: () =>
                                _handleViewLogContent(context, ref, item),
                            icon: const Icon(Icons.subject_outlined),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
          if (sectionKey == 'database') ...[
            const SizedBox(height: 16),
            _AdminAsyncCard(
              title: 'Canli veritabani durumu',
              states: [dbBackupsState, dbDriverState],
              builder: () {
                final backups = dbBackupsState.value!;
                final driver = dbDriverState.value!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdminPreviewListCard(
                      title: 'Driver durumu',
                      total: backups.length,
                      children: [
                        _AdminPreviewLine(
                          title:
                              '${driver.currentDriver} -> ${driver.targetDriver}',
                          subtitle: driver.inProgress
                              ? 'Surucu gecisi devam ediyor'
                              : (driver.switchEnabled
                                    ? 'Geçiş hazır'
                                    : 'Gecis blokeli'),
                          trailing: '${driver.blockerCount} blocker',
                          action: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonal(
                                onPressed:
                                    driver.switchEnabled &&
                                        driver.targetDriver.isNotEmpty &&
                                        driver.challengeToken.isNotEmpty
                                    ? () => _handleSwitchDbDriver(
                                        context,
                                        ref,
                                        driver,
                                      )
                                    : null,
                                child: const Text('Driver degistir'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () =>
                                    _handleCreateDbBackup(context, ref),
                                child: const Text('Yedek al'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed:
                                    driver.currentDriver.isNotEmpty &&
                                        driver.targetDriver.isNotEmpty
                                    ? () => _handleCopyDbData(
                                        context,
                                        ref,
                                        driver,
                                      )
                                    : null,
                                child: const Text('Veri kopyala'),
                              ),
                            ],
                          ),
                        ),
                        if (driver.blockers.isNotEmpty)
                          for (final blocker in driver.blockers.take(3))
                            _AdminPreviewLine(
                              title: 'Blokaj',
                              subtitle: blocker,
                              trailing: '',
                            ),
                        if (driver.warnings.isNotEmpty)
                          for (final warning in driver.warnings.take(3))
                            _AdminPreviewLine(
                              title: 'Uyari',
                              subtitle: warning,
                              trailing: '',
                            ),
                        if (driver.lastError.isNotEmpty)
                          _AdminPreviewLine(
                            title: 'Son hata',
                            subtitle: driver.lastError,
                            trailing: '',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdminPreviewListCard(
                      title: 'Son yedekler',
                      total: backups.length,
                      children: [
                        for (final item in backups.take(4))
                          _AdminPreviewLine(
                            title: item.name,
                            subtitle: '${item.size} byte',
                            trailing: item.createdAt,
                            action: FilledButton.tonal(
                              onPressed: () =>
                                  _handleRestoreBackup(context, ref, item),
                              child: const Text('Geri yukle'),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu bölümde yer alan akışlar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final capability in section.capabilities) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chevron_right,
                        color: _adminToneColor(context, section.tone),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(capability)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (sectionKey == 'requests') ...[
            const SizedBox(height: 16),
            _AdminAsyncCard(
              title: 'Canli talep kuyrugu',
              states: [memberRequestPreviewState, verificationPreviewState],
              builder: () {
                final requests = memberRequestPreviewState.value!;
                final verifications = verificationPreviewState.value!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdminPreviewListCard(
                      title: 'Üye talepleri',
                      total: requests.total,
                      children: [
                        for (final item in requests.items)
                          _AdminPreviewLine(
                            title: item.requesterHandle.isNotEmpty
                                ? '@${item.requesterHandle}'
                                : item.requesterName,
                            subtitle: item.categoryLabel,
                            trailing: item.createdAt,
                            action: _AdminDecisionButtons(
                              onApprove: () => _handleMemberRequestReview(
                                context,
                                ref,
                                item: item,
                                id: item.id,
                                status: 'approved',
                              ),
                              onReject: () => _handleMemberRequestReview(
                                context,
                                ref,
                                item: item,
                                id: item.id,
                                status: 'rejected',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdminPreviewListCard(
                      title: 'Doğrulama talepleri',
                      total: verifications.total,
                      children: [
                        for (final item in verifications.items)
                          _AdminPreviewLine(
                            title: item.requesterHandle.isNotEmpty
                                ? '@${item.requesterHandle}'
                                : item.requesterName,
                            subtitle: item.graduationYear.isNotEmpty
                                ? 'Mezuniyet yılı: ${item.graduationYear}'
                                : 'Mezuniyet yılı yok',
                            trailing: item.createdAt,
                            action: _AdminDecisionButtons(
                              onApprove: () => _handleVerificationReview(
                                context,
                                ref,
                                id: item.id,
                                status: 'approved',
                              ),
                              onReject: () => _handleVerificationReview(
                                context,
                                ref,
                                id: item.id,
                                status: 'rejected',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          if (sectionKey == 'languages') ...[
            const SizedBox(height: 16),
            _AdminAsyncCard(
              title: 'Canli dil ayarlari',
              states: [
                languagesState,
                languageConfigState,
                languageStringsState,
                languageKeysState,
              ],
              builder: () {
                final languages = languagesState.value!;
                final config = languageConfigState.value!;
                final strings = languageStringsState.value!;
                final keys = languageKeysState.value!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdminPreviewListCard(
                      title: 'Dil secimi',
                      total: languages.length,
                      children: [
                        _AdminPreviewLine(
                          title: config.selectionEnabled
                              ? 'Dil seçimi açık'
                              : 'Dil seçimi kapalı',
                          subtitle:
                              'Açık: ${config.defaultOpen} · Kapalı: ${config.defaultClosed}',
                          trailing: '',
                          action: Switch(
                            value: config.selectionEnabled,
                            onChanged: (value) =>
                                _handleLanguageSelectionToggle(
                                  context,
                                  ref,
                                  config,
                                  value,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdminPreviewListCard(
                      title: 'Diller',
                      total: languages.length,
                      children: [
                        _AdminInlineActionRow(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    _handleAddLanguage(context, ref),
                                icon: const Icon(Icons.add),
                                label: const Text('Dil ekle'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed:
                                    languagePreviewCode.isNotEmpty &&
                                        languagePreviewCode != 'tr'
                                    ? () => _handleFillMissingLanguageStrings(
                                        context,
                                        ref,
                                        languagePreviewCode,
                                      )
                                    : null,
                                child: const Text('Eksikleri doldur'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: languagePreviewCode.isNotEmpty
                                    ? () => _handleBulkImportLanguageStrings(
                                        context,
                                        ref,
                                        languagePreviewCode,
                                      )
                                    : null,
                                child: const Text('Bulk import'),
                              ),
                            ],
                          ),
                        ),
                        for (final item in languages.take(6))
                          _AdminPreviewLine(
                            title: '${item.code.toUpperCase()} · ${item.name}',
                            subtitle:
                                '${item.nativeName}${item.isDefault ? ' · Varsayılan' : ''}',
                            trailing: item.isActive ? 'Aktif' : 'Pasif',
                            action: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: item.isActive,
                                  onChanged: item.isDefault
                                      ? null
                                      : (_) => _handleLanguageToggle(
                                          context,
                                          ref,
                                          item,
                                        ),
                                ),
                                if (!item.isDefault)
                                  _AdminDeleteButton(
                                    label: 'Dili sil',
                                    onConfirm: () => _handleLanguageDelete(
                                      context,
                                      ref,
                                      item.code,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (languagePreviewCode.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final item in strings.take(6))
                            _AdminPreviewLine(
                              title: item.key,
                              subtitle: item.value,
                              trailing: item.updatedAt,
                              action: IconButton(
                                tooltip: 'Metni düzenle',
                                onPressed: () => _handleEditLanguageString(
                                  context,
                                  ref,
                                  item,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ),
                          const SizedBox(height: 12),
                          for (final item in keys.take(6))
                            _AdminPreviewLine(
                              title: item.key,
                              subtitle: 'Dil sayisi: ${item.languageCount}',
                              trailing: '',
                              action: _AdminDeleteButton(
                                label: 'Key sil',
                                onConfirm: () => _handleDeleteLanguageKey(
                                  context,
                                  ref,
                                  item.key,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sunucu baglantisi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu ekran ${section.routeFile} ile eslesecek sekilde eklendi. '
                  'Mobil tarafta admin ulasim yolu artik var; islem bazli formlar ve tablolar bu temelin uzerine genisletilebilir.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAction(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    required int id,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Onay gerekiyor'),
          content: Text('$successMessage Bu islem geri alinmaz.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Devam et'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deleteContent(type: type, id: id);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? successMessage : (actionState.message ?? 'Islem tamamlanamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleMemberRequestReview(
    BuildContext context,
    WidgetRef ref, {
    required AdminRequestQueueItem item,
    required int id,
    required String status,
  }) async {
    var graduationYearOverride = '';
    if (status == 'approved' &&
        item.categoryKey == 'graduation_year_change' &&
        item.requestedGraduationYear.isNotEmpty) {
      final selectedYear = await showDialog<String>(
        context: context,
        builder: (dialogContext) =>
            _GraduationYearDialog(initialYear: item.requestedGraduationYear),
      );
      if (selectedYear == null || selectedYear.trim().isEmpty) return;
      graduationYearOverride = selectedYear.trim();
    }
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .reviewMemberRequest(
          id: id,
          status: status,
          graduationYearOverride: graduationYearOverride,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (status == 'approved'
                    ? 'Talep onaylandi.'
                    : 'Talep reddedildi.')
              : (actionState.message ?? 'Islem tamamlanamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleVerificationReview(
    BuildContext context,
    WidgetRef ref, {
    required int id,
    required String status,
  }) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .reviewVerificationRequest(id: id, status: status);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (status == 'approved'
                    ? 'Doğrulama onaylandı.'
                    : 'Doğrulama reddedildi.')
              : (actionState.message ?? 'Islem tamamlanamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleMemberDelete(
    BuildContext context,
    WidgetRef ref, {
    required int id,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kullanıcıyı sil'),
          content: const Text(
            'Bu işlem kullanıcıyı ve ilgili verileri kalıcı olarak siler.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deleteMember(id: id);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kullanıcı silindi.'
              : (actionState.message ?? 'Kullanıcı silinemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleGraduationYearEdit(
    BuildContext context,
    WidgetRef ref,
    AdminUserPreviewItem item,
  ) async {
    final nextYear = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _GraduationYearDialog(initialYear: item.graduationYear),
    );
    if (nextYear == null || nextYear.isEmpty || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .updateGraduationYear(id: item.id, graduationYear: nextYear);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Mezuniyet yılı güncellendi.'
              : (actionState.message ?? 'Güncelleme yapılamadı.'),
        ),
      ),
    );
  }

  Future<void> _handleSiteOpenToggle(
    BuildContext context,
    WidgetRef ref,
    AdminSiteControlsSnapshot siteControls,
    bool nextValue,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .updateSiteOpen(
          siteOpen: nextValue,
          maintenanceMessage: siteControls.maintenanceMessage,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (nextValue ? 'Site açıldı.' : 'Site bakım moduna alındı.')
              : (actionState.message ?? 'Site durumu güncellenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleCreateDbBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final labelController = TextEditingController(text: 'manual');
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Veritabani yedegi olustur'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminInfoBanner(
                  title: 'Operasyon notu',
                  body:
                      'Anlamli bir label kullanmak geri donus operasyonlarini kolaylastirir.',
                  tone: Theme.of(dialogContext).sdal.info,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(labelController.text.trim()),
              child: const Text('Olustur'),
            ),
          ],
        );
      },
    );
    labelController.dispose();
    if (label == null || label.isEmpty || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .createDbBackup(label: label);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Veritabani yedegi olusturuldu.'
              : (actionState.message ?? 'Yedek olusturulamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleCopyDbData(
    BuildContext context,
    WidgetRef ref,
    AdminDbDriverStatusSnapshot driver,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Veriyi kopyala'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${driver.currentDriver} -> ${driver.targetDriver}'),
                const SizedBox(height: 12),
                const _AdminInfoBanner(
                  title: 'Bakım penceresi önerilir',
                  body:
                      'Buyuk veri setlerinde islem uzun surebilir. Canli ortamda trafik dusukken calistirin.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Baslat'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .copyDbData(
          sourceDriver: driver.currentDriver,
          targetDriver: driver.targetDriver,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Veri kopyalama baslatildi.'
              : (actionState.message ?? 'Veri kopyalama baslatilamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleLanguageSelectionToggle(
    BuildContext context,
    WidgetRef ref,
    AdminLanguageConfigSnapshot config,
    bool enabled,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .updateLanguageSelection(
          enabled: enabled,
          defaultOpen: config.defaultOpen,
          defaultClosed: config.defaultClosed,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Dil seçimi ayarı güncellendi.'
              : (actionState.message ?? 'Dil secimi ayari kaydedilemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleLanguageToggle(
    BuildContext context,
    WidgetRef ref,
    AdminLanguageItem item,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .toggleLanguageActive(item: item);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (item.isActive ? 'Dil pasife alindi.' : 'Dil aktive edildi.')
              : (actionState.message ?? 'Dil güncellenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleLanguageDelete(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Dili sil'),
          content: Text('$code dili ve ilgili çeviri kayıtları silinecek.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deleteLanguage(code: code);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Dil silindi.' : (actionState.message ?? 'Dil silinemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleAddLanguage(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final nativeNameController = TextEditingController();
    final payload = await showDialog<(String, String, String)?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yeni dil ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Kod'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nativeNameController,
                decoration: const InputDecoration(labelText: 'Native ad'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((
                codeController.text.trim(),
                nameController.text.trim(),
                nativeNameController.text.trim(),
              )),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
    codeController.dispose();
    nameController.dispose();
    nativeNameController.dispose();
    if (payload == null || !context.mounted) return;
    final (code, name, nativeName) = payload;
    if (code.isEmpty || name.isEmpty || nativeName.isEmpty) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .addLanguage(code: code, name: name, nativeName: nativeName);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Dil eklendi.' : (actionState.message ?? 'Dil eklenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleFillMissingLanguageStrings(
    BuildContext context,
    WidgetRef ref,
    String lang,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .fillMissingLanguageStrings(lang: lang);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Eksik çeviriler dolduruldu.'
              : (actionState.message ?? 'Eksik çeviriler doldurulamadı.'),
        ),
      ),
    );
  }

  Future<void> _handleEditLanguageString(
    BuildContext context,
    WidgetRef ref,
    AdminLanguageStringItem item,
  ) async {
    final controller = TextEditingController(text: item.value);
    final nextValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(item.key),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(labelText: item.langCode),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nextValue == null || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .saveLanguageString(
          lang: item.langCode,
          key: item.key,
          value: nextValue,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Çeviri kaydedildi.'
              : (actionState.message ?? 'Çeviri kaydedilemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleAddPage(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final iconController = TextEditingController(text: 'yok');
    final payload = await showDialog<(String, String, String)?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sayfa ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Sayfa adi'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Resim / ikon'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((
                nameController.text.trim(),
                urlController.text.trim(),
                iconController.text.trim(),
              )),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    urlController.dispose();
    iconController.dispose();
    if (payload == null || !context.mounted) return;
    final (name, url, icon) = payload;
    if (name.isEmpty || url.isEmpty) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .addPage(name: name, url: url, icon: icon.isEmpty ? 'yok' : icon);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Sayfa eklendi.' : (actionState.message ?? 'Sayfa eklenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleDeletePage(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deletePage(id: id);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Sayfa silindi.' : (actionState.message ?? 'Sayfa silinemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleAddEmailCategory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final valueController = TextEditingController();
    final descriptionController = TextEditingController();
    final payload = await showDialog<(String, String, String, String)?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('E-posta kategorisi ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Tur'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Deger'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((
                nameController.text.trim(),
                typeController.text.trim(),
                valueController.text.trim(),
                descriptionController.text.trim(),
              )),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    typeController.dispose();
    valueController.dispose();
    descriptionController.dispose();
    if (payload == null || !context.mounted) return;
    final (name, type, value, description) = payload;
    if (name.isEmpty || type.isEmpty) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .addEmailCategory(
          name: name,
          type: type,
          value: value,
          description: description,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'E-posta kategorisi eklendi.'
              : (actionState.message ?? 'Kategori eklenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleDeleteEmailCategory(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deleteEmailCategory(id: id);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'E-posta kategorisi silindi.'
              : (actionState.message ?? 'Kategori silinemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleSwitchDbDriver(
    BuildContext context,
    WidgetRef ref,
    AdminDbDriverStatusSnapshot driver,
  ) async {
    final confirmController = TextEditingController();
    var acknowledgeSqliteDrift = false;
    var copyData = false;
    final payload = await showDialog<(String, bool, bool)?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('DB driver degistir'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminDialogSection(
                        title: 'Gecis plani',
                        subtitle:
                            'API process restart tetiklenir; prod ortaminda kontrollu pencere kullanin.',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text('Kaynak: ${driver.currentDriver}'),
                            ),
                            Chip(label: Text('Hedef: ${driver.targetDriver}')),
                            Chip(
                              label: Text(
                                driver.switchEnabled
                                    ? 'Geçiş hazır'
                                    : 'Ek kontrol gerekli',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (driver.warnings.isNotEmpty)
                        _AdminDialogSection(
                          title: 'Uyarilar',
                          child: Column(
                            children: [
                              for (final warning in driver.warnings)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AdminInfoBanner(
                                    title: 'Uyari',
                                    body: warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (driver.warnings.isNotEmpty)
                        const SizedBox(height: 10),
                      _AdminDialogSection(
                        title: 'Onay',
                        subtitle:
                            'Devam etmek icin asagidaki metni birebir yazin.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              driver.expectedConfirmText,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: confirmController,
                              decoration: const InputDecoration(
                                labelText: 'Onay metnini yaz',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AdminDialogSection(
                        title: 'Ek secenekler',
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: copyData,
                              onChanged: driver.dataCopySupported
                                  ? (value) => setState(
                                      () => copyData = value ?? false,
                                    )
                                  : null,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Veriyi hedef drivera kopyala'),
                              subtitle: const Text(
                                'Yapilandirma degisiminin yanina veri tasimasini da ekler.',
                              ),
                            ),
                            if (driver.requiresSqliteDriftAck)
                              CheckboxListTile(
                                value: acknowledgeSqliteDrift,
                                onChanged: (value) => setState(
                                  () => acknowledgeSqliteDrift = value ?? false,
                                ),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'SQLite drift riskini kabul ediyorum',
                                ),
                                subtitle: const Text(
                                  'Postgres -> SQLite donuslerinde tum yetenekler birebir korunmayabilir.',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Vazgec'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop((
                    confirmController.text.trim(),
                    acknowledgeSqliteDrift,
                    copyData,
                  )),
                  child: const Text('Gecisi baslat'),
                ),
              ],
            );
          },
        );
      },
    );
    confirmController.dispose();
    if (payload == null || !context.mounted) return;
    final (confirmText, ackDrift, copyDataValue) = payload;
    if (confirmText.isEmpty) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .switchDbDriver(
          targetDriver: driver.targetDriver,
          confirmText: confirmText,
          challengeToken: driver.challengeToken,
          acknowledgeSqliteDrift: ackDrift,
          copyData: copyDataValue,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Driver gecisi baslatildi.'
              : (actionState.message ?? 'Driver gecisi baslatilamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleRestoreBackup(
    BuildContext context,
    WidgetRef ref,
    AdminDbBackupItem item,
  ) async {
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final matches = confirmController.text.trim() == item.name;
            return AlertDialog(
              title: const Text('Yedekten geri yukle'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminInfoBanner(
                        title: 'Yuksek riskli islem',
                        body:
                            'Aktif veritabani bu backup ile degistirilir. Islemden once otomatik bir pre-restore yedegi alinmaya devam eder.',
                        tone: Theme.of(dialogContext).sdal.danger,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(height: 20),
                      _AdminDialogSection(
                        title: 'Secilen backup',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              item.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.size} byte · ${item.createdAt}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AdminDialogSection(
                        title: 'Onay',
                        subtitle:
                            'Devam etmek icin backup adini birebir yazin.',
                        child: TextField(
                          controller: confirmController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Backup adi',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgec'),
                ),
                FilledButton(
                  onPressed: matches
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Geri yukle'),
                ),
              ],
            );
          },
        );
      },
    );
    confirmController.dispose();
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .restoreDbBackupByName(name: item.name);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Geri yukleme baslatildi.'
              : (actionState.message ?? 'Geri yukleme baslatilamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleEditPage(
    BuildContext context,
    WidgetRef ref,
    AdminPageItem item,
  ) async {
    final nameController = TextEditingController(text: item.name);
    final urlController = TextEditingController(text: item.url);
    final iconController = TextEditingController(text: item.icon);
    final parentController = TextEditingController(
      text: item.parentId.toString(),
    );
    final layoutController = TextEditingController(
      text: item.layoutOption.toString(),
    );
    var menuVisible = item.menuVisible;
    var isRedirect = item.isRedirect;
    final payload =
        await showDialog<
          ({
            String icon,
            int layoutOption,
            bool menuVisible,
            String name,
            int parentId,
            bool isRedirect,
            String url,
          })?
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setState) {
                return AlertDialog(
                  title: const Text('Sayfa düzenle'),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: 560,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _AdminDialogSection(
                            title: 'Yapi',
                            subtitle:
                                'Gezinimde görünüm ve hiyerarşi ayarlarını birlikte düzenleyin.',
                            child: SizedBox.shrink(),
                          ),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Sayfa adi',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: urlController,
                            decoration: const InputDecoration(labelText: 'URL'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: iconController,
                            decoration: const InputDecoration(
                              labelText: 'Ikon',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: parentController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Parent ID',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: layoutController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Layout secenegi',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: menuVisible,
                            onChanged: (value) =>
                                setState(() => menuVisible = value ?? false),
                            title: const Text('Menüde görünsün'),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isRedirect,
                            onChanged: (value) =>
                                setState(() => isRedirect = value ?? false),
                            title: const Text('Yonlendirme sayfasi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Vazgec'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop((
                        name: nameController.text.trim(),
                        url: urlController.text.trim(),
                        icon: iconController.text.trim(),
                        parentId:
                            int.tryParse(parentController.text.trim()) ?? 0,
                        menuVisible: menuVisible,
                        isRedirect: isRedirect,
                        layoutOption:
                            int.tryParse(layoutController.text.trim()) ?? 0,
                      )),
                      child: const Text('Kaydet'),
                    ),
                  ],
                );
              },
            );
          },
        );
    nameController.dispose();
    urlController.dispose();
    iconController.dispose();
    parentController.dispose();
    layoutController.dispose();
    if (payload == null || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .updatePage(
          id: item.id,
          name: payload.name,
          url: payload.url,
          icon: payload.icon.isEmpty ? 'yok' : payload.icon,
          parentId: payload.parentId,
          menuVisible: payload.menuVisible,
          isRedirect: payload.isRedirect,
          layoutOption: payload.layoutOption,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sayfa güncellendi.'
              : (actionState.message ?? 'Sayfa güncellenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleReorderPage(
    BuildContext context,
    WidgetRef ref,
    List<AdminPageItem> pages,
    AdminPageItem item,
    int delta,
  ) async {
    final ordered = [...pages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentIndex = ordered.indexWhere((page) => page.id == item.id);
    if (currentIndex < 0) return;
    final nextIndex = currentIndex + delta;
    if (nextIndex < 0 || nextIndex >= ordered.length) return;
    final moved = ordered.removeAt(currentIndex);
    ordered.insert(nextIndex, moved);
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .reorderPages(order: ordered.map((page) => page.id).toList());
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sayfa sırası güncellendi.'
              : (actionState.message ?? 'Sayfa sırası güncellenemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleAddEmailTemplate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _showEmailTemplateDialog(context, ref);
  }

  Future<void> _handleEditEmailTemplate(
    BuildContext context,
    WidgetRef ref,
    AdminEmailTemplateItem item,
  ) async {
    await _showEmailTemplateDialog(context, ref, existing: item);
  }

  Future<void> _showEmailTemplateDialog(
    BuildContext context,
    WidgetRef ref, {
    AdminEmailTemplateItem? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final subjectController = TextEditingController(
      text: existing?.subject ?? '',
    );
    final bodyController = TextEditingController(
      text: existing?.bodyHtml ?? '',
    );
    final payload = await showDialog<(String, String, String)?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Şablon ekle' : 'Şablon düzenle'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminDialogSection(
                    title: 'Şablon kimliği',
                    subtitle: 'Baslik ve konu, listede hizli ayrisim saglar.',
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Ad'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: subjectController,
                          decoration: const InputDecoration(labelText: 'Konu'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _AdminDialogSection(
                    title: 'Govde',
                    subtitle:
                        'HTML govdeyi burada saklayip toplu gonderimde tekrar kullanabilirsiniz.',
                    child: TextField(
                      controller: bodyController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'HTML govde',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((
                nameController.text.trim(),
                subjectController.text.trim(),
                bodyController.text,
              )),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    subjectController.dispose();
    bodyController.dispose();
    if (payload == null || !context.mounted) return;
    final (name, subject, bodyHtml) = payload;
    if (name.isEmpty || subject.isEmpty || bodyHtml.trim().isEmpty) return;
    final notifier = ref.read(adminActionControllerProvider.notifier);
    final ok = existing == null
        ? await notifier.addEmailTemplate(
            name: name,
            subject: subject,
            bodyHtml: bodyHtml,
          )
        : await notifier.updateEmailTemplate(
            id: existing.id,
            name: name,
            subject: subject,
            bodyHtml: bodyHtml,
          );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (existing == null ? 'Şablon eklendi.' : 'Şablon güncellendi.')
              : (actionState.message ?? 'Şablon kaydedilemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleDeleteEmailTemplate(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deleteEmailTemplate(id: id);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Şablon silindi.'
              : (actionState.message ?? 'Şablon silinemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleSendBulkEmail(
    BuildContext context,
    WidgetRef ref,
    List<AdminEmailCategoryItem> categories,
    List<AdminEmailTemplateItem> templates,
  ) async {
    if (categories.isEmpty) return;
    AdminEmailCategoryItem selectedCategory = categories.first;
    AdminEmailTemplateItem? selectedTemplate = templates.isNotEmpty
        ? templates.first
        : null;
    final subjectController = TextEditingController(
      text: selectedTemplate?.subject ?? '',
    );
    final htmlController = TextEditingController(
      text: selectedTemplate?.bodyHtml ?? '',
    );
    final fromController = TextEditingController();
    final payload =
        await showDialog<
          ({int categoryId, String from, String html, String subject})?
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setState) {
                return AlertDialog(
                  title: const Text('Toplu e-posta gonder'),
                  content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AdminInfoBanner(
                            title: 'Toplu gonderim',
                            body:
                                'Kategori seçimi alıcıları belirler. Şablon seçmek sadece gövdeyi hızlı doldurur.',
                            tone: Theme.of(dialogContext).sdal.info,
                          ),
                          const SizedBox(height: 20),
                          _AdminDialogSection(
                            title: 'Alıcı ve şablon',
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: selectedCategory.id,
                                  decoration: const InputDecoration(
                                    labelText: 'Kategori',
                                  ),
                                  items: [
                                    for (final item in categories)
                                      DropdownMenuItem(
                                        value: item.id,
                                        child: Text(item.name),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    final match = categories.where(
                                      (item) => item.id == value,
                                    );
                                    if (match.isNotEmpty) {
                                      setState(
                                        () => selectedCategory = match.first,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int?>(
                                  initialValue: selectedTemplate?.id,
                                  decoration: const InputDecoration(
                                    labelText: 'Şablon',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Şablon kullanma'),
                                    ),
                                    for (final item in templates)
                                      DropdownMenuItem<int?>(
                                        value: item.id,
                                        child: Text(item.name),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    final match = templates.where(
                                      (item) => item.id == value,
                                    );
                                    setState(() {
                                      selectedTemplate = match.isEmpty
                                          ? null
                                          : match.first;
                                      if (selectedTemplate != null) {
                                        subjectController.text =
                                            selectedTemplate!.subject;
                                        htmlController.text =
                                            selectedTemplate!.bodyHtml;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _AdminDialogSection(
                            title: 'Mesaj',
                            child: Column(
                              children: [
                                TextField(
                                  controller: fromController,
                                  decoration: const InputDecoration(
                                    labelText: 'Kimden',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: subjectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Konu',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: htmlController,
                                  maxLines: 10,
                                  decoration: const InputDecoration(
                                    labelText: 'HTML govde',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Vazgec'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop((
                        categoryId: selectedCategory.id,
                        from: fromController.text.trim(),
                        subject: subjectController.text.trim(),
                        html: htmlController.text,
                      )),
                      child: const Text('Gonder'),
                    ),
                  ],
                );
              },
            );
          },
        );
    subjectController.dispose();
    htmlController.dispose();
    fromController.dispose();
    if (payload == null || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .sendBulkEmail(
          categoryId: payload.categoryId,
          subject: payload.subject,
          html: payload.html,
          from: payload.from,
        );
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Toplu e-posta kuyruga alindi.'
              : (actionState.message ?? 'Gonderim baslatilamadi.'),
        ),
      ),
    );
  }

  Future<void> _handleViewLogContent(
    BuildContext context,
    WidgetRef ref,
    AdminLogFileItem item,
  ) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => _AdminLogContentPage(item: item)),
    );
  }

  Future<void> _handleBulkImportLanguageStrings(
    BuildContext context,
    WidgetRef ref,
    String lang,
  ) async {
    final controller = TextEditingController(text: '{\n  \n}');
    final jsonPayload = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$lang icin bulk import'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminInfoBanner(
                  title: 'Beklenen format',
                  body:
                      'Gecerli bir JSON object beklenir. Her key string olmali ve value metne donusebilir olmalidir.',
                  tone: Theme.of(dialogContext).sdal.info,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'JSON key/value',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Ice aktar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (jsonPayload == null || !context.mounted) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonPayload);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON parse edilemedi. Gecerli obje girin.'),
        ),
      );
      return;
    }
    if (decoded is! Map) return;
    final strings = <String, String>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      strings[key] = entry.value?.toString() ?? '';
    }
    if (strings.isEmpty) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .bulkImportLanguageStrings(lang: lang, strings: strings);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Bulk import tamamlandi.'
              : (actionState.message ?? 'Bulk import basarisiz.'),
        ),
      ),
    );
  }

  Future<void> _handleDeleteLanguageKey(
    BuildContext context,
    WidgetRef ref,
    String key,
  ) async {
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .deleteLanguageKey(key: key);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Dil keyi silindi.'
              : (actionState.message ?? 'Dil keyi silinemedi.'),
        ),
      ),
    );
  }

  Future<void> _handleUserDetailEdit(
    BuildContext context,
    WidgetRef ref,
    int userId,
  ) async {
    final nextDetail = await Navigator.of(context, rootNavigator: true)
        .push<AdminUserDetail>(
          MaterialPageRoute(
            builder: (_) => _AdminUserDetailPage(userId: userId),
          ),
        );
    if (nextDetail == null || !context.mounted) return;
    final ok = await ref
        .read(adminActionControllerProvider.notifier)
        .updateUserDetail(detail: nextDetail);
    if (!context.mounted) return;
    final actionState = ref.read(adminActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kullanıcı güncellendi.'
              : (actionState.message ?? 'Kullanıcı güncellenemedi.'),
        ),
      ),
    );
  }
}

class _AdminUserDetailPage extends ConsumerWidget {
  const _AdminUserDetailPage({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(adminUserDetailProvider(userId));
    return detailState.when(
      loading: () => const FeatureScaffold(
        title: 'Kullanıcı yükleniyor',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FeatureScaffold(
        title: 'Kullanıcı yüklenemedi',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 36),
                    const SizedBox(height: 16),
                    Text(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(adminUserDetailProvider(userId)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      data: (detail) => _AdminUserDetailOverviewPage(detail: detail),
    );
  }
}

class _AdminUserDetailOverviewPage extends StatelessWidget {
  const _AdminUserDetailOverviewPage({required this.detail});

  final AdminUserDetail detail;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: '@${detail.handle}',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.tonalIcon(
            onPressed: () async {
              final nextDetail =
                  await Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push<AdminUserDetail>(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) =>
                          _AdminUserDetailEditFormPage(detail: detail),
                    ),
                  );
              if (nextDetail == null || !context.mounted) return;
              Navigator.of(context, rootNavigator: true).pop(nextDetail);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Düzenle'),
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('@${detail.handle}')),
                    Chip(label: Text(detail.isActive ? 'Aktif' : 'Pasif')),
                    Chip(label: Text(detail.isBanned ? 'Yasaklı' : 'Açık')),
                    if (detail.isVerified)
                      const Chip(label: Text('Doğrulanmış')),
                  ],
                ),
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Kimlik',
                  child: Column(
                    children: [
                      _AdminDetailRow(label: 'İsim', value: detail.firstName),
                      _AdminDetailRow(label: 'Soyisim', value: detail.lastName),
                      _AdminDetailRow(label: 'E-posta', value: detail.email),
                      _AdminDetailRow(
                        label: 'Aktivasyon kodu',
                        value: detail.activationToken,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Profil',
                  child: Column(
                    children: [
                      _AdminDetailRow(
                        label: 'Mezuniyet yılı',
                        value: detail.graduationYear,
                      ),
                      _AdminDetailRow(
                        label: 'Üniversite',
                        value: detail.university,
                      ),
                      _AdminDetailRow(
                        label: 'Meslek',
                        value: detail.profession,
                      ),
                      _AdminDetailRow(label: 'Şehir', value: detail.city),
                      _AdminDetailRow(label: 'Website', value: detail.website),
                      _AdminDetailRow(label: 'Avatar', value: detail.avatar),
                    ],
                  ),
                ),
                if (detail.signature.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _AdminDialogSection(
                    title: 'İmza özeti',
                    subtitle:
                        'Uzun metin alanları yalnızca düzenleme ekranında tam olarak açılır.',
                    child: _AdminDetailMultilineValue(
                      value: detail.signature,
                      maxChars: 320,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Durum',
                  child: Column(
                    children: [
                      _AdminDetailRow(
                        label: 'Profil başlangıcı tamam',
                        value: detail.isProfileInitialized ? 'Evet' : 'Hayır',
                      ),
                      _AdminDetailRow(
                        label: 'E-posta gizli',
                        value: detail.isEmailHidden ? 'Evet' : 'Hayır',
                      ),
                      _AdminDetailRow(
                        label: 'Profil hit',
                        value: detail.profileViewCount.toString(),
                      ),
                      _AdminDetailRow(
                        label: 'Doğum tarihi',
                        value: [
                          detail.birthDay,
                          detail.birthMonth,
                          detail.birthYear,
                        ].where((item) => item.trim().isNotEmpty).join('/'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserDetailEditFormPage extends StatefulWidget {
  const _AdminUserDetailEditFormPage({required this.detail});

  final AdminUserDetail detail;

  @override
  State<_AdminUserDetailEditFormPage> createState() =>
      _AdminUserDetailEditFormPageState();
}

class _AdminUserDetailEditFormPageState
    extends State<_AdminUserDetailEditFormPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _activationController;
  late final TextEditingController _professionController;
  late final TextEditingController _cityController;
  late final TextEditingController _websiteController;
  late final TextEditingController _universityController;
  late final TextEditingController _graduationController;
  late final TextEditingController _avatarController;
  late final TextEditingController _signatureController;
  late final TextEditingController _hitController;
  late final TextEditingController _birthDayController;
  late final TextEditingController _birthMonthController;
  late final TextEditingController _birthYearController;

  late bool _isActive;
  late bool _isBanned;
  late bool _isProfileInitialized;
  late bool _isEmailHidden;
  late bool _isVerified;

  AdminUserDetail get _detail => widget.detail;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: _detail.firstName);
    _lastNameController = TextEditingController(text: _detail.lastName);
    _emailController = TextEditingController(text: _detail.email);
    _activationController = TextEditingController(
      text: _detail.activationToken,
    );
    _professionController = TextEditingController(text: _detail.profession);
    _cityController = TextEditingController(text: _detail.city);
    _websiteController = TextEditingController(text: _detail.website);
    _universityController = TextEditingController(text: _detail.university);
    _graduationController = TextEditingController(text: _detail.graduationYear);
    _avatarController = TextEditingController(text: _detail.avatar);
    _signatureController = TextEditingController(text: _detail.signature);
    _hitController = TextEditingController(
      text: _detail.profileViewCount.toString(),
    );
    _birthDayController = TextEditingController(text: _detail.birthDay);
    _birthMonthController = TextEditingController(text: _detail.birthMonth);
    _birthYearController = TextEditingController(text: _detail.birthYear);

    _isActive = _detail.isActive;
    _isBanned = _detail.isBanned;
    _isProfileInitialized = _detail.isProfileInitialized;
    _isEmailHidden = _detail.isEmailHidden;
    _isVerified = _detail.isVerified;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _activationController.dispose();
    _professionController.dispose();
    _cityController.dispose();
    _websiteController.dispose();
    _universityController.dispose();
    _graduationController.dispose();
    _avatarController.dispose();
    _signatureController.dispose();
    _hitController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  void _close([AdminUserDetail? result]) {
    Navigator.of(context).pop(result);
  }

  AdminUserDetail _buildResult() {
    return AdminUserDetail(
      id: _detail.id,
      handle: _detail.handle,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      activationToken: _activationController.text.trim(),
      isActive: _isActive,
      isBanned: _isBanned,
      isProfileInitialized: _isProfileInitialized,
      website: _websiteController.text.trim(),
      signature: _signatureController.text,
      profession: _professionController.text.trim(),
      city: _cityController.text.trim(),
      isEmailHidden: _isEmailHidden,
      profileViewCount: int.tryParse(_hitController.text.trim()) ?? 0,
      isVerified: _isVerified,
      graduationYear: _graduationController.text.trim(),
      university: _universityController.text.trim(),
      birthDay: _birthDayController.text.trim(),
      birthMonth: _birthMonthController.text.trim(),
      birthYear: _birthYearController.text.trim(),
      avatar: _avatarController.text.trim().isEmpty
          ? 'yok'
          : _avatarController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: '@${_detail.handle}',
      actions: [
        TextButton(onPressed: () => _close(), child: const Text('Vazgeç')),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: () => _close(_buildResult()),
            child: const Text('Kaydet'),
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('@${_detail.handle}')),
                    Chip(label: Text(_isActive ? 'Aktif' : 'Pasif')),
                    if (_isVerified) const Chip(label: Text('Doğrulanmış')),
                  ],
                ),
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Kimlik',
                  child: Column(
                    children: [
                      TextField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'İsim'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Soyisim'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'E-posta'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _activationController,
                        decoration: const InputDecoration(
                          labelText: 'Aktivasyon kodu',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Profil',
                  child: Column(
                    children: [
                      TextField(
                        controller: _professionController,
                        decoration: const InputDecoration(labelText: 'Meslek'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Şehir'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _websiteController,
                        decoration: const InputDecoration(labelText: 'Website'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _universityController,
                        decoration: const InputDecoration(
                          labelText: 'Üniversite',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _graduationController,
                        decoration: const InputDecoration(
                          labelText: 'Mezuniyet yılı',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _avatarController,
                        decoration: const InputDecoration(labelText: 'Avatar'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _signatureController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'İmza'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Sayısal alanlar ve doğum tarihi',
                  child: Column(
                    children: [
                      TextField(
                        controller: _hitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hit'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _birthDayController,
                              decoration: const InputDecoration(
                                labelText: 'Gün',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _birthMonthController,
                              decoration: const InputDecoration(
                                labelText: 'Ay',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _birthYearController,
                              decoration: const InputDecoration(
                                labelText: 'Yıl',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _AdminDialogSection(
                  title: 'Durum flagleri',
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (value) =>
                            setState(() => _isActive = value ?? false),
                        title: const Text('Aktif'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isBanned,
                        onChanged: (value) =>
                            setState(() => _isBanned = value ?? false),
                        title: const Text('Yasaklı'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isProfileInitialized,
                        onChanged: (value) => setState(
                          () => _isProfileInitialized = value ?? false,
                        ),
                        title: const Text('İlk profil adımı tamam'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isEmailHidden,
                        onChanged: (value) =>
                            setState(() => _isEmailHidden = value ?? false),
                        title: const Text('E-posta gizli'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isVerified,
                        onChanged: (value) =>
                            setState(() => _isVerified = value ?? false),
                        title: const Text('Doğrulanmış'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLogContentPage extends ConsumerWidget {
  const _AdminLogContentPage({required this.item});

  final AdminLogFileItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotState = ref.watch(
      adminLogContentProvider((type: item.type, file: item.name)),
    );
    return snapshotState.when(
      loading: () => FeatureScaffold(
        title: item.name,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FeatureScaffold(
        title: item.name,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 36),
                    const SizedBox(height: 16),
                    Text(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(
                        adminLogContentProvider((
                          type: item.type,
                          file: item.name,
                        )),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      data: (snapshot) => FeatureScaffold(
        title: item.name,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Toplam: ${snapshot.total}')),
                      Chip(label: Text('Eşleşen: ${snapshot.matched}')),
                      Chip(label: Text('Dönen: ${snapshot.returned}')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).sdal.panelRaised,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      snapshot.content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSectionCard extends StatelessWidget {
  const _AdminSectionCard({required this.section});

  final _AdminSection section;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/admin/${section.key}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _adminToneColor(
                  context,
                  section.tone,
                ).withValues(alpha: 0.16),
                foregroundColor: _adminToneColor(context, section.tone),
                child: Icon(section.icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).sdal.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStatChip extends StatelessWidget {
  const _AdminStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _AdminAsyncCard extends StatelessWidget {
  const _AdminAsyncCard({
    required this.title,
    required this.states,
    required this.builder,
  });

  final String title;
  final List<AsyncValue<Object?>> states;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    Object? error;
    for (final state in states) {
      if (state.hasError) {
        error = state.error;
        break;
      }
    }
    final isLoading = states.any((state) => state.isLoading);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (error != null)
            Text('Bir hata oluştu.')
          else if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            builder(),
        ],
      ),
    );
  }
}

class _AdminPreviewListCard extends StatelessWidget {
  const _AdminPreviewListCard({
    required this.title,
    required this.total,
    required this.children,
  });

  final String title;
  final int total;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$total kayit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).sdal.foregroundMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (children.isEmpty)
            Text(
              'Kayit yok.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).sdal.foregroundMuted,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _AdminPreviewLine extends StatelessWidget {
  const _AdminPreviewLine({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.action,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingWidget = trailing.trim().isEmpty
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.sdal.panelRaised,
              borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
            ),
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.sdal.foregroundMuted,
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final metaRow = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              if (trailing.trim().isNotEmpty) trailingWidget,
              ...?action == null ? null : [action!],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: metaRow,
                    ),
                  ],
                )
              else ...[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                metaRow,
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: theme.sdal.panelBorder),
            ],
          );
        },
      ),
    );
  }
}

class _AdminDialogSection extends StatelessWidget {
  const _AdminDialogSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.sdal.foregroundMuted,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = value.trim().isEmpty ? 'Belirtilmemiş' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).sdal.foregroundMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(resolvedValue)),
        ],
      ),
    );
  }
}

class _AdminDetailMultilineValue extends StatelessWidget {
  const _AdminDetailMultilineValue({required this.value, this.maxChars = 320});

  final String value;
  final int maxChars;

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    final shortened = trimmed.characters.length > maxChars
        ? '${trimmed.characters.take(maxChars).toString()}…'
        : trimmed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).sdal.panelRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(shortened),
    );
  }
}

class _AdminInfoBanner extends StatelessWidget {
  const _AdminInfoBanner({
    required this.title,
    required this.body,
    this.tone,
    this.icon = Icons.info_outline,
  });

  final String title;
  final String body;
  final Color? tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = this.tone ?? theme.sdal.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.sdal.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDeleteButton extends StatelessWidget {
  const _AdminDeleteButton({required this.label, required this.onConfirm});

  final String label;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onConfirm,
      icon: const Icon(Icons.delete_outline),
    );
  }
}

class _AdminDecisionButtons extends StatelessWidget {
  const _AdminDecisionButtons({
    required this.onApprove,
    required this.onReject,
  });

  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Onayla',
          onPressed: onApprove,
          icon: const Icon(Icons.check_circle_outline),
        ),
        IconButton(
          tooltip: 'Reddet',
          onPressed: onReject,
          icon: const Icon(Icons.cancel_outlined),
        ),
      ],
    );
  }
}

class _AdminInlineActionRow extends StatelessWidget {
  const _AdminInlineActionRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _AdminSection {
  const _AdminSection({
    required this.key,
    required this.title,
    required this.summary,
    required this.description,
    required this.icon,
    required this.tone,
    required this.routeFile,
    required this.capabilities,
  });

  final String key;
  final String title;
  final String summary;
  final String description;
  final IconData icon;
  final _AdminTone tone;
  final String routeFile;
  final List<String> capabilities;
}

enum _AdminTone { info, warning, success, danger, experiment, accent }

Color _adminToneColor(BuildContext context, _AdminTone tone) {
  final tokens = Theme.of(context).sdal;
  return switch (tone) {
    _AdminTone.info => tokens.info,
    _AdminTone.warning => tokens.warning,
    _AdminTone.success => tokens.success,
    _AdminTone.danger => tokens.danger,
    _AdminTone.experiment => tokens.adminExperiment,
    _AdminTone.accent => tokens.accent,
  };
}

Future<void> _showAdminLoginDialog(BuildContext context, WidgetRef ref) async {
  final passwordController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Admin oturumu aç'),
      content: TextField(
        controller: passwordController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Admin sifresi',
          prefixIcon: Icon(Icons.lock_outline),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Devam et'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref
        .read(adminRepositoryProvider)
        .loginToAdmin(passwordController.text.trim());
    ref.invalidate(adminAccessProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Admin oturumu açıldı.')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı.')));
  }
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
    ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı.')));
  }
}

List<_AdminSection> _visibleAdminSections(AdminAccessSnapshot access) {
  if (!access.canOpenAdminShell) return const <_AdminSection>[];
  if (access.user?.hasAdminAccess ?? false) return _adminSections;
  final keys = access.permissions?.permissionKeys ?? const <String>[];
  final role = access.permissions?.role ?? access.user?.role ?? '';
  final isFullAccess =
      access.permissions?.isSuperModerator == true ||
      role == 'admin' ||
      role == 'root';
  if (isFullAccess) return _adminSections;

  final visibleKeys = <String>{};
  for (final key in keys) {
    if (key.contains('request') || key.contains('verify')) {
      visibleKeys.add('requests');
    }
    if (key.contains('post') ||
        key.contains('comment') ||
        key.contains('story') ||
        key.contains('group') ||
        key.contains('message')) {
      visibleKeys.add('content');
    }
    if (key.contains('member') ||
        key.contains('user') ||
        key.contains('role')) {
      visibleKeys.add('management');
    }
  }
  return _adminSections
      .where((section) => visibleKeys.contains(section.key))
      .toList(growable: false);
}

const _adminSections = <_AdminSection>[
  _AdminSection(
    key: 'management',
    title: 'Roller ve yönetim',
    summary: 'Admin oturumu, root durumu, moderatör rolleri ve izinleri.',
    description:
        'Kullanıcı rolleri, moderatör kapsam atamaları ve temel admin oturum kontrolleri burada toplanır.',
    icon: Icons.manage_accounts_outlined,
    tone: _AdminTone.info,
    routeFile: 'server/routes/adminManagementRoutes.js',
    capabilities: [
      'Admin oturumu ve root bootstrap durumu',
      'Kullanıcı rol güncelleme',
      'Moderatör kapsam ve yetki atamaları',
    ],
  ),
  _AdminSection(
    key: 'api-monitor',
    title: 'API monitörü',
    summary:
        'Seçilen kullanıcı için canlı endpoint akışlarını izleme overlayi.',
    description:
        'Admin kullanıcının seçtiği üye için son API akışını toplar ve tüm sayfalarda alttan açılıp kapanan bir izleme paneli sunar.',
    icon: Icons.radar_outlined,
    tone: _AdminTone.info,
    routeFile: 'server/routes/adminManagementRoutes.js',
    capabilities: [
      'Kullanıcı bazlı canlı API akışı',
      'Admin overlay activate / deactivate',
      'Varsayılan hedef olarak kendini izleme',
    ],
  ),
  _AdminSection(
    key: 'content',
    title: 'İçerik moderasyonu',
    summary: 'Gruplar, paylaşımlar, yorumlar, hikâyeler, sohbet ve filtreler.',
    description:
        'Topluluk içeriği üzerindeki denetim akışlarını bir araya getirir.',
    icon: Icons.shield_outlined,
    tone: _AdminTone.warning,
    routeFile: 'server/routes/adminContentModerationRoutes.js',
    capabilities: [
      'Doğrulama talepleri',
      'Gruplar, postlar, yorumlar ve hikâyeler',
      'Canlı sohbet ve mesaj denetimi',
      'İçerik filtre kuralları',
    ],
  ),
  _AdminSection(
    key: 'requests',
    title: 'Talep moderasyonu',
    summary: 'Üyelik talepleri ve öğretmen ağı bağlantı onayları.',
    description:
        'Üyelik doğrulama, talep bildirimleri ve öğretmen bağlantısı incelemeleri bu bölümdedir.',
    icon: Icons.assignment_turned_in_outlined,
    tone: _AdminTone.success,
    routeFile: 'server/routes/adminRequestModerationRoutes.js',
    capabilities: [
      'Üyelik ve mezuniyet talepleri',
      'Öğretmen ağı bağlantı review akışları',
      'Admin doğrulama işlemleri',
    ],
  ),
  _AdminSection(
    key: 'operations',
    title: 'Operasyonlar ve güvenlik',
    summary: 'Operasyonel kontroller, güvenlik ve denetim yüzeyleri.',
    description:
        'Bakım, operasyon ve güvenlik odaklı admin akışlarını tek yerde toplar.',
    icon: Icons.security_outlined,
    tone: _AdminTone.danger,
    routeFile:
        'server/routes/adminOperationsRoutes.js + adminSecurityRoutes.js',
    capabilities: [
      'Operasyonel durum kontrolleri',
      'Güvenlik odaklı admin akışlarına erişim',
      'Denetim ve koruma yüzeyleri',
    ],
  ),
  _AdminSection(
    key: 'experiments',
    title: 'Deneyler ve dashboard',
    summary: 'A/B testleri, engagement skorları ve yönetici özetleri.',
    description:
        'Deney varyantları ile yönetici panelindeki özet ve aktivite akışlarını kapsar.',
    icon: Icons.science_outlined,
    tone: _AdminTone.experiment,
    routeFile: 'server/routes/adminExperimentRoutes.js',
    capabilities: [
      'Engagement A/B yönetimi',
      'Network suggestion deneyleri',
      'Dashboard summary ve live activity',
      'Engagement score yeniden hesaplama',
    ],
  ),
  _AdminSection(
    key: 'database',
    title: 'Veritabanı',
    summary: 'Backup, restore ve aktif sürücü geçişi.',
    description:
        'Veritabanı sürücü durumu, yedekleme ve veri taşıma akışlarını kapsar.',
    icon: Icons.storage_outlined,
    tone: _AdminTone.info,
    routeFile: 'server/routes/adminDbRoutes.js',
    capabilities: [
      'Backup listesi ve indirme',
      'Restore yükleme',
      'Driver status ve switch işlemleri',
      'Veri kopyalama akışları',
    ],
  ),
  _AdminSection(
    key: 'languages',
    title: 'Diller',
    summary: 'Dil listesi, anahtarlar ve çeviri metinleri.',
    description:
        'Dil konfigürasyonu ve metin yönetimi için gerekli admin endpointlerini kapsar.',
    icon: Icons.translate_outlined,
    tone: _AdminTone.accent,
    routeFile: 'server/routes/adminLanguageRoutes.js',
    capabilities: [
      'Dil ekleme, güncelleme ve silme',
      'Dil string anahtarları ve toplu güncelleme',
      'Eksik çevirileri doldurma',
      'Dil ayarları yönetimi',
    ],
  ),
];

_AdminSection? _sectionByKey(String key) {
  for (final section in _adminSections) {
    if (section.key == key) return section;
  }
  return null;
}

// Dialog'un kendi State'i controller'ı yönetir; böylece dispose() exit
// animasyonu bitmeden çağrılmaz (controller.dispose() crash'i önlenir).
class _GraduationYearDialog extends StatefulWidget {
  const _GraduationYearDialog({required this.initialYear});

  final String initialYear;

  @override
  State<_GraduationYearDialog> createState() => _GraduationYearDialogState();
}

class _GraduationYearDialogState extends State<_GraduationYearDialog> {
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
      title: const Text('Mezuniyet yılını güncelle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Mezuniyet yılı veya Öğretmen',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
