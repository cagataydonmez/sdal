import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../application/community_action_controller.dart';

class AnnouncementsCreatePage extends ConsumerStatefulWidget {
  const AnnouncementsCreatePage({super.key});

  @override
  ConsumerState<AnnouncementsCreatePage> createState() =>
      _AnnouncementsCreatePageState();
}

class _AnnouncementsCreatePageState
    extends ConsumerState<AnnouncementsCreatePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  File? _imageFile;
  bool _publishNow = true;
  bool _showInFeed = true;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(communityActionControllerProvider);
    final isSaving =
        actionState.isLoading && actionState.scope == 'announcements:create';

    return FeatureScaffold(
      title: 'Yeni duyuru öner',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Başlık',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'İçerik',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isSaving ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_imageFile == null ? 'Görsel ekle' : 'Görsel değiştir'),
          ),
          if (_imageFile != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hemen yayınla'),
            subtitle: Text(
              _publishNow
                  ? 'Duyuru yayın akışına hazırlanacak'
                  : 'Duyuru taslaklara kaydedilecek, yalnızca siz göreceksiniz',
            ),
            value: _publishNow,
            onChanged: isSaving ? null : (v) => setState(() => _publishNow = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Akışta göster'),
            subtitle: const Text(
              'Yayınlanan duyuru akışta görseliyle post gibi görünür',
            ),
            value: _showInFeed,
            onChanged: isSaving || !_publishNow
                ? null
                : (v) => setState(() => _showInFeed = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSaving ? null : _create,
            icon: const Icon(Icons.check_outlined),
            label: Text(isSaving ? 'Gönderiliyor...' : 'Duyuruyu gönder'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isSaving ? null : () => context.pop(),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await pickAndCropImage(
      context,
      source: source,
      aspectPreset: CropAspectPreset.wide169,
      title: 'Duyuru görselini hazırla',
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = picked);
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve içerik gerekli.')),
      );
      return;
    }
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .createAnnouncement(
          title: title,
          body: body,
          imageFile: _imageFile,
          showInFeed: _showInFeed,
          publish: _publishNow,
        );
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Duyuru gönderildi.' : 'Duyuru gönderilemedi.'),
        ),
      ),
    );
    if (!ok) return;
    if (!mounted) return;
    context.pop();
  }
}
