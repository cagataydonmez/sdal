import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/widgets/surface_card.dart';
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
      footer: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          TextButton(
            onPressed: () => context.push('/register'),
            child: Text(l10n.register),
          ),
          TextButton(
            onPressed: () => context.push('/activation/resend'),
            child: Text(l10n.resendActivation),
          ),
          TextButton(
            onPressed: () => context.push('/password-reset'),
            child: Text(l10n.resetPassword),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthTextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            labelText: l10n.username,
            prefixIcon: const Icon(Icons.alternate_email),
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _submit(),
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
            icon: const Icon(Icons.g_mobiledata),
            label: Text(l10n.continueWithGoogle),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: submitting ? null : () => _startOAuth('x'),
            icon: const Icon(Icons.alternate_email),
            label: Text(l10n.continueWithX),
          ),
        ],
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
  });

  final TextEditingController controller;
  final String labelText;
  final Widget? prefixIcon;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _yearController = TextEditingController(text: '2011');
  final _captchaController = TextEditingController();
  String? _captchaSvg;
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
    final result = await ref
        .read(apiClientProvider)
        .get<String>('/api/captcha');
    if (!mounted) return;
    setState(() {
      _captchaSvg = result.rawData is String ? result.rawData as String : null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _previewError = null;
    });

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
            : 'Kayıt bilgileri doğrulanamadı.';
      });
      await _loadCaptcha();
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
    await _loadCaptcha();
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
            : 'Kullanılabilirlik kontrolü yapılamadı.';
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
            ? 'Bu kullanıcı adı zaten kayıtlı.'
            : 'Kullanıcı adı uygun görünüyor.',
      );
    }
    if (email.isNotEmpty) {
      parts.add(
        emailExists
            ? 'Bu e-posta adresi zaten kayıtlı.'
            : 'E-posta adresi uygun görünüyor.',
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

    return _AuthFrame(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _twoColumn(
            _AuthTextField(
              controller: _firstNameController,
              labelText: l10n.firstName,
            ),
            _AuthTextField(
              controller: _lastNameController,
              labelText: l10n.lastName,
            ),
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _usernameController,
            labelText: l10n.username,
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            labelText: l10n.email,
          ),
          if (_checkingAvailability) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_availabilityMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _availabilityMessage!,
              style: TextStyle(color: Colors.green.shade700),
            ),
          ],
          if (_availabilityError != null) ...[
            const SizedBox(height: 8),
            Text(
              _availabilityError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          _twoColumn(
            _AuthTextField(
              controller: _passwordController,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              labelText: l10n.password,
            ),
            _AuthTextField(
              controller: _repeatPasswordController,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              labelText: l10n.passwordRepeat,
            ),
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            labelText: l10n.graduationYear,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _kvkkConsent,
            onChanged: submitting
                ? null
                : (value) => setState(() => _kvkkConsent = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'KVKK Aydınlatma Metni\'ni okudum ve onaylıyorum.',
            ),
          ),
          CheckboxListTile(
            value: _directoryConsent,
            onChanged: submitting
                ? null
                : (value) => setState(() => _directoryConsent = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Mezun Rehberi açık rıza onayını veriyorum.'),
          ),
          const SizedBox(height: 16),
          if (_captchaSvg != null) ...[
            SurfaceCard(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.string(_captchaSvg!, height: 56),
            ),
            const SizedBox(height: 12),
          ],
          _AuthTextField(
            controller: _captchaController,
            keyboardType: TextInputType.number,
            labelText: l10n.captchaCode,
          ),
          if (statusText != null) ...[
            const SizedBox(height: 12),
            Text(
              statusText,
              style: TextStyle(
                color: isSuccessState
                    ? Colors.green.shade700
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

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop
          ? AppBar(
              backgroundColor: const Color(0xFF0D2238),
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2238), Color(0xFFF4F7FB)],
            stops: [0, 0.35],
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
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: const Color(0xFF0D2238)),
                        ),
                        const SizedBox(height: 8),
                        Text(subtitle),
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

Widget _twoColumn(Widget left, Widget right) {
  return Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );
}
