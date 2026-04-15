import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/paged_response.dart';
import '../../../core/network/realtime_connection_state.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/chat_jump_to_latest_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/realtime_status_banner.dart';
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
  static const _pollInterval = Duration(seconds: 6);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<MessengerRealtimeEvent>? _eventsSubscription;
  ProviderSubscription<AsyncValue<PagedResponse<MessengerMessage>>>?
  _messagesSubscription;
  Timer? _pollTimer;
  bool _disposed = false;
  final List<MessengerMessage> _olderMessages = <MessengerMessage>[];
  late final GoRouter _router;
  bool _markReadInFlight = false;
  bool _loadingOlder = false;
  bool _hasOlderMessages = false;
  bool _showJumpToLatest = false;
  bool _hasPendingNewMessages = false;
  int? _lastNewestMessageId;
  int? _lastMarkedReadMessageId;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider);
    _router.routerDelegate.addListener(_syncActiveThreadVisibility);
    _scheduleActiveThreadVisibilitySync();
    _scrollController.addListener(_handleScroll);
    final realtime = ref.read(messengerRealtimeServiceProvider);
    realtime.start();
    _eventsSubscription = realtime.events.listen((event) {
      if (_disposed) return;
      if (event.threadId == widget.threadId) {
        ref.invalidate(messengerMessagesProvider(widget.threadId));
      }
      ref.invalidate(messengerThreadsProvider(''));
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_disposed || !_isThreadVisible()) return;
      ref.invalidate(messengerMessagesProvider(widget.threadId));
    });
    _messagesSubscription = ref.listenManual(
      messengerMessagesProvider(widget.threadId),
      (_, next) => next.whenData(_handleMessagesUpdate),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleActiveThreadVisibilitySync();
  }

  void _syncActiveThreadVisibility() {
    if (_disposed || !mounted) return;
    final notifier = ref.read(activeMessengerThreadIdProvider.notifier);
    if (_isThreadVisible()) {
      if (notifier.state != widget.threadId) {
        notifier.state = widget.threadId;
      }
      final newestMessageId = _lastNewestMessageId;
      if (newestMessageId != null) {
        _scheduleMarkThreadRead(newestMessageId: newestMessageId);
      }
      return;
    }
    if (notifier.state == widget.threadId) {
      notifier.state = null;
    }
  }

  bool _isThreadVisible() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    final isCurrentRoute = route?.isCurrent ?? true;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    return isCurrentRoute && tickerEnabled;
  }

  void _scheduleActiveThreadVisibilitySync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncActiveThreadVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant ThreadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId) {
      _scheduleActiveThreadVisibilitySync();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _router.routerDelegate.removeListener(_syncActiveThreadVisibility);
    final notifier = ref.read(activeMessengerThreadIdProvider.notifier);
    if (notifier.state == widget.threadId) {
      notifier.state = null;
    }
    _pollTimer?.cancel();
    _eventsSubscription?.cancel();
    _messagesSubscription?.close();
    _messageController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShowJump = !_isNearBottom();
    if (shouldShowJump != _showJumpToLatest) {
      setState(() => _showJumpToLatest = shouldShowJump);
    }
    if (_hasPendingNewMessages && _isNearBottom()) {
      setState(() {
        _hasPendingNewMessages = false;
        _showJumpToLatest = false;
      });
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentAfter <= 96;
  }

  void _handleMessagesUpdate(PagedResponse<MessengerMessage> page) {
    final newestId = page.items.isEmpty ? null : page.items.last.id;
    final isFirstLoad = _lastNewestMessageId == null;
    final hasNewMessage =
        newestId != null &&
        _lastNewestMessageId != null &&
        newestId != _lastNewestMessageId;
    _lastNewestMessageId = newestId;
    if (isFirstLoad) {
      _scrollToBottom(force: true, animated: false);
    } else if (hasNewMessage) {
      final shouldAutoScroll = _isNearBottom();
      _scrollToBottom(force: shouldAutoScroll);
      if (!shouldAutoScroll && mounted) {
        setState(() {
          _showJumpToLatest = true;
          _hasPendingNewMessages = true;
        });
      }
    }
    _scheduleMarkThreadRead(newestMessageId: newestId);
  }

  void _scheduleMarkThreadRead({required int? newestMessageId}) {
    if (_markReadInFlight || newestMessageId == null) return;
    // Only mark as read when the user is actively viewing this thread.
    // The page stays mounted on tab switch (StatefulShellBranch), so incoming
    // messages would otherwise be silently marked read while the user is gone.
    if (!_isThreadVisible()) return;
    if (_lastMarkedReadMessageId == newestMessageId) return;
    _markReadInFlight = true;
    Future<void>.microtask(() async {
      try {
        final result = await ref
            .read(messengerRepositoryProvider)
            .markThreadRead(widget.threadId);
        if (!result.ok) {
          if (_isThreadVisible()) {
            ref.invalidate(messengerThreadsProvider(''));
            ref.invalidate(messengerUnreadCountProvider);
          }
          return;
        }
        _lastMarkedReadMessageId = newestMessageId;
        ref.invalidate(messengerThreadsProvider(''));
        ref.invalidate(messengerUnreadCountProvider);
      } catch (_) {
      } finally {
        _markReadInFlight = false;
        final latestNewestId = _lastNewestMessageId;
        if (_isThreadVisible() &&
            latestNewestId != null &&
            latestNewestId != newestMessageId) {
          _scheduleMarkThreadRead(newestMessageId: latestNewestId);
        }
      }
    });
  }

  void _scrollToBottom({bool force = false, bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && !_isNearBottom()) {
        if (mounted) {
          setState(() => _showJumpToLatest = true);
        }
        return;
      }
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      if (mounted) {
        setState(() {
          _showJumpToLatest = false;
          _hasPendingNewMessages = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messengerMessagesProvider(widget.threadId));
    final threadsState = ref.watch(messengerThreadsProvider(''));
    final realtime = ref.watch(messengerRealtimeServiceProvider);
    final config = ref.watch(appConfigProvider);
    final actionState = ref.watch(messengerActionControllerProvider);
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final sending =
        actionState.isLoading &&
        actionState.scope == 'messenger:send:${widget.threadId}';

    MessengerThreadSummary? thread;
    final threadItems = threadsState.value ?? const <MessengerThreadSummary>[];
    for (final item in threadItems) {
      if (item.id == widget.threadId) {
        thread = item;
        break;
      }
    }
    final title = thread?.peer.name ?? l10n.threadFallbackTitle;

    return FeatureScaffold(
      title: title,
      child: Column(
        children: [
          StreamBuilder(
            stream: realtime.states,
            initialData: realtime.currentState,
            builder: (context, snapshot) {
              final state =
                  snapshot.data ?? const RealtimeConnectionState.disconnected();
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, -0.12),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: RealtimeStatusBanner(
                  key: ValueKey(state.status),
                  state: state,
                  connectedLabel: l10n.realtimeConnected,
                  reconnectingLabel: l10n.realtimeReconnecting,
                  failedLabel: l10n.realtimeFailed,
                  connectingLabel: l10n.realtimeConnecting,
                  disconnectedLabel: l10n.realtimeDisconnected,
                ),
              );
            },
          ),
          if (thread != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Builder(
                builder: (context) {
                  final currentThread = thread!;
                  return SurfaceCard(
                    onTap: () =>
                        context.push('/members/${currentThread.peer.id}'),
                    tooltip: context.l10n.openMemberProfileForName(
                      currentThread.peer.name,
                    ),
                    semanticLabel: context.l10n.openMemberProfileForName(
                      currentThread.peer.name,
                    ),
                    semanticContainer: true,
                    child: Row(
                      children: [
                        RemoteAvatar(
                          label: currentThread.peer.name,
                          imageUrl: config
                              .resolveUrl(currentThread.peer.photo)
                              .toString(),
                          radius: 24,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentThread.peer.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentThread.peer.handle.isNotEmpty)
                                Text(
                                  '@${currentThread.peer.handle}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const ErrorView(kind: ErrorViewKind.network),
              data: (page) {
                final latestMessages = page.items;
                _hasOlderMessages = _olderMessages.isNotEmpty
                    ? _hasOlderMessages
                    : page.hasMore;
                final messages = [..._olderMessages, ...latestMessages];
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateView(
                        icon: Icons.chat_outlined,
                        title: l10n.threadEmptyTitle,
                        message: l10n.threadEmptyMessage,
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollController,
                      reverse: false,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount:
                          messages.length +
                          ((_loadingOlder || _hasOlderMessages) ? 1 : 0),
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (_loadingOlder || _hasOlderMessages) {
                          if (index == 0) {
                            return Center(
                              child: TextButton.icon(
                                onPressed: _loadingOlder
                                    ? null
                                    : _loadOlderMessages,
                                icon: _loadingOlder
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_less_rounded),
                                label: Text(
                                  _loadingOlder
                                      ? 'Yükleniyor...'
                                      : 'Eski mesajları yükle',
                                ),
                              ),
                            );
                          }
                          index -= 1;
                        }
                        final message = messages[index];
                        final bubbleColor = message.isMine
                            ? tokens.chatOutgoing
                            : tokens.chatIncoming;
                        final textColor = message.isMine
                            ? tokens.foregroundOnAccent
                            : tokens.foreground;
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final textScale = MediaQuery.textScalerOf(
                              context,
                            ).scale(1);
                            final maxBubbleWidth =
                                constraints.maxWidth *
                                (textScale > 1.15 ? 0.92 : 0.82);
                            return Align(
                              alignment: message.isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxBubbleWidth,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: bubbleColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: message.isMine
                                          ? tokens.chatOutgoing
                                          : tokens.panelBorder,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: tokens.foreground.withValues(
                                          alpha: 0.06,
                                        ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.body,
                                          style: TextStyle(color: textColor),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          formatSdalTimestamp(
                                            context,
                                            message.createdAt,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: message.isMine
                                                    ? tokens.foregroundOnAccent
                                                          .withValues(
                                                            alpha: 0.72,
                                                          )
                                                    : tokens.foregroundMuted,
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
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 180),
                        offset: _showJumpToLatest
                            ? Offset.zero
                            : const Offset(0, 0.4),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _showJumpToLatest ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_showJumpToLatest,
                            child: ChatJumpToLatestButton(
                              label: _hasPendingNewMessages
                                  ? l10n.chatNewMessagesAction
                                  : l10n.chatJumpToLatestAction,
                              highlighted: _hasPendingNewMessages,
                              onPressed: () => _scrollToBottom(force: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
      _scrollToBottom(force: true);
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

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder) return;
    final initialPage = ref
        .read(messengerMessagesProvider(widget.threadId))
        .value;
    final initialItems = initialPage?.items ?? const <MessengerMessage>[];
    final oldestId = _olderMessages.isNotEmpty
        ? _olderMessages.first.id
        : (initialItems.isEmpty ? null : initialItems.first.id);
    if ((oldestId ?? 0) <= 0) return;
    setState(() => _loadingOlder = true);
    final page = await ref
        .read(messengerRepositoryProvider)
        .fetchMessages(widget.threadId, beforeId: oldestId);
    if (!mounted) return;
    setState(() {
      _olderMessages.insertAll(0, page.items);
      _hasOlderMessages = page.hasMore;
      _loadingOlder = false;
    });
  }
}
