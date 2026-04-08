import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/api_result.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/networking_repository.dart';

class NetworkingHubPage extends ConsumerStatefulWidget {
  const NetworkingHubPage({super.key});

  @override
  ConsumerState<NetworkingHubPage> createState() => _NetworkingHubPageState();
}

class _NetworkingHubPageState extends ConsumerState<NetworkingHubPage> {
  String _hubSuggestionTelemetryKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(networkingRepositoryProvider)
            .trackTelemetry(
              const NetworkingTelemetryEvent(
                eventName: 'network_hub_viewed',
                sourceSurface: 'network_hub',
                metadata: {'window': '30d'},
              ),
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(networkHubProvider);
    final metricsState = ref.watch(networkMetricsProvider);
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Networking',
      actions: [
        IconButton(
          tooltip: context.l10n.refreshAction,
          onPressed: () {
            ref.invalidate(networkHubProvider);
            ref.invalidate(networkMetricsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: hubState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const ErrorView(compact: true),
          ),
        ),
        data: (hub) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _trackHubSuggestions(hub.discoverySuggestions),
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Aksiyon bekleyen',
                      value: '${hub.actionableCount}',
                      icon: Icons.bolt,
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      label: 'Bağlantı',
                      value:
                          '${hub.incomingConnections.length + hub.outgoingConnections.length}',
                      icon: Icons.people_alt_outlined,
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      label: 'Mentorluk',
                      value:
                          '${hub.incomingMentorship.length + hub.outgoingMentorship.length}',
                      icon: Icons.school_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            metricsState.when(
              loading: () => const SurfaceCard(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (metrics) => SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Networking içgörüleri',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MiniMetricChip(
                          label: 'İstekler',
                          value: '${metrics.connectionsRequested}',
                        ),
                        _MiniMetricChip(
                          label: 'Kabul edilen',
                          value: '${metrics.connectionsAccepted}',
                        ),
                        _MiniMetricChip(
                          label: 'Bekleyen gelen',
                          value: '${metrics.connectionsPendingIncoming}',
                        ),
                        _MiniMetricChip(
                          label: 'Bekleyen giden',
                          value: '${metrics.connectionsPendingOutgoing}',
                        ),
                        _MiniMetricChip(
                          label: 'Mentorluk',
                          value: '${metrics.mentorshipAccepted}',
                        ),
                        _MiniMetricChip(
                          label: 'Öğretmen linki',
                          value: '${metrics.teacherLinksCreated}',
                        ),
                      ],
                    ),
                    if (metrics.timeToFirstNetworkSuccessDays != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'İlk network başarısı: ${metrics.timeToFirstNetworkSuccessDays} gün',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/network/inbox'),
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Networking Inbox'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/network/teachers'),
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('Öğretmen bağlantıları'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Öne çıkan öneriler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (hub.discoverySuggestions.isEmpty)
              const SurfaceCard(
                child: Text('Şu anda yeni networking önerisi yok.'),
              )
            else
              ...hub.discoverySuggestions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RemoteAvatar(
                              label: item.name,
                              imageUrl: config
                                  .resolveUrl(item.photo)
                                  .toString(),
                              radius: 26,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (item.handle.isNotEmpty)
                                    Text(
                                      '@${item.handle}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  if (item.profession.isNotEmpty ||
                                      item.city.isNotEmpty)
                                    Text(
                                      [item.profession, item.city]
                                          .where((part) => part.isNotEmpty)
                                          .join(' · '),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.openAction,
                              onPressed: () =>
                                  context.push('/members/${item.id}'),
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _showActionResult(
                                  context,
                                  ref
                                      .read(networkingRepositoryProvider)
                                      .requestConnection(item.id),
                                  onDone: () {
                                    ref.invalidate(networkHubProvider);
                                    ref.invalidate(networkInboxProvider);
                                  },
                                ),
                                child: const Text('Bağlantı iste'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => _openMentorshipDialog(
                                  context,
                                  ref,
                                  item.id,
                                ),
                                child: const Text('Mentorluk iste'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trackHubSuggestions(List<NetworkDiscoverySuggestion> items) {
    final key = items.map((item) => item.id).join(',');
    if (key.isNotEmpty && key != _hubSuggestionTelemetryKey) {
      _hubSuggestionTelemetryKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(networkingRepositoryProvider)
              .trackTelemetry(
                NetworkingTelemetryEvent(
                  eventName: 'network_hub_suggestions_loaded',
                  sourceSurface: 'network_hub',
                  entityType: 'suggestion_batch',
                  metadata: {'suggestion_count': items.length},
                ),
              ),
        );
      });
    }
    return const SizedBox.shrink();
  }
}

class NetworkingInboxPage extends ConsumerWidget {
  const NetworkingInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(networkInboxProvider);
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Networking Inbox',
      actions: [
        IconButton(
          tooltip: context.l10n.refreshAction,
          onPressed: () {
            ref.invalidate(networkInboxProvider);
            ref.invalidate(connectionRequestsProvider);
            ref.invalidate(mentorshipRequestsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: inboxState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const ErrorView(),
        data: (inbox) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _ConnectionRequestsBrowser(),
            const SizedBox(height: 18),
            const _MentorshipRequestsBrowser(),
            const SizedBox(height: 18),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Öğretmen ağı bildirimleri',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: inbox.teacherEvents.isEmpty
                            ? null
                            : () => _showActionResult(
                                context,
                                ref
                                    .read(networkingRepositoryProvider)
                                    .markTeacherLinksRead(),
                                onDone: () =>
                                    ref.invalidate(networkInboxProvider),
                              ),
                        child: const Text('Okundu işaretle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (inbox.teacherEvents.isEmpty)
                    const Text('Yeni öğretmen ağı bildirimi yok.')
                  else
                    ...inbox.teacherEvents.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: RemoteAvatar(
                          label: item.member.name,
                          imageUrl: config
                              .resolveUrl(item.member.photo)
                              .toString(),
                        ),
                        title: Text(item.message),
                        subtitle: Text(item.createdAt),
                        trailing: item.isUnread
                            ? const Icon(
                                Icons.circle,
                                size: 10,
                                color: Color(0xFF1F6FEB),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionRequestsBrowser extends ConsumerStatefulWidget {
  const _ConnectionRequestsBrowser();

  @override
  ConsumerState<_ConnectionRequestsBrowser> createState() =>
      _ConnectionRequestsBrowserState();
}

class _ConnectionRequestsBrowserState
    extends ConsumerState<_ConnectionRequestsBrowser> {
  static const int _pageSize = 30;
  NetworkRequestDirection _direction = NetworkRequestDirection.incoming;
  ConnectionRequestStatus _status = ConnectionRequestStatus.pending;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final query = ConnectionRequestQuery(
      direction: _direction,
      status: _status,
      limit: _pageSize,
      offset: (_page - 1) * _pageSize,
    );
    final state = ref.watch(connectionRequestsProvider(query));
    final config = ref.watch(appConfigProvider);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bağlantı istekleri',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NetworkRequestDirection.values
                .map(
                  (direction) => ChoiceChip(
                    label: Text(
                      direction == NetworkRequestDirection.incoming
                          ? 'Gelen'
                          : 'Giden',
                    ),
                    selected: _direction == direction,
                    onSelected: (_) => setState(() {
                      _direction = direction;
                      _page = 1;
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ConnectionRequestStatus.values
                .map(
                  (status) => ChoiceChip(
                    label: Text(_connectionStatusLabel(status)),
                    selected: _status == status,
                    onSelected: (_) => setState(() {
                      _status = status;
                      _page = 1;
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => const ErrorView(compact: true),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  '${_direction == NetworkRequestDirection.incoming ? 'Gelen' : 'Giden'} ${_connectionStatusLabel(_status).toLowerCase()} bağlantı isteği yok.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RequestTile(
                        member: item.member,
                        subtitle: item.updatedAt.isNotEmpty
                            ? item.updatedAt
                            : item.createdAt,
                        imageUrl: config
                            .resolveUrl(item.member.photo)
                            .toString(),
                        statusLabel: _connectionStatusLabel(_status),
                        actions: _buildConnectionActions(context, item),
                      ),
                    ),
                  ),
                  _RequestPaginationControls(
                    page: _page,
                    canGoBack: _page > 1,
                    canGoForward: items.length >= _pageSize,
                    onPrevious: () => setState(() => _page -= 1),
                    onNext: () => setState(() => _page += 1),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConnectionActions(
    BuildContext context,
    NetworkRequestItem item,
  ) {
    if (_status != ConnectionRequestStatus.pending) return const [];
    if (_direction == NetworkRequestDirection.incoming) {
      return [
        TextButton(
          onPressed: () => _showActionResult(
            context,
            ref.read(networkingRepositoryProvider).ignoreConnection(item.id),
            onDone: _invalidateNetworkingRequests,
          ),
          child: const Text('Yoksay'),
        ),
        FilledButton(
          onPressed: () => _showActionResult(
            context,
            ref.read(networkingRepositoryProvider).acceptConnection(item.id),
            onDone: _invalidateNetworkingRequests,
          ),
          child: const Text('Kabul et'),
        ),
      ];
    }
    return [
      OutlinedButton(
        onPressed: () => _showActionResult(
          context,
          ref.read(networkingRepositoryProvider).cancelConnection(item.id),
          onDone: _invalidateNetworkingRequests,
        ),
        child: const Text('Geri çek'),
      ),
    ];
  }

  void _invalidateNetworkingRequests() {
    ref.invalidate(networkInboxProvider);
    ref.invalidate(connectionRequestsProvider);
  }
}

class _MentorshipRequestsBrowser extends ConsumerStatefulWidget {
  const _MentorshipRequestsBrowser();

  @override
  ConsumerState<_MentorshipRequestsBrowser> createState() =>
      _MentorshipRequestsBrowserState();
}

class _MentorshipRequestsBrowserState
    extends ConsumerState<_MentorshipRequestsBrowser> {
  static const int _pageSize = 30;
  NetworkRequestDirection _direction = NetworkRequestDirection.incoming;
  MentorshipRequestStatus _status = MentorshipRequestStatus.requested;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final query = MentorshipRequestQuery(
      direction: _direction,
      status: _status,
      limit: _pageSize,
      offset: (_page - 1) * _pageSize,
    );
    final state = ref.watch(mentorshipRequestsProvider(query));
    final config = ref.watch(appConfigProvider);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mentorluk talepleri',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NetworkRequestDirection.values
                .map(
                  (direction) => ChoiceChip(
                    label: Text(
                      direction == NetworkRequestDirection.incoming
                          ? 'Gelen'
                          : 'Giden',
                    ),
                    selected: _direction == direction,
                    onSelected: (_) => setState(() {
                      _direction = direction;
                      _page = 1;
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MentorshipRequestStatus.values
                .map(
                  (status) => ChoiceChip(
                    label: Text(_mentorshipStatusLabel(status)),
                    selected: _status == status,
                    onSelected: (_) => setState(() {
                      _status = status;
                      _page = 1;
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => const ErrorView(compact: true),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  '${_direction == NetworkRequestDirection.incoming ? 'Gelen' : 'Giden'} ${_mentorshipStatusLabel(_status).toLowerCase()} mentorluk talebi yok.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RequestTile(
                        member: item.member,
                        subtitle: item.focusArea.isNotEmpty
                            ? item.focusArea
                            : (item.updatedAt.isNotEmpty
                                  ? item.updatedAt
                                  : item.createdAt),
                        detail: item.message,
                        imageUrl: config
                            .resolveUrl(item.member.photo)
                            .toString(),
                        statusLabel: _mentorshipStatusLabel(_status),
                        actions: _buildMentorshipActions(context, item),
                      ),
                    ),
                  ),
                  _RequestPaginationControls(
                    page: _page,
                    canGoBack: _page > 1,
                    canGoForward: items.length >= _pageSize,
                    onPrevious: () => setState(() => _page -= 1),
                    onNext: () => setState(() => _page += 1),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMentorshipActions(
    BuildContext context,
    NetworkRequestItem item,
  ) {
    if (_status != MentorshipRequestStatus.requested ||
        _direction != NetworkRequestDirection.incoming) {
      return const [];
    }
    return [
      TextButton(
        onPressed: () => _showActionResult(
          context,
          ref.read(networkingRepositoryProvider).declineMentorship(item.id),
          onDone: _invalidateNetworkingRequests,
        ),
        child: const Text('Reddet'),
      ),
      FilledButton(
        onPressed: () => _showActionResult(
          context,
          ref.read(networkingRepositoryProvider).acceptMentorship(item.id),
          onDone: _invalidateNetworkingRequests,
        ),
        child: const Text('Kabul et'),
      ),
    ];
  }

  void _invalidateNetworkingRequests() {
    ref.invalidate(networkInboxProvider);
    ref.invalidate(mentorshipRequestsProvider);
  }
}

class TeacherLinksPage extends ConsumerStatefulWidget {
  const TeacherLinksPage({super.key});

  @override
  ConsumerState<TeacherLinksPage> createState() => _TeacherLinksPageState();
}

class _TeacherLinksPageState extends ConsumerState<TeacherLinksPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(networkingRepositoryProvider)
            .trackTelemetry(
              const NetworkingTelemetryEvent(
                eventName: 'teacher_network_viewed',
                sourceSurface: 'teachers_network_page',
              ),
            ),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linksState = ref.watch(teacherLinksProvider);
    final teacherOptionsState = ref.watch(
      teacherOptionsProvider(_searchController.text.trim()),
    );
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Öğretmen bağlantıları',
      actions: [
        IconButton(
          tooltip: context.l10n.refreshAction,
          onPressed: () => ref.invalidate(teacherLinksProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni öğretmen ekle',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Öğretmen ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                teacherOptionsState.when(
                  loading: () => _searchController.text.trim().isEmpty
                      ? const Text('Kullanıcı adı veya isim ile öğretmen ara.')
                      : const Center(child: CircularProgressIndicator()),
                  error: (error, _) => const ErrorView(compact: true),
                  data: (items) {
                    if (_searchController.text.trim().isEmpty) {
                      return const Text(
                        'Kullanıcı adı veya isim ile öğretmen ara.',
                      );
                    }
                    if (items.isEmpty) {
                      return const Text('Eşleşen öğretmen bulunamadı.');
                    }
                    return Column(
                      children: items
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: RemoteAvatar(
                                label: item.name,
                                imageUrl: config
                                    .resolveUrl(item.photo)
                                    .toString(),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                [
                                  if (item.handle.isNotEmpty) '@${item.handle}',
                                  if (item.studentCount > 0)
                                    '${item.studentCount} öğrenci bağlantısı',
                                ].join(' · '),
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () =>
                                    _openTeacherLinkDialog(context, ref, item),
                                child: const Text('Ekle'),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Kayıtlı öğretmen bağlantıların',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          linksState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => const ErrorView(compact: true),
            data: (items) {
              if (items.isEmpty) {
                return const SurfaceCard(
                  child: Text('Henüz öğretmen bağlantısı eklenmedi.'),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SurfaceCard(
                          child: Row(
                            children: [
                              RemoteAvatar(
                                label: item.member.name,
                                imageUrl: config
                                    .resolveUrl(item.member.photo)
                                    .toString(),
                                radius: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.member.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      item.relationshipType.isEmpty
                                          ? 'Bağlantı kaydı'
                                          : item.relationshipType,
                                    ),
                                    if (item.classYear.isNotEmpty)
                                      Text(
                                        'Sınıf yılı: ${item.classYear}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (item.notes.isNotEmpty)
                                      Text(
                                        item.notes,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
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
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.member,
    required this.subtitle,
    required this.imageUrl,
    required this.actions,
    this.statusLabel = '',
    this.detail = '',
  });

  final NetworkMemberRef member;
  final String subtitle;
  final String imageUrl;
  final List<Widget> actions;
  final String statusLabel;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RemoteAvatar(label: member.name, imageUrl: imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (member.handle.isNotEmpty)
                      Text(
                        '@${member.handle}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (statusLabel.isNotEmpty)
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[const SizedBox(height: 12), Text(detail)],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

class _RequestPaginationControls extends StatelessWidget {
  const _RequestPaginationControls({
    required this.page,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: canGoBack ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Önceki'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sayfa $page',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: canGoForward ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Sonraki'),
          ),
        ],
      ),
    );
  }
}

String _connectionStatusLabel(ConnectionRequestStatus status) {
  switch (status) {
    case ConnectionRequestStatus.pending:
      return 'Bekliyor';
    case ConnectionRequestStatus.accepted:
      return 'Kabul edildi';
    case ConnectionRequestStatus.ignored:
      return 'Yoksayıldı';
  }
}

String _mentorshipStatusLabel(MentorshipRequestStatus status) {
  switch (status) {
    case MentorshipRequestStatus.requested:
      return 'Bekliyor';
    case MentorshipRequestStatus.accepted:
      return 'Kabul edildi';
    case MentorshipRequestStatus.declined:
      return 'Reddedildi';
    case MentorshipRequestStatus.cancelled:
      return 'İptal edildi';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0D2238)),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MiniMetricChip extends StatelessWidget {
  const _MiniMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Future<void> _openMentorshipDialog(
  BuildContext context,
  WidgetRef ref,
  int memberId,
) async {
  final focusController = TextEditingController();
  final messageController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mentorluk iste'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: focusController,
                decoration: const InputDecoration(labelText: 'Odak alanı'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: messageController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Mesaj'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              final result = await ref
                  .read(networkingRepositoryProvider)
                  .requestMentorship(
                    memberId: memberId,
                    focusArea: focusController.text.trim(),
                    message: messageController.text.trim(),
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message.isNotEmpty
                        ? result.message
                        : (result.ok
                              ? 'Mentorluk isteği gönderildi.'
                              : 'İstek gönderilemedi.'),
                  ),
                ),
              );
              if (result.ok) {
                ref.invalidate(networkHubProvider);
                ref.invalidate(networkInboxProvider);
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  } finally {
    focusController.dispose();
    messageController.dispose();
  }
}

Future<void> _openTeacherLinkDialog(
  BuildContext context,
  WidgetRef ref,
  TeacherOption teacher,
) async {
  final classYearController = TextEditingController();
  final notesController = TextEditingController();
  String relationshipType = 'taught_in_class';

  try {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${teacher.name} için bağlantı oluştur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: relationshipType,
                items: const [
                  DropdownMenuItem(
                    value: 'taught_in_class',
                    child: Text('Sınıfta ders verdi'),
                  ),
                  DropdownMenuItem(
                    value: 'advisor',
                    child: Text('Danışman öğretmen'),
                  ),
                  DropdownMenuItem(
                    value: 'club',
                    child: Text('Kulüp / etkinlik'),
                  ),
                ],
                onChanged: (value) => setDialogState(
                  () => relationshipType = value ?? 'taught_in_class',
                ),
                decoration: const InputDecoration(labelText: 'İlişki türü'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: classYearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sınıf yılı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Not'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                final result = await ref
                    .read(networkingRepositoryProvider)
                    .createTeacherLink(
                      teacherId: teacher.id,
                      relationshipType: relationshipType,
                      classYear: classYearController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.message.isNotEmpty
                          ? result.message
                          : (result.ok
                                ? 'Öğretmen bağlantısı eklendi.'
                                : 'Bağlantı eklenemedi.'),
                    ),
                  ),
                );
                if (result.ok) {
                  ref.invalidate(teacherLinksProvider);
                  ref.invalidate(networkInboxProvider);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  } finally {
    classYearController.dispose();
    notesController.dispose();
  }
}

Future<void> _showActionResult(
  BuildContext context,
  Future<ApiResult<dynamic>> future, {
  VoidCallback? onDone,
}) async {
  final result = await future;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.message.isNotEmpty
            ? result.message
            : (result.ok ? 'İşlem tamamlandı.' : 'İşlem başarısız oldu.'),
      ),
    ),
  );
  if (result.ok) onDone?.call();
}
