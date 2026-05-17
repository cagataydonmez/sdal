import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/admin_repository.dart';
import 'widgets/admin_mobile_widgets.dart';

String _rootTimestamp(BuildContext context, String raw) =>
    raw.isEmpty ? '' : formatSdalTimestamp(context, raw);

class RootAdminToolsPage extends ConsumerWidget {
  const RootAdminToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).value?.user;
    if (user?.isRootAdmin != true) return const _RootDeniedPage();

    return FeatureScaffold(
      title: 'Root araçları',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sadece root yetkisi',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu alandaki işlemler sistem geneli veri ve izin yönetimi içindir.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminSectionCard(
            title: 'Üye aktivite izleme',
            subtitle:
                'Kayıtlı bir üyenin post, yorum, like, mesaj, profil ve fotoğraf görüntüleme izlerini incele.',
            icon: Icons.manage_search_outlined,
            tone: AdminTone.accent,
            onTap: () => context.push('/admin/root/member-activity'),
          ),
          const SizedBox(height: 10),
          AdminSectionCard(
            title: 'İzin grupları',
            subtitle: 'Rol ve özel izin setlerini düzenle.',
            icon: Icons.admin_panel_settings_outlined,
            tone: AdminTone.info,
            onTap: () => context.push('/admin/permission-groups'),
          ),
          const SizedBox(height: 10),
          AdminSectionCard(
            title: 'Kullanıcı izinleri',
            subtitle: 'Üyelere root kontrollü izin grupları ata.',
            icon: Icons.verified_user_outlined,
            tone: AdminTone.info,
            onTap: () => context.push('/admin/user-permissions'),
          ),
          const SizedBox(height: 10),
          AdminSectionCard(
            title: 'Factory reset',
            subtitle: 'Yüksek riskli sıfırlama akışı, ayrı doğrulama ister.',
            icon: Icons.delete_forever_outlined,
            tone: AdminTone.danger,
            onTap: () => context.push('/admin/factory-reset'),
          ),
          const SizedBox(height: 10),
          AdminSectionCard(
            title: 'Test verisi',
            subtitle:
                'Geliştirme ve doğrulama için kontrollü test datası üret.',
            icon: Icons.science_outlined,
            tone: AdminTone.warning,
            onTap: () => context.push('/admin/test-data'),
          ),
        ],
      ),
    );
  }
}

class RootMemberActivityPage extends ConsumerStatefulWidget {
  const RootMemberActivityPage({super.key});

  @override
  ConsumerState<RootMemberActivityPage> createState() =>
      _RootMemberActivityPageState();
}

