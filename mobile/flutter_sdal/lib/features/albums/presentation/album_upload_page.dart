import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../explore/data/explore_repository.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/image_lightbox.dart';
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

class _UploadProgressPanel extends StatelessWidget {
  const _UploadProgressPanel({
    required this.current,
    required this.total,
    required this.progress,
  });

  final int current;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeTotal = total <= 0 ? 1 : total;
    final safeCurrent = current.clamp(1, safeTotal);
    final safeProgress = progress.clamp(0.0, 1.0);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  safeTotal > 1
                      ? '$safeCurrent/$safeTotal fotoğraf yükleniyor'
                      : 'Fotoğraf yükleniyor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (safeTotal > 1)
            Row(
              children: [
                for (var i = 0; i < safeTotal; i += 1)
                  Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(
                        right: i == safeTotal - 1 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            end: ((safeProgress * safeTotal) - i).clamp(
                              0.0,
                              1.0,
                            ),
                          ),
                          builder: (context, value, child) {
                            return FractionallySizedBox(
                              widthFactor: value,
                              child: child,
                            );
                          },
                          child: SizedBox.expand(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: safeProgress),
            ),
        ],
      ),
    );
  }
}

class _AlbumUploadPageState extends ConsumerState<AlbumUploadPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<AlbumCategoryItem> _categories = const <AlbumCategoryItem>[];
  final List<MemberSummary> _taggedMembers = <MemberSummary>[];
  int _selectedCategoryId = 0;
  List<EditedMediaResult> _mediaItems = const <EditedMediaResult>[];
  bool _allowComments = true;
  bool _isLoading = true;
  bool _isUploading = false;
  int _uploadIndex = 0;
  int _uploadTotal = 0;
  double _uploadProgress = 0;
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
        _isUploading ||
        (actionState.isLoading && actionState.scope == 'albums:upload');
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
          else if (_categories.isEmpty)
            const SurfaceCard(
              child: Text('Fotoğraf yükleyebileceğin bir albüm bulunamadı.'),
            )
          else ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumLocked ? 'Seçili albüm' : 'Albüm seç',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    albumLocked
                        ? 'Yükleme doğrudan bu albüme gidecek.'
                        : 'Fotoğrafı eklemek istediğin albümü seç.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fotoğraf ayrıntıları',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık öneki',
                      helperText:
                          'Boş bırakırsan dosya adı kullanılır. Çoklu seçimde otomatik numaralanır.',
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Görsel seç ve hazırla',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tek fotoğraf ya da bir seri seçebilirsin. Seçimden sonra kırpma ekranı açılır.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSaving ? null : _pickSingleFile,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Tek fotoğraf'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSaving ? null : _pickMultipleFiles,
                          icon: const Icon(Icons.collections_outlined),
                          label: const Text('Çoklu seç'),
                        ),
                      ),
                    ],
                  ),
                  if (_mediaItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_mediaItems.length} fotoğraf hazır',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mediaItems.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _mediaItems[index];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () => _editSelectedMedia(index),
                                  child: SizedBox(
                                    width: 144,
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: SdalLightboxImage(
                                        imageProvider: FileImage(item.file),
                                        semanticLabel: 'Yüklenecek fotoğraf',
                                        child: Image.file(
                                          item.file,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () => setState(() {
                                          _mediaItems = [
                                            ..._mediaItems.take(index),
                                            ..._mediaItems.skip(index + 1),
                                          ];
                                        }),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isSaving) ...[
              _UploadProgressPanel(
                current: _uploadIndex,
                total: _uploadTotal <= 0 ? _mediaItems.length : _uploadTotal,
                progress: _uploadProgress,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: isSaving ? null : _upload,
              child: Text(isSaving ? 'Yükleniyor...' : 'Fotoğrafı yükle'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickSingleFile() async {
    final picked = await pickAndEditImage(context, title: 'Fotoğrafı hazırla');
    if (picked == null || !mounted) return;
    setState(() => _mediaItems = [picked]);
  }

  Future<void> _pickMultipleFiles() async {
    final picked = await pickAndEditImages(context, title: 'Fotoğrafı hazırla');
    if (!mounted || picked.isEmpty) return;
    setState(() => _mediaItems = picked);
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

  Future<void> _editSelectedMedia(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    final item = _mediaItems[index];
    final edited = await editImageFile(
      context,
      sourceFile: item.sourceFile,
      title: 'Fotoğrafı hazırla ${index + 1}/${_mediaItems.length}',
      initialMetadata: item.metadata,
    );
    if (!mounted || edited == null) return;
    setState(() {
      _mediaItems = [
        ..._mediaItems.take(index),
        edited,
        ..._mediaItems.skip(index + 1),
      ];
    });
  }

  Future<void> _upload() async {
    if (_selectedCategoryId <= 0 || _mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Albüm ve fotoğraf seçmelisin.')),
      );
      return;
    }
    final titlePrefix = _titleController.text.trim();
    final sharedBatchTitle = titlePrefix.isNotEmpty
        ? titlePrefix
        : _buildTitleForUpload(
            '',
            _mediaItems.first.file,
            0,
            _mediaItems.length,
          );
    final titles = <String>[
      for (var index = 0; index < _mediaItems.length; index += 1)
        _mediaItems.length > 1
            ? sharedBatchTitle
            : _buildTitleForUpload(
                titlePrefix,
                _mediaItems[index].file,
                index,
                _mediaItems.length,
              ),
    ];
    final notifier = ref.read(albumsActionControllerProvider.notifier);
    setState(() {
      _isUploading = true;
      _uploadTotal = _mediaItems.length;
      _uploadIndex = 1;
      _uploadProgress = 0;
    });
    final AlbumUploadResult uploadResult;
    try {
      uploadResult = _mediaItems.length == 1
          ? await _uploadSingleMedia(notifier, titles.first, _mediaItems.first)
          : await _uploadMediaSequentially(notifier, titles);
      if (mounted) {
        setState(() {
          _uploadProgress = uploadResult.ok ? 1 : _uploadProgress;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (uploadResult.ok
                  ? 'Fotoğraf yüklendi.'
                  : 'Fotoğraf yüklenemedi.'),
        ),
      ),
    );
    if (!uploadResult.ok) return;
    ref.invalidate(albumsDashboardProvider);
    ref.invalidate(myAlbumsProvider);
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _mediaItems = const <EditedMediaResult>[];
      _allowComments = true;
      _taggedMembers.clear();
      _uploadIndex = 0;
      _uploadTotal = 0;
      _uploadProgress = 0;
    });
    if (uploadResult.photoId > 0) {
      context.replace('/albums/photo/${uploadResult.photoId}');
    }
  }

  Future<AlbumUploadResult> _uploadSingleMedia(
    AlbumsActionController notifier,
    String title,
    EditedMediaResult item, {
    String albumGroupKey = '',
    int albumGroupIndex = 0,
  }) {
    if (mounted) {
      setState(() {
        _uploadProgress = _mediaItems.length <= 1 ? 0.18 : _uploadProgress;
      });
    }
    return notifier.uploadPhoto(
      categoryId: _selectedCategoryId,
      title: title,
      description: _descriptionController.text.trim(),
      file: item.file,
      sourceFile: item.sourceFile,
      allowComments: _allowComments,
      taggedUserIds: _taggedMembers.map((member) => member.id).toList(),
      editMetadata: item.metadata,
      albumGroupKey: albumGroupKey,
      albumGroupIndex: albumGroupIndex,
    );
  }

  Future<AlbumUploadResult> _uploadMediaSequentially(
    AlbumsActionController notifier,
    List<String> titles,
  ) async {
    final groupKey = _buildAlbumGroupKey();
    var firstPhotoId = 0;
    for (var index = 0; index < _mediaItems.length; index += 1) {
      if (!mounted) {
        return const AlbumUploadResult(ok: false, message: 'Yükleme durdu.');
      }
      setState(() {
        _uploadIndex = index + 1;
        _uploadProgress = (index + 0.15) / _mediaItems.length;
      });
      final result = await _uploadSingleMedia(
        notifier,
        titles[index],
        _mediaItems[index],
        albumGroupKey: groupKey,
        albumGroupIndex: index,
      );
      if (!result.ok) {
        return result;
      }
      firstPhotoId = firstPhotoId == 0 ? result.photoId : firstPhotoId;
      if (mounted) {
        setState(() {
          _uploadProgress = (index + 1) / _mediaItems.length;
        });
      }
    }
    return AlbumUploadResult(
      ok: true,
      photoId: firstPhotoId,
      message: '${_mediaItems.length} fotoğraf yüklendi.',
    );
  }

  String _buildAlbumGroupKey() {
    final random = math.Random().nextInt(1 << 32);
    return 'album-${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  String _buildTitleForUpload(String prefix, File file, int index, int total) {
    if (prefix.isNotEmpty) {
      return total > 1 ? '$prefix ${index + 1}' : prefix;
    }
    final fileName = file.uri.pathSegments.isEmpty
        ? 'Fotoğraf'
        : file.uri.pathSegments.last.split('.').first;
    final clean = fileName.trim();
    return clean.isEmpty ? 'Fotoğraf ${index + 1}' : clean;
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
