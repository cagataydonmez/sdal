import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
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
  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationsProvider);
    final preferencesState = ref.watch(notificationPreferencesProvider);
    final unreadCountState = ref.watch(notificationUnreadCountProvider);
    final actionState = ref.watch(notificationsActionControllerProvider);
    final l10n = context.l10n;
    final savingPreferences =
        actionState.isLoading && actionState.scope == 'preferences';

    return FeatureScaffold(
      title: l10n.notificationsTitle,
      actions: [
        IconButton(
          onPressed: () {
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
                    error: (error, _) => Text(error.toString()),
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
                        .markAllRead();
                    if (!context.mounted) return;
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
            error: (error, _) => SurfaceCard(child: Text(error.toString())),
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
            error: (error, _) => Text(error.toString()),
            data: (items) {
              if (items.isEmpty) {
                return SurfaceCard(child: Text(l10n.notificationsEmpty));
              }
              return Column(
                children: items
                    .map(
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
                                    const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: Color(0xFF1F6FEB),
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
                                                .runAction(action);
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
                                                .markRead(item.id);
                                            if (!context.mounted) return;
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
                                    onPressed: () => _openNotification(
                                      context,
                                      ref,
                                      item.id,
                                    ),
                                    child: Text(l10n.openAction),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
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
    int notificationId,
  ) async {
    final target = await ref
        .read(notificationsActionControllerProvider.notifier)
        .open(notificationId);
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
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.preferences,
    required this.saving,
    required this.onChanged,
  });

  final NotificationPreferences preferences;
  final bool saving;
  final Future<void> Function(NotificationPreferences next) onChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bildirim tercihleri',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...preferences.categories.entries.map(
            (entry) => SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(_labelForCategory(entry.key)),
              value: entry.value,
              onChanged: saving
                  ? null
                  : (enabled) => onChanged(
                      NotificationPreferences(
                        categories: {
                          ...preferences.categories,
                          entry.key: enabled,
                        },
                        quietModeEnabled: preferences.quietModeEnabled,
                        quietModeStart: preferences.quietModeStart,
                        quietModeEnd: preferences.quietModeEnd,
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
                    if (preferences.quietModeStart.isNotEmpty)
                      preferences.quietModeStart,
                    if (preferences.quietModeEnd.isNotEmpty)
                      preferences.quietModeEnd,
                  ].join(' - ').isEmpty
                  ? 'Başlangıç ve bitiş saati tanımlanmadı.'
                  : '${preferences.quietModeStart} - ${preferences.quietModeEnd}',
            ),
            value: preferences.quietModeEnabled,
            onChanged: saving
                ? null
                : (enabled) => onChanged(
                    NotificationPreferences(
                      categories: preferences.categories,
                      quietModeEnabled: enabled,
                      quietModeStart: preferences.quietModeStart.isEmpty
                          ? '22:00'
                          : preferences.quietModeStart,
                      quietModeEnd: preferences.quietModeEnd.isEmpty
                          ? '08:00'
                          : preferences.quietModeEnd,
                    ),
                  ),
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
  if (value.startsWith('/new/network/hub')) return '/network/hub';
  if (value.startsWith('/new/network/inbox')) return '/network/inbox';
  if (value.startsWith('/new/profile/verification')) {
    return '/profile/verification';
  }
  if (value.startsWith('/new/profile')) return '/profile';
  if (value.startsWith('/new/members/')) {
    final id = value.split('/').last;
    return '/members/$id';
  }
  if (value.startsWith('/new/messages/')) {
    final id = value.split('/').last;
    return '/messages/$id';
  }
  return null;
}
