import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_models.dart';
import '../../../core/state/async_action_state.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/profile_action_controller.dart';
import '../data/profile_repository.dart';

const String _teacherGraduationYearValue = '9999';

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
  int _currentEditStep = 0;

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
                  _ProfileEditStepHeader(
                    currentStep: _currentEditStep,
                    totalSteps: 5,
                    title: _editStepTitle(_currentEditStep, l10n),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: _buildEditStep(
                      context,
                      profile: profile,
                      actionState: actionState,
                    ),
                  ),
                ],
              ),
            ),
            actionState: actionState,
            isFirstStep: _currentEditStep == 0,
            isLastStep: _currentEditStep == 4,
            onBack: () => setState(() => _currentEditStep -= 1),
            onNext: _goToNextEditStep,
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

  String _editStepTitle(int step, AppLocalizations l10n) => switch (step) {
    0 => l10n.profileEditIdentitySectionTitle,
    1 => 'İş ve uzmanlık',
    2 => 'Eğitim ve bağlantılar',
    3 => 'Mentorluk ve profil notu',
    _ => l10n.profileEditPrivacySectionTitle,
  };

  Widget _buildEditStep(
    BuildContext context, {
    required ProfileData profile,
    required AsyncActionState actionState,
  }) {
    final l10n = context.l10n;
    return switch (_currentEditStep) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileEditInfo(
            text:
                'Ad, soyad, şehir ve mezuniyet dönemi seni doğru kişilere bağlamak için kullanılır. Mezuniyet yılı sonradan yönetim onayıyla değişir.',
          ),
          const SizedBox(height: 18),
          _ProfileEditField(
            controller: _firstNameController,
            label: l10n.profileEditFirstNameLabel,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            validator: (value) =>
                _requiredValidator(value, l10n.profileEditFirstNameLabel),
          ),
          _ProfileEditField(
            controller: _lastNameController,
            label: l10n.profileEditLastNameLabel,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            validator: (value) =>
                _requiredValidator(value, l10n.profileEditLastNameLabel),
          ),
          _GraduationYearRequestTile(
            graduationYear: profile.graduationYear,
            onRequestChange: actionState.isLoading
                ? null
                : () =>
                      context.push('/requests?category=graduation_year_change'),
          ),
          _ProfileEditField(
            controller: _cityController,
            label: l10n.profileEditCityLabel,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.addressCity],
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileEditInfo(
            text:
                'Meslek, şirket, unvan ve uzmanlık bilgileri; mentorluk, iş fırsatları ve dönem arkadaşlarının seni doğru bağlamda tanıması için kullanılır.',
          ),
          const SizedBox(height: 18),
          _ProfileEditField(
            controller: _professionController,
            label: l10n.profileEditProfessionLabel,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          _ProfileEditField(
            controller: _companyController,
            label: l10n.profileEditCompanyLabel,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          _ProfileEditField(
            controller: _titleController,
            label: l10n.profileEditTitleLabel,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          _ProfileEditField(
            controller: _expertiseController,
            label: l10n.profileEditExpertiseLabel,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileEditInfo(
            text:
                'Web sitesi, LinkedIn ve eğitim bilgileri profiline bakanların geçmişini daha hızlı anlamasını ve sana doğru kanaldan ulaşmasını sağlar. Link alanları profilinde buton olarak gösterilir.',
          ),
          const SizedBox(height: 18),
          _ProfileEditField(
            controller: _websiteController,
            label: l10n.profileEditWebsiteLabel,
            hintText: 'https://example.com',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.url],
            validator: _websiteValidator,
          ),
          _ProfileEditField(
            controller: _linkedinController,
            label: l10n.profileEditLinkedinLabel,
            hintText: 'https://www.linkedin.com/in/kullanici-adi',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.url],
            validator: _linkedinValidator,
          ),
          _ProfileEditField(
            controller: _universityController,
            label: l10n.profileEditUniversityLabel,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          _ProfileEditField(
            controller: _departmentController,
            label: l10n.profileEditDepartmentLabel,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      3 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileEditInfo(
            text:
                'Mentorluk konuları ve kısa profil notu, diğer mezunların hangi konuda sana danışabileceğini ve seni nasıl tanıyacağını gösterir.',
          ),
          const SizedBox(height: 18),
          _ProfileEditField(
            controller: _mentorTopicsController,
            label: l10n.profileEditMentorTopicsLabel,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
          ),
          _ProfileEditField(
            controller: _signatureController,
            label: l10n.profileEditSignatureLabel,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.profileEditMentorVisibleLabel),
            subtitle: const Text(
              'Açık olduğunda mentorluk arayan üyeler profilini bu bağlamda görebilir.',
            ),
            value: _mentorOptIn,
            onChanged: actionState.isLoading
                ? null
                : (value) => setState(() => _mentorOptIn = value),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileEditInfo(text: l10n.profileEditPrivacySectionDescription),
          const SizedBox(height: 12),
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
          TextButton(
            onPressed: () => context.push(
              '/legal',
              extra: {'title': l10n.registerKvkkTitle, 'path': '/kvkk'},
            ),
            child: Text(l10n.registerKvkkTitle),
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
          TextButton(
            onPressed: () => context.push(
              '/legal',
              extra: {
                'title': l10n.registerDirectoryConsentTitle,
                'path': '/kvkk/acik-riza',
              },
            ),
            child: Text(l10n.registerDirectoryConsentTitle),
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
    };
  }

  void _goToNextEditStep() {
    if (_currentEditStep == 0) {
      final valid =
          _requiredValidator(
                _firstNameController.text,
                context.l10n.profileEditFirstNameLabel,
              ) ==
              null &&
          _requiredValidator(
                _lastNameController.text,
                context.l10n.profileEditLastNameLabel,
              ) ==
              null;
      if (!valid) {
        _formKey.currentState?.validate();
        return;
      }
    }
    if (_currentEditStep == 2) {
      final valid =
          _websiteValidator(_websiteController.text) == null &&
          _linkedinValidator(_linkedinController.text) == null;
      if (!valid) {
        _formKey.currentState?.validate();
        return;
      }
    }
    setState(() => _currentEditStep += 1);
  }

  Future<void> _submit(ProfileData profile) async {
    final l10n = context.l10n;
    if (_requiredValidator(
              _firstNameController.text,
              l10n.profileEditFirstNameLabel,
            ) !=
            null ||
        _requiredValidator(
              _lastNameController.text,
              l10n.profileEditLastNameLabel,
            ) !=
            null) {
      _showEditStepValidation(0);
      return;
    }
    if (_websiteValidator(_websiteController.text) != null ||
        _linkedinValidator(_linkedinController.text) != null) {
      _showEditStepValidation(2);
      return;
    }
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

  void _showEditStepValidation(int step) {
    setState(() => _currentEditStep = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _formKey.currentState?.validate();
    });
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

class GraduationYearOnboardingPage extends ConsumerStatefulWidget {
  const GraduationYearOnboardingPage({super.key});

  @override
  ConsumerState<GraduationYearOnboardingPage> createState() =>
      _GraduationYearOnboardingPageState();
}

class _GraduationYearOnboardingPageState
    extends ConsumerState<GraduationYearOnboardingPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordRepeatController = TextEditingController();
  String _selectedYear = '${DateTime.now().year}';
  int _currentStep = 0;
  bool _kvkkConsent = false;
  bool _directoryConsent = false;
  String? _localError;
  String? _usernameMessage;
  String? _usernameError;
  bool _checkingUsername = false;
  bool _didSeedUsername = false;
  Timer? _usernameDebounce;
  int _usernameRequestId = 0;

  bool get _isTeacher => _selectedYear == _teacherGraduationYearValue;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_scheduleUsernameCheck);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final usernameError = _usernameValidationError();
    if (usernameError != null || _usernameError != null) {
      setState(() {
        _localError = usernameError ?? _usernameError;
        _currentStep = 0;
      });
      return;
    }
    final passwordError = _passwordError();
    if (passwordError != null) {
      setState(() {
        _localError = passwordError;
        _currentStep = 1;
      });
      return;
    }
    if (!_kvkkConsent || !_directoryConsent) {
      setState(() {
        _localError = 'KVKK ve Mezun Rehberi onaylarını tamamlayın.';
        _currentStep = 2;
      });
      return;
    }
    final ok = await ref
        .read(profileActionControllerProvider.notifier)
        .claimGraduationYear(
          username: _usernameController.text.trim(),
          graduationYear: _selectedYear,
          password: _passwordController.text,
          passwordRepeat: _passwordRepeatController.text,
          kvkkConsent: _kvkkConsent,
          directoryConsent: _directoryConsent,
        );
    if (!mounted) return;
    final state = ref.read(profileActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Mezuniyet yılı kaydedildi.' : 'İşlem tamamlanamadı.'),
        ),
      ),
    );
    if (!ok) return;
    await ref.read(sessionControllerProvider.notifier).refreshSilently();
    if (!mounted) return;
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(profileActionControllerProvider);
    final session = ref.watch(sessionControllerProvider).value;
    _seedUsername(session?.user);
    final submitting =
        actionState.isLoading &&
        actionState.scope == 'profile:graduation-claim';
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return FeatureScaffold(
      title: 'İlk kayıt beyanı',
      background: FeatureScaffoldBackground.neutral,
      showAppMenu: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.school_outlined, color: tokens.accent, size: 32),
                const SizedBox(height: 12),
                Text(_stepTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 18),
                _buildStep(context, submitting: submitting),
                if (_localError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _localError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (actionState.isError &&
                    actionState.scope == 'profile:graduation-claim') ...[
                  const SizedBox(height: 12),
                  Text(
                    actionState.message ?? 'İşlem tamamlanamadı.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: submitting
                              ? null
                              : () => setState(() {
                                  _localError = null;
                                  _currentStep -= 1;
                                }),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Geri'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: submitting ? null : _handlePrimaryAction,
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _currentStep == 2
                                    ? Icons.check_circle_outline
                                    : Icons.chevron_right,
                              ),
                        label: Text(
                          submitting
                              ? 'Kaydediliyor...'
                              : (_currentStep == 2
                                    ? 'Beyanımı kaydet'
                                    : 'Devam'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle => switch (_currentStep) {
    0 => 'Kullanıcı adı ve dönem',
    1 => 'Şifreni belirle',
    _ => 'Onayları tamamla',
  };

  Widget _buildStep(BuildContext context, {required bool submitting}) {
    final theme = Theme.of(context);
    return switch (_currentStep) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTeacher
                ? 'Öğretmen seçimi, öğretmen ağı ve öğretmen doğrulaması için kullanılacak. Okul veya öğretmenlik bağını gösteren doğrulama daha sonra ayrı değerlendirilecek.'
                : 'Bu seçim, kendi dönemindeki arkadaşlarına ve yakın mezuniyet yıllarındaki SDAL üyelerine daha doğru ulaşman için kullanılacak. Lütfen dikkatli seç; sonradan değişiklik yönetim onayıyla yapılır.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _usernameController,
            enabled: !submitting,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              labelText: 'Kullanıcı adı',
              helperText:
                  'En fazla 15 karakter. Girişte ve profil bağlantında kullanılır.',
              prefixText: '@',
              suffixIcon: _checkingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          if (_usernameMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _usernameMessage!,
              style: TextStyle(color: theme.sdal.success),
            ),
          ],
          if (_usernameError != null) ...[
            const SizedBox(height: 8),
            Text(
              _usernameError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 10),
          _SuggestedUsernameStrip(
            suggestion: _suggestedUsername,
            onUse: submitting
                ? null
                : () {
                    _usernameController.text = _suggestedUsername;
                    _usernameController.selection = TextSelection.collapsed(
                      offset: _usernameController.text.length,
                    );
                  },
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(
              labelText: 'Mezuniyet yılı veya öğretmen',
            ),
            items: _profileGraduationYearOptions()
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      _formatProfileGraduationYearOption(context, value),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: submitting
                ? null
                : (value) => setState(() {
                    _selectedYear = value ?? _selectedYear;
                  }),
          ),
          const SizedBox(height: 14),
          _OnboardingInfoStrip(
            icon: _isTeacher ? Icons.badge_outlined : Icons.groups_2_outlined,
            text: _isTeacher
                ? 'Öğretmen profilleri mezun dönemlerinden ayrı görünür; doğrulama talebinde okul/öğretmenlik bağını anlatman beklenir.'
                : 'Dönem seçimi; keşif, öneriler, albümler ve sosyal bağlarda doğru kişilerin öne çıkmasına yardımcı olur.',
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OnboardingInfoStrip(
            icon: Icons.lock_outline,
            text:
                'OAuth ile kayıt olsan bile daha sonra kullanıcı adı/e-posta ve şifreyle de giriş yapabilmen için burada bir şifre belirle.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            keyboardType: TextInputType.visiblePassword,
            decoration: const InputDecoration(labelText: 'Şifre'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordRepeatController,
            obscureText: true,
            keyboardType: TextInputType.visiblePassword,
            decoration: const InputDecoration(labelText: 'Şifre tekrar'),
          ),
          const SizedBox(height: 10),
          _OnboardingPasswordHint(password: _passwordController.text),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OnboardingInfoStrip(
            icon: Icons.privacy_tip_outlined,
            text:
                'KVKK ve Mezun Rehberi açık rıza onayları, sosyal üyeliğinin tamamlanması ve mezun ağında doğru görünmen için gereklidir.',
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _kvkkConsent,
            onChanged: submitting
                ? null
                : (value) => _handleLegalConsentToggle(
                    value: value ?? false,
                    title: context.l10n.registerKvkkTitle,
                    path: '/kvkk',
                    onApproved: () => _kvkkConsent = true,
                    onRejected: () => _kvkkConsent = false,
                  ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.l10n.registerKvkkConsentLabel),
          ),
          CheckboxListTile(
            value: _directoryConsent,
            onChanged: submitting
                ? null
                : (value) => _handleLegalConsentToggle(
                    value: value ?? false,
                    title: context.l10n.registerDirectoryConsentTitle,
                    path: '/kvkk/acik-riza',
                    onApproved: () => _directoryConsent = true,
                    onRejected: () => _directoryConsent = false,
                  ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.l10n.registerDirectoryConsentLabel),
          ),
        ],
      ),
    };
  }

  void _handlePrimaryAction() {
    if (_currentStep == 0) {
      final error = _usernameValidationError();
      if (error != null || _usernameError != null || _checkingUsername) {
        setState(() {
          _localError = _checkingUsername
              ? 'Kullanıcı adı kontrolünün tamamlanmasını bekleyin.'
              : (error ?? _usernameError);
        });
        return;
      }
      setState(() {
        _localError = null;
        _currentStep = 1;
      });
      return;
    }
    if (_currentStep == 1) {
      final error = _passwordError();
      if (error != null) {
        setState(() => _localError = error);
        return;
      }
      setState(() {
        _localError = null;
        _currentStep = 2;
      });
      return;
    }
    _submit();
  }

  void _seedUsername(SessionUser? user) {
    if (_didSeedUsername) return;
    final current = (user?.kadi ?? '').trim();
    _usernameController.text = _looksGeneratedOAuthUsername(current)
        ? _suggestUsernameFromName(user?.isim ?? '', user?.soyisim ?? '')
        : current;
    _didSeedUsername = true;
  }

  String get _suggestedUsername {
    final user = ref.read(sessionControllerProvider).value?.user;
    return _suggestUsernameFromName(user?.isim ?? '', user?.soyisim ?? '');
  }

  bool _looksGeneratedOAuthUsername(String value) {
    final normalized = value.toLowerCase();
    return normalized.isEmpty ||
        normalized.startsWith('google_') ||
        normalized.startsWith('apple_') ||
        normalized.startsWith('x_') ||
        normalized.startsWith('oauth_');
  }

  String _suggestUsernameFromName(String firstName, String lastName) {
    final source = '${firstName.trim()} ${lastName.trim()}'.trim();
    final normalized = _normalizeUsernameSource(source);
    if (normalized.isNotEmpty) return _limitUsername(normalized);
    final current = _normalizeUsernameSource(_usernameController.text);
    if (current.isNotEmpty) return _limitUsername(current);
    return 'sdaluye';
  }

  String _limitUsername(String value) {
    if (value.length <= 15) return value;
    return value.substring(0, 15);
  }

  String _normalizeUsernameSource(String value) {
    final lower = value.trim().toLowerCase();
    final transliterated = lower
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
    return transliterated.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  void _scheduleUsernameCheck() {
    _usernameDebounce?.cancel();
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameMessage = null;
        _usernameError = null;
      });
      return;
    }
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      _runUsernameCheck,
    );
  }

  Future<void> _runUsernameCheck() async {
    final localError = _usernameValidationError();
    if (localError != null) {
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameMessage = null;
        _usernameError = localError;
      });
      return;
    }
    final username = _usernameController.text.trim();
    final requestId = ++_usernameRequestId;
    setState(() {
      _checkingUsername = true;
      _usernameError = null;
      _usernameMessage = null;
    });
    final result = await ref
        .read(profileRepositoryProvider)
        .checkUsername(username);
    if (!mounted || requestId != _usernameRequestId) return;
    if (!result.ok) {
      setState(() {
        _checkingUsername = false;
        _usernameMessage = null;
        _usernameError = result.message.isNotEmpty
            ? result.message
            : 'Kullanıcı adı kontrol edilemedi.';
      });
      return;
    }
    final exists = asBool(asJsonMap(result.rawData)['kadiExists']) ?? false;
    setState(() {
      _checkingUsername = false;
      _usernameMessage = exists ? null : 'Bu kullanıcı adı uygun görünüyor.';
      _usernameError = exists ? 'Bu kullanıcı adı zaten kayıtlı.' : null;
    });
  }

  String? _usernameValidationError() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return 'Kullanıcı adı belirlemeniz gerekiyor.';
    if (username.length > 15) {
      return 'Kullanıcı adı 15 karakterden fazla olmamalıdır.';
    }
    return null;
  }

  String? _passwordError() {
    final password = _passwordController.text;
    if (password.isEmpty) return 'Şifre belirlemeniz gerekiyor.';
    if (password.length > 20) return 'Şifre 20 karakterden fazla olmamalıdır.';
    if (password != _passwordRepeatController.text) {
      return 'Girdiğiniz şifreler birbirleriyle uyuşmuyor.';
    }
    return null;
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
}

