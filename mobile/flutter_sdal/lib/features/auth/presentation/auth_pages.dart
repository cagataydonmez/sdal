import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/sdal_logo_badge.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_action_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    final actionState = ref.read(authActionControllerProvider);
    if (!actionState.isSuccess) return;
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext(shouldSave: true);
  }

  Future<void> _startOAuth(String provider) async {
    await ref.read(authActionControllerProvider.notifier).startOAuth(provider);
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final l10n = context.l10n;
    final submitting =
        actionState.isLoading &&
        (actionState.scope == 'login' || actionState.scope == 'oauth');
    final error = actionState.isError ? actionState.message : null;

    return _AuthFrame(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      showAppBar: false,
      footer: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push('/register'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(l10n.register),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/activation/resend'),
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: Text(l10n.resendActivation),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/password-reset'),
            icon: const Icon(Icons.lock_reset_rounded),
            label: Text(l10n.resetPassword),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthTextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              labelText: l10n.username,
              prefixIcon: const Icon(Icons.person_outline_rounded),
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 12),
            _AuthTextField(
              controller: _passwordController,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              labelText: l10n.password,
              prefixIcon: const Icon(Icons.lock_outline),
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: submitting ? null : _submit,
              child: Text(submitting ? l10n.loginInProgress : l10n.loginAction),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: submitting ? null : () => _startOAuth('google'),
              icon: const _OAuthProviderLogo(provider: _OAuthProvider.google),
              label: Text(l10n.continueWithGoogle),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: submitting ? null : () => _startOAuth('x'),
              icon: const _OAuthProviderLogo(provider: _OAuthProvider.x),
              label: Text(l10n.continueWithX),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.obscureText = false,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
    this.autofillHints,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final Widget? prefixIcon;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      validator: validator,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      decoration: InputDecoration(labelText: labelText, prefixIcon: prefixIcon),
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _identitySectionKey = GlobalKey();
  final _passwordSectionKey = GlobalKey();
  final _consentSectionKey = GlobalKey();
  final _captchaSectionKey = GlobalKey();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _yearController = TextEditingController(text: '2011');
  final _captchaController = TextEditingController();
  String? _captchaSvg;
  bool _captchaLoading = false;
  String? _captchaLoadError;
  Timer? _availabilityDebounce;
  int _availabilityRequestId = 0;
  bool _checkingAvailability = false;
  String? _availabilityMessage;
  String? _availabilityError;
  String? _previewError;
  bool _kvkkConsent = false;
  bool _directoryConsent = false;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
    _usernameController.addListener(_scheduleAvailabilityCheck);
    _emailController.addListener(_scheduleAvailabilityCheck);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _yearController.dispose();
    _captchaController.dispose();
    _availabilityDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    if (mounted) {
      setState(() {
        _captchaLoading = true;
        _captchaLoadError = null;
        _captchaSvg = null;
      });
    }
    final result = await ref
        .read(apiClientProvider)
        .get<String>('/api/captcha');
    if (!mounted) return;
    setState(() {
      _captchaLoading = false;
      _captchaSvg = result.rawData is String ? result.rawData as String : null;
      if (_captchaSvg == null || _captchaSvg!.trim().isEmpty) {
        _captchaSvg = null;
        _captchaLoadError = result.message.isNotEmpty ? result.message : '';
      }
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _previewError = null;
    });

    if (!_validateBeforeSubmit(l10n)) {
      await _scrollToFirstClientError();
      return;
    }

    final preview = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/register/preview',
          body: {
            'kadi': _usernameController.text.trim(),
            'sifre': _passwordController.text,
            'sifre2': _repeatPasswordController.text,
            'email': _emailController.text.trim(),
            'isim': _firstNameController.text.trim(),
            'soyisim': _lastNameController.text.trim(),
            'mezuniyetyili': _yearController.text.trim(),
            'gkodu': _captchaController.text.trim(),
            'kvkk_consent': _kvkkConsent,
            'directory_consent': _directoryConsent,
          },
          decoder: asJsonMap,
        );
    if (!mounted) return;

    if (!preview.ok) {
      setState(() {
        _previewError = preview.message.isNotEmpty
            ? preview.message
            : l10n.registerPreviewFailed;
      });
      await _loadCaptcha();
      await _scrollToServerError(_previewError);
      return;
    }

    await ref
        .read(authActionControllerProvider.notifier)
        .register(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          repeatPassword: _repeatPasswordController.text,
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          graduationYear: _yearController.text.trim(),
          captcha: _captchaController.text.trim(),
          kvkkConsent: _kvkkConsent,
          directoryConsent: _directoryConsent,
        );
    if (!mounted) return;
    await _loadCaptcha();
    final actionState = ref.read(authActionControllerProvider);
    if (actionState.isError) {
      await _scrollToServerError(actionState.message);
    }
  }

  void _scheduleAvailabilityCheck() {
    _availabilityDebounce?.cancel();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    if (username.isEmpty && email.isEmpty) {
      if (!mounted) return;
      setState(() {
        _checkingAvailability = false;
        _availabilityMessage = null;
        _availabilityError = null;
      });
      return;
    }
    _availabilityDebounce = Timer(
      const Duration(milliseconds: 450),
      _runAvailabilityCheck,
    );
  }

  Future<void> _runAvailabilityCheck() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    if (username.isEmpty && email.isEmpty) return;

    final requestId = ++_availabilityRequestId;
    if (mounted) {
      setState(() {
        _checkingAvailability = true;
        _availabilityError = null;
      });
    }

    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/register/check',
          body: {
            if (username.isNotEmpty) 'kadi': username,
            if (email.isNotEmpty) 'email': email,
          },
          decoder: asJsonMap,
        );
    if (!mounted || requestId != _availabilityRequestId) return;

    if (!result.ok) {
      setState(() {
        _checkingAvailability = false;
        _availabilityMessage = null;
        _availabilityError = result.message.isNotEmpty
            ? result.message
            : context.l10n.registerAvailabilityCheckFailed;
      });
      return;
    }

    final payload = asJsonMap(result.rawData);
    final usernameExists = asBool(payload['kadiExists']) ?? false;
    final emailExists = asBool(payload['emailExists']) ?? false;
    final parts = <String>[];
    if (username.isNotEmpty) {
      parts.add(
        usernameExists
            ? context.l10n.registerUsernameTaken
            : context.l10n.registerUsernameAvailable,
      );
    }
    if (email.isNotEmpty) {
      parts.add(
        emailExists
            ? context.l10n.registerEmailTaken
            : context.l10n.registerEmailAvailable,
      );
    }
    setState(() {
      _checkingAvailability = false;
      _availabilityError = usernameExists || emailExists
          ? parts.join(' ')
          : null;
      _availabilityMessage = usernameExists || emailExists
          ? null
          : parts.join(' ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final l10n = context.l10n;
    final submitting = actionState.isLoading && actionState.scope == 'register';
    final status = actionState.scope == 'register' ? actionState.message : null;
    final statusText = _previewError ?? status;
    final isSuccessState = _previewError == null && actionState.isSuccess;
    final passwordStrength = _passwordStrength(_passwordController.text);

    return _AuthFrame(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(
              key: _identitySectionKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _twoColumn(
                    _AuthTextField(
                      controller: _firstNameController,
                      labelText: l10n.firstName,
                      validator: (value) => _requiredValidator(
                        value,
                        l10n.firstName,
                        maxLength: 20,
                      ),
                    ),
                    _AuthTextField(
                      controller: _lastNameController,
                      labelText: l10n.lastName,
                      validator: (value) => _requiredValidator(
                        value,
                        l10n.lastName,
                        maxLength: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AuthTextField(
                    controller: _usernameController,
                    labelText: l10n.username,
                    validator: (value) =>
                        _requiredValidator(value, l10n.username, maxLength: 15),
                  ),
                  const SizedBox(height: 12),
                  _AuthTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    labelText: l10n.email,
                    validator: _emailValidator,
                  ),
                  if (_checkingAvailability) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (_availabilityMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _availabilityMessage!,
                      style: TextStyle(color: Theme.of(context).sdal.success),
                    ),
                  ],
                  if (_availabilityError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _availabilityError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _passwordSectionKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _twoColumn(
                    _AuthTextField(
                      controller: _passwordController,
                      obscureText: true,
                      keyboardType: TextInputType.visiblePassword,
                      labelText: l10n.password,
                      validator: _passwordValidator,
                    ),
                    _AuthTextField(
                      controller: _repeatPasswordController,
                      obscureText: true,
                      keyboardType: TextInputType.visiblePassword,
                      labelText: l10n.passwordRepeat,
                      validator: _repeatPasswordValidator,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PasswordStrengthCard(strength: passwordStrength),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AuthTextField(
              controller: _yearController,
              keyboardType: TextInputType.text,
              labelText: l10n.graduationYear,
              validator: _graduationYearValidator,
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _consentSectionKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _kvkkConsent,
                    onChanged: submitting
                        ? null
                        : (value) =>
                              setState(() => _kvkkConsent = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.registerKvkkConsentLabel),
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
                      child: Text(l10n.registerKvkkOpenAction),
                    ),
                  ),
                  CheckboxListTile(
                    value: _directoryConsent,
                    onChanged: submitting
                        ? null
                        : (value) => setState(
                            () => _directoryConsent = value ?? false,
                          ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.registerDirectoryConsentLabel),
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
                      child: Text(l10n.registerDirectoryConsentOpenAction),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _captchaSectionKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_captchaLoading)
                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.registerCaptchaLoading,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (_captchaSvg != null)
                    SurfaceCard(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.string(_captchaSvg!, height: 56),
                    )
                  else
                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Theme.of(context).sdal.foregroundMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (_captchaLoadError?.isNotEmpty ?? false)
                                ? _captchaLoadError!
                                : l10n.registerCaptchaUnavailable,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: submitting ? null : _loadCaptcha,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.registerCaptchaRetryAction),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _AuthTextField(
                    controller: _captchaController,
                    keyboardType: TextInputType.number,
                    labelText: l10n.captchaCode,
                    validator: _captchaValidator,
                  ),
                ],
              ),
            ),
            if (statusText != null) ...[
              const SizedBox(height: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: isSuccessState
                      ? Theme.of(context).sdal.success
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: submitting ? null : _submit,
              child: Text(
                submitting ? l10n.submitInProgress : l10n.registerSubmitAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateBeforeSubmit(AppLocalizations l10n) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return false;
    }
    if (!_kvkkConsent) {
      setState(() {
        _previewError = l10n.registerKvkkConsentError;
      });
      return false;
    }
    if (!_directoryConsent) {
      setState(() {
        _previewError = l10n.registerDirectoryConsentError;
      });
      return false;
    }
    if (_captchaLoading) {
      setState(() {
        _previewError = l10n.registerCaptchaLoading;
      });
      return false;
    }
    if (_captchaSvg == null) {
      setState(() {
        _previewError = l10n.registerCaptchaUnavailable;
      });
      return false;
    }
    return true;
  }

  Future<void> _scrollToFirstClientError() async {
    if (!_isIdentitySectionValid()) {
      await _scrollToKey(_identitySectionKey);
      return;
    }
    if (!_isPasswordSectionValid()) {
      await _scrollToKey(_passwordSectionKey);
      return;
    }
    if (!_isConsentSectionValid()) {
      await _scrollToKey(_consentSectionKey);
      return;
    }
    await _scrollToKey(_captchaSectionKey);
  }

  Future<void> _scrollToServerError(String? message) async {
    final lower = (message ?? '').toLowerCase();
    if (lower.contains('captcha') || lower.contains('güvenlik')) {
      await _scrollToKey(_captchaSectionKey);
      return;
    }
    if (lower.contains('şifre') || lower.contains('password')) {
      await _scrollToKey(_passwordSectionKey);
      return;
    }
    if (lower.contains('kvkk') ||
        lower.contains('rıza') ||
        lower.contains('rehberi')) {
      await _scrollToKey(_consentSectionKey);
      return;
    }
    await _scrollToKey(_identitySectionKey);
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  bool _isIdentitySectionValid() {
    return _requiredValidator(
              _firstNameController.text,
              context.l10n.firstName,
              maxLength: 20,
            ) ==
            null &&
        _requiredValidator(
              _lastNameController.text,
              context.l10n.lastName,
              maxLength: 20,
            ) ==
            null &&
        _requiredValidator(
              _usernameController.text,
              context.l10n.username,
              maxLength: 15,
            ) ==
            null &&
        _emailValidator(_emailController.text) == null &&
        _graduationYearValidator(_yearController.text) == null;
  }

  bool _isPasswordSectionValid() {
    return _passwordValidator(_passwordController.text) == null &&
        _repeatPasswordValidator(_repeatPasswordController.text) == null;
  }

  bool _isConsentSectionValid() => _kvkkConsent && _directoryConsent;

  String? _requiredValidator(String? value, String label, {int? maxLength}) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return context.l10n.registerFieldRequired(label);
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return context.l10n.registerFieldTooLong(label, maxLength);
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return context.l10n.registerFieldRequired(context.l10n.email);
    }
    final looksValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
    if (!looksValid) {
      return context.l10n.registerEmailInvalid;
    }
    if (trimmed.length > 50) {
      return context.l10n.registerFieldTooLong(context.l10n.email, 50);
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return context.l10n.registerFieldRequired(context.l10n.password);
    }
    if (raw.length > 20) {
      return context.l10n.registerFieldTooLong(context.l10n.password, 20);
    }
    return null;
  }

  String? _repeatPasswordValidator(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return context.l10n.registerFieldRequired(context.l10n.passwordRepeat);
    }
    if (raw != _passwordController.text) {
      return context.l10n.registerPasswordMismatch;
    }
    return null;
  }

  String? _graduationYearValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return context.l10n.registerGraduationYearInvalid;
    }
    final normalized = trimmed.toLowerCase();
    if (normalized == 'teacher' ||
        normalized == 'öğretmen' ||
        normalized == 'ogretmen') {
      return null;
    }
    final year = int.tryParse(trimmed);
    final currentYear = DateTime.now().year;
    if (year == null || year < 1999 || year > currentYear) {
      return context.l10n.registerGraduationYearInvalid;
    }
    return null;
  }

  String? _captchaValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return context.l10n.registerCaptchaCodeRequired;
    }
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return context.l10n.registerCaptchaDigitsOnly;
    }
    return null;
  }
}

