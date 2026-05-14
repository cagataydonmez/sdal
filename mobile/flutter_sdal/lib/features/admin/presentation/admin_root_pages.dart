import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/admin_repository.dart';

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
