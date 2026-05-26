import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../data/admin_quick_access_store.dart';
import '../data/admin_repository.dart';
import 'widgets/admin_mobile_widgets.dart';

class AdminControlCenterPage extends ConsumerStatefulWidget {
  const AdminControlCenterPage({super.key});

  @override
  ConsumerState<AdminControlCenterPage> createState() =>
      _AdminControlCenterPageState();
}

class _AdminControlCenterPageState
    extends ConsumerState<AdminControlCenterPage> {
  final _searchController = TextEditingController();
  List<String> _quickAccessIds = AdminQuickAccessStore.defaultQuickAccessIds;
  bool _quickAccessLoaded = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadQuickAccess());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuickAccess() async {
    final store = await AdminQuickAccessStore.create();
    final ids = await store.load();
    if (!mounted) return;
    setState(() {
      _quickAccessIds = ids;
      _quickAccessLoaded = true;
    });
  }

  Future<void> _saveQuickAccess(List<String> ids) async {
    setState(() => _quickAccessIds = ids);
    final store = await AdminQuickAccessStore.create();
    await store.save(ids);
  }

  Future<void> _toggleQuickAccess(String id) {
    final next = [..._quickAccessIds];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.insert(0, id);
      if (next.length > 12) next.removeRange(12, next.length);
    }
    return _saveQuickAccess(next);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final user = session?.user;
    if (user == null || !user.hasAdminAccess) {
      return const FeatureScaffold(
        title: 'Yönetim',
        background: FeatureScaffoldBackground.utility,
        child: Center(
          child: AdminEmptyState(
            icon: Icons.lock_outline,
            title: 'Yetki gerekli',
            message: 'Bu alan yalnızca yönetim yetkisi olan hesaplara açık.',
          ),
        ),
      );
    }

    final accessState = ref.watch(adminEffectiveAccessProvider);
    final summaryState = ref.watch(adminMobileSummaryProvider);
    final controls = ref.watch(adminSiteControlsProvider).value;

    return FeatureScaffold(
      title: 'Yönetim',
      background: FeatureScaffoldBackground.utility,
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(adminEffectiveAccessProvider);
            ref.invalidate(adminMobileSummaryProvider);
            ref.invalidate(adminSiteControlsProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: accessState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AdminEmptyState(
              icon: Icons.lock_outline,
              title: 'Yönetim yetkisi doğrulanamadı',
              message: error.toString(),
            ),
          ),
        ),
        data: (access) {
          final summary = summaryState.value;
          final items = _availableItems(access);
          final filteredItems = _filteredItems(items, _query);
          final recommendedIds = _recommendedIds(
            items,
            summary,
            controls,
            access,
          );
          final quickItems = _quickAccessIds
              .map((id) => _itemById(items, id))
              .whereType<_AdminConsoleItem>()
              .toList(growable: false);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _CommandHeader(
                    access: access,
                    summary: summary,
                    controls: controls,
                    onSearchChanged: (value) =>
                        setState(() => _query = value.trim()),
                    searchController: _searchController,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuickAccessPanel(
                    items: quickItems,
                    recommended: recommendedIds
                        .map((id) => _itemById(items, id))
                        .whereType<_AdminConsoleItem>()
                        .toList(growable: false),
                    loaded: _quickAccessLoaded,
                    pinnedIds: _quickAccessIds,
                    onOpen: (item) => _openItem(context, item),
                    onTogglePinned: (id) => unawaited(_toggleQuickAccess(id)),
                  ),
                ),
              ),
              if ((summary?.attention ?? const <AdminAttentionItem>[])
                  .isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _AttentionPanel(
                      attention: summary!.attention,
                      onOpenPath: (path) => _openPath(context, path),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SystemSnapshotPanel(summary: summary),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: _query.isEmpty ? 'Yönetim alanları' : 'Sonuçlar',
                    subtitle: _query.isEmpty
                        ? 'Backend yüzeyleri iş mantığına göre gruplanır.'
                        : '${filteredItems.length} alan bulundu.',
                  ),
                ),
              ),
              if (filteredItems.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: AdminEmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'Sonuç yok',
                      message: 'Farklı bir yönetim alanı veya işlem adı ara.',
                    ),
                  ),
                )
              else
                for (final group in _groupItems(filteredItems).entries)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    sliver: SliverToBoxAdapter(
                      child: _ConsoleGroup(
                        title: group.key,
                        items: group.value,
                        pinnedIds: _quickAccessIds,
                        onOpen: (item) => _openItem(context, item),
                        onTogglePinned: (id) =>
                            unawaited(_toggleQuickAccess(id)),
                      ),
                    ),
                  ),
              if ((summary?.recentAudit ?? const <AdminAuditLogItem>[])
                  .isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: _AuditPanel(items: summary!.recentAudit),
                  ),
                )
              else
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }

  List<_AdminConsoleItem> _availableItems(AdminEffectiveAccessSnapshot access) {
    final role = access.user.role.trim().toLowerCase();
    final root = role == 'root';
    final broadAdmin = root || role == 'admin' || access.user.isAdmin;
    final allowedPaths = access.modules.map((item) => item.path).toSet();
    return _adminConsoleItems
        .where((item) {
          if (item.rootOnly && !root) return false;
          if (broadAdmin) return true;
          if (allowedPaths.contains(item.path)) return true;
          if (item.permissions.isEmpty) return true;
          return item.permissions.any(access.can);
        })
        .toList(growable: false);
  }

  List<_AdminConsoleItem> _filteredItems(
    List<_AdminConsoleItem> items,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return items;
    return items
        .where((item) => item.searchText.contains(normalized))
        .toList(growable: false);
  }

  List<String> _recommendedIds(
    List<_AdminConsoleItem> items,
    AdminMobileSummarySnapshot? summary,
    AdminSiteControlsSnapshot? controls,
    AdminEffectiveAccessSnapshot access,
  ) {
    final available = items.map((item) => item.id).toSet();
    final next = <String>[];
    void add(String id) {
      if (!available.contains(id) || next.contains(id)) return;
      next.add(id);
    }

    for (final item in summary?.attention ?? const <AdminAttentionItem>[]) {
      final match = items.where((entry) => entry.path == item.path).firstOrNull;
      if (match != null) add(match.id);
    }

    final counts = summary?.counts ?? const <String, int>{};
    if ((counts['pendingUsers'] ?? 0) > 0 ||
        (counts['suspendedUsers'] ?? 0) > 0) {
      add('members');
    }
    add('memberJourney');
    if ((counts['requests'] ?? 0) > 0 ||
        (counts['verificationRequests'] ?? 0) > 0) {
      add('requests');
    }
    if ((counts['posts'] ?? 0) > 0 || (counts['stories'] ?? 0) > 0) {
      add('content');
    }
    if (controls != null && !controls.siteOpen) add('siteControls');
    if (access.can('notifications.manage')) add('notifications');
    if (access.can('audit.view')) add('audit');

    for (final id in const [
      'members',
      'memberJourney',
      'requests',
      'content',
      'media',
      'siteControls',
    ]) {
      add(id);
    }
    return next.take(6).toList(growable: false);
  }

  _AdminConsoleItem? _itemById(List<_AdminConsoleItem> items, String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Map<String, List<_AdminConsoleItem>> _groupItems(
    List<_AdminConsoleItem> items,
  ) {
    final groups = <String, List<_AdminConsoleItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.group, () => <_AdminConsoleItem>[]).add(item);
    }
    return groups;
  }

  void _openItem(BuildContext context, _AdminConsoleItem item) {
    _openPath(context, item.path);
  }

  void _openPath(BuildContext context, String path) {
    if (path.startsWith('/admin') || path.startsWith('/moderation')) {
      context.go(path);
      return;
    }
    context.push(path);
  }
}

