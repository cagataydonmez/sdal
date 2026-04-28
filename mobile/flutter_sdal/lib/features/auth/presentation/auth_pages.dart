import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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

const String _teacherGraduationYearValue = '9999';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  String? _captchaSvg;
  bool _captchaLoading = false;
  String? _captchaLoadError;
  int _failedLoginCount = 0;
  bool _showCaptcha = false;
  bool _showPasswordReset = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
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
    final result = await ref
        .read(authActionControllerProvider.notifier)
        .loginWithResult(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          captcha: _captchaController.text.trim(),
        );
    if (!mounted) return;
    if (result.activationRequired) {
      context.go(
        Uri(
          path: '/activate',
          queryParameters: {
            if (result.username.isNotEmpty) 'kadi': result.username,
            if (result.email.isNotEmpty) 'email': result.email,
          },
        ).toString(),
      );
      return;
    }
    if (result.deviceChallengeRequired) {
      context.go('/device-challenge');
      return;
    }
    if (!result.success) {
      setState(() {
        _failedLoginCount += 1;
        _showPasswordReset = true;
        _showCaptcha = result.captchaRequired || _failedLoginCount >= 3;
      });
      if (_showCaptcha && _captchaSvg == null && !_captchaLoading) {
        await _loadCaptcha();
      }
      return;
    }
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
          SizedBox(
            width: 190,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/register'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l10n.register),
            ),
          ),
          SizedBox(
            width: 190,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/activate'),
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Aktivasyon Kodu Gir'),
            ),
          ),
          if (_showPasswordReset)
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
              autofocus: true,
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
                _showPasswordReset
                    ? '$error Şifrenizi hatırlamıyorsanız şifre hatırlama seçeneğini kullanabilirsiniz.'
                    : error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_showCaptcha) ...[
              const SizedBox(height: 12),
              _CaptchaView(
                svg: _captchaSvg,
                loading: _captchaLoading,
                error: _captchaLoadError,
                onReload: submitting ? null : _loadCaptcha,
              ),
              const SizedBox(height: 12),
              _AuthTextField(
                controller: _captchaController,
                keyboardType: TextInputType.text,
                labelText: l10n.captchaCode,
                prefixIcon: const Icon(Icons.verified_user_outlined),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
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
    this.autofocus = false,
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
  final bool autofocus;

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
      autofocus: autofocus,
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
  String? _inactiveActivationUsername;
  String? _inactiveActivationEmail;
  bool _kvkkConsent = false;
  bool _directoryConsent = false;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
    _usernameController.addListener(_scheduleAvailabilityCheck);
    _emailController.addListener(_scheduleAvailabilityCheck);
    _passwordController.addListener(_refreshPasswordStrength);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.removeListener(_refreshPasswordStrength);
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

  void _refreshPasswordStrength() {
    if (mounted) setState(() {});
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
      _inactiveActivationUsername = null;
      _inactiveActivationEmail = null;
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
      final payload = asJsonMap(preview.rawData);
      setState(() {
        _previewError = preview.message.isNotEmpty
            ? preview.message
            : l10n.registerPreviewFailed;
        if (preview.code == 'ACTIVATION_REQUIRED' ||
            asString(payload['code']) == 'ACTIVATION_REQUIRED') {
          _inactiveActivationUsername =
              asString(payload['kadi']) ?? _usernameController.text.trim();
          _inactiveActivationEmail = asString(payload['email']);
        }
      });
      await _loadCaptcha();
      await _scrollToServerError(_previewError);
      return;
    }

    final registerPayload = await ref
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
    final actionState = ref.read(authActionControllerProvider);
    if (actionState.isSuccess) {
      final email = asString(registerPayload?['email']) ?? '';
      context.go(
        Uri(
          path: '/activate',
          queryParameters: {
            if (_usernameController.text.trim().isNotEmpty)
              'kadi': _usernameController.text.trim(),
            if (email.isNotEmpty) 'email': email,
          },
        ).toString(),
      );
      return;
    }
    await _loadCaptcha();
    if (!mounted) return;
    if (actionState.isError) {
      final payload = asJsonMap(registerPayload);
      final message = actionState.message ?? '';
      if (message.contains('aktivasyon')) {
        setState(() {
          _inactiveActivationUsername =
              asString(payload['kadi']) ?? _usernameController.text.trim();
          _inactiveActivationEmail = asString(payload['email']);
        });
      }
      await _scrollToServerError(message);
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
    if (email.isNotEmpty && !_isEmailFormatValid(email)) {
      if (mounted) {
        setState(() {
          _checkingAvailability = false;
          _availabilityMessage = null;
          _availabilityError = null;
        });
      }
      if (username.isEmpty) return;
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
    final emailCanBeChecked = email.isEmpty || _isEmailFormatValid(email);
    if (username.isEmpty && !emailCanBeChecked) {
      if (!mounted) return;
      setState(() {
        _checkingAvailability = false;
        _availabilityMessage = null;
        _availabilityError = null;
      });
      return;
    }

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
            if (email.isNotEmpty && emailCanBeChecked) 'email': email,
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
    final inactiveExists =
        (asBool(payload['kadiInactive']) ?? false) ||
        (asBool(payload['emailInactive']) ?? false);
    final parts = <String>[];
    if (username.isNotEmpty) {
      parts.add(
        usernameExists
            ? context.l10n.registerUsernameTaken
            : context.l10n.registerUsernameAvailable,
      );
    }
    if (email.isNotEmpty && emailCanBeChecked) {
      parts.add(
        emailExists
            ? context.l10n.registerEmailTaken
            : context.l10n.registerEmailAvailable,
      );
    }
    setState(() {
      _checkingAvailability = false;
      _availabilityError = usernameExists || emailExists
          ? inactiveExists
                ? '${parts.join(' ')} Aktivasyonu tamamlayarak devam edebilirsiniz.'
                : parts.join(' ')
          : null;
      _availabilityMessage = usernameExists || emailExists
          ? null
          : parts.join(' ');
      _inactiveActivationUsername = inactiveExists
          ? _usernameController.text.trim()
          : null;
      _inactiveActivationEmail = inactiveExists
          ? asString(payload['inactiveEmail'])
          : null;
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
                    if ((_inactiveActivationUsername?.isNotEmpty ?? false) ||
                        (_inactiveActivationEmail?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _goToActivation(
                          username: _inactiveActivationUsername,
                          email: _inactiveActivationEmail,
                        ),
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('Aktivasyon sayfasına git'),
                      ),
                    ],
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
            DropdownButtonFormField<String>(
              initialValue: _yearController.text,
              decoration: InputDecoration(labelText: l10n.graduationYear),
              items: _graduationYearOptions()
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(_formatGraduationYearOption(context, value)),
                    ),
                  )
                  .toList(growable: false),
              validator: _graduationYearValidator,
              onChanged: submitting
                  ? null
                  : (value) => setState(() {
                      _yearController.text = value ?? '';
                    }),
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
                        : (value) => _handleConsentToggle(
                            value: value ?? false,
                            title: l10n.registerKvkkTitle,
                            path: '/kvkk',
                            onApproved: () => _kvkkConsent = true,
                            onRejected: () => _kvkkConsent = false,
                          ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.registerKvkkConsentLabel),
                  ),
                  CheckboxListTile(
                    value: _directoryConsent,
                    onChanged: submitting
                        ? null
                        : (value) => _handleConsentToggle(
                            value: value ?? false,
                            title: l10n.registerDirectoryConsentTitle,
                            path: '/kvkk/acik-riza',
                            onApproved: () => _directoryConsent = true,
                            onRejected: () => _directoryConsent = false,
                          ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.registerDirectoryConsentLabel),
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
                  _CaptchaView(
                    svg: _captchaSvg,
                    loading: _captchaLoading,
                    error: _captchaLoadError,
                    onReload: submitting ? null : _loadCaptcha,
                  ),
                  const SizedBox(height: 12),
                  _AuthTextField(
                    controller: _captchaController,
                    keyboardType: TextInputType.text,
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
              if ((_inactiveActivationUsername?.isNotEmpty ?? false) ||
                  (_inactiveActivationEmail?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _goToActivation(
                    username: _inactiveActivationUsername,
                    email: _inactiveActivationEmail,
                  ),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Aktivasyon sayfasına git'),
                ),
              ],
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

  void _goToActivation({String? username, String? email}) {
    context.go(
      Uri(
        path: '/activate',
        queryParameters: {
          if ((username ?? '').isNotEmpty) 'kadi': username!,
          if ((email ?? '').isNotEmpty) 'email': email!,
        },
      ).toString(),
    );
  }

  Future<void> _handleConsentToggle({
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
    if (!_isEmailFormatValid(trimmed)) {
      return context.l10n.registerEmailInvalid;
    }
    if (trimmed.length > 50) {
      return context.l10n.registerFieldTooLong(context.l10n.email, 50);
    }
    return null;
  }

  bool _isEmailFormatValid(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
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
    if (trimmed == _teacherGraduationYearValue) {
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
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)) {
      return context.l10n.registerCaptchaDigitsOnly;
    }
    return null;
  }
}

List<String> _graduationYearOptions() => <String>[
  _teacherGraduationYearValue,
  for (var year = DateTime.now().year; year >= 1999; year--) '$year',
];

String _formatGraduationYearOption(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == _teacherGraduationYearValue ||
      normalized == 'teacher' ||
      normalized == 'öğretmen' ||
      normalized == 'ogretmen') {
    return Localizations.localeOf(context).languageCode == 'tr'
        ? 'Öğretmen'
        : 'Teacher';
  }
  return value;
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

class _CaptchaView extends StatelessWidget {
  const _CaptchaView({
    required this.svg,
    required this.loading,
    required this.error,
    required this.onReload,
  });

  final String? svg;
  final bool loading;
  final String? error;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: loading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        const SizedBox(height: 10),
                        Text(l10n.registerCaptchaLoading),
                      ],
                    )
                  : svg != null
                  ? SvgPicture.string(svg!, height: 56)
                  : Text(
                      (error?.isNotEmpty ?? false)
                          ? error!
                          : l10n.registerCaptchaUnavailable,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: onReload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.registerCaptchaRetryAction,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyActivationLine extends StatelessWidget {
  const _ReadOnlyActivationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class ActivationPage extends ConsumerStatefulWidget {
  const ActivationPage({
    super.key,
    required this.memberId,
    required this.code,
    this.username = '',
    this.email = '',
  });

  final String memberId;
  final String code;
  final String username;
  final String email;

  @override
  ConsumerState<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends ConsumerState<ActivationPage> {
  late final TextEditingController _memberIdController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _codeFocusNode = FocusNode();
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  bool _activationComplete = false;

  @override
  void initState() {
    super.initState();
    _memberIdController = TextEditingController(text: widget.memberId);
    _usernameController = TextEditingController(text: widget.username);
    _passwordController = TextEditingController();
    _codeController = TextEditingController(text: widget.code);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController();
    if (widget.memberId.isNotEmpty && widget.code.isNotEmpty) {
      Future<void>.microtask(_submit);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _memberIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isRegistrationActivation =
        _usernameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty;
    await ref
        .read(authActionControllerProvider.notifier)
        .activate(
          memberId: _memberIdController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          email: _emailController.text.trim(),
          code: _codeController.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(authActionControllerProvider);
    if (isRegistrationActivation &&
        state.scope == 'activate' &&
        state.isSuccess) {
      setState(() => _activationComplete = true);
    }
  }

  Future<void> _resend() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .resendActivation(
          memberId: _memberIdController.text.trim(),
          email: _emailController.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(authActionControllerProvider);
    if (state.isSuccess) {
      _startResendCountdown();
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = 120;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
        return;
      }
      setState(() => _resendSecondsLeft -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final l10n = context.l10n;
    final submitting = actionState.isLoading && actionState.scope == 'activate';
    final resending =
        actionState.isLoading && actionState.scope == 'resendActivation';
    final status = actionState.scope == 'activate' ? actionState.message : null;
    final resendStatus = actionState.scope == 'resendActivation'
        ? actionState.message
        : null;
    final isRegistrationActivation =
        _usernameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty;
    final isLegacyLinkActivation = _memberIdController.text.trim().isNotEmpty;
    final activationComplete =
        _activationComplete ||
        (actionState.scope == 'activate' && actionState.isSuccess);

    return _AuthFrame(
      title: l10n.activationTitle,
      subtitle: activationComplete && isRegistrationActivation
          ? 'Telefon numaranızı tek seferlik doğrulayın.'
          : isRegistrationActivation
          ? 'E-postadaki aktivasyon kodunu girin.'
          : 'Kullanıcı adı, şifre ve aktivasyon kodunu girin.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activationComplete && isRegistrationActivation) ...[
              _PhoneVerificationStep(phoneController: _phoneController),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Daha sonra giriş sayfasına dön'),
              ),
            ] else ...[
              if (isLegacyLinkActivation) ...[
                TextField(
                  controller: _memberIdController,
                  readOnly: true,
                  decoration: InputDecoration(labelText: l10n.memberId),
                ),
                const SizedBox(height: 12),
              ],
              if (isRegistrationActivation) ...[
                _ReadOnlyActivationLine(
                  label: l10n.username,
                  value: _usernameController.text.trim(),
                ),
              ] else ...[
                TextField(
                  controller: _usernameController,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.username),
                ),
              ],
              if (!isRegistrationActivation && !isLegacyLinkActivation) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: l10n.password),
                ),
              ],
              if (isRegistrationActivation) ...[
                const SizedBox(height: 12),
                _ReadOnlyActivationLine(
                  label: l10n.email,
                  value: _emailController.text.trim(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                autofocus: true,
                autofillHints: const [AutofillHints.oneTimeCode],
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l10n.activationCode),
              ),
              if (status != null) ...[const SizedBox(height: 12), Text(status)],
              if (resendStatus != null) ...[
                const SizedBox(height: 12),
                Text(resendStatus),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: submitting ? null : _submit,
                child: Text(
                  submitting
                      ? l10n.activationChecking
                      : l10n.activationSubmitAction,
                ),
              ),
              const SizedBox(height: 10),
              if (_emailController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: (resending || _resendSecondsLeft > 0)
                      ? null
                      : _resend,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    _resendSecondsLeft > 0
                        ? 'Tekrar gönder ($_resendSecondsLeft sn)'
                        : l10n.resendAction,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PhoneVerificationStep extends ConsumerStatefulWidget {
  const _PhoneVerificationStep({required this.phoneController});

  final TextEditingController phoneController;

  @override
  ConsumerState<_PhoneVerificationStep> createState() =>
      _PhoneVerificationStepState();
}

class _PhoneVerificationStepState
    extends ConsumerState<_PhoneVerificationStep> {
  final _otpController = TextEditingController();
  String _verificationId = '';
  int? _resendToken;
  String? _status;
  String _phonePreview = '';
  bool _sending = false;
  bool _verifying = false;
  bool _normalizingPhone = false;

  @override
  void initState() {
    super.initState();
    widget.phoneController.addListener(_normalizePhoneInput);
    _normalizePhoneInput();
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(_normalizePhoneInput);
    _otpController.dispose();
    super.dispose();
  }

  void _normalizePhoneInput() {
    if (_normalizingPhone) return;
    final raw = widget.phoneController.text;
    final normalized = _normalizePhoneForAuth(raw, live: true);
    final preview = _normalizePhoneForAuth(raw);
    if (normalized != raw) {
      _normalizingPhone = true;
      widget.phoneController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      _normalizingPhone = false;
    }
    if (mounted && _phonePreview != preview) {
      setState(() => _phonePreview = preview);
    }
  }

  Future<void> _sendCode() async {
    final phone = _normalizePhoneForAuth(widget.phoneController.text);
    if (phone.isEmpty) {
      setState(() => _status = 'Geçerli bir telefon numarası girin.');
      return;
    }
    setState(() {
      _sending = true;
      _status = null;
    });
    bool allowed;
    try {
      allowed = await ref
          .read(authActionControllerProvider.notifier)
          .startPhoneVerification(phoneNumber: phone);
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _sending = false;
        _status =
            ref.read(authActionControllerProvider).message ??
            'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      });
      return;
    }
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final token = await userCredential.user?.getIdToken();
        if (token != null) await _completeWithToken(token);
      },
      verificationFailed: (error) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _status = 'Kod geçersiz veya oturum süresi doldu.';
        });
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _verificationId = verificationId;
          _resendToken = resendToken;
          _status = 'SMS kodu gönderildi.';
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_verificationId.isEmpty || _otpController.text.trim().isEmpty) {
      setState(() => _status = 'SMS kodunu girin.');
      return;
    }
    setState(() {
      _verifying = true;
      _status = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final token = await userCredential.user?.getIdToken();
      if (token == null) throw StateError('missing firebase token');
      await _completeWithToken(token);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _status = 'Kod geçersiz veya oturum süresi doldu.';
      });
    }
  }

  Future<void> _completeWithToken(String token) async {
    final phone = _normalizePhoneForAuth(widget.phoneController.text);
    final ok = await ref
        .read(authActionControllerProvider.notifier)
        .completePhoneVerification(phoneNumber: phone, firebaseIdToken: token);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _verifying = false;
      _status = ok
          ? 'Telefon ve cihaz doğrulandı.'
          : ref.read(authActionControllerProvider).message ??
                'Kod geçersiz veya oturum süresi doldu.';
    });
    if (ok) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.phoneController,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Telefon numarası',
            hintText: '05061111111, 5061111111 veya +905061111111',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
        ),
        if (_phonePreview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            RegExp(r'^\+90\d{10}$').hasMatch(_phonePreview) ||
                    RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_phonePreview)
                ? 'Doğrulanacak numara: $_phonePreview'
                : 'Numara otomatik +90 formatına tamamlanır.',
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sending ? null : _sendCode,
          icon: const Icon(Icons.sms_outlined),
          label: Text(_sending ? 'Gönderiliyor...' : 'SMS kodu gönder'),
        ),
        if (_verificationId.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            autofillHints: const [AutofillHints.oneTimeCode],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'SMS kodu',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _verifying ? null : _verifyCode,
            child: Text(_verifying ? 'Doğrulanıyor...' : 'Kodu doğrula'),
          ),
        ],
        if (_status != null) ...[const SizedBox(height: 12), Text(_status!)],
      ],
    );
  }
}

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Telefon doğrulama',
      subtitle: 'Telefon numaranızı tek seferlik doğrulayın.',
      showAppBar: false,
      child: _PhoneVerificationStep(phoneController: _phoneController),
    );
  }
}