class _SuggestedUsernameStrip extends StatelessWidget {
  const _SuggestedUsernameStrip({
    required this.suggestion,
    required this.onUse,
  });

  final String suggestion;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.accentMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: tokens.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Önerilen kullanıcı adı: @$suggestion',
                style: TextStyle(
                  color: tokens.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onUse, child: const Text('Kullan')),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPasswordHint extends StatelessWidget {
  const _OnboardingPasswordHint({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final score = [
      password.length >= 8,
      RegExp(r'[A-Z]').hasMatch(password) &&
          RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'\d').hasMatch(password),
      RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    ].where((item) => item).length;
    final value = password.isEmpty ? 0.0 : (score / 4).clamp(0.2, 1.0);
    final color = score >= 3
        ? tokens.success
        : (score >= 2 ? tokens.warning : tokens.danger);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: value,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            const Text('8+ karakter, harf, sayı ve sembol kullanman önerilir.'),
          ],
        ),
      ),
    );
  }
}

class _OnboardingInfoStrip extends StatelessWidget {
  const _OnboardingInfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.infoMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tokens.info),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
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

List<String> _profileGraduationYearOptions() => <String>[
  _teacherGraduationYearValue,
  for (var year = DateTime.now().year; year >= 1999; year--) '$year',
];

String _formatProfileGraduationYearOption(BuildContext context, String value) {
  return _isTeacherGraduationYear(value)
      ? (Localizations.localeOf(context).languageCode == 'tr'
            ? 'Öğretmen'
            : 'Teacher')
      : value;
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
    required this.isFirstStep,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
    required this.onSave,
  });

  final Widget form;
  final AsyncActionState actionState;
  final bool isFirstStep;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
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
            child: Row(
              children: [
                if (!isFirstStep) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: actionState.isLoading ? null : onBack,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Geri'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: actionState.isLoading
                        ? null
                        : (isLastStep ? onSave : onNext),
                    icon: actionState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isLastStep
                                ? Icons.save_outlined
                                : Icons.chevron_right,
                          ),
                    label: Text(
                      actionState.isLoading
                          ? l10n.profileEditSaveInProgress
                          : (isLastStep ? l10n.saveAction : 'Devam'),
                    ),
                  ),
                ),
              ],
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
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
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
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        validator: validator,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hintText),
      ),
    );
  }
}

class _ProfileEditStepHeader extends StatelessWidget {
  const _ProfileEditStepHeader({
    required this.currentStep,
    required this.totalSteps,
    required this.title,
  });

  final int currentStep;
  final int totalSteps;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${currentStep + 1}/$totalSteps',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (currentStep + 1) / totalSteps,
          minHeight: 6,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _ProfileEditInfo extends StatelessWidget {
  const _ProfileEditInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: tokens.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