class _CommandHeader extends StatelessWidget {
  const _CommandHeader({
    required this.access,
    required this.summary,
    required this.controls,
    required this.searchController,
    required this.onSearchChanged,
  });

  final AdminEffectiveAccessSnapshot access;
  final AdminMobileSummarySnapshot? summary;
  final AdminSiteControlsSnapshot? controls;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final attentionCount =
        summary?.attention.fold<int>(0, (sum, item) => sum + item.count) ?? 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yönetim konsolu',
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
                  label: '${access.modules.length} alan',
                  tone: AdminTone.accent,
                ),
                AdminStatusChip(
                  label: attentionCount > 0
                      ? '$attentionCount bekleyen'
                      : 'Kuyruk sakin',
                  tone: attentionCount > 0
                      ? AdminTone.warning
                      : AdminTone.success,
                ),
                if (controls != null)
                  AdminStatusChip(
                    label: controls!.siteOpen ? 'Site açık' : 'Site kapalı',
                    tone: controls!.siteOpen
                        ? AdminTone.success
                        : AdminTone.danger,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Temizle',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                labelText: 'Panelde ara',
                hintText: 'Üye, medya, bildirim, veritabanı, audit...',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessPanel extends StatelessWidget {
  const _QuickAccessPanel({
    required this.items,
    required this.recommended,
    required this.loaded,
    required this.pinnedIds,
    required this.onOpen,
    required this.onTogglePinned,
  });

  final List<_AdminConsoleItem> items;
  final List<_AdminConsoleItem> recommended;
  final bool loaded;
  final List<String> pinnedIds;
  final ValueChanged<_AdminConsoleItem> onOpen;
  final ValueChanged<String> onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Hızlı erişim',
              subtitle: 'Panel önerir; admin yıldızla ekleyip çıkarır.',
              compact: true,
            ),
            const SizedBox(height: 12),
            if (!loaded)
              const LinearProgressIndicator(minHeight: 2)
            else if (items.isEmpty)
              Text(
                'Henüz sabitlenen alan yok.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.foregroundMuted),
              )
            else
              _QuickTileStrip(
                items: items,
                pinnedIds: pinnedIds,
                onOpen: onOpen,
                onTogglePinned: onTogglePinned,
              ),
            const SizedBox(height: 14),
            if (recommended.isNotEmpty) ...[
              Text(
                'Önerilen',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _QuickTileStrip(
                items: recommended,
                pinnedIds: pinnedIds,
                onOpen: onOpen,
                onTogglePinned: onTogglePinned,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickTileStrip extends StatelessWidget {
  const _QuickTileStrip({
    required this.items,
    required this.pinnedIds,
    required this.onOpen,
    required this.onTogglePinned,
  });

  final List<_AdminConsoleItem> items;
  final List<String> pinnedIds;
  final ValueChanged<_AdminConsoleItem> onOpen;
  final ValueChanged<String> onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final pinned = pinnedIds.contains(item.id);
          final colors = AdminToneColors.from(context, item.tone);
          return SizedBox(
            width: 178,
            child: Material(
              color: colors.muted,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onOpen(item),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, color: colors.foreground, size: 20),
                          const Spacer(),
                          InkResponse(
                            radius: 18,
                            onTap: () => onTogglePinned(item.id),
                            child: Icon(
                              pinned ? Icons.star_rounded : Icons.star_border,
                              color: colors.foreground,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.attention, required this.onOpenPath});

  final List<AdminAttentionItem> attention;
  final ValueChanged<String> onOpenPath;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'İlgilenilmesi gerekenler',
            subtitle: 'Sıradaki operasyonel işleri tek yerde gösterir.',
            compact: true,
          ),
          const SizedBox(height: 12),
          for (final item in attention)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${item.count}')),
                title: Text(item.label),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => onOpenPath(item.path),
              ),
            ),
        ],
      ),
    );
  }
}

