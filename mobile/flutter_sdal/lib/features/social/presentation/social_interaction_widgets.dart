import 'package:flutter/material.dart';

import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';

class SocialLikePerson {
  const SocialLikePerson({
    required this.id,
    required this.displayName,
    required this.imageUrl,
    this.subtitle = '',
  });

  final int id;
  final String displayName;
  final String imageUrl;
  final String subtitle;
}

class SocialLikePreviewButton extends StatelessWidget {
  const SocialLikePreviewButton({
    super.key,
    required this.people,
    this.title = 'Beğenenler',
    this.ctaLabel = 'Beğenenler',
    this.onUserTap,
  });

  final List<SocialLikePerson> people;
  final String title;
  final String ctaLabel;
  final void Function(BuildContext context, SocialLikePerson person)? onUserTap;

  static const _avatarRadius = 13.0;
  static const _overlap = 9.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (people.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showPeopleSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlappingAvatarRow(
                people: people,
                avatarRadius: _avatarRadius,
                overlap: _overlap,
                borderColor: theme.colorScheme.surface,
              ),
              const SizedBox(width: 8),
              Text(
                ctaLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeopleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _LikedBySheet(title: title, people: people, onUserTap: onUserTap),
    );
  }
}

class SocialCommentCard extends StatelessWidget {
  const SocialCommentCard({
    super.key,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.body,
    required this.createdLabel,
    this.authorHandle = '',
    this.editedLabel,
    this.onAuthorTap,
    this.trailing,
  });

  final String authorName;
  final String authorHandle;
  final String authorPhotoUrl;
  final String body;
  final String createdLabel;
  final String? editedLabel;
  final VoidCallback? onAuthorTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onAuthorTap,
                child: RemoteAvatar(
                  label: authorName,
                  imageUrl: authorPhotoUrl,
                  radius: 18,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (authorHandle.isNotEmpty)
                      Text(
                        '@$authorHandle',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              ...[trailing].whereType<Widget>(),
            ],
          ),
          const SizedBox(height: 8),
          Text(body),
          if (createdLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(createdLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (editedLabel != null && editedLabel!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              editedLabel!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class SocialCommentActionMenuButton extends StatelessWidget {
  const SocialCommentActionMenuButton({
    super.key,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    this.canDelete = true,
    this.onReport,
    this.onBlock,
    this.editLabel = 'Yorumu düzenle',
    this.deleteLabel = 'Sil',
    this.reportLabel = 'Şikayet et',
    this.blockLabel = 'Kullanıcıyı engelle',
    this.tooltip = 'Daha fazla işlem',
  });

  final bool canEdit;
  final bool canDelete;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onReport;
  final Future<void> Function()? onBlock;
  final String editLabel;
  final String deleteLabel;
  final String reportLabel;
  final String blockLabel;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      icon: const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == 'edit') {
          await onEdit();
        } else if (value == 'delete') {
          await onDelete();
        } else if (value == 'report') {
          await onReport?.call();
        } else if (value == 'block') {
          await onBlock?.call();
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem<String>(value: 'edit', child: Text(editLabel)),
        if (canDelete)
          PopupMenuItem<String>(value: 'delete', child: Text(deleteLabel)),
        if (onReport != null)
          PopupMenuItem<String>(value: 'report', child: Text(reportLabel)),
        if (onBlock != null)
          PopupMenuItem<String>(value: 'block', child: Text(blockLabel)),
      ],
    );
  }
}

class SocialEditTextDialog extends StatefulWidget {
  const SocialEditTextDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.minLines = 2,
    this.maxLines = 6,
    this.confirmLabel = 'Kaydet',
    this.cancelLabel = 'Vazgeç',
  });

  final String title;
  final String initialValue;
  final int minLines;
  final int maxLines;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<SocialEditTextDialog> createState() => _SocialEditTextDialogState();
}

class _SocialEditTextDialogState extends State<SocialEditTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _OverlappingAvatarRow extends StatelessWidget {
  const _OverlappingAvatarRow({
    required this.people,
    required this.avatarRadius,
    required this.overlap,
    required this.borderColor,
  });

  final List<SocialLikePerson> people;
  final double avatarRadius;
  final double overlap;
  final Color borderColor;

  static const _maxVisible = 12;

  @override
  Widget build(BuildContext context) {
    final display = people.take(_maxVisible).toList(growable: false);
    final extra = people.length - display.length;
    final diameter = avatarRadius * 2;
    final step = diameter - overlap;
    final totalItems = display.length + (extra > 0 ? 1 : 0);
    final stackWidth = diameter + (totalItems - 1) * step;
    return SizedBox(
      width: stackWidth,
      height: diameter,
      child: Stack(
        children: [
          for (var index = 0; index < display.length; index++)
            Positioned(
              left: index * step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: RemoteAvatar(
                  label: display[index].displayName,
                  imageUrl: display[index].imageUrl,
                  radius: avatarRadius,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: display.length * step,
              child: _ExtraCount(
                count: extra,
                radius: avatarRadius,
                borderColor: borderColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtraCount extends StatelessWidget {
  const _ExtraCount({
    required this.count,
    required this.radius,
    required this.borderColor,
  });

  final int count;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _LikedBySheet extends StatelessWidget {
  const _LikedBySheet({
    required this.title,
    required this.people,
    this.onUserTap,
  });

  final String title;
  final List<SocialLikePerson> people;
  final void Function(BuildContext context, SocialLikePerson person)? onUserTap;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: people.isEmpty
                ? const Center(child: Text('Henüz beğeni yok.'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return ListTile(
                        leading: RemoteAvatar(
                          label: person.displayName,
                          imageUrl: person.imageUrl,
                          radius: 20,
                        ),
                        title: Text(person.displayName),
                        subtitle: person.subtitle.trim().isEmpty
                            ? null
                            : Text(person.subtitle),
                        onTap: onUserTap == null
                            ? null
                            : () => onUserTap!(context, person),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
