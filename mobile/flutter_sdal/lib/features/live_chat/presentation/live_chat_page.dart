import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
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
  bool _loadingOlder = false;
  bool _hasOlder = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
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

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingOlder ||
        !_hasOlder) {
      return;
    }
    if (_scrollController.offset <= 140) {
      _loadOlder();
    }
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
    final merged = _mergeMessages(const <LiveChatMessage>[], items);
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
      _loading = false;
      _hasOlder = items.length >= 50;
    });
    _jumpToBottom();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    final older = await ref
        .read(liveChatRepositoryProvider)
        .fetchMessages(beforeId: _messages.first.id, limit: 30);
    if (!mounted) return;
    final merged = _mergeMessages(_messages, older);
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
      _loadingOlder = false;
      _hasOlder = older.length >= 30;
    });
  }

  void _handleEvent(LiveChatEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event.type) {
        case 'chat:new':
        case 'chat:updated':
          if (event.item != null) {
            final merged = _mergeMessages(_messages, [event.item!]);
            _messages
              ..clear()
              ..addAll(merged);
          }
          break;
        case 'chat:deleted':
          _messages.removeWhere((message) => message.id == event.messageId);
          break;
      }
    });
    _jumpToBottom();
  }

  List<LiveChatMessage> _mergeMessages(
    List<LiveChatMessage> base,
    List<LiveChatMessage> incoming,
  ) {
    final merged = <int, LiveChatMessage>{
      for (final item in base) item.id: item,
    };
    for (final item in incoming) {
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
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return FeatureScaffold(
      title: l10n.liveChatTitle,
      background: FeatureScaffoldBackground.utility,
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
                  ? tokens.successMuted
                  : tokens.warningMuted,
              child: Text(
                _connectionState!.status == RealtimeConnectionStatus.connected
                    ? l10n.liveChatConnected
                    : l10n.liveChatReconnecting,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInitial,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          if (_loadingOlder) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 12);
                        }
                        final item = _messages[index - 1];
                        final isMine = item.userId == currentUserId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: isMine
                                  ? () => _openMessageActions(context, item)
                                  : null,
                              child: LayoutBuilder(
                                builder: (context, constraints) => ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width *
                                        (MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(1) >
                                                1.15
                                            ? 0.8
                                            : 0.72),
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? tokens.chatOutgoing
                                          : tokens.chatIncoming,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: isMine
                                            ? tokens.chatOutgoing
                                            : tokens.panelBorder,
                                      ),
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
                                                      context
                                                          .l10n
                                                          .genericMemberLabel,
                                                  imageUrl: config
                                                      .resolveUrl(
                                                        item.user?.photo ?? '',
                                                      )
                                                      .toString(),
                                                  radius: 16,
                                                ),
                                              if (!isMine)
                                                const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.user?.displayName ??
                                                      context
                                                          .l10n
                                                          .genericMemberLabel,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        color: isMine
                                                            ? tokens
                                                                  .foregroundOnAccent
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
                                                          ? tokens
                                                                .foregroundOnAccent
                                                                .withValues(
                                                                  alpha: 0.72,
                                                                )
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
                                                      ? tokens
                                                            .foregroundOnAccent
                                                      : null,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackComposer =
                      constraints.maxWidth < 420 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2;
                  final field = TextField(
                    controller: _composerController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.messageFieldLabel,
                      hintText: l10n.liveChatComposerHint,
                      border: const OutlineInputBorder(),
                    ),
                  );
                  final sendButton = FilledButton(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _sendMessage(context),
                    child: Text(
                      actionState.isLoading
                          ? l10n.messageSendInProgress
                          : l10n.messageSendAction,
                    ),
                  );
                  if (stackComposer) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [field, const SizedBox(height: 12), sendButton],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: field),
                      const SizedBox(width: 12),
                      sendButton,
                    ],
                  );
                },
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
      final merged = _mergeMessages(_messages, [item]);
      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
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
              title: Text(context.l10n.liveChatEditMessageAction),
              onTap: () async {
                Navigator.of(context).pop();
                await _editMessage(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.liveChatDeleteMessageAction),
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
        title: Text(context.l10n.liveChatEditDialogTitle),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.saveAction),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    final updated = await ref
        .read(liveChatActionControllerProvider.notifier)
        .editMessage(messageId: item.id, message: next);
    if (!mounted || updated == null) return;
    final merged = _mergeMessages(_messages, [updated]);
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
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
