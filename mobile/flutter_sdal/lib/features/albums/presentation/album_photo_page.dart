import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/image_lightbox.dart';
import '../../../core/widgets/sdal_network_image.dart';
import '../../../core/widgets/surface_card.dart';
import '../../explore/data/explore_repository.dart';
import '../../social/presentation/member_mention_composer.dart';
import '../../social/presentation/social_interaction_widgets.dart';
import '../application/albums_action_controller.dart';
import '../data/albums_repository.dart';
import 'album_member_picker_sheet.dart';

class AlbumPhotoPage extends ConsumerStatefulWidget {
  const AlbumPhotoPage({super.key, required this.photoId});

  final int photoId;

  @override
  ConsumerState<AlbumPhotoPage> createState() => _AlbumPhotoPageState();
}

class _AlbumPhotoPageState extends ConsumerState<AlbumPhotoPage> {
  final TextEditingController _commentController = TextEditingController();
  final List<MemberSummary> _selectedMentions = <MemberSummary>[];
  final PageController _groupPageController = PageController();

  AlbumPhotoDetail? _photo;
  List<AlbumComment> _comments = const <AlbumComment>[];
  bool _commentsHidden = false;
  bool _isLoading = true;
  String _error = '';
  int _activeGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    _groupPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(albumsActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final likesState = ref.watch(albumPhotoLikesProvider(widget.photoId));
    final submittingComment =
        actionState.isLoading &&
        actionState.scope == 'albums:comment:${widget.photoId}';

    return FeatureScaffold(
      title: _photo?.title ?? 'Fotoğraf',
      actions: [
        if (_photo?.canEditPhoto ?? false)
          PopupMenuButton<String>(
            tooltip: 'Fotoğraf işlemleri',
            onSelected: (value) async {
              if (value == 'edit') {
                await _showPhotoEditor();
              } else if (value == 'delete') {
                await _confirmDeletePhoto();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Fotoğrafı/seriyi düzenle'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Fotoğrafı/seriyi sil'),
              ),
            ],
          ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            SurfaceCard(
              child: ErrorView(
                message: _error,
                kind: ErrorViewKind.network,
                onRetry: _load,
              ),
            )
          else if (_photo == null)
            const SurfaceCard(
              child: EmptyStateView(
                icon: Icons.photo_library_outlined,
                title: 'Fotoğraf bulunamadı',
                message: 'Bu fotoğrafa artık erişilemiyor olabilir.',
                compact: true,
              ),
            )
          else ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoGroupViewer(
                    photo: _photo!,
                    activeIndex: _activeGroupIndex,
                    controller: _groupPageController,
                    onChanged: (index) =>
                        setState(() => _activeGroupIndex = index),
                    onPrevious: _previousGroupPhoto,
                    onNext: _nextGroupPhoto,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _photo!.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_photo!.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_plainText(_photo!.description)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaChip(label: _photo!.categoryTitle),
                      _MetaChip(label: '${_photo!.viewCount} görüntüleme'),
                      _MetaChip(label: '${_photo!.likeCount} beğeni'),
                      _MetaChip(label: '${_photo!.commentCount} yorum'),
                      if (_photo!.groupCount > 1)
                        _MetaChip(
                          label: '${_photo!.groupCount} fotoğraflık seri',
                        ),
                    ],
                  ),
                  if (_photo!.taggedUsers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Etiketlenen kişiler',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _photo!.taggedUsers
                          .map(
                            (member) => InputChip(
                              label: Text(member.displayName),
                              onPressed: member.id > 0
                                  ? () => context.push('/members/${member.id}')
                                  : null,
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
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _toggleLike,
                    icon: Icon(
                      _photo!.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    label: Text('${_photo!.likeCount}'),
                  ),
                  if (_photo!.canBulkDeleteComments)
                    FilledButton.tonalIcon(
                      onPressed: _comments.isEmpty
                          ? null
                          : _confirmDeleteAllComments,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Yorumları temizle'),
                    ),
                ],
              ),
            ),
            likesState.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (likes) {
                if (likes.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SocialLikePreviewButton(
                    people: likes
                        .map(
                          (user) => SocialLikePerson(
                            id: user.id,
                            displayName: user.displayName,
                            imageUrl: config
                                .resolveUrl(user.avatarUrl)
                                .toString(),
                            subtitle: [
                              if (user.username.isNotEmpty) '@${user.username}',
                              if (user.graduationYear != null)
                                '${user.graduationYear}',
                            ].join(' • '),
                          ),
                        )
                        .toList(growable: false),
                    title: 'Beğenenler',
                    ctaLabel: 'Beğenenler',
                    onUserTap: (context, person) {
                      Navigator.of(context).pop();
                      if (person.id > 0) {
                        context.push('/members/${person.id}');
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_photo!.allowComments) ...[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yorum ekle',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    MemberMentionComposer(
                      controller: _commentController,
                      selectedMembers: _selectedMentions,
                      onSelectedMembersChanged: (members) => setState(() {
                        _selectedMentions
                          ..clear()
                          ..addAll(members);
                      }),
                      labelText: 'Yorum',
                      hintText: 'Yorumunu yaz, @ ile üye etiketle...',
                      minLines: 3,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: submittingComment ? null : _submitComment,
                        child: Text(
                          submittingComment
                              ? 'Gönderiliyor...'
                              : 'Yorumu gönder',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              SurfaceCard(
                child: Text(
                  _commentsHidden
                      ? 'Yorumlar şu anda kapalı. Yeniden açıldığında önceki yorumlar geri gelir.'
                      : 'Bu fotoğrafta yorumlar kapalı.',
                ),
              ),
            const SizedBox(height: 16),
            if (_comments.isEmpty)
              SurfaceCard(
                child: EmptyStateView(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: _commentsHidden ? 'Yorumlar gizli' : 'Henüz yorum yok',
                  message: _commentsHidden
                      ? 'Fotoğrafı yükleyen kişi yorumları kapatmış durumda.'
                      : 'İlk yorumu sen yazabilirsin.',
                  compact: true,
                ),
              )
            else
              ..._comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SocialCommentCard(
                    authorName: comment.displayName,
                    authorHandle: comment.handle,
                    authorPhotoUrl: config.resolveUrl(comment.photo).toString(),
                    body: _plainText(comment.comment),
                    createdLabel: formatSdalCreatedLabel(context, comment.date),
                    editedLabel: comment.isEdited
                        ? formatSdalEditedLabel(context, comment.updatedAt)
                        : null,
                    onAuthorTap: comment.userId > 0
                        ? () => context.push('/members/${comment.userId}')
                        : null,
                    trailing: comment.canEdit || comment.canDelete
                        ? SocialCommentActionMenuButton(
                            canEdit: comment.canEdit,
                            onEdit: () => _editComment(comment),
                            onDelete: () => _deleteComment(comment),
                            editLabel: 'Yorumu düzenle',
                            deleteLabel: 'Yorumu sil',
                            tooltip: 'Yorum işlemleri',
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final repo = ref.read(albumsRepositoryProvider);
      final photo = await repo.fetchPhotoDetail(widget.photoId);
      final commentsPayload = await repo.fetchComments(widget.photoId);
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _comments = commentsPayload.$1;
        _commentsHidden = commentsPayload.$2;
        _activeGroupIndex = _initialGroupIndex(photo);
      });
      if (photo.groupPhotos.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_groupPageController.hasClients) return;
          _groupPageController.jumpToPage(_activeGroupIndex);
        });
      }
      ref.invalidate(albumPhotoLikesProvider(widget.photoId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _initialGroupIndex(AlbumPhotoDetail photo) {
    final photos = photo.groupPhotos;
    if (photos.isEmpty) return 0;
    final byId = photos.indexWhere((item) => item.id == widget.photoId);
    if (byId >= 0) return byId;
    final byFile = photos.indexWhere((item) => item.fileName == photo.fileName);
    return byFile >= 0 ? byFile : 0;
  }

  void _previousGroupPhoto() {
    if (_activeGroupIndex <= 0) return;
    _groupPageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _nextGroupPhoto() {
    final total = _photo?.groupPhotos.length ?? 0;
    if (_activeGroupIndex >= total - 1) return;
    _groupPageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submitComment() async {
    final comment = composeMentionText(
      _commentController.text,
      _selectedMentions,
    );
    if (comment.isEmpty) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .addComment(photoId: widget.photoId, comment: comment);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Yorum gönderildi.' : 'Yorum gönderilemedi.'),
        ),
      ),
    );
    if (!ok) return;
    _commentController.clear();
    setState(() => _selectedMentions.clear());
    await _load();
  }

  Future<void> _toggleLike() async {
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .toggleLike(widget.photoId);
    if (!mounted || !ok) return;
    ref.invalidate(albumPhotoLikesProvider(widget.photoId));
    await _load();
  }

  Future<void> _showPhotoEditor() async {
    final photo = _photo;
    if (photo == null) return;
    final config = ref.read(appConfigProvider);
    final titleController = TextEditingController(text: photo.title);
    final descriptionController = TextEditingController(
      text: _plainText(photo.description),
    );
    var allowComments = photo.allowComments;
    EditedMediaResult? replacementFile;
    final tagged = <MemberSummary>[
      for (final member in photo.taggedUsers)
        MemberSummary(
          id: member.id,
          name: member.displayName,
          handle: member.handle,
          city: '',
          profession: '',
          photo: member.photo,
          verified: false,
          role: 'user',
          following: false,
          graduationYear: '',
          teacherSubject: '',
          teacherSubjectOther: '',
          teacherCurrentlyWorking: false,
          joinedAt: null,
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  photo.groupCount > 1
                      ? 'Fotoğraf serisini düzenle'
                      : 'Fotoğrafı düzenle',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: replacementFile != null
                            ? SdalLightboxImage(
                                imageProvider: FileImage(replacementFile!.file),
                                semanticLabel: 'Düzenlenen fotoğraf önizlemesi',
                                child: Image.file(
                                  replacementFile!.file,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : SdalNetworkImage(
                                imageUrl: config.siteBaseUri
                                    .resolve(
                                      '/api/media/kucukresim?width=800&file=${Uri.encodeComponent(photo.fileName)}',
                                    )
                                    .toString(),
                                fit: BoxFit.cover,
                                semanticLabel: photo.title,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              replacementFile != null
                                  ? 'Kayda hazır'
                                  : 'Mevcut fotoğraf',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await pickAndEditImage(
                            ctx,
                            title: 'Yeni fotoğrafı kırp',
                          );
                          if (picked == null) return;
                          setModalState(() => replacementFile = picked);
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeriden değiştir'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final edited = await _editCurrentPhotoSource(photo);
                          if (!ctx.mounted || edited == null) return;
                          setModalState(() => replacementFile = edited);
                        },
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Mevcut görseli aç'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Başlık',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: allowComments,
                  title: const Text('Yorumları açık tut'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) =>
                      setModalState(() => allowComments = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result =
                        await showModalBottomSheet<List<MemberSummary>>(
                          context: ctx,
                          isScrollControlled: true,
                          builder: (context) =>
                              AlbumMemberPickerSheet(initial: tagged),
                        );
                    if (result == null) return;
                    setModalState(() {
                      tagged
                        ..clear()
                        ..addAll(result);
                    });
                  },
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: Text(
                    tagged.isEmpty
                        ? 'Kişi etiketle'
                        : '${tagged.length} kişi etiketli',
                  ),
                ),
                if (tagged.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tagged
                        .map(
                          (member) => InputChip(
                            label: Text(member.name),
                            onDeleted: () => setModalState(
                              () => tagged.removeWhere(
                                (item) => item.id == member.id,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final notifier = ref.read(
                      albumsActionControllerProvider.notifier,
                    );
                    // Replace file first if a new one was picked.
                    if (replacementFile != null) {
                      final fileOk = await notifier.replacePhotoFile(
                        photoId: widget.photoId,
                        file: replacementFile!.file,
                        sourceFile: replacementFile!.sourceFile,
                        editMetadata: replacementFile!.metadata,
                      );
                      if (!mounted || !ctx.mounted) return;
                      if (!fileOk) {
                        final st = ref.read(albumsActionControllerProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              st.message ?? 'Fotoğraf değiştirilemedi.',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    final ok = await notifier.updatePhoto(
                      photoId: widget.photoId,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      allowComments: allowComments,
                      taggedUserIds: tagged.map((member) => member.id).toList(),
                    );
                    if (!mounted || !ctx.mounted) return;
                    final state = ref.read(albumsActionControllerProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.message ??
                              (ok
                                  ? 'Fotoğraf güncellendi.'
                                  : 'Fotoğraf güncellenemedi.'),
                        ),
                      ),
                    );
                    if (!ok) return;
                    ref.invalidate(albumPhotoLikesProvider(widget.photoId));
                    Navigator.of(ctx).pop();
                    await _load();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<EditedMediaResult?> _editCurrentPhotoSource(
    AlbumPhotoDetail photo,
  ) async {
    final sourceFile = await _downloadPhotoEditorSource(photo);
    if (!mounted || sourceFile == null) return null;
    return editImageFile(
      context,
      sourceFile: sourceFile,
      title: 'Fotoğrafı düzenle',
      initialMetadata: photo.editSourceFileName.isNotEmpty
          ? photo.editMetadata
          : const <String, dynamic>{},
    );
  }

  Future<File?> _downloadPhotoEditorSource(AlbumPhotoDetail photo) async {
    final apiClient = ref.read(apiClientProvider);
    final sourceFileName = photo.editSourceFileName.isNotEmpty
        ? photo.editSourceFileName
        : photo.fileName;
    if (sourceFileName.isEmpty) return null;

    final uri = apiClient.buildApiUri(
      '/uploads/album/${Uri.encodeComponent(sourceFileName)}',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final cookieHeader = await apiClient.cookieHeaderForUri(uri);
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fotoğraf düzenleme kaynağı indirilemedi.'),
            ),
          );
        }
        return null;
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      final tempDir = await getTemporaryDirectory();
      final extension = sourceFileName.contains('.')
          ? '.${sourceFileName.split('.').last}'
          : '.jpg';
      final file = File(
        '${tempDir.path}/album-edit-source-${photo.id}-${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf düzenleme kaynağı indirilemedi.'),
          ),
        );
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _editComment(AlbumComment comment) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SocialEditTextDialog(
        title: 'Yorumu düzenle',
        initialValue: _plainText(comment.comment),
        minLines: 3,
        maxLines: 5,
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .editComment(
          photoId: widget.photoId,
          commentId: comment.id,
          comment: result,
        );
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Yorum güncellendi.' : 'Yorum güncellenemedi.'),
        ),
      ),
    );
    if (ok) await _load();
  }

  Future<void> _deleteComment(AlbumComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu sil'),
        content: const Text('Bu yorumu silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .deleteComment(photoId: widget.photoId, commentId: comment.id);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Yorum silindi.' : 'Yorum silinemedi.'),
        ),
      ),
    );
    if (ok) await _load();
  }

  Future<void> _confirmDeleteAllComments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm yorumları sil'),
        content: const Text(
          'Bu fotoğraftaki tüm yorumları kalıcı olarak silmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hepsini sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .deleteAllComments(widget.photoId);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Tüm yorumlar silindi.' : 'Yorumlar silinemedi.'),
        ),
      ),
    );
    if (ok) await _load();
  }

  Future<void> _confirmDeletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotoğrafı sil'),
        content: Text(
          (_photo?.groupCount ?? 1) > 1
              ? 'Bu serideki tüm fotoğraflar ve altındaki yorumlar kaldırılacak. Bu işlem geri alınamaz.'
              : 'Bu fotoğraf ve altındaki yorumlar kaldırılacak. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .deletePhoto(widget.photoId);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Fotoğraf silindi.' : 'Fotoğraf silinemedi.'),
        ),
      ),
    );
    if (!ok) return;
    ref.invalidate(albumsDashboardProvider);
    ref.invalidate(myAlbumsProvider);
    context.pop();
  }
}