String _normalizePhoneForAuth(String raw, {bool live = false}) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  var compact = text.replaceAll(RegExp(r'[\s().-]'), '');
  if (compact.startsWith('+')) {
    final digits = compact.substring(1).replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '+' : '+$digits';
  }
  final digits = compact.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) return '+${digits.substring(2)}';
  if (digits.startsWith('0')) return '+90${digits.substring(1)}';
  if (digits.startsWith('90')) return '+$digits';
  if (digits.startsWith('5')) return '+90$digits';
  return live ? digits : '+$digits';
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

class DeviceEmailChallengePage extends ConsumerStatefulWidget {
  const DeviceEmailChallengePage({super.key});

  @override
  ConsumerState<DeviceEmailChallengePage> createState() =>
      _DeviceEmailChallengePageState();
}

class _DeviceEmailChallengePageState
    extends ConsumerState<DeviceEmailChallengePage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(authActionControllerProvider.notifier)
        .completeDeviceEmailChallenge(code: _codeController.text.trim());
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionControllerProvider);
    final submitting =
        actionState.isLoading && actionState.scope == 'deviceChallenge';
    final status = actionState.scope == 'deviceChallenge'
        ? actionState.message
        : null;
    return _AuthFrame(
      title: 'Cihaz doğrulama',
      subtitle: 'Yeni cihazdan giriş için e-postadaki kodu girin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeController,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'E-posta kodu',
              prefixIcon: Icon(Icons.mark_email_read_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (status != null) ...[const SizedBox(height: 12), Text(status)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: Text(submitting ? 'Doğrulanıyor...' : 'Cihazı doğrula'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: submitting ? null : () => context.go('/login'),
            child: const Text('Giriş sayfasına dön'),
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
