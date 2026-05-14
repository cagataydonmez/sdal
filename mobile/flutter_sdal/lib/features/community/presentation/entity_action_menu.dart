import 'package:flutter/material.dart';
import '../../../core/l10n/context_l10n.dart';

enum EntityActionKind {
  event,
  announcement,
  job,
  groupEvent,
  groupAnnouncement,
}

class EntityActionLabels {
  const EntityActionLabels(this.kind);

  final EntityActionKind kind;

  bool get isEvent =>
      kind == EntityActionKind.event || kind == EntityActionKind.groupEvent;
  bool get isAnnouncement =>
      kind == EntityActionKind.announcement ||
      kind == EntityActionKind.groupAnnouncement;
  bool get isJob => kind == EntityActionKind.job;

  String get edit => isEvent
      ? 'Etkinliği düzenle'
      : isAnnouncement
      ? 'Duyuruyu düzenle'
      : 'İş ilanını düzenle';

  String get unpublish => isEvent
      ? 'Etkinliği yayından kaldır'
      : isAnnouncement
      ? 'Duyuruyu yayından kaldır'
      : 'İş ilanını yayından kaldır';

  String get delete => isEvent
      ? 'Etkinliği sil'
      : isAnnouncement
      ? 'Duyuruyu sil'
      : 'İş ilanını sil';

  String get unpublishTitle => isEvent
      ? 'Etkinlik yayından kaldırılsın mı?'
      : isAnnouncement
      ? 'Duyuru yayından kaldırılsın mı?'
      : 'İş ilanı yayından kaldırılsın mı?';

  String get deleteTitle => isEvent
      ? 'Etkinlik silinsin mi?'
      : isAnnouncement
      ? 'Duyuru silinsin mi?'
      : 'İş ilanı silinsin mi?';

  String get unpublishMessage => isEvent
      ? 'Bu etkinlik akıştan kaldırılır ve taslaklara döner.'
      : isAnnouncement
      ? 'Bu duyuru akıştan kaldırılır ve taslaklara döner.'
      : 'Bu iş ilanı akıştan kaldırılır ve taslaklara döner.';

  String get deleteMessage => isEvent
      ? 'Bu etkinlik kalıcı olarak silinir.'
      : isAnnouncement
      ? 'Bu duyuru kalıcı olarak silinir.'
      : 'Bu iş ilanı kalıcı olarak silinir.';
}

class EntityActionMenu extends StatelessWidget {
  const EntityActionMenu({
    super.key,
    required this.kind,
    this.onEdit,
    this.onUnpublish,
    this.onDelete,
    this.dark = false,
    this.child,
  });

  final EntityActionKind kind;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onUnpublish;
  final Future<void> Function()? onDelete;
  final bool dark;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final labels = EntityActionLabels(kind);
    return PopupMenuButton<String>(
      tooltip: context.l10n.moreActions,
      icon: child == null
          ? Icon(Icons.more_vert, color: dark ? Colors.white : null)
          : null,
      child: child,
      onSelected: (value) async {
        if (value == 'edit') {
          await onEdit?.call();
          return;
        }
        if (value == 'unpublish') {
          final confirmed = await _confirm(
            context,
            title: labels.unpublishTitle,
            message: labels.unpublishMessage,
            actionLabel: 'Yayından kaldır',
          );
          if (confirmed == true) await onUnpublish?.call();
          return;
        }
        if (value == 'delete') {
          final confirmed = await _confirm(
            context,
            title: labels.deleteTitle,
            message: labels.deleteMessage,
            actionLabel: context.l10n.deleteAction,
          );
          if (confirmed == true) await onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem<String>(value: 'edit', child: Text(labels.edit)),
        if (onUnpublish != null)
          PopupMenuItem<String>(
            value: 'unpublish',
            child: Text(labels.unpublish),
          ),
        if (onDelete != null)
          PopupMenuItem<String>(value: 'delete', child: Text(labels.delete)),
      ],
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
