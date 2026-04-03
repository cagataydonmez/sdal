import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/messenger_repository.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  final _searchController = TextEditingController();
  StreamSubscription<MessengerRealtimeEvent>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    final realtime = ref.read(messengerRealtimeServiceProvider);
    realtime.start();
    _eventsSubscription = realtime.events.listen((_) {
      ref.invalidate(messengerThreadsProvider(_searchController.text.trim()));
    });
  }

  @override
  void dispose() {
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

    return FeatureScaffold(
      title: 'Mesajlar',
      actions: [
        StreamBuilder(
          stream: realtime.states,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final color = switch (state?.status) {
              RealtimeConnectionStatus.connected => Colors.green,
              RealtimeConnectionStatus.reconnecting => Colors.orange,
              RealtimeConnectionStatus.failed => Theme.of(
                context,
              ).colorScheme.error,
              _ => Colors.grey,
            };
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.circle, size: 10, color: color),
            );
          },
        ),
        IconButton(
          onPressed: () => ref.invalidate(
            messengerThreadsProvider(_searchController.text.trim()),
          ),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Yeni sohbet'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Kişi veya kullanıcı adı ara',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: threadsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (threads) {
                if (threads.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Henüz konuşma yok. Yeni bir mesaj başlatmak için sağ alttaki düğmeyi kullan.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: threads.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => context.push('/messages/${thread.id}'),
                      child: SurfaceCard(
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D2238),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${thread.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    thread.lastMessage?.body ??
                                        'Yeni sohbete başla',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  if ((thread.lastMessage?.createdAt ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      thread.lastMessage!.createdAt,
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

Future<void> _openComposeSheet(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer(
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
                  'Yeni sohbet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Kişi ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: contactsState.when(
                    loading: () => controller.text.trim().isEmpty
                        ? const Center(
                            child: Text('Kullanıcı adı veya isim gir.'),
                          )
                        : const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text(error.toString())),
                    data: (contacts) {
                      if (controller.text.trim().isEmpty) {
                        return const Center(
                          child: Text('Kullanıcı adı veya isim gir.'),
                        );
                      }
                      if (contacts.isEmpty) {
                        return const Center(
                          child: Text('Eşleşen kişi bulunamadı.'),
                        );
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
                                  .read(messengerRepositoryProvider)
                                  .createThread(contact.id);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              if (threadId != null) {
                                context.push('/messages/$threadId');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sohbet başlatılamadı.'),
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
    );
  } finally {
    controller.dispose();
  }
}
