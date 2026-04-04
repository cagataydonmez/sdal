import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/following_action_controller.dart';
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
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Takip edilenler',
      actions: [
        IconButton(
          onPressed: _isLoadingInitial ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            if (_isLoadingInitial)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty && _items.isEmpty)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Takip listesi yüklenemedi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_error),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Henüz takip ettiğin üye yok.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keşfet ekranından ilgilendiğin üyeleri takip ederek burada görebilirsin.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => context.push('/explore'),
                      child: const Text('Keşfete git'),
                    ),
                  ],
                ),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Row(
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    if (item.verified)
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                  ],
                                ),
                                if (item.handle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${item.handle}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Etkileşim puanı: ${item.engagementScore.toStringAsFixed(1)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (item.followedAt.isNotEmpty)
                                  Text(
                                    'Takip tarihi: ${_formatDate(item.followedAt)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed:
                              actionState.isLoading &&
                                  actionState.scope == 'follow:${item.memberId}'
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
                  ),
                ),
              ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_hasMore && _items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Takip listenin sonuna ulaştın.',
                    style: TextStyle(color: Colors.black54),
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
}

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}
