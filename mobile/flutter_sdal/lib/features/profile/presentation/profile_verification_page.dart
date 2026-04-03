import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/profile_repository.dart';

class ProfileVerificationPage extends ConsumerStatefulWidget {
  const ProfileVerificationPage({super.key});

  @override
  ConsumerState<ProfileVerificationPage> createState() =>
      _ProfileVerificationPageState();
}

class _ProfileVerificationPageState
    extends ConsumerState<ProfileVerificationPage> {
  final ImagePicker _picker = ImagePicker();
  File? _proofFile;
  String _proofPath = '';
  String _proofImageRecordId = '';
  bool _uploading = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final user = session?.user;

    return FeatureScaffold(
      title: 'Profil doğrulama',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Durum', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  user?.isVerified == true
                      ? 'Profilin doğrulanmış görünüyor.'
                      : 'Networking ve bazı sosyal akışlar için doğrulama gerekiyor. Kimlik veya okul bağlantısını gösteren bir görsel yükleyebilirsin.',
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
                  'Kanıt yükle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _proofFile == null
                      ? 'Fotoğraf galerinden veya kameradan bir görsel seç.'
                      : 'Seçilen dosya: ${_proofFile!.path.split('/').last}',
                ),
                if (_proofPath.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Yüklenen kanıt hazır.',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading || _submitting
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeriden seç'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading || _submitting
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Kamera'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _uploading || _submitting || _proofFile == null
                        ? null
                        : _uploadProof,
                    child: Text(
                      _uploading ? 'Kanıt yükleniyor...' : 'Kanıtı yükle',
                    ),
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
                  'Talebi gönder',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'İstersen önce kanıt yükle, istersen sadece doğrulama talebini gönder.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting || user?.isVerified == true
                        ? null
                        : _submitRequest,
                    child: Text(
                      _submitting
                          ? 'Gönderiliyor...'
                          : 'Doğrulama talebini gönder',
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

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2000,
    );
    if (picked == null || !mounted) return;
    setState(() => _proofFile = File(picked.path));
  }

  Future<void> _uploadProof() async {
    final file = _proofFile;
    if (file == null) return;
    setState(() => _uploading = true);
    final result = await ref
        .read(profileRepositoryProvider)
        .uploadVerificationProof(file);
    if (!mounted) return;
    setState(() => _uploading = false);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : 'Kanıt yüklenemedi.',
          ),
        ),
      );
      return;
    }

    final upload = VerificationUploadResult.fromMap(result.rawData);
    setState(() {
      _proofPath = upload.proofPath;
      _proofImageRecordId = upload.proofImageRecordId;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kanıt dosyası yüklendi.')));
  }

  Future<void> _submitRequest() async {
    setState(() => _submitting = true);
    final result = await ref
        .read(profileRepositoryProvider)
        .submitVerificationRequest(
          proofPath: _proofPath,
          proofImageRecordId: _proofImageRecordId,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : (result.ok
                    ? 'Doğrulama talebi gönderildi.'
                    : 'Talep gönderilemedi.'),
        ),
      ),
    );
    if (result.ok) {
      ref.invalidate(sessionControllerProvider);
    }
  }
}
