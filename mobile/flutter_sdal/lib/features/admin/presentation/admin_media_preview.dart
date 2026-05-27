import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/network/legacy_media_value.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/sdal_network_image.dart';

class AdminMediaPreview extends ConsumerWidget {
  const AdminMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.label,
    this.semanticLabel,
    this.height = 132,
  });

  final String mediaUrl;
  final String label;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = normalizeLegacyMediaValue(mediaUrl);
    if (normalized.isEmpty) return const SizedBox.shrink();

    final config = ref.watch(appConfigProvider);
    final resolved = config.resolveUrl(normalized).toString();
    final fileName = _mediaFileName(normalized);
    final kind = _mediaKind(normalized);

    if (kind == _AdminMediaKind.image) {
      return _AdminImagePreview(
        imageUrl: resolved,
        fileName: fileName,
        label: label,
        semanticLabel: semanticLabel ?? label,
        height: height,
      );
    }

    return _AdminFilePreview(
      fileName: fileName,
      kind: kind,
      label: label,
      onOpen: () => _openMedia(context, resolved),
    );
  }

  Future<void> _openMedia(BuildContext context, String resolved) async {
    final uri = Uri.tryParse(resolved);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosya bağlantısı açılamadı.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosya görüntüleyici açılamadı.')),
      );
    }
  }
}

class _AdminImagePreview extends StatelessWidget {
  const _AdminImagePreview({
    required this.imageUrl,
    required this.fileName,
    required this.label,
    required this.semanticLabel,
    required this.height,
  });

  final String imageUrl;
  final String fileName;
  final String label;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final radius = BorderRadius.circular(SdalThemeTokens.radiusMd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '$label ön izlemesi. Büyütmek için dokun.',
          child: InkWell(
            onTap: () => _openImagePreview(context),
            borderRadius: radius,
            child: Stack(
              children: [
                SdalNetworkImage(
                  imageUrl: imageUrl,
                  height: height,
                  width: double.infinity,
                  borderRadius: radius,
                  semanticLabel: semanticLabel,
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _MediaBadge(label: label, icon: Icons.image_outlined),
                ),
              ],
            ),
          ),
        ),
        if (fileName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
        ],
      ],
    );
  }

  void _openImagePreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final maxHeight = size.height * 0.78;
        final maxWidth = size.width * 0.92;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SdalNetworkImage(
                    imageUrl: imageUrl,
                    height: maxHeight,
                    width: maxWidth,
                    borderRadius: BorderRadius.zero,
                    semanticLabel: semanticLabel,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminFilePreview extends StatelessWidget {
  const _AdminFilePreview({
    required this.fileName,
    required this.kind,
    required this.label,
    required this.onOpen,
  });

  final String fileName;
  final _AdminMediaKind kind;
  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.panelMuted,
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusMd),
          border: Border.all(color: tokens.panelBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.panelRaised,
                borderRadius: BorderRadius.circular(SdalThemeTokens.radiusSm),
              ),
              child: Icon(_mediaIcon(kind), color: tokens.foregroundMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    fileName.isEmpty ? 'Dosyayı aç' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelRaised.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tokens.foregroundMuted),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

enum _AdminMediaKind { image, video, pdf, file }

_AdminMediaKind _mediaKind(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  final extension = path.contains('.') ? path.split('.').last : '';
  if (<String>{'mp4', 'mov', 'm4v', 'webm'}.contains(extension)) {
    return _AdminMediaKind.video;
  }
  if (extension == 'pdf') return _AdminMediaKind.pdf;
  if (<String>{
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
  }.contains(extension)) {
    return _AdminMediaKind.file;
  }
  return _AdminMediaKind.image;
}

IconData _mediaIcon(_AdminMediaKind kind) {
  return switch (kind) {
    _AdminMediaKind.video => Icons.play_circle_outline,
    _AdminMediaKind.pdf => Icons.picture_as_pdf_outlined,
    _AdminMediaKind.file => Icons.insert_drive_file_outlined,
    _AdminMediaKind.image => Icons.image_outlined,
  };
}

String _mediaFileName(String value) {
  final path = Uri.tryParse(value)?.path ?? value;
  final decoded = Uri.decodeComponent(path.split('/').last);
  return decoded.trim();
}