class _PhotoGroupViewer extends ConsumerWidget {
  const _PhotoGroupViewer({
    required this.photo,
    required this.activeIndex,
    required this.controller,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final AlbumPhotoDetail photo;
  final int activeIndex;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final photos = photo.groupPhotos.isEmpty
        ? [
            AlbumPhotoGroupItem(
              id: photo.id,
              fileName: photo.fileName,
              title: photo.title,
              groupIndex: 0,
            ),
          ]
        : photo.groupPhotos;
    final hasMultiple = photos.length > 1;

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: controller,
              onPageChanged: onChanged,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final item = photos[index];
                return SdalNetworkImage(
                  imageUrl: config.siteBaseUri
                      .resolve(
                        '/api/media/kucukresim?width=1400&file=${Uri.encodeComponent(item.fileName)}',
                      )
                      .toString(),
                  semanticLabel: item.title,
                );
              },
            ),
          ),
        ),
        if (hasMultiple) ...[
          Positioned(
            left: 8,
            child: _PhotoGroupArrowButton(
              icon: Icons.chevron_left_rounded,
              enabled: activeIndex > 0,
              onPressed: onPrevious,
            ),
          ),
          Positioned(
            right: 8,
            child: _PhotoGroupArrowButton(
              icon: Icons.chevron_right_rounded,
              enabled: activeIndex < photos.length - 1,
              onPressed: onNext,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${activeIndex + 1}/${photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoGroupArrowButton extends StatelessWidget {
  const _PhotoGroupArrowButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: enabled ? 0.52 : 0.22),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(label),
    );
  }
}

String _plainText(String raw) => plainTextFromRichContent(raw);
