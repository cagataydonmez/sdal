import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../application/community_action_controller.dart';

class EventsCreatePage extends ConsumerStatefulWidget {
  const EventsCreatePage({super.key});

  @override
  ConsumerState<EventsCreatePage> createState() => _EventsCreatePageState();
}

class _EventsCreatePageState extends ConsumerState<EventsCreatePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startsAtController = TextEditingController();
  final TextEditingController _endsAtController = TextEditingController();
  File? _imageFile;
  bool _showInFeed = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(communityActionControllerProvider);
    final isSaving =
        actionState.isLoading && actionState.scope == 'events:create';

    return FeatureScaffold(
      title: 'Yeni etkinlik öner',
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
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Konum',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startsAtController,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç tarihi',
                    hintText: '2026-04-04T19:30',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endsAtController,
                  decoration: const InputDecoration(
                    labelText: 'Bitiş tarihi',
                    hintText: '2026-04-04T22:00',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isSaving
                ? null
                : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _imageFile == null
                  ? 'Kapak görseli ekle'
                  : 'Kapak görselini değiştir',
            ),
          ),
          if (_imageFile != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _imageFile!,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ana akışta göster'),
            subtitle: const Text('Etkinlik herkese açık akışta görünsün'),
            value: _showInFeed,
            onChanged: isSaving ? null : (v) => setState(() => _showInFeed = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSaving ? null : _createEvent,
            icon: const Icon(Icons.check_outlined),
            label: Text(
              isSaving ? 'Gönderiliyor...' : 'Etkinliği gönder',
            ),
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
      title: 'Etkinlik görselini hazırla',
    );
    if (picked == null || !mounted) return;
    setState(() => _imageFile = picked);
  }

  Future<void> _createEvent() async {
    final ok = await ref
        .read(communityActionControllerProvider.notifier)
        .createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          startsAt: _startsAtController.text.trim(),
          endsAt: _endsAtController.text.trim(),
          imageFile: _imageFile,
          showInFeed: _showInFeed,
        );
    if (!mounted) return;
    final state = ref.read(communityActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Etkinlik gönderildi.' : 'Etkinlik oluşturulamadı.'),
        ),
      ),
    );
    if (!ok) return;
    if (!mounted) return;
    context.pop();
  }
}
