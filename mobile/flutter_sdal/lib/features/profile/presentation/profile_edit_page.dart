import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/profile_action_controller.dart';
import '../data/profile_repository.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _expertiseController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _mentorTopicsController = TextEditingController();
  final _signatureController = TextEditingController();

  bool _didSeedForm = false;
  bool _mentorOptIn = false;
  bool _kvkkConsent = false;
  bool _directoryConsent = false;
  bool _emailHidden = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _expertiseController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _mentorTopicsController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profileState = ref.watch(profileProvider);
    final actionState = ref.watch(profileActionControllerProvider);

    return FeatureScaffold(
      title: l10n.profileEditPageTitle,
      background: FeatureScaffoldBackground.neutral,
      child: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const ErrorView(),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.profileMissing));
          }
          _seedForm(profile);
          return _ProfileEditFormLayout(
            form: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.profileEditIdentitySectionTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profileEditIdentitySectionDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                        _ProfileEditField(
                          controller: _firstNameController,
                          label: l10n.profileEditFirstNameLabel,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _requiredValidator(
                            value,
                            l10n.profileEditFirstNameLabel,
                          ),
                        ),
                        _ProfileEditField(
                          controller: _lastNameController,
                          label: l10n.profileEditLastNameLabel,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _requiredValidator(
                            value,
                            l10n.profileEditLastNameLabel,
                          ),
                        ),
                        _GraduationYearRequestTile(
                          graduationYear: profile.graduationYear,
                          onRequestChange: actionState.isLoading
                              ? null
                              : () => context.push(
                                  '/requests?category=graduation_year_change',
                                ),
                        ),
                        _ProfileEditField(
                          controller: _cityController,
                          label: l10n.profileEditCityLabel,
                          textInputAction: TextInputAction.next,
                        ),
                        _ProfileEditField(
                          controller: _professionController,
                          label: l10n.profileEditProfessionLabel,
                          textInputAction: TextInputAction.next,
                        ),
                        _ProfileEditField(
                          controller: _companyController,
                          label: l10n.profileEditCompanyLabel,
                          textInputAction: TextInputAction.next,
                        ),
                        _ProfileEditField(
                          controller: _titleController,
                          label: l10n.profileEditTitleLabel,
                          textInputAction: TextInputAction.next,
                        ),
                        _ProfileEditField(
                          controller: _expertiseController,
                          label: l10n.profileEditExpertiseLabel,
                          textInputAction: TextInputAction.next,
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
                          l10n.profileEditContactSectionTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profileEditContactSectionDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                        _ProfileEditField(
                          controller: _websiteController,
                          label: l10n.profileEditWebsiteLabel,
                          hintText: 'https://example.com',
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          validator: _websiteValidator,
                        ),
                        _ProfileEditField(
                          controller: _linkedinController,
                          label: l10n.profileEditLinkedinLabel,
                          hintText: 'https://linkedin.com/in/...',
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          validator: _linkedinValidator,
                        ),
                        _ProfileEditField(
                          controller: _universityController,
                          label: l10n.profileEditUniversityLabel,
                          textInputAction: TextInputAction.next,
                        ),
                        _ProfileEditField(
                          controller: _departmentController,
                          label: l10n.profileEditDepartmentLabel,
                          textInputAction: TextInputAction.next,
                        ),
                        _ProfileEditField(
                          controller: _mentorTopicsController,
                          label: l10n.profileEditMentorTopicsLabel,
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                        ),
                        _ProfileEditField(
                          controller: _signatureController,
                          label: l10n.profileEditSignatureLabel,
                          minLines: 3,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
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
                          l10n.profileEditPrivacySectionTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profileEditPrivacySectionDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.profileEditMentorVisibleLabel),
                          value: _mentorOptIn,
                          onChanged: actionState.isLoading
                              ? null
                              : (value) => setState(() => _mentorOptIn = value),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.profileEditKvkkConsentLabel),
                          value: _kvkkConsent,
                          onChanged: actionState.isLoading
                              ? null
                              : (value) => _handleLegalConsentToggle(
                                  value: value,
                                  title: l10n.registerKvkkTitle,
                                  path: '/kvkk',
                                  onApproved: () => _kvkkConsent = true,
                                  onRejected: () => _kvkkConsent = false,
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => context.push(
                              '/legal',
                              extra: {
                                'title': l10n.registerKvkkTitle,
                                'path': '/kvkk',
                              },
                            ),
                            child: Text(l10n.registerKvkkTitle),
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.profileEditDirectoryConsentLabel),
                          value: _directoryConsent,
                          onChanged: actionState.isLoading
                              ? null
                              : (value) => _handleLegalConsentToggle(
                                  value: value,
                                  title: l10n.registerDirectoryConsentTitle,
                                  path: '/kvkk/acik-riza',
                                  onApproved: () => _directoryConsent = true,
                                  onRejected: () => _directoryConsent = false,
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => context.push(
                              '/legal',
                              extra: {
                                'title': l10n.registerDirectoryConsentTitle,
                                'path': '/kvkk/acik-riza',
                              },
                            ),
                            child: Text(l10n.registerDirectoryConsentTitle),
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.profileEditHideEmailLabel),
                          value: _emailHidden,
                          onChanged: actionState.isLoading
                              ? null
                              : (value) => setState(() => _emailHidden = value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionState: actionState,
            onSave: () => _submit(profile),
          );
        },
      ),
    );
  }

  void _seedForm(ProfileData profile) {
    if (_didSeedForm) return;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _cityController.text = profile.city;
    _professionController.text = profile.profession;
    _companyController.text = profile.company;
    _titleController.text = profile.title;
    _expertiseController.text = profile.expertise;
    _websiteController.text = profile.website;
    _linkedinController.text = profile.linkedinUrl;
    _universityController.text = profile.university;
    _departmentController.text = profile.universityDepartment;
    _mentorTopicsController.text = profile.mentorTopics;
    _signatureController.text = profile.signature;
    _mentorOptIn = profile.mentorOptIn;
    _kvkkConsent = profile.kvkkConsent;
    _directoryConsent = profile.directoryConsent;
    _emailHidden = profile.emailHidden;
    _didSeedForm = true;
  }

  Future<void> _submit(ProfileData profile) async {
    final l10n = context.l10n;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final nextProfile = profile.copyWith(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      city: _cityController.text.trim(),
      profession: _professionController.text.trim(),
      website: _websiteController.text.trim(),
      university: _universityController.text.trim(),
      signature: _signatureController.text.trim(),
      company: _companyController.text.trim(),
      title: _titleController.text.trim(),
      expertise: _expertiseController.text.trim(),
      linkedinUrl: _linkedinController.text.trim(),
      universityDepartment: _departmentController.text.trim(),
      mentorTopics: _mentorTopicsController.text.trim(),
      mentorOptIn: _mentorOptIn,
      kvkkConsent: _kvkkConsent,
      directoryConsent: _directoryConsent,
      emailHidden: _emailHidden,
    );

    final ok = await ref
        .read(profileActionControllerProvider.notifier)
        .updateProfile(nextProfile);
    if (!mounted) return;

    final actionState = ref.read(profileActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ??
              (ok ? l10n.profileEditSaved : l10n.profileEditSaveFailed),
        ),
      ),
    );
    if (ok) {
      context.pop();
    }
  }

  Future<void> _handleLegalConsentToggle({
    required bool value,
    required String title,
    required String path,
    required VoidCallback onApproved,
    required VoidCallback onRejected,
  }) async {
    if (!value) {
      setState(onRejected);
      return;
    }
    final approved = await context.push<bool>(
      '/legal',
      extra: {'title': title, 'path': path, 'requireAcceptance': true},
    );
    if (!mounted) return;
    setState(approved == true ? onApproved : onRejected);
  }

  String? _requiredValidator(String? value, String label) {
    if ((value ?? '').trim().isNotEmpty) return null;
    return context.l10n.profileEditRequiredField(label);
  }

  String? _websiteValidator(String? value) {
    if (_isBlank(value)) return null;
    return _looksLikeUrl(value) ? null : context.l10n.profileEditWebsiteError;
  }

  String? _linkedinValidator(String? value) {
    if (_isBlank(value)) return null;
    if (!_looksLikeUrl(value)) {
      return context.l10n.profileEditLinkedinError;
    }
    final uri = _parseUrl(value!);
    final host = (uri?.host ?? '').toLowerCase();
    if (host.contains('linkedin.com')) return null;
    return context.l10n.profileEditLinkedinError;
  }

  bool _isBlank(String? value) => (value ?? '').trim().isEmpty;

  bool _looksLikeUrl(String? value) {
    final uri = _parseUrl(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        (uri.host.contains('.') || uri.host == 'localhost');
  }

  Uri? _parseUrl(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    return Uri.tryParse(withScheme);
  }
}

