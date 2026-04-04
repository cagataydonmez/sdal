import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';

class AlbumUploadPage extends ConsumerStatefulWidget {
  const AlbumUploadPage({super.key});

  @override
  ConsumerState<AlbumUploadPage> createState() => _AlbumUploadPageState();
}

class _AlbumUploadPageState extends ConsumerState<AlbumUploadPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<AlbumCategoryItem> _categories = const <AlbumCategoryItem>[];
  int _selectedCategoryId = 0;
  File? _file;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
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

    return FeatureScaffold(
      title: 'Albüme yükle',
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
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId == 0
                        ? null
                        : _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
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
                        : (value) =>
                              setState(() => _selectedCategoryId = value ?? 0),
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 94,
      maxWidth: 2600,
    );
    if (picked == null || !mounted) return;
    setState(() => _file = File(picked.path));
  }

  Future<void> _upload() async {
    if (_selectedCategoryId <= 0 || _file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori ve fotoğraf seçmelisin.')),
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
    setState(() => _file = null);
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
        _selectedCategoryId = categories.isNotEmpty ? categories.first.id : 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