class _SystemSnapshotPanel extends StatelessWidget {
  const _SystemSnapshotPanel({required this.summary});

  final AdminMobileSummarySnapshot? summary;

  @override
  Widget build(BuildContext context) {
    final counts = summary?.counts ?? const <String, int>{};
    final system = summary?.system;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricPill(
          icon: Icons.groups_outlined,
          label: 'Üye',
          value: '${counts['users'] ?? 0}',
          tone: AdminTone.info,
        ),
        _MetricPill(
          icon: Icons.block_outlined,
          label: 'Askıda',
          value: '${counts['suspendedUsers'] ?? 0}',
          tone: (counts['suspendedUsers'] ?? 0) > 0
              ? AdminTone.danger
              : AdminTone.success,
        ),
        _MetricPill(
          icon: Icons.pending_actions_outlined,
          label: 'Talep',
          value: '${counts['requests'] ?? 0}',
          tone: (counts['requests'] ?? 0) > 0
              ? AdminTone.warning
              : AdminTone.success,
        ),
        if (system != null && system.diskSupported)
          _MetricPill(
            icon: Icons.storage_outlined,
            label: 'Disk',
            value: '${system.diskUsedPct.toStringAsFixed(0)}%',
            tone: system.diskUsedPct > 85 ? AdminTone.warning : AdminTone.info,
          ),
        if (system != null && system.cpuSupported)
          _MetricPill(
            icon: Icons.memory_outlined,
            label: 'CPU',
            value: '${system.cpuUsagePct.toStringAsFixed(0)}%',
            tone: system.cpuUsagePct > 85 ? AdminTone.warning : AdminTone.info,
          ),
      ],
    );
  }
}

