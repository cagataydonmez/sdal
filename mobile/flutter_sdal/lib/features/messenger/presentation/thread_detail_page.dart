import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/messenger_action_controller.dart';
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
    final actionState = ref.watch(messengerActionControllerProvider);
    final l10n = context.l10n;
    final sending =
        actionState.isLoading &&
        actionState.scope == 'messenger:send:${widget.threadId}';

    MessengerThreadSummary? thread;
    final threadItems =
        threadsState.valueOrNull ?? const <MessengerThreadSummary>[];
    for (final item in threadItems) {
      if (item.id == widget.threadId) {
        thread = item;
        break;
      }
    }
    final title = thread?.peer.name ?? l10n.threadFallbackTitle;

    return FeatureScaffold(
      title: title,
      actions: [
        StreamBuilder(
          stream: realtime.states,
          initialData: realtime.currentState,
          builder: (context, snapshot) {
            final state =
                snapshot.data ?? const RealtimeConnectionState.disconnected();
            final label = switch (state.status) {
              RealtimeConnectionStatus.connected => l10n.realtimeConnected,
              RealtimeConnectionStatus.reconnecting => l10n.realtimeConnected,
              RealtimeConnectionStatus.failed => l10n.realtimeFailed,
              RealtimeConnectionStatus.connecting => l10n.realtimeConnecting,
              RealtimeConnectionStatus.disconnected => l10n.realtimeConnecting,
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.threadEmpty),
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
                      decoration: InputDecoration(
                        labelText: l10n.messageFieldLabel,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: sending ? null : _sendMessage,
                    child: Text(
                      sending
                          ? l10n.messageSendInProgress
                          : l10n.messageSendAction,
                    ),
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
    final ok = await ref
        .read(messengerActionControllerProvider.notifier)
        .sendMessage(threadId: widget.threadId, text: text);
    if (!mounted) return;

    if (ok) {
      _messageController.clear();
      return;
    }

    final actionState = ref.read(messengerActionControllerProvider);
    final actionMessage = actionState.message ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionMessage.isNotEmpty
              ? actionMessage
              : context.l10n.messageSendFailed,
        ),
      ),
    );
  }
}
