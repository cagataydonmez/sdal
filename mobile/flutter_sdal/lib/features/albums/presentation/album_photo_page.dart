import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../explore/data/explore_repository.dart';
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
  AlbumPhotoDetail? _photo;
  List<AlbumComment> _comments = const <AlbumComment>[];
  bool _commentsHidden = false;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(albumsActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    return FeatureScaffold(
      title: _photo?.title ?? 'Fotoğraf',
      actions: [
        if (_photo?.canEditPhoto ?? false)
          IconButton(
            tooltip: 'Fotoğrafı düzenle',
            onPressed: _showPhotoEditor,
            icon: const Icon(Icons.edit_outlined),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      config.siteBaseUri
                          .resolve(
                            '/api/media/kucukresim?width=1400&file=${Uri.encodeComponent(_photo!.fileName)}',
                          )
                          .toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
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
                              avatar: CircleAvatar(
                                backgroundImage: member.photo.trim().isEmpty
                                    ? null
                                    : NetworkImage(
                                        config
                                            .resolveUrl(member.photo)
                                            .toString(),
                                      ),
                              ),
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
                  FilledButton.tonalIcon(
                    onPressed: _showLikes,
                    icon: const Icon(Icons.people_outline_rounded),
                    label: const Text('Beğenenler'),
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
                    TextField(
                      controller: _commentController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Yorum',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _insertMention,
                          icon: const Icon(Icons.alternate_email_rounded),
                          label: const Text('Kişi etiketle'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed:
                              actionState.isLoading &&
                                  actionState.scope ==
                                      'albums:comment:${widget.photoId}'
                              ? null
                              : _submitComment,
                          child: Text(
                            actionState.isLoading &&
                                    actionState.scope ==
                                        'albums:comment:${widget.photoId}'
                                ? 'Gönderiliyor...'
                                : 'Yorumu gönder',
                          ),
                        ),
                      ],
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
                  child: SurfaceCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RemoteAvatar(
                          label: comment.displayName,
                          imageUrl: config.resolveUrl(comment.photo).toString(),
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      comment.displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  if (comment.canEdit || comment.canDelete)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editComment(comment);
                                        } else if (value == 'delete') {
                                          _deleteComment(comment);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (comment.canEdit)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Yorumu düzenle'),
                                          ),
                                        if (comment.canDelete)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Yorumu sil'),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                              Text(
                                [
                                  _formatDate(comment.date),
                                  if (comment.isEdited) 'düzenlendi',
                                ].join(' • '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(_plainText(comment.comment)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
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
    await _load();
  }

  Future<void> _insertMention() async {
    final result = await showModalBottomSheet<List<MemberSummary>>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          const AlbumMemberPickerSheet(title: 'Yorumda kişiyi etiketle'),
    );
    if (result == null || result.isEmpty || !mounted) return;
    final handles = result
        .where((member) => member.handle.trim().isNotEmpty)
        .map((member) => '@${member.handle.trim()}')
        .join(' ');
    if (handles.isEmpty) return;
    setState(() {
      final previous = _commentController.text.trim();
      _commentController.text = previous.isEmpty
          ? handles
          : '$previous $handles';
      _commentController.selection = TextSelection.collapsed(
        offset: _commentController.text.length,
      );
    });
  }

  Future<void> _toggleLike() async {
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .toggleLike(widget.photoId);
    if (!mounted || !ok) return;
    await _load();
  }

  Future<void> _showLikes() async {
    final likes = await ref
        .read(albumsRepositoryProvider)
        .fetchLikes(widget.photoId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Beğenenler', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (likes.isEmpty)
              const Text('Henüz beğeni yok.')
            else
              ...likes.map(
                (user) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.avatarUrl.trim().isEmpty
                        ? null
                        : NetworkImage(
                            ref
                                .read(appConfigProvider)
                                .resolveUrl(user.avatarUrl)
                                .toString(),
                          ),
                  ),
                  title: Text(user.displayName),
                  subtitle: Text(
                    [
                      if (user.username.isNotEmpty) '@${user.username}',
                      if (user.graduationYear != null) '${user.graduationYear}',
                    ].join(' • '),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoEditor() async {
    final photo = _photo;
    if (photo == null) return;
    final titleController = TextEditingController(text: photo.title);
    final descriptionController = TextEditingController(
      text: _plainText(photo.description),
    );
    var allowComments = photo.allowComments;
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
          following: false,
          graduationYear: '',
          joinedAt: null,
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Fotoğrafı düzenle',
                  style: Theme.of(context).textTheme.titleLarge,
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
                          context: context,
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
                        .map((member) => InputChip(label: Text(member.name)))
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final ok = await ref
                        .read(albumsActionControllerProvider.notifier)
                        .updatePhoto(
                          photoId: widget.photoId,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          allowComments: allowComments,
                          taggedUserIds: tagged
                              .map((member) => member.id)
                              .toList(),
                        );
                    if (!mounted || !context.mounted) return;
                    final state = ref.read(albumsActionControllerProvider);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.message ??
                              (ok
                                  ? 'Fotoğraf güncellendi.'
                                  : 'Fotoğraf güncellenemedi.'),
                        ),
                      ),
                    );
                    if (ok) {
                      Navigator.of(context).pop();
                      await _load();
                    }
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

  Future<void> _editComment(AlbumComment comment) async {
    final controller = TextEditingController(text: _plainText(comment.comment));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu düzenle'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .editComment(
          photoId: widget.photoId,
          commentId: comment.id,
          comment: result,
        );
    if (ok && mounted) await _load();
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
    if (ok && mounted) await _load();
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
    if (ok && mounted) await _load();
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

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}