class _ConsoleGroup extends StatelessWidget {
  const _ConsoleGroup({
    required this.title,
    required this.items,
    required this.pinnedIds,
    required this.onOpen,
    required this.onTogglePinned,
  });

  final String title;
  final List<_AdminConsoleItem> items;
  final List<String> pinnedIds;
  final ValueChanged<_AdminConsoleItem> onOpen;
  final ValueChanged<String> onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 920
                  ? 3
                  : width >= 620
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 132,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ConsoleTile(
                    item: item,
                    pinned: pinnedIds.contains(item.id),
                    onOpen: () => onOpen(item),
                    onTogglePinned: () => onTogglePinned(item.id),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConsoleTile extends StatelessWidget {
  const _ConsoleTile({
    required this.item,
    required this.pinned,
    required this.onOpen,
    required this.onTogglePinned,
  });

  final _AdminConsoleItem item;
  final bool pinned;
  final VoidCallback onOpen;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final colors = AdminToneColors.from(context, item.tone);
    return Material(
      color: tokens.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.muted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: colors.foreground, size: 19),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: pinned
                        ? 'Hızlı erişimden çıkar'
                        : 'Hızlı erişime ekle',
                    visualDensity: VisualDensity.compact,
                    onPressed: onTogglePinned,
                    icon: Icon(
                      pinned ? Icons.star_rounded : Icons.star_border,
                      color: pinned
                          ? colors.foreground
                          : tokens.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.foregroundMuted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel({required this.items});

  final List<AdminAuditLogItem> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Son denetim',
            subtitle: 'Paneldeki son kritik yönetim izleri.',
            compact: true,
          ),
          const SizedBox(height: 8),
          for (final item in items.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(
                item.action.isEmpty ? 'Audit kaydı' : item.action,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  item.actorLabel,
                  if (item.createdAt.isNotEmpty)
                    formatSdalTimestamp(context, item.createdAt),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AdminToneColors.from(context, tone);
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                (compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

class _AdminConsoleItem {
  const _AdminConsoleItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.group,
    required this.path,
    required this.icon,
    required this.tone,
    this.permissions = const <String>[],
    this.rootOnly = false,
    this.keywords = const <String>[],
  });

  final String id;
  final String title;
  final String subtitle;
  final String group;
  final String path;
  final IconData icon;
  final AdminTone tone;
  final List<String> permissions;
  final bool rootOnly;
  final List<String> keywords;

  String get searchText =>
      [id, title, subtitle, group, path, ...keywords].join(' ').toLowerCase();
}

String _roleLabel(String role) {
  return switch (role.trim().toLowerCase()) {
    'root' => 'Root',
    'admin' => 'Admin',
    'mod' => 'Moderatör',
    _ => 'Yönetici',
  };
}

const _adminConsoleItems = <_AdminConsoleItem>[
  _AdminConsoleItem(
    id: 'members',
    title: 'Üyeler',
    subtitle: 'Arama, avatar, durum, rol, askı ve üye kayıt işlemleri.',
    group: 'Üye ve kimlik',
    path: '/admin/management',
    icon: Icons.groups_outlined,
    tone: AdminTone.info,
    permissions: ['users.view'],
    keywords: ['kullanıcı', 'avatar', 'rol', 'ban', 'askı', 'profil'],
  ),
  _AdminConsoleItem(
    id: 'memberJourney',
    title: 'Üye yolculuğu',
    subtitle:
        'Kayıttan bugüne profil, talep, içerik, medya, mesaj, ağ, bildirim ve audit dosyası.',
    group: 'Üye ve kimlik',
    path: '/admin/member-journey',
    icon: Icons.route_outlined,
    tone: AdminTone.accent,
    permissions: ['users.view', 'audit.view'],
    keywords: [
      'journey',
      'timeline',
      'aktivite',
      'dosya',
      'mesaj',
      'medya',
      'audit',
    ],
  ),
  _AdminConsoleItem(
    id: 'requests',
    title: 'Talepler',
    subtitle: 'Üyelik, profil doğrulama ve öğretmen ağı başvuruları.',
    group: 'Üye ve kimlik',
    path: '/admin/requests',
    icon: Icons.assignment_turned_in_outlined,
    tone: AdminTone.success,
    permissions: ['requests.view'],
    keywords: ['başvuru', 'doğrulama', 'mezuniyet', 'teacher'],
  ),
  _AdminConsoleItem(
    id: 'authSecurity',
    title: 'Auth güvenliği',
    subtitle: 'Telefon doğrulama, güvenilir cihaz ve challenge kayıtları.',
    group: 'Üye ve kimlik',
    path: '/admin/auth-security',
    icon: Icons.phonelink_lock_outlined,
    tone: AdminTone.danger,
    permissions: ['settings.manage'],
    keywords: ['sms', 'trusted device', 'cihaz', 'telefon'],
  ),
  _AdminConsoleItem(
    id: 'content',
    title: 'İçerik',
    subtitle: 'Post, yorum, hikaye, grup, sohbet ve filtre moderasyonu.',
    group: 'İçerik ve medya',
    path: '/admin/content',
    icon: Icons.shield_outlined,
    tone: AdminTone.warning,
    permissions: ['moderation.view'],
    keywords: ['post', 'yorum', 'hikaye', 'grup', 'filtre', 'chat'],
  ),
  _AdminConsoleItem(
    id: 'media',
    title: 'Albüm ve medya',
    subtitle: 'Albüm fotoğrafları, medya önizleme ve yorum temizliği.',
    group: 'İçerik ve medya',
    path: '/admin/app/albums',
    icon: Icons.photo_library_outlined,
    tone: AdminTone.accent,
    permissions: ['moderation.view', 'settings.manage'],
    keywords: ['fotoğraf', 'album', 'resim', 'medya'],
  ),
  _AdminConsoleItem(
    id: 'groups',
    title: 'Gruplar',
    subtitle: 'Grup, etkinlik ve duyuru içerik yüzeyleri.',
    group: 'İçerik ve medya',
    path: '/admin/app/groups',
    icon: Icons.diversity_3_outlined,
    tone: AdminTone.info,
    permissions: ['moderation.view', 'groups.manage'],
    keywords: ['event', 'duyuru', 'topluluk'],
  ),
  _AdminConsoleItem(
    id: 'messenger',
    title: 'Mesajlar',
    subtitle: 'Özel mesaj ve sohbet içeriklerini inceleme/temizleme.',
    group: 'İçerik ve medya',
    path: '/admin/app/messenger',
    icon: Icons.forum_outlined,
    tone: AdminTone.warning,
    permissions: ['moderation.view'],
    keywords: ['message', 'dm', 'sohbet', 'media'],
  ),
  _AdminConsoleItem(
    id: 'notifications',
    title: 'Bildirim ve push',
    subtitle: 'Broadcast, push ayarı, teslimat hataları ve operasyon sağlığı.',
    group: 'İletişim',
    path: '/admin/notifications',
    icon: Icons.notifications_active_outlined,
    tone: AdminTone.info,
    permissions: ['notifications.manage'],
    keywords: ['fcm', 'broadcast', 'duyuru', 'teslimat'],
  ),
  _AdminConsoleItem(
    id: 'email',
    title: 'E-posta',
    subtitle: 'Kategori, şablon, tekil ve toplu e-posta işlemleri.',
    group: 'İletişim',
    path: '/admin/operations',
    icon: Icons.mark_email_read_outlined,
    tone: AdminTone.accent,
    permissions: ['settings.manage'],
    keywords: ['mail', 'template', 'bulk'],
  ),
  _AdminConsoleItem(
    id: 'siteControls',
    title: 'Site ve modüller',
    subtitle: 'Site açık/kapalı, bakım mesajı, tema ve modül görünürlüğü.',
    group: 'Platform',
    path: '/admin/modules',
    icon: Icons.dashboard_customize_outlined,
    tone: AdminTone.accent,
    permissions: ['settings.manage'],
    keywords: ['bakım', 'tema', 'modül', 'menü', 'landing'],
  ),
  _AdminConsoleItem(
    id: 'appModules',
    title: 'Uygulama modülleri',
    subtitle: 'Akış, ağ, profil, iş ilanı ve keşif modül yönetimi.',
    group: 'Platform',
    path: '/admin/app/feed',
    icon: Icons.apps_outlined,
    tone: AdminTone.info,
    permissions: ['settings.manage'],
    keywords: ['feed', 'explore', 'networking', 'jobs'],
  ),
  _AdminConsoleItem(
    id: 'experiments',
    title: 'Deneyler',
    subtitle: 'A/B testleri, engagement skorları ve öneri algoritmaları.',
    group: 'Platform',
    path: '/admin/experiments',
    icon: Icons.science_outlined,
    tone: AdminTone.accent,
    permissions: ['settings.manage'],
    keywords: ['ab', 'engagement', 'recalculate', 'network suggestion'],
  ),
  _AdminConsoleItem(
    id: 'languages',
    title: 'Dil ve metinler',
    subtitle: 'Dil listesi, string anahtarları ve toplu çeviri yönetimi.',
    group: 'Platform',
    path: '/admin/languages',
    icon: Icons.translate_outlined,
    tone: AdminTone.info,
    permissions: ['settings.manage'],
    keywords: ['çeviri', 'localization', 'arb', 'language'],
  ),
  _AdminConsoleItem(
    id: 'audit',
    title: 'Audit',
    subtitle: 'Admin işlemleri, aktörler, hedefler ve denetim izi.',
    group: 'Güvenlik ve denetim',
    path: '/admin/audit',
    icon: Icons.receipt_long_outlined,
    tone: AdminTone.warning,
    permissions: ['audit.view'],
    keywords: ['log', 'denetim', 'işlem geçmişi'],
  ),
  _AdminConsoleItem(
    id: 'security',
    title: 'Güvenlik durumu',
    subtitle: 'Helmet, validation, auth ve operasyonel güvenlik sinyalleri.',
    group: 'Güvenlik ve denetim',
    path: '/admin/operations',
    icon: Icons.security_outlined,
    tone: AdminTone.danger,
    permissions: ['settings.manage'],
    keywords: ['helmet', 'validation', 'security'],
  ),
  _AdminConsoleItem(
    id: 'apiMonitor',
    title: 'API monitörü',
    subtitle: 'Seçili kullanıcı için endpoint akışı ve hata izleme.',
    group: 'Güvenlik ve denetim',
    path: '/admin/api-monitor',
    icon: Icons.radar_outlined,
    tone: AdminTone.info,
    permissions: ['audit.view', 'settings.manage'],
    keywords: ['endpoint', 'network', 'debug'],
  ),
  _AdminConsoleItem(
    id: 'database',
    title: 'Veritabanı',
    subtitle: 'Backup, restore, driver durumu ve veri kopyalama akışları.',
    group: 'Root ve veri',
    path: '/admin/database',
    icon: Icons.storage_outlined,
    tone: AdminTone.danger,
    rootOnly: true,
    keywords: ['db', 'backup', 'restore', 'postgres', 'sqlite'],
  ),
  _AdminConsoleItem(
    id: 'permissions',
    title: 'İzin grupları',
    subtitle: 'Permission matrix, grup tanımı ve kullanıcı izin atamaları.',
    group: 'Root ve veri',
    path: '/admin/permission-groups',
    icon: Icons.admin_panel_settings_outlined,
    tone: AdminTone.accent,
    rootOnly: true,
    keywords: ['rbac', 'role', 'permission'],
  ),
  _AdminConsoleItem(
    id: 'userPermissions',
    title: 'Kullanıcı izinleri',
    subtitle: 'Üyelere root kontrollü izin grubu atama.',
    group: 'Root ve veri',
    path: '/admin/user-permissions',
    icon: Icons.verified_user_outlined,
    tone: AdminTone.accent,
    rootOnly: true,
    keywords: ['permission group', 'yetki'],
  ),
  _AdminConsoleItem(
    id: 'rootActivity',
    title: 'Üye aktivite dosyası',
    subtitle: 'Root için post, mesaj, medya ve profil görüntüleme izi.',
    group: 'Root ve veri',
    path: '/admin/root/member-activity',
    icon: Icons.manage_search_outlined,
    tone: AdminTone.info,
    rootOnly: true,
    keywords: ['activity', 'dossier', 'media', 'message'],
  ),
  _AdminConsoleItem(
    id: 'testData',
    title: 'Test verisi',
    subtitle: 'Geliştirme ve doğrulama için kontrollü veri üretimi.',
    group: 'Root ve veri',
    path: '/admin/test-data',
    icon: Icons.biotech_outlined,
    tone: AdminTone.warning,
    rootOnly: true,
    keywords: ['seed', 'fixture', 'test'],
  ),
  _AdminConsoleItem(
    id: 'factoryReset',
    title: 'Factory reset',
    subtitle: 'Yüksek riskli sıfırlama akışı ve ayrı doğrulama.',
    group: 'Root ve veri',
    path: '/admin/factory-reset',
    icon: Icons.delete_forever_outlined,
    tone: AdminTone.danger,
    rootOnly: true,
    keywords: ['reset', 'wipe', 'danger'],
  ),
];
