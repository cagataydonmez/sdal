import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/messenger_action_controller.dart';
import '../data/messenger_repository.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  static const _pollInterval = Duration(seconds: 8);

  final _searchController = TextEditingController();
  StreamSubscription<MessengerRealtimeEvent>? _eventsSubscription;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    final realtime = ref.read(messengerRealtimeServiceProvider);
    realtime.start();
    _eventsSubscription = realtime.events.listen((_) {
      ref.invalidate(messengerThreadsProvider(_searchController.text.trim()));
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      ref.invalidate(messengerThreadsProvider(_searchController.text.trim()));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _eventsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadsState = ref.watch(
      messengerThreadsProvider(_searchController.text.trim()),
    );
    final realtime = ref.watch(messengerRealtimeServiceProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.messagesTitle,
      actions: [
        StreamBuilder(
          stream: realtime.states,
          initialData: realtime.currentState,
          builder: (context, snapshot) {
            final state =
                snapshot.data ?? const RealtimeConnectionState.disconnected();
            final color = switch (state.status) {
              RealtimeConnectionStatus.connected => Theme.of(
                context,
              ).sdal.success,
              RealtimeConnectionStatus.failed => Theme.of(
                context,
              ).colorScheme.error,
              _ => Theme.of(context).colorScheme.outline,
            };
            return Tooltip(
              message: switch (state.status) {
                RealtimeConnectionStatus.connected => l10n.realtimeConnected,
                RealtimeConnectionStatus.failed => l10n.realtimeFailed,
                RealtimeConnectionStatus.reconnecting =>
                  l10n.realtimeReconnecting,
                RealtimeConnectionStatus.connecting => l10n.realtimeConnecting,
                RealtimeConnectionStatus.disconnected =>
                  l10n.realtimeDisconnected,
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.circle, size: 10, color: color),
              ),
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.newChatAction),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.searchPeopleHint,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: threadsState.when(
              loading: () => const _InboxThreadsSkeleton(),
              error: (error, _) => ErrorView(
                kind: ErrorViewKind.network,
                onRetry: () => ref.invalidate(
                  messengerThreadsProvider(_searchController.text.trim()),
                ),
              ),
              data: (threads) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(
                    messengerThreadsProvider(_searchController.text.trim()),
                  );
                  await ref.read(
                    messengerThreadsProvider(
                      _searchController.text.trim(),
                    ).future,
                  );
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: threads.isEmpty ? 1 : threads.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (threads.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: EmptyStateView(
                          icon: Icons.forum_outlined,
                          title: l10n.messagesEmptyTitle,
                          message: l10n.messagesEmptyMessage,
                          actionLabel: l10n.startNewChat,
                          onAction: () => _openComposeSheet(context, ref),
                        ),
                      );
                    }
                    final thread = threads[index];
                    return SurfaceCard(
                      onTap: () => context.push('/messages/${thread.id}'),
                      tooltip: l10n.openAction,
                      semanticContainer: true,
                      child: Row(
                        children: [
                          RemoteAvatar(
                            label: thread.peer.name,
                            imageUrl: config
                                .resolveUrl(thread.peer.photo)
                                .toString(),
                            radius: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        thread.peer.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    if (thread.unreadCount > 0)
                                      Semantics(
                                        label: l10n.messagesUnreadCount(
                                          thread.unreadCount,
                                        ),
                                        child: ExcludeSemantics(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D2238),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    SdalThemeTokens.radiusPill,
                                                  ),
                                            ),
                                            child: Text(
                                              '${thread.unreadCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  thread.lastMessage?.body ?? l10n.startNewChat,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if ((thread.lastMessage?.createdAt ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    formatSdalTimestamp(
                                      context,
                                      thread.lastMessage!.createdAt,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxThreadsSkeleton extends StatelessWidget {
  const _InboxThreadsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: 5,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _InboxThreadCardSkeleton(),
    );
  }
}

class _InboxThreadCardSkeleton extends StatelessWidget {
  const _InboxThreadCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: const [
          SkeletonBox(height: 52, width: 52, shape: BoxShape.circle),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLines(widthFactors: [0.54, 0.24], lineHeight: 11),
                SizedBox(height: 10),
                SkeletonLines(widthFactors: [0.82, 0.38], lineHeight: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openComposeSheet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final controller = TextEditingController();

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Consumer(
          builder: (context, ref, _) {
            final contactsState = ref.watch(
              messengerContactsProvider(controller.text.trim()),
            );
            final config = ref.watch(appConfigProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.newChatTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.searchPersonHint,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: contactsState.when(
                    loading: () => controller.text.trim().isEmpty
                        ? Center(child: Text(l10n.searchPrompt))
                        : const Center(child: CircularProgressIndicator()),
                    error: (error, _) => const ErrorView(),
                    data: (contacts) {
                      if (controller.text.trim().isEmpty) {
                        return Center(child: Text(l10n.searchPrompt));
                      }
                      if (contacts.isEmpty) {
                        return Center(child: Text(l10n.searchNoResults));
                      }
                      return ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return ListTile(
                            leading: RemoteAvatar(
                              label: contact.name,
                              imageUrl: config
                                  .resolveUrl(contact.photo)
                                  .toString(),
                            ),
                            title: Text(contact.name),
                            subtitle: Text(
                              contact.handle.isNotEmpty
                                  ? '@${contact.handle}'
                                  : '',
                            ),
                            onTap: () async {
                              final threadId = await ref
                                  .read(
                                    messengerActionControllerProvider.notifier,
                                  )
                                  .createThread(contact.id);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              if (threadId != null) {
                                context.push('/messages/$threadId');
                              } else {
                                final actionState = ref.read(
                                  messengerActionControllerProvider,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      actionState.message ??
                                          'Sohbet başlatılamadı.',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}
