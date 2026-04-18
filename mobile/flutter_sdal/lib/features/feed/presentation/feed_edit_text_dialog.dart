import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/image_lightbox.dart';
import '../../../core/widgets/sdal_network_image.dart';

class FeedEditPostResult {
  const FeedEditPostResult({
    required this.content,
    this.imageFile,
    this.removeImage = false,
  });

  final String content;
  final File? imageFile;
  final bool removeImage;
}

class FeedEditPostSheet extends StatefulWidget {
  const FeedEditPostSheet({
    super.key,
    required this.initialContent,
    this.currentImageUrl,
  });

  final String initialContent;
  final String? currentImageUrl;

  @override
  State<FeedEditPostSheet> createState() => _FeedEditPostSheetState();
}

class _FeedEditPostSheetState extends State<FeedEditPostSheet> {
  late final TextEditingController _controller;
  File? _newImage;
  bool _removeExistingImage = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasExistingImage =>
      (widget.currentImageUrl?.isNotEmpty ?? false) && !_removeExistingImage;

  Future<void> _pickImage() async {
    final file = await pickAndCropImage(
      context,
      aspectPreset: CropAspectPreset.portrait45,
      title: 'Gönderi görselini kırp',
    );
    if (!mounted) return;
    if (file != null) {
      setState(() {
        _newImage = file;
        _removeExistingImage = true;
      });
    }
  }

  void _removeNewImage() {
    setState(() {
      _newImage = null;
      // Restore the existing image if user cancels new image selection
      _removeExistingImage = false;
    });
  }

  void _removeCurrentImage() {
    setState(() {
      _removeExistingImage = true;
      _newImage = null;
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    final hasContent = text.isNotEmpty;
    final hasImage = _newImage != null || _hasExistingImage;
    if (!hasContent && !hasImage) return;
    Navigator.of(context).pop(
      FeedEditPostResult(
        content: text,
        imageFile: _newImage,
        removeImage: _removeExistingImage && _newImage == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.feedPostEditTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.feedComposerHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_newImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ImagePreview(
                  onRemove: _removeNewImage,
                  removeTooltip: l10n.removeImageAction,
                  child: SdalLightboxImage(
                    imageProvider: FileImage(_newImage!),
                    semanticLabel: 'Seçilen gönderi görseli',
                    child: Image.file(
                      _newImage!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )
            else if (_hasExistingImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ImagePreview(
                  onRemove: _removeCurrentImage,
                  removeTooltip: l10n.removeImageAction,
                  child: SdalNetworkImage(
                    imageUrl: widget.currentImageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.pickFromGallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.saveAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.child,
    required this.onRemove,
    required this.removeTooltip,
  });

  final Widget child;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: removeTooltip,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// Legacy dialog kept for comment editing (text-only)
class FeedEditTextDialog extends StatefulWidget {
  const FeedEditTextDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.minLines,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final int minLines;
  final int maxLines;

  @override
  State<FeedEditTextDialog> createState() => _FeedEditTextDialogState();
}

class _FeedEditTextDialogState extends State<FeedEditTextDialog> {
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(text);
            }
          },
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}