enum _RegisterPasswordStrength { none, weak, medium, strong }

_RegisterPasswordStrength _passwordStrength(String value) {
  if (value.isEmpty) return _RegisterPasswordStrength.none;
  var score = 0;
  if (value.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(value)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
  if (value.length >= 12) score++;
  if (score <= 1) return _RegisterPasswordStrength.weak;
  if (score <= 3) return _RegisterPasswordStrength.medium;
  return _RegisterPasswordStrength.strong;
}

class _PasswordStrengthCard extends StatelessWidget {
  const _PasswordStrengthCard({required this.strength});

  final _RegisterPasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final (label, color, value) = switch (strength) {
      _RegisterPasswordStrength.none => (
        l10n.registerPasswordStrengthNone,
        tokens.foregroundMuted,
        0.0,
      ),
      _RegisterPasswordStrength.weak => (
        l10n.registerPasswordStrengthWeak,
        tokens.danger,
        0.34,
      ),
      _RegisterPasswordStrength.medium => (
        l10n.registerPasswordStrengthMedium,
        tokens.warning,
        0.67,
      ),
      _RegisterPasswordStrength.strong => (
        l10n.registerPasswordStrengthStrong,
        tokens.success,
        1.0,
      ),
    };

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: tokens.panelMuted,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.registerPasswordHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ActivationPage extends ConsumerStatefulWidget {
  const ActivationPage({super.key, required this.memberId, required this.code});

  final String memberId;
  final String code;

  @override
  ConsumerState<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends ConsumerState<ActivationPage> {
  late final TextEditingController _memberIdController;
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _memberIdController = TextEditingController(text: widget.memberId);
    _codeController = TextEditingController(text: widget.code);
    if (widget.memberId.isNotEmpty && widget.code.isNotEmpty) {
      Future<void>.microtask(_submit);
    }
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .activate(
          memberId: _memberIdController.text.trim(),
          code: _codeController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final l10n = context.l10n;
    final submitting = actionState.isLoading && actionState.scope == 'activate';
    final status = actionState.scope == 'activate' ? actionState.message : null;

    return _AuthFrame(
      title: l10n.activationTitle,
      subtitle: l10n.activationSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _memberIdController,
            decoration: InputDecoration(labelText: l10n.memberId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(labelText: l10n.activationCode),
          ),
          if (status != null) ...[const SizedBox(height: 12), Text(status)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: Text(
              submitting
                  ? l10n.activationChecking
                  : l10n.activationSubmitAction,
            ),
          ),
        ],
      ),
    );
  }
}

class ActivationResendPage extends ConsumerStatefulWidget {
  const ActivationResendPage({super.key});

  @override
  ConsumerState<ActivationResendPage> createState() =>
      _ActivationResendPageState();
}

class _ActivationResendPageState extends ConsumerState<ActivationResendPage> {
  final _memberIdController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _memberIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .resendActivation(
          memberId: _memberIdController.text.trim(),
          email: _emailController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final l10n = context.l10n;
    final submitting =
        actionState.isLoading && actionState.scope == 'resendActivation';
    final status = actionState.scope == 'resendActivation'
        ? actionState.message
        : null;

    return _AuthFrame(
      title: l10n.resendActivationTitle,
      subtitle: l10n.resendActivationSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _memberIdController,
            decoration: InputDecoration(labelText: l10n.memberId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.email),
          ),
          if (status != null) ...[const SizedBox(height: 12), Text(status)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: Text(submitting ? l10n.submitInProgress : l10n.resendAction),
          ),
        ],
      ),
    );
  }
}

