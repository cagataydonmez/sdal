import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../stories/presentation/stories_rail.dart';
import '../application/profile_action_controller.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;

    return FeatureScaffold(
      title: l10n.profileTitle,
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(profileProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (profile) {
          final user = session?.user;
          if (profile == null || user == null) {
            return Center(child: Text(l10n.profileMissing));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SurfaceCard(
                child: Row(
                  children: [
                    RemoteAvatar(
                      label: user.displayName,
                      imageUrl: config.resolveUrl(profile.photo).toString(),
                      radius: 34,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (user.kadi.isNotEmpty) Text('@${user.kadi}'),
                          if (profile.email.isNotEmpty)
                            Text(
                              profile.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(
                                label: user.isVerified
                                    ? l10n.profileVerified
                                    : l10n.profilePendingVerification,
                                color: user.isVerified
                                    ? const Color(0xFF0D7A4B)
                                    : const Color(0xFF9A6700),
                              ),
                              _StatusChip(
                                label: user.role,
                                color: const Color(0xFF173657),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const StoriesRail(
                mode: StoryRailMode.mine,
                showUpload: true,
                title: 'Benim hikayelerim',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/profile/photo'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.profilePhotoAction),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/profile/verification'),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(l10n.profileVerificationAction),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.profileAccountDetailsTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              _openEditProfileDialog(context, ref, profile),
                          child: Text(l10n.editAction),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ProfileRow(label: 'Ad', value: profile.firstName),
                    _ProfileRow(label: 'Soyad', value: profile.lastName),
                    _ProfileRow(
                      label: 'Mezuniyet',
                      value: profile.graduationYear,
                    ),
                    _ProfileRow(label: 'Şehir', value: profile.city),
                    _ProfileRow(label: 'Meslek', value: profile.profession),
                    _ProfileRow(label: 'Şirket', value: profile.company),
                    _ProfileRow(label: 'Unvan', value: profile.title),
                    _ProfileRow(label: 'Uzmanlık', value: profile.expertise),
                    _ProfileRow(label: 'Web sitesi', value: profile.website),
                    _ProfileRow(label: 'LinkedIn', value: profile.linkedinUrl),
                    _ProfileRow(label: 'Üniversite', value: profile.university),
                    _ProfileRow(
                      label: 'Bölüm',
                      value: profile.universityDepartment,
                    ),
                    _ProfileRow(
                      label: 'Mentorluk konuları',
                      value: profile.mentorTopics,
                    ),
                    _ProfileRow(label: 'İmza', value: profile.signature),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileAccountActionsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () => _openEmailChangeDialog(context, ref),
                          child: Text(l10n.changeEmailAction),
                        ),
                        OutlinedButton(
                          onPressed: () => _openPasswordDialog(context, ref),
                          child: Text(l10n.changePasswordAction),
                        ),
                        FilledButton(
                          onPressed: () async {
                            final message = await ref
                                .read(sessionControllerProvider.notifier)
                                .logout();
                            if (!context.mounted) return;
                            if (message == null) {
                              context.go('/login');
                              return;
                            }
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          },
                          child: Text(l10n.logoutAction),
                        ),
                      ],
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
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Future<void> _openEditProfileDialog(
  BuildContext context,
  WidgetRef ref,
  ProfileData profile,
) async {
  final firstNameController = TextEditingController(text: profile.firstName);
  final lastNameController = TextEditingController(text: profile.lastName);
  final graduationController = TextEditingController(
    text: profile.graduationYear,
  );
  final cityController = TextEditingController(text: profile.city);
  final professionController = TextEditingController(text: profile.profession);
  final websiteController = TextEditingController(text: profile.website);
  final universityController = TextEditingController(text: profile.university);
  final signatureController = TextEditingController(text: profile.signature);
  final companyController = TextEditingController(text: profile.company);
  final titleController = TextEditingController(text: profile.title);
  final expertiseController = TextEditingController(text: profile.expertise);
  final linkedinController = TextEditingController(text: profile.linkedinUrl);
  final departmentController = TextEditingController(
    text: profile.universityDepartment,
  );
  final mentorTopicsController = TextEditingController(
    text: profile.mentorTopics,
  );
  var mentorOptIn = profile.mentorOptIn;
  var kvkkConsent = profile.kvkkConsent;
  var directoryConsent = profile.directoryConsent;
  var emailHidden = profile.emailHidden;

  try {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Profili düzenle'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(firstNameController, 'Ad'),
                  _dialogField(lastNameController, 'Soyad'),
                  _dialogField(graduationController, 'Mezuniyet yılı'),
                  _dialogField(cityController, 'Şehir'),
                  _dialogField(professionController, 'Meslek'),
                  _dialogField(companyController, 'Şirket'),
                  _dialogField(titleController, 'Unvan'),
                  _dialogField(expertiseController, 'Uzmanlık'),
                  _dialogField(websiteController, 'Web sitesi'),
                  _dialogField(linkedinController, 'LinkedIn'),
                  _dialogField(universityController, 'Üniversite'),
                  _dialogField(departmentController, 'Üniversite bölümü'),
                  _dialogField(mentorTopicsController, 'Mentorluk konuları'),
                  _dialogField(signatureController, 'İmza', minLines: 3),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mentor olarak görün'),
                    value: mentorOptIn,
                    onChanged: (value) =>
                        setDialogState(() => mentorOptIn = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('KVKK onayı'),
                    value: kvkkConsent,
                    onChanged: (value) =>
                        setDialogState(() => kvkkConsent = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rehber açık rıza'),
                    value: directoryConsent,
                    onChanged: (value) =>
                        setDialogState(() => directoryConsent = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('E-postayı gizle'),
                    value: emailHidden,
                    onChanged: (value) =>
                        setDialogState(() => emailHidden = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                final nextProfile = profile.copyWith(
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  graduationYear: graduationController.text.trim(),
                  city: cityController.text.trim(),
                  profession: professionController.text.trim(),
                  website: websiteController.text.trim(),
                  university: universityController.text.trim(),
                  signature: signatureController.text.trim(),
                  company: companyController.text.trim(),
                  title: titleController.text.trim(),
                  expertise: expertiseController.text.trim(),
                  linkedinUrl: linkedinController.text.trim(),
                  universityDepartment: departmentController.text.trim(),
                  mentorTopics: mentorTopicsController.text.trim(),
                  mentorOptIn: mentorOptIn,
                  kvkkConsent: kvkkConsent,
                  directoryConsent: directoryConsent,
                  emailHidden: emailHidden,
                );
                final ok = await ref
                    .read(profileActionControllerProvider.notifier)
                    .updateProfile(nextProfile);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                final actionState = ref.read(profileActionControllerProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      actionState.message ??
                          (ok
                              ? 'Profil güncellendi.'
                              : 'Profil güncellenemedi.'),
                    ),
                  ),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  } finally {
    firstNameController.dispose();
    lastNameController.dispose();
    graduationController.dispose();
    cityController.dispose();
    professionController.dispose();
    websiteController.dispose();
    universityController.dispose();
    signatureController.dispose();
    companyController.dispose();
    titleController.dispose();
    expertiseController.dispose();
    linkedinController.dispose();
    departmentController.dispose();
    mentorTopicsController.dispose();
  }
}

Future<void> _openEmailChangeDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('E-posta değiştir'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Yeni e-posta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(profileActionControllerProvider.notifier)
                  .requestEmailChange(controller.text.trim());
              if (!context.mounted) return;
              Navigator.of(context).pop();
              final actionState = ref.read(profileActionControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    actionState.message ??
                        (ok
                            ? 'Doğrulama e-postası gönderildi.'
                            : 'İstek başarısız oldu.'),
                  ),
                ),
              );
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _openPasswordDialog(BuildContext context, WidgetRef ref) async {
  final currentController = TextEditingController();
  final nextController = TextEditingController();
  final repeatController = TextEditingController();
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifre değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(currentController, 'Eski şifre', obscureText: true),
            _dialogField(nextController, 'Yeni şifre', obscureText: true),
            _dialogField(
              repeatController,
              'Yeni şifre tekrar',
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(profileActionControllerProvider.notifier)
                  .changePassword(
                    currentPassword: currentController.text,
                    nextPassword: nextController.text,
                    nextPasswordRepeat: repeatController.text,
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              final actionState = ref.read(profileActionControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    actionState.message ??
                        (ok ? 'Şifre güncellendi.' : 'Şifre güncellenemedi.'),
                  ),
                ),
              );
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  } finally {
    currentController.dispose();
    nextController.dispose();
    repeatController.dispose();
  }
}

Widget _dialogField(
  TextEditingController controller,
  String label, {
  bool obscureText = false,
  int minLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: obscureText ? 1 : (minLines > 1 ? minLines + 2 : 1),
      decoration: InputDecoration(labelText: label),
    ),
  );
}
