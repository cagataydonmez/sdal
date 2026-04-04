import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../application/live_chat_action_controller.dart';
import '../data/live_chat_repository.dart';

class LiveChatPage extends ConsumerStatefulWidget {
  const LiveChatPage({super.key});

  @override
  ConsumerState<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends ConsumerState<LiveChatPage> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  final List<LiveChatMessage> _messages = <LiveChatMessage>[];
  StreamSubscription<LiveChatEvent>? _eventsSubscription;
  StreamSubscription<RealtimeConnectionState>? _statesSubscription;
  RealtimeConnectionState? _connectionState;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _eventsSubscription?.cancel();
    _statesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadInitial();
    final service = ref.read(liveChatRealtimeServiceProvider);
    _eventsSubscription = service.events.listen(_handleEvent);
    _statesSubscription = service.states.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
      }
    });
    await service.start();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final items = await ref.read(liveChatRepositoryProvider).fetchMessages();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(_mergeMessages(items));
      _loading = false;
    });
    _jumpToBottom();
  }

  void _handleEvent(LiveChatEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event.type) {
        case 'chat:new':
        case 'chat:updated':
          if (event.item != null) {
            _messages
              ..clear()
              ..addAll(_mergeMessages([..._messages, event.item!]));
          }
          break;
        case 'chat:deleted':
          _messages.removeWhere((message) => message.id == event.messageId);
          break;
      }
    });
    _jumpToBottom();
  }

  List<LiveChatMessage> _mergeMessages(List<LiveChatMessage> items) {
    final merged = <int, LiveChatMessage>{
      for (final item in _messages) item.id: item,
    };
    for (final item in items) {
      merged[item.id] = item;
    }
    final out = merged.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final currentUserId = session?.user?.id ?? 0;
    final config = ref.watch(appConfigProvider);
    final actionState = ref.watch(liveChatActionControllerProvider);
    return FeatureScaffold(
      title: 'Canli sohbet',
      actions: [
        IconButton(onPressed: _loadInitial, icon: const Icon(Icons.refresh)),
      ],
      child: Column(
        children: [
          if (_connectionState != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color:
                  _connectionState!.status == RealtimeConnectionStatus.connected
                  ? const Color(0xFFE5F7ED)
                  : const Color(0xFFFFF0D5),
              child: Text(
                _connectionState!.status == RealtimeConnectionStatus.connected
                    ? 'Canli baglanti aktif'
                    : 'Baglanti yeniden kuruluyor...',
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInitial,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _messages[index];
                        final isMine = item.userId == currentUserId;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: isMine
                                ? () => _openMessageActions(context, item)
                                : null,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? const Color(0xFF0D4C7D)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (!isMine)
                                            RemoteAvatar(
                                              label:
                                                  item.user?.displayName ??
                                                  'Uye',
                                              imageUrl: config
                                                  .resolveUrl(
                                                    item.user?.photo ?? '',
                                                  )
                                                  .toString(),
                                              radius: 16,
                                            ),
                                          if (!isMine) const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.user?.displayName ??
                                                  'SDAL Uyesi',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: isMine
                                                        ? Colors.white70
                                                        : null,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            item.createdAt,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: isMine
                                                      ? Colors.white60
                                                      : null,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.message,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: isMine
                                                  ? Colors.white
                                                  : null,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Mesajini yaz',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _sendMessage(context),
                    child: Text(actionState.isLoading ? '...' : 'Gonder'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final item = await ref
        .read(liveChatActionControllerProvider.notifier)
        .sendMessage(text);
    if (!mounted) return;
    if (item != null) {
      setState(() {
        _messages
          ..clear()
          ..addAll(_mergeMessages([item]));
      });
      _composerController.clear();
      _jumpToBottom();
      return;
    }
    final message = ref.read(liveChatActionControllerProvider).message;
    if ((message ?? '').isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(message!)));
    }
  }

  Future<void> _openMessageActions(
    BuildContext context,
    LiveChatMessage item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Mesaji duzenle'),
              onTap: () async {
                Navigator.of(context).pop();
                await _editMessage(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Mesaji sil'),
              onTap: () async {
                Navigator.of(context).pop();
                await _deleteMessage(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(LiveChatMessage item) async {
    final controller = TextEditingController(text: item.message);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesaji duzenle'),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    final updated = await ref
        .read(liveChatActionControllerProvider.notifier)
        .editMessage(messageId: item.id, message: next);
    if (!mounted || updated == null) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(_mergeMessages([updated]));
    });
  }

  Future<void> _deleteMessage(LiveChatMessage item) async {
    final ok = await ref
        .read(liveChatActionControllerProvider.notifier)
        .deleteMessage(item.id);
    if (!mounted || !ok) return;
    setState(() => _messages.removeWhere((message) => message.id == item.id));
  }
}
