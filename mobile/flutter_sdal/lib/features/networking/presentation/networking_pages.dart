import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_result.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/networking_repository.dart';

class NetworkingHubPage extends ConsumerWidget {
  const NetworkingHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubState = ref.watch(networkHubProvider);
    final config = ref.watch(appConfigProvider);

    return FeatureScaffold(
      title: 'Networking',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(networkHubProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: hubState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (hub) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
          onPressed: () => ref.invalidate(networkInboxProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: inboxState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (inbox) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _RequestSection(
              title: 'Gelen bağlantı istekleri',
              items: inbox.incomingConnections,
              emptyMessage: 'Bekleyen bağlantı isteği yok.',
              itemBuilder: (item) => _RequestTile(
                member: item.member,
                subtitle: item.updatedAt,
                imageUrl: config.resolveUrl(item.member.photo).toString(),
                actions: [
                  TextButton(
                    onPressed: () => _showActionResult(
                      context,
                      ref
                          .read(networkingRepositoryProvider)
                          .ignoreConnection(item.id),
                      onDone: () => ref.invalidate(networkInboxProvider),
                    ),
                    child: const Text('Yoksay'),
                  ),
                  FilledButton(
                    onPressed: () => _showActionResult(
                      context,
                      ref
                          .read(networkingRepositoryProvider)
                          .acceptConnection(item.id),
                      onDone: () => ref.invalidate(networkInboxProvider),
                    ),
                    child: const Text('Kabul et'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _RequestSection(
              title: 'Gönderdiğin bağlantı istekleri',
              items: inbox.outgoingConnections,
              emptyMessage: 'Aktif giden bağlantı isteği yok.',
              itemBuilder: (item) => _RequestTile(
                member: item.member,
                subtitle: item.updatedAt,
                imageUrl: config.resolveUrl(item.member.photo).toString(),
                actions: [
                  OutlinedButton(
                    onPressed: () => _showActionResult(
                      context,
                      ref
                          .read(networkingRepositoryProvider)
                          .cancelConnection(item.id),
                      onDone: () => ref.invalidate(networkInboxProvider),
                    ),
                    child: const Text('Geri çek'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _RequestSection(
              title: 'Gelen mentorluk istekleri',
              items: inbox.incomingMentorship,
              emptyMessage: 'Bekleyen mentorluk isteği yok.',
              itemBuilder: (item) => _RequestTile(
                member: item.member,
                subtitle: item.focusArea.isNotEmpty
                    ? item.focusArea
                    : item.updatedAt,
                detail: item.message,
                imageUrl: config.resolveUrl(item.member.photo).toString(),
                actions: [
                  TextButton(
                    onPressed: () => _showActionResult(
                      context,
                      ref
                          .read(networkingRepositoryProvider)
                          .declineMentorship(item.id),
                      onDone: () => ref.invalidate(networkInboxProvider),
                    ),
                    child: const Text('Reddet'),
                  ),
                  FilledButton(
                    onPressed: () => _showActionResult(
                      context,
                      ref
                          .read(networkingRepositoryProvider)
                          .acceptMentorship(item.id),
                      onDone: () => ref.invalidate(networkInboxProvider),
                    ),
                    child: const Text('Kabul et'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _RequestSection(
              title: 'Gönderdiğin mentorluk istekleri',
              items: inbox.outgoingMentorship,
              emptyMessage: 'Aktif giden mentorluk isteği yok.',
              itemBuilder: (item) => _RequestTile(
                member: item.member,
                subtitle: item.focusArea.isNotEmpty
                    ? item.focusArea
                    : item.updatedAt,
                detail: item.message,
                imageUrl: config.resolveUrl(item.member.photo).toString(),
                actions: const [],
              ),
            ),
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

class TeacherLinksPage extends ConsumerStatefulWidget {
  const TeacherLinksPage({super.key});

  @override
  ConsumerState<TeacherLinksPage> createState() => _TeacherLinksPageState();
}

class _TeacherLinksPageState extends ConsumerState<TeacherLinksPage> {
  final _searchController = TextEditingController();

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
                  error: (error, _) => Text(error.toString()),
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
            error: (error, _) => Text(error.toString()),
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

class _RequestSection extends StatelessWidget {
  const _RequestSection({
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final String title;
  final List<NetworkRequestItem> items;
  final String emptyMessage;
  final Widget Function(NetworkRequestItem item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (items.isEmpty)
          SurfaceCard(child: Text(emptyMessage))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: itemBuilder(item),
            ),
          ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.member,
    required this.subtitle,
    required this.imageUrl,
    required this.actions,
    this.detail = '',
  });

  final NetworkMemberRef member;
  final String subtitle;
  final String imageUrl;
  final List<Widget> actions;
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
