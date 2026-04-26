import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/profile_action_controller.dart';

class ProfileVerificationPage extends ConsumerStatefulWidget {
  const ProfileVerificationPage({super.key});

  @override
  ConsumerState<ProfileVerificationPage> createState() =>
      _ProfileVerificationPageState();
}

class _ProfileVerificationPageState
    extends ConsumerState<ProfileVerificationPage> {
  File? _proofFile;
  String _proofPath = '';
  String _proofImageRecordId = '';
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final actionState = ref.watch(profileActionControllerProvider);
    final user = session?.user;
    final isTeacherVerification = isTeacherCohort(user?.graduationYear ?? '');
    final l10n = context.l10n;
    final uploading =
        actionState.isLoading && actionState.scope == 'profile:proof';
    final submitting =
        actionState.isLoading && actionState.scope == 'profile:verification';

    return FeatureScaffold(
      title: l10n.profileVerificationPageTitle,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statusLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  user?.isVerified == true
                      ? l10n.profileVerifiedMessage
                      : _submitted
                      ? l10n.verificationSubmitted
                      : isTeacherVerification
                      ? 'Öğretmen doğrulaması için okul/öğretmenlik bağınızı gösteren belgeyi yükleyin. Bu onay, mezun üye doğrulamasından ayrı değerlendirilir.'
                      : l10n.profileVerificationHint,
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
                  l10n.proofUploadTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _proofFile == null
                      ? l10n.proofUploadHint
                      : l10n.proofSelectedFile(
                          _proofFile!.path.split('/').last,
                        ),
                ),
                if (_proofPath.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.proofReady,
                    style: TextStyle(color: Theme.of(context).sdal.success),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uploading || submitting
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.pickFromGallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uploading || submitting
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
                  child: FilledButton.tonal(
                    onPressed: uploading || submitting || _proofFile == null
                        ? null
                        : _uploadProof,
                    child: Text(
                      uploading
                          ? l10n.proofUploadInProgress
                          : l10n.proofUploadAction,
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
                  l10n.proofRequestTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(l10n.proofRequestHint),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        submitting || user?.isVerified == true || _submitted
                        ? null
                        : _submitRequest,
                    child: Text(
                      submitting
                          ? l10n.verificationSubmitInProgress
                          : l10n.verificationSubmitAction,
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
    final picked = await pickAndCropImage(
      context,
      source: source,
      title: 'Belgeyi kırp',
    );
    if (picked == null || !mounted) return;
    setState(() => _proofFile = picked);
  }

  Future<void> _uploadProof() async {
    final file = _proofFile;
    if (file == null) return;
    final result = await ref
        .read(profileActionControllerProvider.notifier)
        .uploadVerificationProof(file);
    if (!mounted) return;

    if (result == null) {
      final actionState = ref.read(profileActionControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionState.message ?? context.l10n.proofUploadFailed),
        ),
      );
      return;
    }

    setState(() {
      _proofPath = result.proofPath;
      _proofImageRecordId = result.proofImageRecordId;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.proofUploaded)));
  }

  Future<void> _submitRequest() async {
    final ok = await ref
        .read(profileActionControllerProvider.notifier)
        .submitVerificationRequest(
          proofPath: _proofPath,
          proofImageRecordId: _proofImageRecordId,
          requestType:
              isTeacherCohort(
                ref
                        .read(sessionControllerProvider)
                        .value
                        ?.user
                        ?.graduationYear ??
                    '',
              )
              ? 'teacher_verification'
              : 'member_verification',
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _submitted = true);
    }
    final actionState = ref.read(profileActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ??
              (ok
                  ? context.l10n.verificationSubmitted
                  : context.l10n.verificationSubmitFailed),
        ),
      ),
    );
  }
}
