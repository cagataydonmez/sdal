import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/session_controller.dart';
import '../../explore/data/explore_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';
import 'album_group_picker_sheet.dart';
import 'album_member_picker_sheet.dart';

class AlbumEditPage extends ConsumerStatefulWidget {
  const AlbumEditPage({super.key, this.profileMode = false});

  final bool profileMode;

  @override
  ConsumerState<AlbumEditPage> createState() => _AlbumEditPageState();
}

class _AlbumEditPageState extends ConsumerState<AlbumEditPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _visibilityScope = 'public';
  final List<MemberSummary> _allowedMembers = <MemberSummary>[];
  final List<GroupListItem> _allowedGroups = <GroupListItem>[];

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(sessionControllerProvider.notifier).refreshSilently(),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(albumsActionControllerProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final isSaving =
        actionState.isLoading && actionState.scope == 'albums:create';
    final canUseCohort = (session?.user?.graduationYear ?? '')
        .trim()
        .isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.profileMode ? 'Profil albümü oluştur' : 'Albüm oluştur',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Albüm adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _visibilityScope,
            decoration: const InputDecoration(
              labelText: 'Görünürlük',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 'public',
                child: Text('Herkese açık'),
              ),
              if (canUseCohort)
                const DropdownMenuItem(
                  value: 'cohort',
                  child: Text('Sadece cohort'),
                ),
              const DropdownMenuItem(
                value: 'custom',
                child: Text('Belirli kişiler'),
              ),
              const DropdownMenuItem(
                value: 'private',
                child: Text('Yalnızca seçtiklerim'),
              ),
            ],
            onChanged: isSaving
                ? null
                : (value) =>
                      setState(() => _visibilityScope = value ?? 'public'),
          ),
          if (_visibilityScope == 'cohort' && canUseCohort) ...[
            const SizedBox(height: 12),
            Text(
              'Bu albüm yalnızca ${session?.user?.graduationYear} cohortu tarafından görülebilir.',
            ),
          ],
          if (_visibilityScope == 'custom' ||
              _visibilityScope == 'private') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isSaving ? null : _pickMembers,
              icon: const Icon(Icons.alternate_email_rounded),
              label: Text(
                _allowedMembers.isEmpty
                    ? 'Kişi seç'
                    : '${_allowedMembers.length} kişi seçildi',
              ),
            ),
            if (_allowedMembers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allowedMembers
                    .map(
                      (member) => InputChip(
                        label: Text(member.name),
                        onDeleted: () => setState(() {
                          _allowedMembers.removeWhere(
                            (item) => item.id == member.id,
                          );
                        }),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isSaving ? null : _pickGroups,
              icon: const Icon(Icons.groups_2_outlined),
              label: Text(
                _allowedGroups.isEmpty
                    ? 'Grup seç'
                    : '${_allowedGroups.length} grup seçildi',
              ),
            ),
            if (_allowedGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allowedGroups
                    .map(
                      (group) => InputChip(
                        label: Text(group.name),
                        onDeleted: () => setState(() {
                          _allowedGroups.removeWhere(
                            (item) => item.id == group.id,
                          );
                        }),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            widget.profileMode
                ? 'Profil albümleri profilinde listelenir. İstersen belirli kişilere veya üye olduğun gruplara açabilirsin.'
                : 'Genel/cohort albümleri için silme-yönetim yetkisi admin ve modlarda kalır.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : _submit,
              child: Text(isSaving ? 'Kaydediliyor...' : 'Albümü oluştur'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMembers() async {
    final result = await showModalBottomSheet<List<MemberSummary>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AlbumMemberPickerSheet(initial: _allowedMembers),
    );
    if (result == null || !mounted) return;
    setState(() {
      _allowedMembers
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _pickGroups() async {
    final result = await showModalBottomSheet<List<GroupListItem>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AlbumGroupPickerSheet(initial: _allowedGroups),
    );
    if (result == null || !mounted) return;
    setState(() {
      _allowedGroups
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Albüm adı zorunlu.')));
      return;
    }
    if ((_visibilityScope == 'custom' || _visibilityScope == 'private') &&
        _allowedMembers.isEmpty &&
        _allowedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir kişi veya grup seçmelisin.')),
      );
      return;
    }

    await ref.read(sessionControllerProvider.notifier).refreshSilently();
    final graduationYear =
        ref.read(sessionControllerProvider).value?.user?.graduationYear ?? '';
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .createAlbum(
          title: title,
          description: _descriptionController.text.trim(),
          visibilityScope: _visibilityScope,
          isProfileAlbum: widget.profileMode,
          cohortYear: _visibilityScope == 'cohort' ? graduationYear : '',
          allowedUserIds: _allowedMembers.map((member) => member.id).toList(),
          allowedGroupIds: _allowedGroups.map((group) => group.id).toList(),
        );
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Albüm oluşturuldu.' : 'Albüm oluşturulamadı.'),
        ),
      ),
    );
    if (ok) {
      ref.invalidate(albumsDashboardProvider);
      ref.invalidate(myAlbumsProvider);
      Navigator.of(context).pop(true);
    }
  }
}
