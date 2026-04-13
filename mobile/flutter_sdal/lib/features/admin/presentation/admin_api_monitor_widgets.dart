import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/session_models.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/admin_api_monitor_controller.dart';
import '../data/admin_repository.dart';

class AdminApiMonitorSection extends ConsumerStatefulWidget {
  const AdminApiMonitorSection({super.key});

  @override
  ConsumerState<AdminApiMonitorSection> createState() =>
      _AdminApiMonitorSectionState();
}

class _AdminApiMonitorSectionState
    extends ConsumerState<AdminApiMonitorSection> {
  late final TextEditingController _searchController;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final sessionUser = session?.user;
    if (sessionUser == null) {
      return const SurfaceCard(
        child: Text('API monitoru icin aktif bir admin oturumu gerekli.'),
      );
    }

    final monitorState = ref.watch(adminApiMonitorControllerProvider);
    final controller = ref.read(adminApiMonitorControllerProvider.notifier);
    final effectiveSelection = _effectiveSelection(monitorState, sessionUser);
    final userQuery = AdminUserListQuery(
      query: _searchController.text.trim(),
      filter: 'all',
      page: _page,
      limit: 12,
    );
    final userPreviewState = ref.watch(adminUserPreviewProvider(userQuery));
    final activityState = ref.watch(
      adminUserApiActivityProvider(
        AdminApiMonitorQuery(userId: effectiveSelection.id, limit: 40),
      ),
    );
    final visibleItems = _visibleItemsFromState(activityState, monitorState);
    final availableCategories = _availableCategoriesFromState(activityState);

    return Column(
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overlay kontrolu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _SelectionBanner(
                selection: effectiveSelection,
                isSelf: monitorState.selectedUser == null,
                isEnabled: monitorState.isEnabled,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: controller.toggleEnabled,
                    icon: Icon(
                      monitorState.isEnabled
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      monitorState.isEnabled ? 'Deactivate' : 'Activate',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: monitorState.isEnabled
                        ? controller.toggleExpanded
                        : null,
                    icon: Icon(
                      monitorState.isExpanded
                          ? Icons.height_outlined
                          : Icons.vertical_align_top_outlined,
                    ),
                    label: Text(
                      monitorState.isExpanded
                          ? 'Paneli kucult'
                          : 'Paneli buyut',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.useSelfAsDefault,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Kendime don'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                monitorState.isEnabled
                    ? 'Overlay tum sayfalarda gorunur. Ust cubugu yukari veya asagi surukleyerek boyutunu elle degistirebilirsiniz.'
                    : 'Overlay su anda kapali.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).sdal.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log filtreleri',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: monitorState.showPollingRequests,
                onChanged: controller.setShowPollingRequests,
                contentPadding: EdgeInsets.zero,
                title: const Text('Periyodik GET isteklerini goster'),
                subtitle: const Text(
                  'Kapatirsan oturum, bildirim, liste yenileme gibi arka plan GET akislari gizlenir.',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in availableCategories)
                    FilterChip(
                      label: Text(_categoryLabel(category)),
                      selected: !monitorState.disabledCategories.contains(
                        category,
                      ),
                      onSelected: (_) => controller.toggleCategory(category),
                    ),
                  if (availableCategories.isNotEmpty)
                    TextButton(
                      onPressed: controller.showAllCategories,
                      child: const Text('Tumunu goster'),
                    ),
                ],
              ),
              if (visibleItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Filtre sonrasinda ${visibleItems.length} kayit gorunuyor.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).sdal.foregroundMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canli API akisi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _ActivityFeed(
                state: activityState,
                monitorState: monitorState,
                maxItems: 10,
                emptyLabel:
                    '${effectiveSelection.displayLabel} icin gosterilecek bir API kaydi bulunmadi.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Izlenecek kullaniciyi sec',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Kullanici, e-posta veya handle ara',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => setState(() => _page = 1),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: () => setState(() => _page = 1),
                    child: const Text('Ara'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _page = 1;
                    }),
                    child: const Text('Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              userPreviewState.when(
                data: (users) {
                  if (users.items.isEmpty) {
                    return const Text(
                      'Arama sonucunda secilebilir kullanici bulunmadi.',
                    );
                  }
                  return Column(
                    children: [
                      for (final item in users.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _UserSelectionRow(
                            item: item,
                            isSelected: effectiveSelection.id == item.id,
                            onSelect: () {
                              controller.selectUser(
                                AdminApiMonitorSelection.fromUserPreview(item),
                              );
                              controller.activate();
                            },
                          ),
                        ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _page > 1
                                ? () => setState(() => _page -= 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Onceki'),
                          ),
                          const Spacer(),
                          Text('Sayfa $_page'),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: users.items.length >= userQuery.limit
                                ? () => setState(() => _page += 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Sonraki'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, _) => Text(error.toString()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminApiMonitorOverlayHost extends ConsumerWidget {
  const AdminApiMonitorOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final sessionUser = session?.user;
    final monitorState = ref.watch(adminApiMonitorControllerProvider);

    if (sessionUser == null ||
        !sessionUser.isAdmin ||
        !monitorState.isEnabled) {
      return child;
    }

    final selection = _effectiveSelection(monitorState, sessionUser);
    final activityState = ref.watch(
      adminUserApiActivityProvider(
        AdminApiMonitorQuery(
          userId: selection.id,
          limit: monitorState.isExpanded ? 80 : 28,
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 72),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: _OverlayPanel(
                  selection: selection,
                  state: activityState,
                  monitorState: monitorState,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayPanel extends ConsumerWidget {
  const _OverlayPanel({
    required this.selection,
    required this.state,
    required this.monitorState,
  });

  final AdminApiMonitorSelection selection;
  final AsyncValue<AdminApiMonitorSnapshot> state;
  final AdminApiMonitorState monitorState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(adminApiMonitorControllerProvider.notifier);
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = (screenHeight * monitorState.panelHeightFactor).clamp(
      150.0,
      screenHeight * 0.8,
    );
    final categories = _availableCategoriesFromState(state);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: panelHeight,
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  controller.adjustPanelHeightFactor(
                    -(details.delta.dy / screenHeight),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).sdal.panelBorder,
                          borderRadius: BorderRadius.circular(
                            SdalThemeTokens.radiusPill,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Canli API akisi · ${selection.displayLabel}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: monitorState.isExpanded
                            ? 'Paneli kucult'
                            : 'Paneli buyut',
                        child: IconButton(
                          onPressed: controller.toggleExpanded,
                          icon: Icon(
                            monitorState.isExpanded
                                ? Icons.unfold_less_outlined
                                : Icons.unfold_more_outlined,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Paneli kapat',
                        child: IconButton(
                          onPressed: controller.deactivate,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Periyodik GET'),
                          selected: monitorState.showPollingRequests,
                          onSelected: controller.setShowPollingRequests,
                        ),
                        for (final category in categories)
                          FilterChip(
                            label: Text(_categoryLabel(category)),
                            selected: !monitorState.disabledCategories.contains(
                              category,
                            ),
                            onSelected: (_) =>
                                controller.toggleCategory(category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kategori filtreleri acik/kapali yapilabilir. Log satirlarini yukari-asagi surukleyerek daha cok alan acabilirsiniz.',
                      style: _logMetaStyle(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: SingleChildScrollView(
                    child: _ActivityFeed(
                      state: state,
                      monitorState: monitorState,
                      maxItems: monitorState.isExpanded ? 18 : 5,
                      compact: true,
                      emptyLabel: 'Gosterilecek log bulunmadi.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({
    required this.selection,
    required this.isSelf,
    required this.isEnabled,
  });

  final AdminApiMonitorSelection selection;
  final bool isSelf;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEnabled ? tokens.infoMuted : tokens.panelMuted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selection.displayLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${selection.name} · ${selection.role}${isSelf ? ' · varsayilan hedef' : ''}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

class _UserSelectionRow extends StatelessWidget {
  const _UserSelectionRow({
    required this.item,
    required this.isSelected,
    required this.onSelect,
  });

  final AdminUserPreviewItem item;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? tokens.successMuted : tokens.panelRaised,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.handle.isNotEmpty ? '@${item.handle}' : item.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.name} · ${item.role} · ${item.email}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: isSelected ? null : onSelect,
            icon: Icon(
              isSelected ? Icons.check_circle_outline : Icons.radar_outlined,
            ),
            label: Text(isSelected ? 'Secili' : 'Izle'),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({
    required this.state,
    required this.monitorState,
    required this.maxItems,
    required this.emptyLabel,
    this.compact = false,
  });

  final AsyncValue<AdminApiMonitorSnapshot> state;
  final AdminApiMonitorState monitorState;
  final int maxItems;
  final String emptyLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (snapshot) {
        final items = _filterItems(snapshot.items, monitorState);
        if (items.isEmpty) {
          return Text(emptyLabel, style: _logTextStyle(context));
        }
        return Column(
          children: [
            for (final item in items.take(maxItems))
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                child: _ActivityRow(item: item, compact: compact),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) =>
          Text(error.toString(), style: _logTextStyle(context)),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.compact});

  final AdminApiMonitorActivityItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final description = _describeActivity(item);
    final statusColor = item.isSuccessful
        ? tokens.success
        : (item.status >= 400 ? tokens.danger : tokens.warning);
    final payload = _bodyPreview(item.bodySummary);
    final pollingLabel = _isPollingCandidate(item) ? ' · Periyodik GET' : '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: compact ? tokens.panelRaised : tokens.panelMuted,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusSm),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description.title, style: _logTitleStyle(context)),
                const SizedBox(height: 4),
                Text(
                  '${description.subtitle}$pollingLabel',
                  style: _logMetaStyle(context),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.method} ${item.path}',
                  style: _logMonoStyle(context),
                ),
                if (item.query.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Query: ${item.query}', style: _logMetaStyle(context)),
                ],
                if (payload != null && payload.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Icerik: $payload', style: _logTextStyle(context)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.status}',
                style: _logTitleStyle(
                  context,
                ).copyWith(color: statusColor, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('${item.durationMs} ms', style: _logMetaStyle(context)),
              const SizedBox(height: 4),
              Text(_timeLabel(item.at), style: _logMetaStyle(context)),
              const SizedBox(height: 4),
              Text(
                _categoryLabel(_activityCategory(item)),
                style: _logMetaStyle(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApiActivityDescription {
  const _ApiActivityDescription({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

AdminApiMonitorSelection _effectiveSelection(
  AdminApiMonitorState state,
  SessionUser sessionUser,
) {
  return state.selectedUser ??
      AdminApiMonitorSelection(
        id: sessionUser.id,
        name: sessionUser.displayName,
        handle: sessionUser.kadi,
        role: sessionUser.role,
      );
}

_ApiActivityDescription _describeActivity(AdminApiMonitorActivityItem item) {
  final domain = _domainLabelForPath(item.path);
  final payload = _bodyPreview(item.bodySummary);
  final action = switch (item.method) {
    'GET' => '$domain verisi cekildi',
    'POST' => '$domain icin yeni islem gonderildi',
    'PUT' => '$domain kaydi guncellendi',
    'PATCH' => '$domain parcali guncellendi',
    'DELETE' => '$domain kaydi silme istegi gonderildi',
    _ => '$domain istegi tamamlandi',
  };
  final statusText = item.status >= 400
      ? 'Sunucu bu istegi hata veya red ile cevapladi.'
      : 'Sunucudan basarili cevap alindi.';
  final subtitle = payload == null || payload.isEmpty
      ? statusText
      : '$statusText Icerik ozeti mevcut.';
  return _ApiActivityDescription(title: action, subtitle: subtitle);
}

List<AdminApiMonitorActivityItem> _filterItems(
  List<AdminApiMonitorActivityItem> items,
  AdminApiMonitorState monitorState,
) {
  return items
      .where((item) {
        if (!monitorState.showPollingRequests && _isPollingCandidate(item)) {
          return false;
        }
        if (monitorState.disabledCategories.contains(_activityCategory(item))) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

List<AdminApiMonitorActivityItem> _visibleItemsFromState(
  AsyncValue<AdminApiMonitorSnapshot> state,
  AdminApiMonitorState monitorState,
) {
  return state.maybeWhen(
    data: (snapshot) => _filterItems(snapshot.items, monitorState),
    orElse: () => const <AdminApiMonitorActivityItem>[],
  );
}

List<String> _availableCategoriesFromState(
  AsyncValue<AdminApiMonitorSnapshot> state,
) {
  return state.maybeWhen(
    data: (snapshot) {
      final categories =
          snapshot.items.map(_activityCategory).toSet().toList(growable: false)
            ..sort();
      return categories;
    },
    orElse: () => const <String>[],
  );
}

String _activityCategory(AdminApiMonitorActivityItem item) {
  final path = item.path;
  if (path.startsWith('/api/auth/') || path.startsWith('/api/login')) {
    return 'auth';
  }
  if (path.startsWith('/api/profile')) return 'profile';
  if (path.startsWith('/api/new/chat')) return 'chat';
  if (path.startsWith('/api/new/messages') ||
      path.startsWith('/api/messages')) {
    return 'messaging';
  }
  if (path.startsWith('/api/new/notifications') ||
      path.startsWith('/api/notifications') ||
      path.startsWith('/api/new/mobile/push/')) {
    return 'notifications';
  }
  if (path.startsWith('/api/new/requests') ||
      path.startsWith('/api/module-access-requests')) {
    return 'requests';
  }
  if (path.startsWith('/api/new/jobs') ||
      path.startsWith('/api/new/opportunities')) {
    return 'opportunities';
  }
  if (path.startsWith('/api/new/admin/') || path.startsWith('/api/admin/')) {
    return 'admin';
  }
  if (path.startsWith('/api/new/groups') ||
      path.startsWith('/api/groups') ||
      path.startsWith('/api/feed') ||
      path.startsWith('/api/new/posts')) {
    return 'social';
  }
  if (path.startsWith('/api/media') || path.startsWith('/api/upload')) {
    return 'media';
  }
  if (path == '/api/session' || path == '/api/site-access') return 'system';
  return 'other';
}

String _categoryLabel(String category) {
  return switch (category) {
    'auth' => 'Kimlik',
    'profile' => 'Profil',
    'chat' => 'Canli sohbet',
    'messaging' => 'Mesajlar',
    'notifications' => 'Bildirimler',
    'requests' => 'Talepler',
    'opportunities' => 'Firsatlar',
    'admin' => 'Admin',
    'social' => 'Topluluk',
    'media' => 'Medya',
    'system' => 'Sistem',
    _ => 'Diger',
  };
}

bool _isPollingCandidate(AdminApiMonitorActivityItem item) {
  if (item.method != 'GET') return false;
  const pollingPrefixes = <String>[
    '/api/session',
    '/api/site-access',
    '/api/new/chat/messages',
    '/api/new/messages',
    '/api/messages',
    '/api/new/notifications',
    '/api/notifications',
    '/api/new/request-categories',
    '/api/new/requests/my',
    '/api/feed',
  ];
  return pollingPrefixes.any(item.path.startsWith);
}

String _domainLabelForPath(String path) {
  if (path == '/api/session') return 'Oturum';
  if (path == '/api/site-access') return 'Site erisim durumu';
  if (path.startsWith('/api/profile')) return 'Profil';
  if (path.startsWith('/api/auth/')) return 'Kimlik dogrulama';
  if (path.startsWith('/api/new/chat')) return 'Canli sohbet';
  if (path.startsWith('/api/new/requests')) return 'Talep yonetimi';
  if (path.startsWith('/api/module-access-requests')) {
    return 'Modul erisim talebi';
  }
  if (path.startsWith('/api/new/jobs')) return 'Is ilanlari';
  if (path.startsWith('/api/new/opportunities')) return 'Firsatlar';
  if (path.startsWith('/api/new/admin/')) return 'Admin paneli';
  if (path.startsWith('/api/admin/')) return 'Admin islemi';
  if (path.startsWith('/api/new/mobile/push/')) return 'Push bildirim';
  if (path.startsWith('/api/new/messages') ||
      path.startsWith('/api/messages')) {
    return 'Mesajlasma';
  }
  if (path.startsWith('/api/new/notifications') ||
      path.startsWith('/api/notifications')) {
    return 'Bildirimler';
  }
  if (path.startsWith('/api/new/groups') || path.startsWith('/api/groups')) {
    return 'Gruplar';
  }
  if (path.startsWith('/api/new/network') || path.startsWith('/api/network')) {
    return 'Networking';
  }
  if (path.startsWith('/api/new/')) {
    final segments = Uri.parse(path).pathSegments;
    if (segments.length >= 3) {
      return _humanizeSegment(segments[2]);
    }
  }
  final segments = Uri.parse(path).pathSegments;
  if (segments.length >= 2) return _humanizeSegment(segments[1]);
  return 'API';
}

String _humanizeSegment(String value) {
  final normalized = value.replaceAll('-', ' ').replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'API';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String? _bodyPreview(Object? raw) {
  if (raw == null) return null;
  if (raw is String) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.isEmpty ? null : text;
  }
  if (raw is num || raw is bool) return raw.toString();
  if (raw is List) {
    final items = raw
        .map(_bodyPreview)
        .whereType<String>()
        .toList(growable: false);
    if (items.isEmpty) return null;
    return items.join(', ');
  }
  if (raw is Map) {
    const preferredKeys = <String>[
      'message',
      'body',
      'content',
      'text',
      'caption',
      'subject',
      'title',
      'html',
      'status',
    ];
    for (final key in preferredKeys) {
      final match = raw.entries.where(
        (entry) => entry.key.toString().toLowerCase() == key,
      );
      for (final entry in match) {
        final value = _bodyPreview(entry.value);
        if (value != null && value.isNotEmpty) {
          return '${entry.key}: $value';
        }
      }
    }

    final compact = <String>[];
    for (final entry in raw.entries.take(5)) {
      final value = _bodyPreview(entry.value);
      if (value == null || value.isEmpty) continue;
      compact.add('${entry.key}: $value');
    }
    if (compact.isEmpty) return null;
    final joined = compact.join(' · ');
    if (joined.length <= 220) return joined;
    return jsonEncode(raw).replaceAll(RegExp(r'\s+'), ' ').substring(0, 220);
  }
  return raw.toString();
}

String _timeLabel(String raw) {
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  final ss = parsed.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

TextStyle _logTitleStyle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.bodyMedium!.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700);
}

TextStyle _logTextStyle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.bodySmall!.copyWith(fontSize: 11.5, height: 1.3);
}

TextStyle _logMetaStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(
    fontSize: 10.8,
    height: 1.25,
    color: Theme.of(context).sdal.foregroundMuted,
  );
}

TextStyle _logMonoStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(
    fontSize: 10.8,
    height: 1.2,
    fontFamily: 'monospace',
  );
}