class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .requestPasswordReset(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final l10n = context.l10n;
    final submitting =
        actionState.isLoading && actionState.scope == 'passwordReset';
    final status = actionState.scope == 'passwordReset'
        ? actionState.message
        : null;

    return _AuthFrame(
      title: l10n.resetPasswordTitle,
      subtitle: l10n.resetPasswordSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.username),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.email),
          ),
          if (status != null) ...[const SizedBox(height: 12), Text(status)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: Text(
              submitting
                  ? l10n.submitInProgress
                  : l10n.passwordResetSubmitAction,
            ),
          ),
        ],
      ),
    );
  }
}

class OAuthCallbackPage extends StatelessWidget {
  const OAuthCallbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AuthFrame(
      title: l10n.oauthTitle,
      subtitle: l10n.oauthSubtitle,
      child: Text(l10n.oauthInfoMessage),
    );
  }
}

enum _OAuthProvider { google, x }

class _OAuthProviderLogo extends StatelessWidget {
  const _OAuthProviderLogo({required this.provider});

  final _OAuthProvider provider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: 24,
      child: switch (provider) {
        _OAuthProvider.google => SvgPicture.string(
          _googleLogoSvg,
          width: 20,
          height: 20,
        ),
        _OAuthProvider.x => SvgPicture.string(
          _xLogoSvg(isDark ? Colors.white : const Color(0xFF111111)),
          width: 18,
          height: 18,
        ),
      },
    );
  }
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showAppBar = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: showAppBar && canPop
          ? AppBar(
              backgroundColor: tokens.accent,
              foregroundColor: tokens.foregroundOnAccent,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ExcludeSemantics(
                    child: SdalLogoBadge(size: 22, frameSize: 30),
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                ],
              ),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.accent, tokens.canvas],
            stops: const [0, 0.38],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: SdalLogoBadge(size: 80, frameSize: 96),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: tokens.foreground),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.foregroundMuted),
                        ),
                        const SizedBox(height: 20),
                        child,
                        if (footer != null) ...[
                          const SizedBox(height: 16),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const String _googleLogoSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path fill="#EA4335" d="M12.24 10.285v3.818h5.445c-.233 1.227-.932 2.266-1.98 2.964l3.2 2.482c1.864-1.718 2.936-4.245 2.936-7.264 0-.691-.061-1.355-.176-2H12.24Z"/>'
    '<path fill="#4285F4" d="M12 22c2.7 0 4.965-.894 6.62-2.42l-3.2-2.482c-.89.597-2.03.95-3.42.95-2.63 0-4.858-1.777-5.655-4.166H3.037v2.56A9.997 9.997 0 0 0 12 22Z"/>'
    '<path fill="#FBBC05" d="M6.345 13.882A5.997 5.997 0 0 1 6.029 12c0-.654.113-1.29.316-1.882v-2.56H3.037A9.997 9.997 0 0 0 2 12c0 1.61.386 3.13 1.037 4.442l3.308-2.56Z"/>'
    '<path fill="#34A853" d="M12 5.952c1.468 0 2.786.505 3.822 1.495l2.864-2.864C16.96 2.973 14.695 2 12 2A9.997 9.997 0 0 0 3.037 7.558l3.308 2.56C7.142 7.73 9.37 5.952 12 5.952Z"/>'
    '</svg>';

String _xLogoSvg(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path fill="#$hex" d="M18.244 2H21.5l-7.11 8.128L22.75 22h-6.544l-5.124-6.706L5.214 22H1.955l7.606-8.693L1.5 2h6.71l4.632 6.117L18.244 2Zm-1.142 18h1.803L7.229 3.892H5.293L17.102 20Z"/>'
      '</svg>';
}

Widget _twoColumn(Widget left, Widget right) {
  return Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );
}
