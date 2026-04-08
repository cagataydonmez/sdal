import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/paged_response.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/notifications_action_controller.dart';
import '../data/notifications_repository.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  ProviderSubscription<AsyncValue<PagedResponse<AppNotification>>>?
  _notificationsSubscription;
  List<AppNotification> _items = const <AppNotification>[];
  final Set<int> _trackedImpressionIds = <int>{};
  String? _nextCursor;
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _notificationsSubscription = ref.listenManual(
      notificationsProvider,
      (_, next) => next.whenData(_applyFirstPage),
    );
  }

  @override
  void dispose() {
    _notificationsSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationsProvider);
    final preferencesState = ref.watch(notificationPreferencesProvider);
    final unreadCountState = ref.watch(notificationUnreadCountProvider);
    final actionState = ref.watch(notificationsActionControllerProvider);
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final savingPreferences =
        actionState.isLoading && actionState.scope == 'preferences';
    final visibleItems = _items;

    return FeatureScaffold(
      title: l10n.notificationsTitle,
      actions: [
        IconButton(
          tooltip: l10n.refreshAction,
          onPressed: () {
            setState(() {
              _items = const <AppNotification>[];
              _nextCursor = null;
              _hasMore = false;
              _loadingMore = false;
            });
            ref.invalidate(notificationsProvider);
            ref.invalidate(notificationPreferencesProvider);
            ref.invalidate(notificationUnreadCountProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: unreadCountState.when(
                    loading: () => Text(l10n.notificationsUnreadLoading),
                    error: (error, _) => const ErrorView(compact: true),
                    data: (count) => Text(
                      l10n.notificationsUnreadCount(count),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await ref
                        .read(notificationsActionControllerProvider.notifier)
                        .markAllRead(trackedItems: visibleItems);
                    if (!context.mounted) return;
                    if (ok) {
                      _markAllLoadedRead();
                    }
                    final nextState = ref.read(
                      notificationsActionControllerProvider,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nextState.message ??
                              (ok
                                  ? l10n.notificationsUpdatedAllRead
                                  : l10n.notificationsActionFailed),
                        ),
                      ),
                    );
                  },
                  child: Text(l10n.notificationsMarkAllRead),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          preferencesState.when(
            loading: () => const SurfaceCard(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (preferences) => _PreferencesCard(
              preferences: preferences,
              saving: savingPreferences,
              onChanged: (next) async {
                final ok = await ref
                    .read(notificationsActionControllerProvider.notifier)
                    .savePreferences(next);
                if (!context.mounted) return;
                final nextState = ref.read(
                  notificationsActionControllerProvider,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      nextState.message ??
                          (ok
                              ? l10n.notificationsPreferencesUpdated
                              : l10n.notificationsPreferencesFailed),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.notificationsInboxTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          notificationsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                const ErrorView(compact: true, kind: ErrorViewKind.network),
            data: (page) {
              final items = visibleItems.isEmpty ? page.items : visibleItems;
              final hasMore = visibleItems.isEmpty ? page.hasMore : _hasMore;
              if (items.isEmpty) {
                return SurfaceCard(
                  child: EmptyStateView(
                    icon: Icons.notifications_none_rounded,
                    title: l10n.notificationsEmptyTitle,
                    message: l10n.notificationsEmptyMessage,
                    actionLabel: l10n.refreshAction,
                    onAction: () => ref.invalidate(notificationsProvider),
                  ),
                );
              }
              return Column(
                children: [
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.message,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (item.sourceName.isNotEmpty)
                                            item.sourceName,
                                          if (item.category.isNotEmpty)
                                            item.category,
                                          if (item.createdAt.isNotEmpty)
                                            item.createdAt,
                                        ].join(' · '),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.isUnread)
                                  Padding(
                                    padding: EdgeInsets.only(left: 12),
                                    child: Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: tokens.info,
                                    ),
                                  ),
                              ],
                            ),
                            if (item.actions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: item.actions
                                    .map(
                                      (action) => OutlinedButton(
                                        onPressed: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final ok = await ref
                                              .read(
                                                notificationsActionControllerProvider
                                                    .notifier,
                                              )
                                              .runAction(
                                                action,
                                                notificationId: item.id,
                                                notificationType: item.type,
                                              );
                                          if (!context.mounted) return;
                                          final nextState = ref.read(
                                            notificationsActionControllerProvider,
                                          );
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                nextState.message ??
                                                    (ok
                                                        ? '${action.label} tamamlandı.'
                                                        : l10n.notificationsActionFailed),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(action.label),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: item.isUnread
                                      ? () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final ok = await ref
                                              .read(
                                                notificationsActionControllerProvider
                                                    .notifier,
                                              )
                                              .markRead(
                                                item.id,
                                                notificationType: item.type,
                                              );
                                          if (!context.mounted) return;
                                          if (ok) {
                                            _markNotificationRead(item.id);
                                          }
                                          final nextState = ref.read(
                                            notificationsActionControllerProvider,
                                          );
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                nextState.message ??
                                                    (ok
                                                        ? 'Bildirim okundu.'
                                                        : l10n.notificationsActionFailed),
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  child: Text(l10n.notificationsReadAction),
                                ),
                                const Spacer(),
                                FilledButton.tonal(
                                  onPressed: () =>
                                      _openNotification(context, ref, item),
                                  child: Text(l10n.openAction),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasMore) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _loadingMore
                            ? null
                            : () => _loadMore(context),
                        icon: _loadingMore
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more),
                        label: Text(
                          _loadingMore ? 'Yükleniyor...' : 'Daha fazla yükle',
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    final target = await ref
        .read(notificationsActionControllerProvider.notifier)
        .open(item.id, notificationType: item.type);
    if (!context.mounted) return;
    if (target == null) {
      final actionState = ref.read(notificationsActionControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actionState.message ?? context.l10n.notificationOpenedFailed,
          ),
        ),
      );
      return;
    }

    _markNotificationRead(item.id);

    final appRoute = _mapWebRouteToApp(
      target.route.isNotEmpty ? target.route : target.href,
    );
    if (appRoute != null && appRoute.isNotEmpty) {
      context.push(appRoute);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          target.label.isNotEmpty ? target.label : 'Bildirim açıldı.',
        ),
      ),
    );
  }

  void _applyFirstPage(PagedResponse<AppNotification> page) {
    if (!mounted) return;
    setState(() {
      _items = page.items;
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _loadingMore = false;
    });
    _trackImpressions(page.items);
  }

  Future<void> _loadMore(BuildContext context) async {
    if (_loadingMore || !_hasMore || (_nextCursor?.isEmpty ?? true)) {
      return;
    }
    setState(() => _loadingMore = true);
    final result = await ref
        .read(notificationsRepositoryProvider)
        .fetchNotifications(cursor: _nextCursor);
    if (!mounted) return;
    final existingIds = _items.map((item) => item.id).toSet();
    final freshItems = result.items
        .where((item) => !existingIds.contains(item.id))
        .toList(growable: false);
    setState(() {
      _items = [..._items, ...freshItems];
      _nextCursor = result.nextCursor;
      _hasMore = result.hasMore;
      _loadingMore = false;
    });
    _trackImpressions(freshItems);
    if (freshItems.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni bildirim bulunamadı.')),
      );
    }
  }

  void _trackImpressions(Iterable<AppNotification> items) {
    final fresh = items
        .where((item) => _trackedImpressionIds.add(item.id))
        .toList(growable: false);
    if (fresh.isEmpty) return;
    unawaited(
      ref
          .read(notificationsActionControllerProvider.notifier)
          .trackImpressions(fresh),
    );
  }

  void _markNotificationRead(int notificationId) {
    final readAt = DateTime.now().toIso8601String();
    setState(() {
      _items = _items
          .map(
            (item) => item.id == notificationId && item.readAt.isEmpty
                ? item.copyWith(readAt: readAt)
                : item,
          )
          .toList(growable: false);
    });
  }

  void _markAllLoadedRead() {
    final readAt = DateTime.now().toIso8601String();
    setState(() {
      _items = _items
          .map(
            (item) =>
                item.readAt.isEmpty ? item.copyWith(readAt: readAt) : item,
          )
          .toList(growable: false);
    });
  }
}

class _PreferencesCard extends StatefulWidget {
  const _PreferencesCard({
    required this.preferences,
    required this.saving,
    required this.onChanged,
  });

  final NotificationPreferences preferences;
  final bool saving;
  final Future<void> Function(NotificationPreferences next) onChanged;

  @override
  State<_PreferencesCard> createState() => _PreferencesCardState();
}

class _PreferencesCardState extends State<_PreferencesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Semantics(
              button: true,
              toggled: _expanded,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bildirim tercihleri',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _expanded
                                  ? 'Hangi bildirimlerin açık olduğunu buradan yönetebilirsin.'
                                  : 'Kategori ve sessiz mod ayarlarını görmek için aç.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const ExcludeSemantics(
                          child: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  ...widget.preferences.categories.entries.map(
                    (entry) => SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_labelForCategory(entry.key)),
                      value: entry.value,
                      onChanged: widget.saving
                          ? null
                          : (enabled) => widget.onChanged(
                              NotificationPreferences(
                                categories: {
                                  ...widget.preferences.categories,
                                  entry.key: enabled,
                                },
                                quietModeEnabled:
                                    widget.preferences.quietModeEnabled,
                                quietModeStart:
                                    widget.preferences.quietModeStart,
                                quietModeEnd: widget.preferences.quietModeEnd,
                              ),
                            ),
                    ),
                  ),
                  const Divider(height: 24),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sessiz mod'),
                    subtitle: Text(
                      [
                            if (widget.preferences.quietModeStart.isNotEmpty)
                              widget.preferences.quietModeStart,
                            if (widget.preferences.quietModeEnd.isNotEmpty)
                              widget.preferences.quietModeEnd,
                          ].join(' - ').isEmpty
                          ? 'Başlangıç ve bitiş saati tanımlanmadı.'
                          : '${widget.preferences.quietModeStart} - ${widget.preferences.quietModeEnd}',
                    ),
                    value: widget.preferences.quietModeEnabled,
                    onChanged: widget.saving
                        ? null
                        : (enabled) => widget.onChanged(
                            NotificationPreferences(
                              categories: widget.preferences.categories,
                              quietModeEnabled: enabled,
                              quietModeStart:
                                  widget.preferences.quietModeStart.isEmpty
                                  ? '22:00'
                                  : widget.preferences.quietModeStart,
                              quietModeEnd:
                                  widget.preferences.quietModeEnd.isEmpty
                                  ? '08:00'
                                  : widget.preferences.quietModeEnd,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

String _labelForCategory(String key) {
  switch (key) {
    case 'social':
      return 'Sosyal';
    case 'messaging':
      return 'Mesajlaşma';
    case 'groups':
      return 'Gruplar';
    case 'events':
      return 'Etkinlikler';
    case 'networking':
      return 'Networking';
    case 'jobs':
      return 'İş ve fırsatlar';
    case 'system':
      return 'Sistem';
    default:
      return key;
  }
}

String? _mapWebRouteToApp(String rawRoute) {
  final value = rawRoute.trim();
  if (value.isEmpty) return null;
  final uri = _parseMaybeRelativeUri(value);
  final path = uri?.path ?? value;
  final query = uri != null && uri.hasQuery ? '?${uri.query}' : '';

  if (path.startsWith('/new/network/hub')) return '/network/hub$query';
  if (path.startsWith('/new/network/inbox')) return '/network/inbox$query';
  if (path.startsWith('/new/profile/verification')) {
    return '/profile/verification';
  }
  if (path.startsWith('/new/profile')) return '/profile$query';
  if (path.startsWith('/new/following')) return '/following$query';
  if (path.startsWith('/new/requests')) return '/requests$query';
  if (path.startsWith('/new/groups/')) {
    final id = path.split('/').last;
    return '/groups/$id$query';
  }
  if (path.startsWith('/new/groups')) return '/groups$query';
  if (path.startsWith('/new/events')) return '/events$query';
  if (path.startsWith('/new/announcements')) return '/announcements$query';
  if (path.startsWith('/new/jobs')) return '/jobs$query';
  if (path.startsWith('/new/opportunities')) return '/opportunities$query';
  if (path.startsWith('/new/albums/photo/')) {
    final id = path.split('/').last;
    return '/albums/photo/$id$query';
  }
  if (path.startsWith('/new/albums/upload')) return '/albums/upload$query';
  if (path.startsWith('/new/albums/')) {
    final id = path.split('/').last;
    return '/albums/$id$query';
  }
  if (path.startsWith('/new/albums')) return '/albums$query';
  if (path.startsWith('/new/members/')) {
    final id = path.split('/').last;
    return '/members/$id';
  }
  if (path.startsWith('/new/messages/')) {
    final id = path.split('/').last;
    return '/messages/$id';
  }
  return null;
}

Uri? _parseMaybeRelativeUri(String value) {
  final absolute = Uri.tryParse(value);
  if (absolute != null && absolute.hasScheme) return absolute;
  return Uri.tryParse('https://sdal.local$value');
}
