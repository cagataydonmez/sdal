import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../explore/data/explore_repository.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';
import 'album_member_picker_sheet.dart';

class AlbumUploadPage extends ConsumerStatefulWidget {
  const AlbumUploadPage({super.key, this.initialCategoryId = 0});

  final int initialCategoryId;

  @override
  ConsumerState<AlbumUploadPage> createState() => _AlbumUploadPageState();
}

class _AlbumUploadPageState extends ConsumerState<AlbumUploadPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<AlbumCategoryItem> _categories = const <AlbumCategoryItem>[];
  final List<MemberSummary> _taggedMembers = <MemberSummary>[];
  int _selectedCategoryId = 0;
  File? _file;
  bool _allowComments = true;
  bool _isLoading = true;
  String _error = '';

  AlbumCategoryItem? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
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
    final isSaving =
        actionState.isLoading && actionState.scope == 'albums:upload';
    final albumLocked =
        widget.initialCategoryId > 0 &&
        _selectedCategoryId == widget.initialCategoryId;

    return FeatureScaffold(
      title: 'Fotoğraf yükle',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            SurfaceCard(child: Text(_error))
          else
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumLocked ? 'Seçili albüm' : 'Albüm seç',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (albumLocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCategory?.title ?? 'Albüm yükleniyor...',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Buradan yüklenen fotoğraf doğrudan bu albüme eklenecek.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId == 0
                          ? null
                          : _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Albüm',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.title),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: isSaving
                          ? null
                          : (value) => setState(
                              () => _selectedCategoryId = value ?? 0,
                            ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _allowComments,
                    title: const Text('Yorumlara izin ver'),
                    subtitle: const Text(
                      'Sonradan kapatırsan mevcut yorumlar gizlenir, yeniden açınca geri gelir.',
                    ),
                    contentPadding: EdgeInsets.zero,
                    onChanged: isSaving
                        ? null
                        : (value) => setState(() => _allowComments = value),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _pickMembers,
                    icon: const Icon(Icons.alternate_email_rounded),
                    label: Text(
                      _taggedMembers.isEmpty
                          ? 'Fotoğrafta kişi etiketle'
                          : '${_taggedMembers.length} kişi etiketli',
                    ),
                  ),
                  if (_taggedMembers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _taggedMembers
                          .map(
                            (member) => InputChip(
                              label: Text(member.name),
                              onDeleted: () => setState(() {
                                _taggedMembers.removeWhere(
                                  (item) => item.id == member.id,
                                );
                              }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Fotoğraf',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _pickFile,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _file == null
                          ? 'Fotoğraf seç'
                          : _file!.path.split('/').last,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving ? null : _upload,
                      child: Text(
                        isSaving ? 'Yükleniyor...' : 'Fotoğrafı yükle',
                      ),
                    ),
                  ),
                  if (_file != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.file(_file!, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final picked = await pickAndCropImage(
      context,
      source: ImageSource.gallery,
      imageQuality: 94,
      maxWidth: 2600,
      title: 'Fotoğrafı kırp',
    );
    if (picked == null || !mounted) return;
    setState(() => _file = picked);
  }

  Future<void> _pickMembers() async {
    final result = await showModalBottomSheet<List<MemberSummary>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AlbumMemberPickerSheet(initial: _taggedMembers),
    );
    if (result == null || !mounted) return;
    setState(() {
      _taggedMembers
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _upload() async {
    if (_selectedCategoryId <= 0 || _file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Albüm ve fotoğraf seçmelisin.')),
      );
      return;
    }
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .uploadPhoto(
          categoryId: _selectedCategoryId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          file: _file!,
          allowComments: _allowComments,
          taggedUserIds: _taggedMembers.map((member) => member.id).toList(),
        );
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Fotoğraf yüklendi.' : 'Fotoğraf yüklenemedi.'),
        ),
      ),
    );
    if (!ok) return;
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _file = null;
      _allowComments = true;
      _taggedMembers.clear();
    });
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final categories = await ref
          .read(albumsRepositoryProvider)
          .fetchUploadCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        final initialExists = categories.any(
          (category) => category.id == _selectedCategoryId,
        );
        if (_selectedCategoryId == 0) {
          _selectedCategoryId = categories.isNotEmpty ? categories.first.id : 0;
        } else if (!initialExists) {
          _selectedCategoryId = categories.isNotEmpty ? categories.first.id : 0;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
