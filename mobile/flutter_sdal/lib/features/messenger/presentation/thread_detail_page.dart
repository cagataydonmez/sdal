import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/messenger_repository.dart';

class ThreadDetailPage extends ConsumerStatefulWidget {
  const ThreadDetailPage({super.key, required this.threadId});

  final int threadId;

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage> {
  final _messageController = TextEditingController();
  StreamSubscription<MessengerRealtimeEvent>? _eventsSubscription;
  bool _sending = false;
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    final realtime = ref.read(messengerRealtimeServiceProvider);
    realtime.start();
    _eventsSubscription = realtime.events.listen((event) {
      if (event.threadId == widget.threadId) {
        ref.invalidate(messengerMessagesProvider(widget.threadId));
      }
      ref.invalidate(messengerThreadsProvider(''));
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messengerMessagesProvider(widget.threadId));
    final threadsState = ref.watch(messengerThreadsProvider(''));
    final realtime = ref.watch(messengerRealtimeServiceProvider);
    final config = ref.watch(appConfigProvider);

    MessengerThreadSummary? thread;
    final threadItems =
        threadsState.valueOrNull ?? const <MessengerThreadSummary>[];
    for (final item in threadItems) {
      if (item.id == widget.threadId) {
        thread = item;
        break;
      }
    }
    final title = thread?.peer.name ?? 'Sohbet';

    return FeatureScaffold(
      title: title,
      actions: [
        StreamBuilder(
          stream: realtime.states,
          builder: (context, snapshot) {
            final state =
                snapshot.data ?? const RealtimeConnectionState.disconnected();
            final label = switch (state.status) {
              RealtimeConnectionStatus.connected => 'Canlı',
              RealtimeConnectionStatus.reconnecting => 'Yeniden bağlanıyor',
              RealtimeConnectionStatus.failed => 'Bağlantı yok',
              RealtimeConnectionStatus.connecting => 'Bağlanıyor',
              RealtimeConnectionStatus.disconnected => 'Kapalı',
            };
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        ),
      ],
      child: Column(
        children: [
          if (thread != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: SurfaceCard(
                child: Row(
                  children: [
                    RemoteAvatar(
                      label: thread.peer.name,
                      imageUrl: config.resolveUrl(thread.peer.photo).toString(),
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.peer.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (thread.peer.handle.isNotEmpty)
                            Text(
                              '@${thread.peer.handle}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (messages) {
                if (!_markedRead) {
                  _markedRead = true;
                  Future<void>.microtask(() async {
                    await ref
                        .read(messengerRepositoryProvider)
                        .markThreadRead(widget.threadId);
                    ref.invalidate(messengerThreadsProvider(''));
                  });
                }
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Henüz mesaj yok. İlk mesajı sen gönder.'),
                    ),
                  );
                }
                return ListView.separated(
                  reverse: false,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: messages.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bubbleColor = message.isMine
                        ? const Color(0xFF0D2238)
                        : Colors.white;
                    final textColor = message.isMine
                        ? Colors.white
                        : const Color(0xFF0D2238);
                    return Align(
                      alignment: message.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.body,
                                  style: TextStyle(color: textColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message.createdAt,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: message.isMine
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Mesaj',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    child: Text(_sending ? '...' : 'Gönder'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final result = await ref
        .read(messengerRepositoryProvider)
        .sendMessage(threadId: widget.threadId, text: text);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.ok) {
      _messageController.clear();
      ref.invalidate(messengerMessagesProvider(widget.threadId));
      ref.invalidate(messengerThreadsProvider(''));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isNotEmpty ? result.message : 'Mesaj gönderilemedi.',
        ),
      ),
    );
  }
}
