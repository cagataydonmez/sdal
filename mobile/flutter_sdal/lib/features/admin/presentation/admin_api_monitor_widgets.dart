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
    final effectiveSelection = _effectiveSelection(monitorState, sessionUser);
    final query = AdminUserListQuery(
      query: _searchController.text.trim(),
      filter: 'all',
      page: _page,
      limit: 12,
    );
    final userPreviewState = ref.watch(adminUserPreviewProvider(query));
    final activityState = ref.watch(
      adminUserApiActivityProvider(
        AdminApiMonitorQuery(userId: effectiveSelection.id, limit: 32),
      ),
    );

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
                    onPressed: () {
                      ref
                          .read(adminApiMonitorControllerProvider.notifier)
                          .toggleEnabled();
                    },
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
                        ? () {
                            ref
                                .read(
                                  adminApiMonitorControllerProvider.notifier,
                                )
                                .toggleExpanded();
                          }
                        : null,
                    icon: Icon(
                      monitorState.isExpanded
                          ? Icons.unfold_less_outlined
                          : Icons.unfold_more_outlined,
                    ),
                    label: Text(
                      monitorState.isExpanded
                          ? 'Overlay daralt'
                          : 'Overlay genislet',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(adminApiMonitorControllerProvider.notifier)
                          .useSelfAsDefault();
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Kendime don'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                monitorState.isEnabled
                    ? 'Overlay uygulamanin tum sayfalarinda alttan gorunur.'
                    : 'Overlay su anda kapali. Activate ettiginizde tum sayfalarda canli gorunur.',
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
                'Canli API akisi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _ActivityFeed(
                state: activityState,
                maxItems: 8,
                emptyLabel:
                    '${effectiveSelection.displayLabel} icin son API akisi bulunmadi.',
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
                              final controller = ref.read(
                                adminApiMonitorControllerProvider.notifier,
                              );
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
                            onPressed: users.items.length >= query.limit
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
          limit: monitorState.isExpanded ? 10 : 4,
        ),
      ),
    );
    final bottomOffset = MediaQuery.of(context).padding.bottom + 84;

    return Stack(
      children: [
        child,
        Positioned(
          left: 12,
          right: 12,
          bottom: bottomOffset,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _OverlayPanel(
                selection: selection,
                state: activityState,
                isExpanded: monitorState.isExpanded,
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
    required this.isExpanded,
  });

  final AdminApiMonitorSelection selection;
  final AsyncValue<AdminApiMonitorSnapshot> state;
  final bool isExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).sdal;
    final itemCount = isExpanded ? 6 : 2;

    return Material(
      color: Colors.transparent,
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: state.hasError ? tokens.danger : tokens.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Canli API akisi · ${selection.displayLabel}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: isExpanded ? 'Daralt' : 'Genislet',
                  onPressed: () {
                    ref
                        .read(adminApiMonitorControllerProvider.notifier)
                        .toggleExpanded();
                  },
                  icon: Icon(
                    isExpanded
                        ? Icons.unfold_less_outlined
                        : Icons.unfold_more_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () {
                    ref
                        .read(adminApiMonitorControllerProvider.notifier)
                        .deactivate();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ActivityFeed(
              state: state,
              maxItems: itemCount,
              compact: true,
              emptyLabel: 'Henuz goruntulenecek bir API kaydi yok.',
            ),
          ],
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
            label: Text(isSelected ? 'Secili' : 'Bu kullaniciyi izle'),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({
    required this.state,
    required this.maxItems,
    required this.emptyLabel,
    this.compact = false,
  });

  final AsyncValue<AdminApiMonitorSnapshot> state;
  final int maxItems;
  final String emptyLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (snapshot) {
        if (snapshot.items.isEmpty) return Text(emptyLabel);
        return Column(
          children: [
            for (final item in snapshot.items.take(maxItems))
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
      error: (error, _) => Text(error.toString()),
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
    final semantic = _describeActivity(item);
    final statusColor = item.isSuccessful
        ? tokens.success
        : (item.status >= 400 ? tokens.danger : tokens.warning);

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
            margin: const EdgeInsets.only(top: 3),
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
                Text(
                  semantic.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${semantic.subtitle} · ${item.method} ${item.path}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
                if (item.query.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Query: ${item.query}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.foregroundMuted,
                    ),
                  ),
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
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.durationMs} ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                _timeLabel(item.at),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
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
  final action = switch (item.method) {
    'GET' => '$domain verisi alindi',
    'POST' => '$domain icin yeni istek gonderildi',
    'PUT' => '$domain guncellemesi gonderildi',
    'PATCH' => '$domain parcali guncellemesi gonderildi',
    'DELETE' => '$domain silme istegi gonderildi',
    _ => '$domain istegi tamamlandi',
  };
  final statusText = item.status >= 400
      ? 'Sunucu hata ya da red cevabi verdi'
      : 'Sunucu yaniti basariyla alindi';
  return _ApiActivityDescription(title: action, subtitle: statusText);
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

String _timeLabel(String raw) {
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  final ss = parsed.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}