class _RootMemberActivityPageState
    extends ConsumerState<RootMemberActivityPage> {
  final _queryController = TextEditingController();
  String _query = '';
  int _selectedUserId = 0;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).value?.user;
    if (user?.isRootAdmin != true) return const _RootDeniedPage();
    final usersState = ref.watch(adminRootActivityUsersProvider(_query));

    return FeatureScaffold(
      title: 'Üye aktivite izleme',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(adminRootActivityUsersProvider(_query));
            if (_selectedUserId > 0) {
              ref.invalidate(adminRootMemberActivityProvider(_selectedUserId));
            }
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          SurfaceCard(
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Üye ara',
                hintText: 'Ad, kullanıcı adı veya e-posta',
                suffixIcon: _queryController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Temizle',
                        onPressed: () {
                          _queryController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onSubmitted: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          usersState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => AdminEmptyState(
              icon: Icons.error_outline,
              title: 'Üyeler alınamadı',
              message: error.toString(),
            ),
            data: (users) {
              if (users.isEmpty) {
                return const AdminEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Sonuç yok',
                  message: 'Farklı bir arama deneyin.',
                );
              }
              final selectedId = _selectedUserId == 0
                  ? users.first.id
                  : _selectedUserId;
              if (_selectedUserId == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedUserId == 0) {
                    setState(() => _selectedUserId = selectedId);
                  }
                });
              }
              return Column(
                children: [
                  for (final item in users.take(12))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RootUserPickCard(
                        user: item,
                        selected: item.id == selectedId,
                        onTap: () => setState(() => _selectedUserId = item.id),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _RootActivityDetail(userId: selectedId),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RootUserPickCard extends ConsumerWidget {
  const _RootUserPickCard({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AdminRootActivityUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: RemoteAvatar(
          label: user.displayName,
          imageUrl: config.resolveUrl(user.avatar).toString(),
          radius: 24,
        ),
        title: Text(
          user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (user.handle.isNotEmpty) '@${user.handle}',
            if (user.role.isNotEmpty) user.role,
            if (user.lastActivityDate.isNotEmpty) user.lastActivityDate,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: AdminStatusChip(
          label: user.online ? 'Online' : 'Pasif',
          tone: user.online ? AdminTone.success : AdminTone.info,
        ),
      ),
    );
  }
}

class _RootActivityDetail extends ConsumerWidget {
  const _RootActivityDetail({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId <= 0) return const SizedBox.shrink();
    final state = ref.watch(adminRootMemberActivityProvider(userId));
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => AdminEmptyState(
        icon: Icons.lock_clock_outlined,
        title: 'Aktivite alınamadı',
        message: error.toString(),
      ),
      data: (snapshot) => _RootActivityContent(snapshot: snapshot),
    );
  }
}

class _RootActivityContent extends ConsumerWidget {
  const _RootActivityContent({required this.snapshot});

  final AdminRootMemberActivitySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = snapshot.summary;
    final config = ref.watch(appConfigProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RemoteAvatar(
                    label: snapshot.user.displayName,
                    imageUrl: config
                        .resolveUrl(snapshot.user.avatar)
                        .toString(),
                    radius: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.user.displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (snapshot.user.handle.isNotEmpty)
                              '@${snapshot.user.handle}',
                            if (snapshot.user.email.isNotEmpty)
                              snapshot.user.email,
                            if (snapshot.user.lastSeenAt.isNotEmpty)
                              'Son giriş: ${_rootTimestamp(context, snapshot.user.lastSeenAt)}',
                          ].join(' · '),
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
                  _SummaryChip(label: 'Post', value: summary.posts),
                  _SummaryChip(label: 'Yorum', value: summary.comments),
                  _SummaryChip(
                    label: 'Like',
                    value: summary.postLikes + summary.photoLikes,
                  ),
                  _SummaryChip(label: 'Mesaj', value: summary.messages),
                  _SummaryChip(
                    label: 'Profil bakışı',
                    value: summary.profileViews,
                  ),
                  _SummaryChip(label: 'Foto bakışı', value: summary.photoViews),
                  _SummaryChip(label: 'Takip', value: summary.follows),
                  _SummaryChip(label: 'Oturum', value: summary.sessions),
                  _SummaryChip(
                    label: 'Dakika',
                    value: summary.estimatedTimeMinutes,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (snapshot.topInteractions.isNotEmpty)
          _TopInteractionsCard(items: snapshot.topInteractions),
        _ActivitySection(
          title: 'Son olaylar',
          icon: Icons.timeline_outlined,
          entries: snapshot.entries('timeline'),
        ),
        _ActivitySection(
          title: 'Mesajlaşmalar',
          icon: Icons.forum_outlined,
          entries: snapshot.entries('messages'),
        ),
        _ActivitySection(
          title: 'Profil görüntülemeleri',
          icon: Icons.person_search_outlined,
          entries: snapshot.entries('profileViews'),
        ),
        _ActivitySection(
          title: 'Fotoğraf görüntülemeleri',
          icon: Icons.photo_library_outlined,
          entries: snapshot.entries('photoViews'),
        ),
        _ActivitySection(
          title: 'Postlar',
          icon: Icons.article_outlined,
          entries: snapshot.entries('posts'),
        ),
        _ActivitySection(
          title: 'Yorumlar',
          icon: Icons.mode_comment_outlined,
          entries: snapshot.entries('comments'),
        ),
        _ActivitySection(
          title: 'Post beğenileri',
          icon: Icons.favorite_border,
          entries: snapshot.entries('postLikes'),
        ),
        _ActivitySection(
          title: 'Fotoğraflar',
          icon: Icons.image_outlined,
          entries: snapshot.entries('photos'),
        ),
        _ActivitySection(
          title: 'Fotoğraf beğenileri',
          icon: Icons.photo_camera_back_outlined,
          entries: snapshot.entries('photoLikes'),
        ),
        _ActivitySection(
          title: 'Takip ettikleri',
          icon: Icons.group_add_outlined,
          entries: snapshot.entries('follows'),
        ),
        _ActivitySection(
          title: 'Giriş çıkış',
          icon: Icons.login_outlined,
          entries: snapshot.entries('sessions'),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return AdminStatusChip(label: '$label $value', tone: AdminTone.info);
  }
}

class _TopInteractionsCard extends StatelessWidget {
  const _TopInteractionsCard({required this.items});

  final List<AdminRootTopInteraction> items;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En yoğun etkileşim',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final item in items.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hub_outlined),
              title: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: AdminStatusChip(label: item.score.toStringAsFixed(0)),
            ),
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<AdminRootActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SurfaceCard(
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(
            '$title (${entries.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          children: [
            if (entries.any((entry) => entry.imageUrl.trim().isNotEmpty))
              _SectionMediaStrip(entries: entries),
            for (final entry in entries.take(30))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _EntryMedia(entry: entry, fallbackIcon: icon),
                title: Text(
                  entry.title.isEmpty ? '#${entry.id}' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (entry.text.isNotEmpty) entry.text,
                    if (entry.meta.isNotEmpty) entry.meta,
                    if (entry.createdAt.isNotEmpty)
                      _rootTimestamp(context, entry.createdAt),
                  ].join('\n'),
                  maxLines: title == 'Mesajlaşmalar' ? 24 : 7,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionMediaStrip extends StatelessWidget {
  const _SectionMediaStrip({required this.entries});

  final List<AdminRootActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    final mediaEntries = entries
        .where((entry) => entry.imageUrl.trim().isNotEmpty)
        .take(12)
        .toList(growable: false);
    if (mediaEntries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: mediaEntries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final entry = mediaEntries[index];
            return SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SdalNetworkImage(
                      imageUrl: entry.imageUrl,
                      lightboxImageUrl: entry.lightboxUrl,
                      width: 104,
                      height: 84,
                      fit: BoxFit.cover,
                      semanticLabel: entry.title,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.title.isEmpty ? '#${entry.id}' : entry.title,
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
    );
  }
}

class _EntryMedia extends StatelessWidget {
  const _EntryMedia({required this.entry, required this.fallbackIcon});

  final AdminRootActivityEntry entry;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (entry.imageUrl.trim().isEmpty) {
      return SizedBox(
        width: 56,
        height: 56,
        child: Icon(fallbackIcon, color: Theme.of(context).colorScheme.outline),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SdalNetworkImage(
        imageUrl: entry.imageUrl,
        lightboxImageUrl: entry.lightboxUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        semanticLabel: entry.title,
      ),
    );
  }
}

class FactoryResetPage extends ConsumerStatefulWidget {
  const FactoryResetPage({super.key});

  @override
  ConsumerState<FactoryResetPage> createState() => _FactoryResetPageState();
}

class _FactoryResetPageState extends ConsumerState<FactoryResetPage> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _dryRun = true;
  bool _submitting = false;
  String _message = '';

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).value?.user;
    if (user?.isRootAdmin != true) {
      return const _RootDeniedPage();
    }

    return FeatureScaffold(
      title: 'Factory reset',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tüm veritabanı kayıtları ve yüklenen dosyalar silinecek.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Reset sonrası yalnızca @cagatay root admin olarak kalır. Şifre ROOT_BOOTSTRAP_PASSWORD ortam değişkeninden, geliştirme ortamında yoksa geçici 12345 varsayılanından oluşturulur.',
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _dryRun,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _dryRun = value),
                  title: const Text('Dry run'),
                  subtitle: const Text(
                    'Önce silinecek tabloları ve upload klasörünü kontrol et.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmationController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Onay metni',
                    hintText: 'RESET SDAL',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  enabled: !_submitting,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mevcut root admin şifresi',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _dryRun
                              ? Icons.playlist_add_check
                              : Icons.delete_forever,
                        ),
                  label: Text(
                    _dryRun ? 'Dry run çalıştır' : 'Factory reset çalıştır',
                  ),
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_message),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _message = '';
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .factoryReset(
            confirmation: _confirmationController.text,
            password: _passwordController.text,
            dryRun: _dryRun,
          );
      if (_dryRun) {
        setState(
          () =>
              _message = 'Dry run tamamlandı. Sunucu reset planını doğruladı.',
        );
      } else {
        ref.read(sessionControllerProvider.notifier).expire();
        setState(
          () => _message = 'Factory reset tamamlandı. Oturum yenilendi.',
        );
      }
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class TestDataSeedPage extends ConsumerStatefulWidget {
  const TestDataSeedPage({super.key});

  @override
  ConsumerState<TestDataSeedPage> createState() => _TestDataSeedPageState();
}

class _TestDataSeedPageState extends ConsumerState<TestDataSeedPage> {
  late Future<AdminTestDataCatalog> _catalogFuture;
  final Map<String, int> _counts = {};
  bool _dryRun = false;
  bool _submitting = false;
  AdminTestDataRunResult? _result;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  Future<AdminTestDataCatalog> _loadCatalog() async {
    final catalog = await ref
        .read(adminRepositoryProvider)
        .fetchTestDataCatalog();
    if (mounted) {
      setState(() {
        for (final area in catalog.areas) {
          _counts[area.key] = catalog.defaults[area.key] ?? area.defaultCount;
        }
      });
    }
    return catalog;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).value?.user;
    if (user?.isRootAdmin != true) {
      return const _RootDeniedPage();
    }

    return FeatureScaffold(
      title: 'Test verisi',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _submitting
              ? null
              : () => setState(() {
                  _catalogFuture = _loadCatalog();
                  _result = null;
                  _message = '';
                }),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: FutureBuilder<AdminTestDataCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final catalog = snapshot.data!;
          final total = _counts.values.fold<int>(
            0,
            (sum, value) => sum + value,
          );
          final overLimit = total > catalog.maxTotal;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'API test kullanıcıları',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Chip(label: Text('$total/${catalog.maxTotal}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _dryRun,
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _dryRun = value),
                      title: const Text('Dry run'),
                      subtitle: const Text('Kayıt oluşturmadan planı denetle.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    for (final area in catalog.areas)
                      _SeedCountRow(
                        label: area.label,
                        value: _counts[area.key] ?? area.defaultCount,
                        max: catalog.maxPerArea,
                        enabled: !_submitting,
                        onChanged: (value) =>
                            setState(() => _counts[area.key] = value),
                      ),
                    if (overLimit) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Toplam ${catalog.maxTotal} kaydı aşamaz.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _submitting || overLimit ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _dryRun ? 'Planı çalıştır' : 'Test verisi ekle',
                      ),
                    ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_message),
                    ],
                  ],
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result!.dryRun ? 'Dry run sonucu' : 'Seed sonucu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_result!.usersCreated} kullanıcı, ${_result!.totalCreated} API kaydı. Run: ${_result!.runId}',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in _result!.summary.entries)
                            Chip(label: Text('${entry.key}: ${entry.value}')),
                        ],
                      ),
                      if (_result!.errors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final error in _result!.errors)
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _message = '';
      _result = null;
    });
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .runTestDataSeed(
            counts: Map<String, int>.from(_counts),
            dryRun: _dryRun,
          );
      setState(() {
        _result = result;
        _message = result.errors.isEmpty
            ? 'Tamamlandı.'
            : 'Kısmi tamamlandı. Bazı API alanları hata döndürdü.';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SeedCountRow extends StatelessWidget {
  const _SeedCountRow({
    required this.label,
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.outlined(
            tooltip: 'Azalt',
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton.outlined(
            tooltip: 'Artır',
            onPressed: enabled && value < max
                ? () => onChanged(value + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class PermissionGroupsPage extends ConsumerWidget {
  const PermissionGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).value?.user;
    if (user?.isRootAdmin != true) return const _RootDeniedPage();
    final permissionsState = ref.watch(adminPermissionsProvider);
    final groupsState = ref.watch(adminPermissionGroupsProvider);

    return FeatureScaffold(
      title: 'Permission groups',
      actions: [
        IconButton(
          onPressed: () {
            ref.invalidate(adminPermissionsProvider);
            ref.invalidate(adminPermissionGroupsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: permissionsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (permissions) => groupsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (groups) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _showGroupEditor(context, ref, permissions),
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni grup'),
                ),
              ),
              const SizedBox(height: 16),
              for (final group in groups) ...[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Düzenle',
                            onPressed: () => _showGroupEditor(
                              context,
                              ref,
                              permissions,
                              group: group,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Sil',
                            onPressed: group.isDefaultGroup
                                ? null
                                : () => _deleteGroup(context, ref, group),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      if (group.description.isNotEmpty) Text(group.description),
                      const SizedBox(height: 8),
                      Text(
                        '${group.permissions.where((p) => p.canRead).length} read · ${group.permissions.where((p) => p.canWrite).length} write',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class UserPermissionsPage extends ConsumerStatefulWidget {
  const UserPermissionsPage({super.key});

  @override
  ConsumerState<UserPermissionsPage> createState() =>
      _UserPermissionsPageState();
}

class _UserPermissionsPageState extends ConsumerState<UserPermissionsPage> {
  final _searchController = TextEditingController();
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).value?.user;
    if (user?.isRootAdmin != true) return const _RootDeniedPage();
    final groupsState = ref.watch(adminPermissionGroupsProvider);
    final usersState = ref.watch(
      adminPermissionUsersProvider((
        query: _searchController.text,
        page: _page,
      )),
    );

    return FeatureScaffold(
      title: 'User permissions',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setState(() => _page = 1),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: () => setState(() => _page = 1),
                  child: const Text('Ara'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          groupsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (groups) => usersState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
              data: (snapshot) => Column(
                children: [
                  for (final item in snapshot.users) ...[
                    SurfaceCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.handle.isNotEmpty
                                      ? '@${item.handle}'
                                      : item.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text('${item.email} · ${item.role}'),
                              ],
                            ),
                          ),
                          DropdownButton<int>(
                            value: item.groupId > 0 ? item.groupId : null,
                            hint: const Text('Grup'),
                            onChanged: item.isRoot
                                ? null
                                : (value) => _assignGroup(item.id, value),
                            items: [
                              for (final group in groups)
                                DropdownMenuItem(
                                  value: group.id,
                                  child: Text(group.name),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _page > 1
                            ? () => setState(() => _page -= 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Önceki'),
                      ),
                      Expanded(
                        child: Text(
                          'Sayfa $_page · Toplam ${snapshot.total}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: snapshot.users.length >= 30
                            ? () => setState(() => _page += 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Sonraki'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignGroup(int userId, int? groupId) async {
    if (groupId == null) return;
    await ref
        .read(adminRepositoryProvider)
        .assignUserPermissionGroup(userId: userId, groupId: groupId);
    ref.invalidate(adminPermissionUsersProvider);
    ref.invalidate(adminAccessProvider);
  }
}

class _RootDeniedPage extends StatelessWidget {
  const _RootDeniedPage();

  @override
  Widget build(BuildContext context) {
    return const FeatureScaffold(
      title: 'Root admin',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SurfaceCard(
            child: Text(
              'Bu alan yalnızca @cagatay root admin hesabı için açık.',
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _deleteGroup(
  BuildContext context,
  WidgetRef ref,
  AdminPermissionGroup group,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${group.name} silinsin mi?'),
      content: const Text(
        'Bu işlem atanmış kullanıcısı olmayan özel gruplar için geçerlidir.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(adminRepositoryProvider).deletePermissionGroup(group.id);
  ref.invalidate(adminPermissionGroupsProvider);
}

Future<void> _showGroupEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminPermissionDefinition> definitions, {
  AdminPermissionGroup? group,
}) async {
  final nameController = TextEditingController(text: group?.name ?? '');
  final descriptionController = TextEditingController(
    text: group?.description ?? '',
  );
  final existingByKey = <String, AdminGroupPermission>{
    for (final item in group?.permissions ?? const <AdminGroupPermission>[])
      item.key: item,
  };
  final values = <String, AdminGroupPermission>{
    for (final definition in definitions)
      definition.key: AdminGroupPermission(
        key: definition.key,
        canRead: existingByKey[definition.key]?.canRead ?? false,
        canWrite: existingByKey[definition.key]?.canWrite ?? false,
      ),
  };

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          group == null ? 'Yeni izin grubu' : '${group.name} düzenle',
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: group?.isDefaultGroup != true,
                  decoration: const InputDecoration(labelText: 'Grup adı'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                const SizedBox(height: 14),
                for (final definition in definitions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(definition.label),
                    subtitle: Text(definition.key),
                    value: values[definition.key]?.canWrite == true,
                    secondary: Checkbox(
                      value: values[definition.key]?.canRead == true,
                      onChanged: (checked) => setState(() {
                        final current = values[definition.key]!;
                        values[definition.key] = AdminGroupPermission(
                          key: current.key,
                          canRead: checked ?? false,
                          canWrite: (checked ?? false)
                              ? current.canWrite
                              : false,
                        );
                      }),
                    ),
                    onChanged: (checked) => setState(() {
                      final current = values[definition.key]!;
                      values[definition.key] = AdminGroupPermission(
                        key: current.key,
                        canRead: current.canRead || (checked ?? false),
                        canWrite: checked ?? false,
                      );
                    }),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(adminRepositoryProvider)
                  .savePermissionGroup(
                    id: group?.id,
                    name: nameController.text,
                    description: descriptionController.text,
                    permissions: values.values.toList(growable: false),
                  );
              ref.invalidate(adminPermissionGroupsProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  descriptionController.dispose();
}