class _GraduationYearRequestTile extends StatelessWidget {
  const _GraduationYearRequestTile({
    required this.graduationYear,
    required this.onRequestChange,
  });

  final String graduationYear;
  final VoidCallback? onRequestChange;

  @override
  Widget build(BuildContext context) {
    final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
    final title = isTurkish ? 'Mezuniyet yılı' : 'Graduation year';
    final value = graduationYear.trim().isEmpty
        ? (isTurkish ? 'Belirtilmemiş' : 'Not set')
        : (_isTeacherGraduationYear(graduationYear)
              ? (isTurkish ? 'Öğretmen' : 'Teacher')
              : graduationYear);
    final helper = isTurkish
        ? 'Bu bilgi yönetim onayıyla değiştirilir.'
        : 'This field changes through admin approval.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: const Icon(Icons.school_outlined),
          title: Text(title),
          subtitle: Text('$value\n$helper'),
          trailing: TextButton.icon(
            onPressed: onRequestChange,
            icon: const Icon(Icons.assignment_outlined),
            label: Text(isTurkish ? 'Talep aç' : 'Request'),
          ),
        ),
      ),
    );
  }
}

bool _isTeacherGraduationYear(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == '9999' ||
      normalized == 'teacher' ||
      normalized == 'ogretmen' ||
      normalized == 'öğretmen';
}

class _ProfileEditFormLayout extends StatelessWidget {
  const _ProfileEditFormLayout({
    required this.form,
    required this.actionState,
    required this.onSave,
  });

  final Widget form;
  final AsyncActionState actionState;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    return Column(
      children: [
        Expanded(child: form),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.viewInsetsOf(context).bottom > 0
                ? MediaQuery.viewInsetsOf(context).bottom + 16
                : 20,
          ),
          decoration: BoxDecoration(
            color: tokens.canvas.withValues(alpha: 0.96),
            border: Border(top: BorderSide(color: tokens.panelBorder)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: actionState.isLoading ? null : onSave,
                icon: actionState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  actionState.isLoading
                      ? l10n.profileEditSaveInProgress
                      : l10n.saveAction,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileEditField extends StatelessWidget {
  const _ProfileEditField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hintText),
      ),
    );
  }
}
