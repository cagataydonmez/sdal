import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/page_onboarding_card.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../messenger/application/messenger_action_controller.dart';
import '../application/following_action_controller.dart';
import '../data/following_detail_repository.dart';
import '../data/following_repository.dart';

class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  final ScrollController _scrollController = ScrollController();
  final List<FollowingMember> _items = <FollowingMember>[];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(followingActionControllerProvider);
    final messengerState = ref.watch(messengerActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;

    return FeatureScaffold(
      title: 'Takip Ettiklerim',
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            PageOnboardingCard(
              id: 'following-main',
              icon: Icons.people_alt_outlined,
              title: 'Takip listeni güvenilir çevren gibi kullan.',
              message:
                  'Yakın takip ettiğin mezun, öğrenci ve öğretmenlerin güncellemelerine buradan dönersin. Yeni bağlantılar için keşfet akışını açabilirsin.',
              primaryActionLabel: context.l10n.exploreTitle,
              onPrimaryAction: () => context.push('/explore'),
            ),
            const SizedBox(height: 16),
            if (_isLoadingInitial)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty && _items.isEmpty)
              SurfaceCard(
                child: ErrorView(
                  message: _error,
                  onRetry: () => _load(reset: true),
                  kind: ErrorViewKind.network,
                ),
              )
            else if (_items.isEmpty)
              SurfaceCard(
                child: EmptyStateView(
                  icon: Icons.person_add_alt_1_outlined,
                  title: context.l10n.followingEmptyTitle,
                  message: context.l10n.followingEmptyMessage,
                  actionLabel: context.l10n.exploreTitle,
                  onAction: () => context.push('/explore'),
                ),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () =>
                                  context.push('/members/${item.memberId}'),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: RemoteAvatar(
                                  label: item.name,
                                  imageUrl: config
                                      .resolveUrl(item.photo)
                                      .toString(),
                                  radius: 28,
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () =>
                                    context.push('/members/${item.memberId}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (item.handle.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '@${item.handle}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: tokens.foregroundMuted,
                                            ),
                                      ),
                                    ],
                                    if (item.verified ||
                                        item.role.trim().toLowerCase() !=
                                            'user') ...[
                                      const SizedBox(height: 6),
                                      MemberBadgeStrip(
                                        verified: item.verified,
                                        role: item.role,
                                        graduationYear: item.graduationYear,
                                        compact: true,
                                      ),
                                    ],
                                    if (item.followedAt.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Takip tarihi: ${_formatDate(context, item.followedAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: tokens.foregroundMuted,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed:
                                  actionState.isLoading &&
                                      actionState.scope ==
                                          'follow:${item.memberId}'
                                  ? null
                                  : () => _toggleFollow(item),
                              child: Text(
                                actionState.isLoading &&
                                        actionState.scope ==
                                            'follow:${item.memberId}'
                                    ? 'İşleniyor...'
                                    : 'Takibi bırak',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: _FollowingActionBar(
                            messageInFlight:
                                messengerState.isLoading &&
                                messengerState.scope ==
                                    'messenger:createThread',
                            onMessage: () => _openConversation(item),
                            onOpenSection: (section) => context.push(
                              '/following/member/${item.memberId}/${section.key}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_hasMore && _items.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Takip listenin sonuna ulaştın.',
                    style: TextStyle(color: tokens.foregroundMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoadingInitial = true;
        _error = '';
        _hasMore = true;
      });
    } else {
      if (_isLoadingInitial || _isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await ref
          .read(followingRepositoryProvider)
          .fetchFollowing(offset: reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _hasMore = result.hasMore;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingInitial || _isLoadingMore) {
      return;
    }
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 240) {
      _load(reset: false);
    }
  }

  Future<void> _toggleFollow(FollowingMember item) async {
    final following = await ref
        .read(followingActionControllerProvider.notifier)
        .toggleFollow(item.memberId);
    if (!mounted) return;

    final actionState = ref.read(followingActionControllerProvider);
    if (following == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionState.message ?? 'İşlem başarısız oldu.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(actionState.message ?? 'Takip güncellendi.')),
    );

    if (following == false) {
      setState(() {
        _items.removeWhere((entry) => entry.memberId == item.memberId);
      });
      if (_items.isEmpty && _hasMore) {
        _load(reset: true);
      }
      return;
    }

    _load(reset: true);
  }

  Future<void> _openConversation(FollowingMember item) async {
    final threadId = await ref
        .read(messengerActionControllerProvider.notifier)
        .createThread(item.memberId);
    if (!mounted) return;

    if (threadId == null) {
      final actionState = ref.read(messengerActionControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.message ?? 'Mesajlaşma başlatılamadı.'),
        ),
      );
      return;
    }

    context.push('/messages/$threadId');
  }
}

class _FollowingActionBar extends StatelessWidget {
  const _FollowingActionBar({
    required this.messageInFlight,
    required this.onMessage,
    required this.onOpenSection,
  });

  final bool messageInFlight;
  final VoidCallback onMessage;
  final ValueChanged<FollowingDetailSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _ActionButton(
        icon: Icons.mail_outline_rounded,
        label: messageInFlight ? 'Açılıyor...' : 'Mesaj gönder',
        onPressed: messageInFlight ? null : onMessage,
      ),
      ...FollowingDetailSection.all.map(
        (section) => _ActionButton(
          icon: section.icon,
          label: section.label,
          onPressed: () => onOpenSection(section),
        ),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: action,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

String _formatDate(BuildContext context, String raw) =>
    formatSdalTimestamp(context, raw);
