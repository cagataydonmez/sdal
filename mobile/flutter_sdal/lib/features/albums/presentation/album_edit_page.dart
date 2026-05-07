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
  const AlbumEditPage({
    super.key,
    this.profileMode = false,
    this.categoryId = 0,
  });

  final bool profileMode;
  final int categoryId;

  @override
  ConsumerState<AlbumEditPage> createState() => _AlbumEditPageState();
}

class _AlbumEditPageState extends ConsumerState<AlbumEditPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _visibilityScope = 'public';
  String _coverMode = 'latest';
  int _coverPhotoId = 0;
  bool _isLoading = false;
  String _error = '';
  AlbumCategoryDetail? _detail;
  final List<MemberSummary> _allowedMembers = <MemberSummary>[];
  final List<GroupListItem> _allowedGroups = <GroupListItem>[];

  bool get _isEditing => widget.categoryId > 0;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(sessionControllerProvider.notifier).refreshSilently(),
      ),
    );
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlbum());
    }
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
        actionState.isLoading &&
        (actionState.scope == 'albums:create' ||
            actionState.scope == 'albums:update:${widget.categoryId}');
    final canUseCohort = (session?.user?.graduationYear ?? '')
        .trim()
        .isNotEmpty;
    final showCohortOption = canUseCohort || _visibilityScope == 'cohort';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Albümü düzenle'
              : widget.profileMode
              ? 'Profil albümü oluştur'
              : 'Albüm oluştur',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            Text(_error)
          else ...[
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
                if (showCohortOption)
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
            if (_visibilityScope == 'cohort' && showCohortOption) ...[
              const SizedBox(height: 12),
              Text(
                'Bu albüm yalnızca ${_cohortYearForSubmit(session?.user?.graduationYear ?? '')} cohortu tarafından görülebilir.',
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
            if (_isEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _coverMode,
                decoration: const InputDecoration(
                  labelText: 'Kapak fotoğrafı',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'latest',
                    child: Text('Son yüklenen fotoğraf'),
                  ),
                  DropdownMenuItem(value: 'shuffle', child: Text('Karıştır')),
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('Sabit fotoğraf seç'),
                  ),
                ],
                onChanged: isSaving
                    ? null
                    : (value) => setState(() {
                        _coverMode = value ?? 'latest';
                        if (_coverMode != 'fixed') _coverPhotoId = 0;
                      }),
              ),
              if (_coverMode == 'fixed') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _coverPhotoId > 0 ? _coverPhotoId : null,
                  decoration: const InputDecoration(
                    labelText: 'Sabit kapak',
                    border: OutlineInputBorder(),
                  ),
                  items: (_detail?.photos ?? const <AlbumPhotoCard>[])
                      .map(
                        (photo) => DropdownMenuItem<int>(
                          value: photo.id,
                          child: Text(photo.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: isSaving
                      ? null
                      : (value) => setState(() => _coverPhotoId = value ?? 0),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Text(
              _isEditing
                  ? 'Albüm adı, kapak davranışı ve erişim ayarları buradan güncellenir.'
                  : widget.profileMode
                  ? 'Profil albümleri profilinde listelenir. İstersen belirli kişilere veya üye olduğun gruplara açabilirsin.'
                  : 'Genel/cohort albümleri için silme-yönetim yetkisi admin ve modlarda kalır.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isSaving ? null : _submit,
                child: Text(
                  isSaving
                      ? 'Kaydediliyor...'
                      : _isEditing
                      ? 'Albümü kaydet'
                      : 'Albümü oluştur',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadAlbum() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final detail = await ref
          .read(albumsRepositoryProvider)
          .fetchCategoryDetail(widget.categoryId, pageSize: 60);
      if (!mounted) return;
      AlbumPhotoCard? coverPhoto;
      for (final photo in detail.photos) {
        if (photo.fileName == detail.coverFileName) {
          coverPhoto = photo;
          break;
        }
      }
      setState(() {
        _detail = detail;
        _titleController.text = detail.title;
        _descriptionController.text = detail.description;
        _visibilityScope = detail.visibilityScope;
        _coverMode = detail.coverMode;
        _coverPhotoId = coverPhoto?.id ?? 0;
        _allowedMembers
          ..clear()
          ..addAll(detail.allowedMembers);
        _allowedGroups
          ..clear()
          ..addAll(detail.allowedGroups);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (_coverMode == 'fixed' && _coverPhotoId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sabit kapak için fotoğraf seçmelisin.')),
      );
      return;
    }

    await ref.read(sessionControllerProvider.notifier).refreshSilently();
    final graduationYear =
        ref.read(sessionControllerProvider).value?.user?.graduationYear ?? '';
    final cohortYear = _cohortYearForSubmit(graduationYear);
    final notifier = ref.read(albumsActionControllerProvider.notifier);
    final ok = _isEditing
        ? await notifier.updateAlbum(
            categoryId: widget.categoryId,
            title: title,
            description: _descriptionController.text.trim(),
            visibilityScope: _visibilityScope,
            cohortYear: _visibilityScope == 'cohort' ? cohortYear : '',
            coverMode: _coverMode,
            coverPhotoId: _coverMode == 'fixed' ? _coverPhotoId : null,
            allowedUserIds: _allowedMembers.map((member) => member.id).toList(),
            allowedGroupIds: _allowedGroups.map((group) => group.id).toList(),
          )
        : await notifier.createAlbum(
            title: title,
            description: _descriptionController.text.trim(),
            visibilityScope: _visibilityScope,
            isProfileAlbum: widget.profileMode,
            cohortYear: _visibilityScope == 'cohort' ? cohortYear : '',
            allowedUserIds: _allowedMembers.map((member) => member.id).toList(),
            allowedGroupIds: _allowedGroups.map((group) => group.id).toList(),
          );
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok
                  ? (_isEditing ? 'Albüm güncellendi.' : 'Albüm oluşturuldu.')
                  : (_isEditing
                        ? 'Albüm güncellenemedi.'
                        : 'Albüm oluşturulamadı.')),
        ),
      ),
    );
    if (ok) {
      ref.invalidate(albumsDashboardProvider);
      ref.invalidate(myAlbumsProvider);
      Navigator.of(context).pop(true);
    }
  }

  String _cohortYearForSubmit(String sessionGraduationYear) {
    final sessionYear = sessionGraduationYear.trim();
    if (sessionYear.isNotEmpty) return sessionYear;
    return (_detail?.cohortYear ?? '').trim();
  }
}
