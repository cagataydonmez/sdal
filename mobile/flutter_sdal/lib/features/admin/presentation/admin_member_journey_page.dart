import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/admin_repository.dart';
import 'widgets/admin_mobile_widgets.dart';

String _journeyTimestamp(BuildContext context, String raw) =>
    raw.trim().isEmpty ? 'Tarih yok' : formatSdalTimestamp(context, raw);

class AdminMemberJourneyPage extends ConsumerStatefulWidget {
  const AdminMemberJourneyPage({super.key});

  @override
  ConsumerState<AdminMemberJourneyPage> createState() =>
      _AdminMemberJourneyPageState();
}

class _AdminMemberJourneyPageState
    extends ConsumerState<AdminMemberJourneyPage> {
  final _queryController = TextEditingController();
  String _query = '';
  int _selectedUserId = 0;
  AdminUserPreviewItem? _selectedUser;
  String _selectedSection = 'timeline';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(sessionControllerProvider).value?.user;
    if (sessionUser == null || !sessionUser.hasAdminAccess) {
      return const FeatureScaffold(
        title: 'Üye yolculuğu',
        background: FeatureScaffoldBackground.utility,
        child: Center(
          child: AdminEmptyState(
            icon: Icons.lock_outline,
            title: 'Yetki gerekli',
            message: 'Bu alan yalnızca yönetim yetkisi olan hesaplara açık.',
          ),
        ),
      );
    }

    final previewQuery = AdminUserListQuery(query: _query, limit: 14);
    final usersState = ref.watch(adminUserPreviewProvider(previewQuery));

    return FeatureScaffold(
      title: 'Üye yolculuğu',
      background: FeatureScaffoldBackground.utility,
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(adminUserPreviewProvider(previewQuery));
            if (_selectedUserId > 0) {
              ref.invalidate(adminMemberJourneyProvider(_selectedUserId));
            }
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _MemberSearchPanel(
            controller: _queryController,
            usersState: usersState,
            selectedUserId: _selectedUserId,
            onQueryChanged: (value) => setState(() {
              _query = value.trim();
              _selectedUserId = 0;
              _selectedUser = null;
            }),
            onSelected: (item) => setState(() {
              _selectedUserId = item.id;
              _selectedUser = item;
            }),
          ),
          const SizedBox(height: 14),
          usersState.when(
            loading: () => const _PanelLoader(),
            error: (error, _) => AdminEmptyState(
              icon: Icons.person_search_outlined,
              title: 'Üye listesi alınamadı',
              message: error.toString(),
            ),
            data: (users) {
              final validUsers = users.items
                  .where((item) => item.id > 0)
                  .toList(growable: false);
              final nextSelected = _selectedUserId == 0 && validUsers.isNotEmpty
                  ? validUsers.first.id
                  : _selectedUserId;
              if (_selectedUserId == 0 && nextSelected > 0) {
                final autoSelected = validUsers.firstWhere(
                  (item) => item.id == nextSelected,
                  orElse: () => validUsers.first,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedUserId == 0) {
                    setState(() {
                      _selectedUserId = nextSelected;
                      _selectedUser = autoSelected;
                    });
                  }
                });
              }
              if (nextSelected <= 0) {
                return const AdminEmptyState(
                  icon: Icons.manage_search_outlined,
                  title: 'Üye seç',
                  message:
                      'Kayıttan bugüne bütün yolculuğu görmek için bir üye ara.',
                );
              }
              return _JourneyDetail(
                userId: nextSelected,
                previewUser: _selectedUser,
                selectedSection: _selectedSection,
                onSectionChanged: (key) =>
                    setState(() => _selectedSection = key),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemberSearchPanel extends ConsumerWidget {
  const _MemberSearchPanel({
    required this.controller,
    required this.usersState,
    required this.selectedUserId,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final TextEditingController controller;
  final AsyncValue<AdminPreviewList<AdminUserPreviewItem>> usersState;
  final int selectedUserId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AdminUserPreviewItem> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).sdal;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, color: tokens.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kayıttan bugüne üye dosyası',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: 'Üye ara',
              hintText: 'Ad, kullanıcı adı, e-posta veya ID',
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 14),
          usersState.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (error, _) => Text(
              error.toString(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.danger),
            ),
            data: (users) {
              final validItems = users.items
                  .where((item) => item.id > 0)
                  .toList(growable: false);
              if (validItems.isEmpty) {
                return Text(
                  'Sonuç bulunamadı.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                );
              }
              return SizedBox(
                height: 106,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: validItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = validItems[index];
                    return _MemberPickChip(
                      item: item,
                      selected: item.id == selectedUserId,
                      onTap: () => onSelected(item),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemberPickChip extends ConsumerWidget {
  const _MemberPickChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminUserPreviewItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final tokens = Theme.of(context).sdal;
    final name = _previewDisplayName(item);
    return SizedBox(
      width: 230,
      child: Material(
        color: selected ? tokens.accentMuted : tokens.panel,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RemoteAvatar(
                  label: name,
                  imageUrl: config.resolveUrl(item.avatar).toString(),
                  radius: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.handle.isNotEmpty) '@${item.handle}',
                          item.role,
                          if (item.graduationYear.isNotEmpty)
                            item.graduationYear,
                        ].where((part) => part.trim().isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyDetail extends ConsumerWidget {
  const _JourneyDetail({
    required this.userId,
    required this.previewUser,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final int userId;
  final AdminUserPreviewItem? previewUser;
  final String selectedSection;
  final ValueChanged<String> onSectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminMemberJourneyProvider(userId));
    return state.when(
      loading: () => const _PanelLoader(),
      error: (error, _) => AdminEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Üye yolculuğu alınamadı',
        message: error.toString(),
      ),
      data: (snapshot) => _JourneyContent(
        snapshot: snapshot,
        previewUser: previewUser,
        selectedSection: selectedSection,
        onSectionChanged: onSectionChanged,
      ),
    );
  }
}

class _JourneyContent extends ConsumerWidget {
  const _JourneyContent({
    required this.snapshot,
    required this.previewUser,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final AdminMemberJourneySnapshot snapshot;
  final AdminUserPreviewItem? previewUser;
  final String selectedSection;
  final ValueChanged<String> onSectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = _journeySections.firstWhere(
      (item) => item.key == selectedSection,
      orElse: () => _journeySections.first,
    );
    final entries = section.key == 'timeline'
        ? snapshot.timeline
        : snapshot.entries(section.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MemberHeader(snapshot: snapshot, previewUser: previewUser),
        const SizedBox(height: 12),
        _JourneyMetricGrid(snapshot: snapshot),
        if (snapshot.media.isNotEmpty) ...[
          const SizedBox(height: 12),
          _JourneyMediaStrip(entries: snapshot.media),
        ],
        const SizedBox(height: 12),
        _SectionSwitcher(
          selectedKey: section.key,
          snapshot: snapshot,
          onSelected: onSectionChanged,
        ),
        const SizedBox(height: 12),
        _JourneySectionCard(section: section, entries: entries),
      ],
    );
  }
}

class _MemberHeader extends ConsumerWidget {
  const _MemberHeader({required this.snapshot, required this.previewUser});

  final AdminMemberJourneySnapshot snapshot;
  final AdminUserPreviewItem? previewUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final user = snapshot.user;
    final displayName = user.displayName == 'Üye #0' && previewUser != null
        ? _previewDisplayName(previewUser!)
        : user.displayName;
    final avatar = user.avatar.isNotEmpty
        ? user.avatar
        : previewUser?.avatar ?? '';
    final handle = user.handle.isNotEmpty
        ? user.handle
        : previewUser?.handle ?? '';
    final email = user.email.isNotEmpty ? user.email : previewUser?.email ?? '';
    final graduationYear = user.graduationYear.isNotEmpty
        ? user.graduationYear
        : previewUser?.graduationYear ?? '';
    final role = user.role.isNotEmpty ? user.role : previewUser?.role ?? '';
    final tokens = Theme.of(context).sdal;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteAvatar(
                label: displayName,
                imageUrl: config.resolveUrl(avatar).toString(),
                radius: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (handle.isNotEmpty) '@$handle',
                        if (email.isNotEmpty) email,
                        if (graduationYear.isNotEmpty) graduationYear,
                      ].where((part) => part.trim().isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminStatusChip(
                label: user.active ? 'Aktif' : 'Aktif değil',
                tone: user.active ? AdminTone.success : AdminTone.warning,
              ),
              AdminStatusChip(
                label: user.banned ? 'Yasaklı' : 'Yasak yok',
                tone: user.banned ? AdminTone.danger : AdminTone.info,
              ),
              AdminStatusChip(
                label: user.verified ? 'Doğrulanmış' : 'Doğrulanmamış',
                tone: user.verified ? AdminTone.success : AdminTone.warning,
              ),
              AdminStatusChip(
                label: user.profileInitialized
                    ? 'Profil tamam'
                    : 'Profil eksik',
                tone: user.profileInitialized
                    ? AdminTone.success
                    : AdminTone.warning,
              ),
              AdminStatusChip(
                label: user.online ? 'Online' : 'Offline',
                tone: user.online ? AdminTone.success : AdminTone.info,
              ),
              if (role.isNotEmpty)
                AdminStatusChip(label: role, tone: AdminTone.accent),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileFacts(user: user),
        ],
      ),
    );
  }
}

class _ProfileFacts extends StatelessWidget {
  const _ProfileFacts({required this.user});

  final AdminMemberJourneyUser user;

  @override
  Widget build(BuildContext context) {
    final facts = <_Fact>[
      _Fact('Kayıt', _journeyTimestamp(context, user.createdAt)),
      _Fact('Son giriş', _journeyTimestamp(context, user.lastSeenAt)),
      _Fact(
        'Son işlem',
        [user.lastActivityDate, user.lastActivityTime].join(' '),
      ),
      _Fact('Profil bakışı', '${user.profileViewCount}'),
      _Fact('Şehir', user.city),
      _Fact('Meslek', user.profession),
      _Fact('Üniversite', user.university),
      _Fact('Doğrulama', user.verificationStatus),
    ].where((fact) => fact.value.trim().isNotEmpty).toList(growable: false);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final fact in facts)
          _FactPill(label: fact.label, value: fact.value),
      ],
    );
  }
}

class _JourneyMetricGrid extends StatelessWidget {
  const _JourneyMetricGrid({required this.snapshot});

  final AdminMemberJourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final metrics = [
      _Metric('İçerik', summary.content, Icons.article_outlined),
      _Metric('Medya', summary.media, Icons.photo_library_outlined),
      _Metric('Mesaj', summary.messages, Icons.forum_outlined),
      _Metric('Ağ', summary.network, Icons.hub_outlined),
      _Metric('Talep', summary.count('requests'), Icons.assignment_outlined),
      _Metric('Bildirim', summary.notifications, Icons.notifications_outlined),
      _Metric('Audit', summary.count('audit'), Icons.receipt_long_outlined),
      _Metric('Aktivite', summary.count('activity'), Icons.timeline_outlined),
    ];
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760
              ? 4
              : constraints.maxWidth >= 420
              ? 2
              : 1;
          final gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final metric in metrics)
                SizedBox(
                  width: width,
                  child: _MetricTile(metric: metric),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Row(
        children: [
          Icon(metric.icon, color: tokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${metric.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyMediaStrip extends StatelessWidget {
  const _JourneyMediaStrip({required this.entries});

  final List<AdminMemberJourneyEntry> entries;

  @override
  Widget build(BuildContext context) {
    final media = entries.take(18).toList(growable: false);
    if (media.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medya önizlemeleri',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = media[index];
                return SizedBox(
                  width: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SdalNetworkImage(
                          imageUrl: item.imageUrl,
                          lightboxImageUrl: item.lightboxUrl,
                          width: 112,
                          height: 88,
                          fit: BoxFit.cover,
                          semanticLabel: item.title,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.title.isEmpty ? '#${item.id}' : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSwitcher extends StatelessWidget {
  const _SectionSwitcher({
    required this.selectedKey,
    required this.snapshot,
    required this.onSelected,
  });

  final String selectedKey;
  final AdminMemberJourneySnapshot snapshot;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final section in _journeySections)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: section.key == selectedKey,
                  avatar: Icon(section.icon, size: 18),
                  label: Text(
                    '${section.label} ${_sectionCount(section, snapshot)}',
                  ),
                  onSelected: (_) => onSelected(section.key),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _sectionCount(
    _JourneySectionSpec section,
    AdminMemberJourneySnapshot snapshot,
  ) {
    final count = section.key == 'timeline'
        ? snapshot.timeline.length
        : snapshot.entries(section.key).length;
    return count > 0 ? '($count)' : '';
  }
}

class _JourneySectionCard extends StatelessWidget {
  const _JourneySectionCard({required this.section, required this.entries});

  final _JourneySectionSpec section;
  final List<AdminMemberJourneyEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AdminStatusChip(label: '${entries.length}', tone: AdminTone.info),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const AdminEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Kayıt yok',
              message: 'Bu bölüm için gösterilecek hareket bulunamadı.',
            )
          else
            Column(
              children: [
                for (final entry in entries.take(80))
                  _JourneyEntryTile(entry: entry, fallbackIcon: section.icon),
              ],
            ),
        ],
      ),
    );
  }
}

class _JourneyEntryTile extends StatelessWidget {
  const _JourneyEntryTile({required this.entry, required this.fallbackIcon});

  final AdminMemberJourneyEntry entry;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.panelMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.panelBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EntryVisual(entry: entry, fallbackIcon: fallbackIcon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title.isEmpty ? '#${entry.id}' : entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _journeyTimestamp(context, entry.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (entry.text.isNotEmpty)
                    Text(
                      entry.text,
                      maxLines: entry.type == 'message' ? 10 : 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (entry.meta.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      entry.meta,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (entry.type.isNotEmpty)
                        AdminStatusChip(
                          label: _entryTypeLabel(entry.type),
                          tone: AdminTone.accent,
                        ),
                      if (entry.direction.isNotEmpty)
                        AdminStatusChip(
                          label: _directionLabel(entry.direction),
                          tone: AdminTone.info,
                        ),
                      if (entry.route.isNotEmpty)
                        const AdminStatusChip(
                          label: 'İlişkili kayıt',
                          tone: AdminTone.info,
                        ),
                    ],
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

class _EntryVisual extends ConsumerWidget {
  const _EntryVisual({required this.entry, required this.fallbackIcon});

  final AdminMemberJourneyEntry entry;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPerson = _personEntryTypes.contains(entry.type);
    if (isPerson && entry.imageUrl.trim().isNotEmpty) {
      final config = ref.watch(appConfigProvider);
      return RemoteAvatar(
        label: entry.title,
        imageUrl: config.resolveUrl(entry.imageUrl).toString(),
        radius: 27,
      );
    }
    if (entry.imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SdalNetworkImage(
          imageUrl: entry.imageUrl,
          lightboxImageUrl: entry.lightboxUrl,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          semanticLabel: entry.title,
        ),
      );
    }
    return SizedBox(
      width: 54,
      height: 54,
      child: Icon(fallbackIcon, color: Theme.of(context).colorScheme.outline),
    );
  }
}

class _PanelLoader extends StatelessWidget {
  const _PanelLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      constraints: const BoxConstraints(minHeight: 46, maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tokens.foregroundMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _previewDisplayName(AdminUserPreviewItem item) {
  if (item.name.trim().isNotEmpty) return item.name.trim();
  if (item.handle.trim().isNotEmpty) return '@${item.handle}';
  return 'Üye #${item.id}';
}

String _entryTypeLabel(String type) {
  return switch (type) {
    'registration' => 'Kayıt',
    'profile' => 'Profil',
    'member_request' => 'Talep',
    'verification' => 'Doğrulama',
    'post' => 'Post',
    'comment' => 'Yorum',
    'post_like' => 'Post like',
    'album_photo' => 'Albüm',
    'album_comment' => 'Foto yorum',
    'album_like' => 'Foto like',
    'message' => 'Mesaj',
    'follow' => 'Takip',
    'follower' => 'Takipçi',
    'connection_request' => 'Bağlantı',
    'mentorship_request' => 'Mentorluk',
    'teacher_link' => 'Öğretmen ağı',
    'networking_telemetry' => 'Networking',
    'notification' => 'Bildirim',
    'notification_telemetry' => 'Bildirim olayı',
    'push_device' => 'Cihaz',
    'push_delivery' => 'Push',
    'audit' => 'Audit',
    'activity' => 'Aktivite',
    'session' => 'Oturum',
    _ => type,
  };
}

String _directionLabel(String value) {
  return switch (value) {
    'sent' || 'out' => 'Giden',
    'received' || 'in' => 'Gelen',
    'teacher' => 'Öğretmen',
    'alumni' => 'Mezun',
    _ => value,
  };
}

const _personEntryTypes = <String>{
  'message',
  'follow',
  'follower',
  'connection_request',
  'mentorship_request',
  'teacher_link',
};

const _journeySections = <_JourneySectionSpec>[
  _JourneySectionSpec('timeline', 'Zaman çizelgesi', Icons.timeline_outlined),
  _JourneySectionSpec('registration', 'Kayıt ve profil', Icons.badge_outlined),
  _JourneySectionSpec('requests', 'Talepler', Icons.assignment_outlined),
  _JourneySectionSpec('content', 'İçerik', Icons.article_outlined),
  _JourneySectionSpec('media', 'Medya', Icons.photo_library_outlined),
  _JourneySectionSpec('messaging', 'Mesaj', Icons.forum_outlined),
  _JourneySectionSpec('network', 'Ağ', Icons.hub_outlined),
  _JourneySectionSpec(
    'notifications',
    'Bildirim',
    Icons.notifications_outlined,
  ),
  _JourneySectionSpec('audit', 'Audit', Icons.receipt_long_outlined),
  _JourneySectionSpec('activity', 'Aktivite', Icons.manage_search_outlined),
];

class _JourneySectionSpec {
  const _JourneySectionSpec(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;
}

class _Fact {
  const _Fact(this.label, this.value);
  final String label;
  final String value;
}
