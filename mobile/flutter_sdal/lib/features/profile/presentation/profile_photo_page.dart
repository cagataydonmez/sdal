import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/profile_action_controller.dart';
import '../data/profile_repository.dart';

class ProfilePhotoPage extends ConsumerStatefulWidget {
  const ProfilePhotoPage({super.key});

  @override
  ConsumerState<ProfilePhotoPage> createState() => _ProfilePhotoPageState();
}

class _ProfilePhotoPageState extends ConsumerState<ProfilePhotoPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final actionState = ref.watch(profileActionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final uploading =
        actionState.isLoading && actionState.scope == 'profile:photo';

    return FeatureScaffold(
      title: l10n.profilePhotoAction,
      child: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil bulunamadı.'));
          }

          final preview = _selectedFile == null
              ? RemoteAvatar(
                  label: '${profile.firstName} ${profile.lastName}'.trim(),
                  imageUrl: config.resolveUrl(profile.photo).toString(),
                  radius: 56,
                )
              : CircleAvatar(
                  radius: 56,
                  backgroundImage: FileImage(_selectedFile!),
                );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SurfaceCard(
                child: Column(
                  children: [
                    preview,
                    const SizedBox(height: 18),
                    Text(
                      _selectedFile == null
                          ? 'Yeni bir fotoğraf seçerek mevcut profil görselini değiştir.'
                          : 'Fotoğraf seçildi: ${_selectedFile!.path.split('/').last}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(l10n.pickFromGallery),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(l10n.cameraAction),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: uploading || _selectedFile == null
                            ? null
                            : _upload,
                        child: Text(
                          uploading
                              ? l10n.submitInProgress
                              : l10n.proofUploadAction,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedFile = File(picked.path);
    });
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null) return;
    final ok = await ref
        .read(profileActionControllerProvider.notifier)
        .uploadPhoto(file);
    if (!mounted) return;
    final actionState = ref.read(profileActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ??
              (ok ? 'Profil fotoğrafı güncellendi.' : 'Fotoğraf yüklenemedi.'),
        ),
      ),
    );
    if (ok) {
      setState(() => _selectedFile = null);
    }
  }
}
