import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/paged_response.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/notifications_action_controller.dart';
import '../data/notifications_repository.dart';
import '../notification_route_mapper.dart';

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
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    final savingPreferences =
        actionState.isLoading && actionState.scope == 'preferences';
    final visibleItems = _items;

    return FeatureScaffold(
      title: l10n.notificationsTitle,
      child: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value != 'delete_all') return;
                      final t = Theme.of(context).sdal;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.notificationsDeleteAll),
                          content: Text(l10n.notificationsDeleteAllConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(l10n.cancelAction),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: t.danger,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(l10n.deleteAction),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      final ok = await ref
                          .read(notificationsActionControllerProvider.notifier)
                          .deleteAll();
                      if (!context.mounted) return;
                      if (ok) {
                        _clearAllItems();
                      }
                      final nextState = ref.read(
                        notificationsActionControllerProvider,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            nextState.message ??
                                (ok
                                    ? l10n.notificationsDeleteAll
                                    : l10n.notificationsActionFailed),
                          ),
                        ),
                      );
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        value: 'delete_all',
                        child: Text(
                          l10n.notificationsDeleteAll,
                          style: TextStyle(color: Theme.of(ctx).sdal.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            preferencesState.when(
              loading: () => const _NotificationPreferencesSkeleton(),
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
              loading: () => const _NotificationsLoadingList(),
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
                      (item) => Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: const SizedBox.shrink(),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: tokens.danger,
                            borderRadius: BorderRadius.circular(
                              SdalThemeTokens.radiusMd,
                            ),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          final ok = await ref
                              .read(
                                notificationsActionControllerProvider.notifier,
                              )
                              .delete(item.id);
                          if (!ok && context.mounted) {
                            final nextState = ref.read(
                              notificationsActionControllerProvider,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  nextState.message ?? 'Bildirim silinemedi.',
                                ),
                              ),
                            );
                          }
                          return ok;
                        },
                        onDismissed: (_) => _deleteItem(item.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SurfaceCard(
                            onTap: () => _openNotification(context, ref, item),
                            color: item.isUnread ? tokens.accentMuted : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RemoteAvatar(
                                      label: item.sourceName.isNotEmpty
                                          ? item.sourceName
                                          : item.sourceInitials,
                                      imageUrl: item.sourcePhoto.isEmpty
                                          ? ''
                                          : config
                                                .resolveUrl(item.sourcePhoto)
                                                .toString(),
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.message,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: item.isUnread
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: item.isUnread
                                                      ? tokens.foreground
                                                      : tokens.foregroundMuted,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (item.sourceName.isNotEmpty)
                                                item.sourceName,
                                              if (item.category.isNotEmpty)
                                                item.category,
                                              if (item.createdAt.isNotEmpty)
                                                formatSdalTimestamp(
                                                  context,
                                                  item.createdAt,
                                                ),
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
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                        ),
                                        child: Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: tokens.accent,
                                        ),
                                      ),
                                    if (item.imageUrl.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      _NotificationTrailingImage(
                                        imageShape: item.imageShape,
                                        imageUrl: config
                                            .resolveUrl(item.imageUrl)
                                            .toString(),
                                      ),
                                    ],
                                  ],
                                ),
                                if (item.actions
                                    .where(
                                      (a) =>
                                          a.kind != 'open' &&
                                          a.endpoint.trim().isNotEmpty,
                                    )
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: item.actions
                                        .where(
                                          (a) =>
                                              a.kind != 'open' &&
                                              a.endpoint.trim().isNotEmpty,
                                        )
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
                              ],
                            ),
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
      ),
    );
  }

  Future<void> _refreshPage() async {
    setState(() {
      _items = const <AppNotification>[];
      _nextCursor = null;
      _hasMore = false;
      _loadingMore = false;
    });
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationPreferencesProvider);
    ref.invalidate(notificationUnreadCountProvider);
    await Future.wait([
      ref.read(notificationsProvider.future),
      ref.read(notificationPreferencesProvider.future),
      ref.read(notificationUnreadCountProvider.future),
    ]);
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

    final appRoute = mapNotificationWebRouteToApp(
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

  void _deleteItem(int id) {
    setState(() {
      _items = _items.where((item) => item.id != id).toList(growable: false);
    });
  }

  void _clearAllItems() {
    setState(() {
      _items = const <AppNotification>[];
      _hasMore = false;
      _nextCursor = null;
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

class _NotificationPreferencesSkeleton extends StatelessWidget {
  const _NotificationPreferencesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 180, height: 16),
          SizedBox(height: 14),
          SkeletonBox(height: 52),
          SizedBox(height: 10),
          SkeletonBox(height: 52),
          SizedBox(height: 10),
          SkeletonBox(height: 52),
        ],
      ),
    );
  }
}

class _NotificationsLoadingList extends StatelessWidget {
  const _NotificationsLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _NotificationCardSkeleton(),
        SizedBox(height: 12),
        _NotificationCardSkeleton(),
        SizedBox(height: 12),
        _NotificationCardSkeleton(),
      ],
    );
  }
}

class _NotificationCardSkeleton extends StatelessWidget {
  const _NotificationCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLines(widthFactors: [0.92, 0.58], lineHeight: 12),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 100, height: 38),
              SizedBox(width: 10),
              SkeletonBox(width: 96, height: 38),
            ],
          ),
        ],
      ),
    );
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
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
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
                                        quietModeEnd:
                                            widget.preferences.quietModeEnd,
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
                                    if (widget
                                        .preferences
                                        .quietModeStart
                                        .isNotEmpty)
                                      widget.preferences.quietModeStart,
                                    if (widget
                                        .preferences
                                        .quietModeEnd
                                        .isNotEmpty)
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
                                          widget
                                              .preferences
                                              .quietModeStart
                                              .isEmpty
                                          ? '22:00'
                                          : widget.preferences.quietModeStart,
                                      quietModeEnd:
                                          widget
                                              .preferences
                                              .quietModeEnd
                                              .isEmpty
                                          ? '08:00'
                                          : widget.preferences.quietModeEnd,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTrailingImage extends StatelessWidget {
  const _NotificationTrailingImage({
    required this.imageShape,
    required this.imageUrl,
  });

  final String imageShape;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 46.0;
    final radius = imageShape == 'circle'
        ? BorderRadius.circular(size / 2)
        : imageShape == 'square'
        ? BorderRadius.zero
        : BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: radius,
      child: SdalNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        borderRadius: radius,
        enableLightbox: false,
        cacheWidth: 92,
        cacheHeight: 92,
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
