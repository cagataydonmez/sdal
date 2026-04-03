import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/surface_card.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final message = await ref
        .read(sessionControllerProvider.notifier)
        .login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = message;
    });
  }

  Future<void> _startOAuth(String provider) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final providers = await ref
          .read(sessionControllerProvider.notifier)
          .fetchOAuthProviders();
      final target = providers.firstWhere((item) => item.provider == provider);
      final config = ref.read(appConfigProvider);
      final apiClient = ref.read(apiClientProvider);
      final authUri = apiClient.buildApiUri(
        target.startUrl,
        query: const {'native': '1'},
      );
      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: config.oauthCallbackScheme,
      );
      final callback = Uri.parse(callbackUrl);
      final token = callback.queryParameters['token'];
      final oauthError = callback.queryParameters['oauth'];
      if (oauthError != null && oauthError.isNotEmpty) {
        throw StateError('OAuth akışı tamamlanamadı: $oauthError');
      }
      if (token == null || token.isEmpty) {
        throw StateError('OAuth dönüşünde oturum jetonu bulunamadı.');
      }
      final message = await ref
          .read(sessionControllerProvider.notifier)
          .exchangeMobileOAuthToken(token);
      if (!mounted) return;
      setState(() => _error = message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'SDAL',
      subtitle: 'Yeni Flutter iOS istemcisine giriş yapın.',
      footer: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('Kayıt ol'),
          ),
          TextButton(
            onPressed: () => context.go('/activation/resend'),
            child: const Text('Aktivasyon tekrar gönder'),
          ),
          TextButton(
            onPressed: () => context.go('/password-reset'),
            child: const Text('Şifre sıfırla'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı adı',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Giriş yapılıyor...' : 'Giriş yap'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : () => _startOAuth('google'),
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Google ile devam et'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : () => _startOAuth('x'),
            icon: const Icon(Icons.alternate_email),
            label: const Text('X ile devam et'),
          ),
        ],
      ),
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
  bool _submitting = false;
  String? _captchaSvg;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
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
      _submitting = true;
      _status = null;
    });
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/register',
          body: {
            'kadi': _usernameController.text.trim(),
            'sifre': _passwordController.text,
            'sifre2': _repeatPasswordController.text,
            'email': _emailController.text.trim(),
            'isim': _firstNameController.text.trim(),
            'soyisim': _lastNameController.text.trim(),
            'mezuniyetyili': _yearController.text.trim(),
            'gkodu': _captchaController.text.trim(),
          },
          decoder: (raw) => asJsonMap(raw),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _status = result.ok
          ? 'Kayıt isteği gönderildi. Aktivasyon e-postasını kontrol edin.'
          : result.message;
    });
    await _loadCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Kayıt ol',
      subtitle: 'V1 için yeni Flutter istemcisinden hesap oluşturun.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _twoColumn(
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Soyad'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 12),
          _twoColumn(
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            TextField(
              controller: _repeatPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre tekrar'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mezuniyet yılı / Teacher',
            ),
          ),
          const SizedBox(height: 16),
          if (_captchaSvg != null) ...[
            SurfaceCard(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.string(_captchaSvg!, height: 56),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _captchaController,
            decoration: const InputDecoration(labelText: 'Captcha kodu'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(
              _status!,
              style: TextStyle(
                color: _status!.contains('gönderildi')
                    ? Colors.green.shade700
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting ? 'Gönderiliyor...' : 'Kayıt isteği gönder',
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
  bool _submitting = false;
  String? _status;

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
    setState(() {
      _submitting = true;
      _status = null;
    });
    final result = await ref
        .read(apiClientProvider)
        .get<JsonMap>(
          '/api/activate',
          query: {
            'id': _memberIdController.text.trim(),
            'akt': _codeController.text.trim(),
          },
          decoder: (raw) => asJsonMap(raw),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _status = result.message.isNotEmpty
          ? result.message
          : (result.ok ? 'Aktivasyon tamamlandı.' : 'Aktivasyon başarısız.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Aktivasyon',
      subtitle:
          'E-posta bağlantınız iOS uygulamasını açtıysa burada tamamlayın.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _memberIdController,
            decoration: const InputDecoration(labelText: 'Üye kimliği'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: 'Aktivasyon kodu'),
          ),
          if (_status != null) ...[const SizedBox(height: 12), Text(_status!)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting ? 'Kontrol ediliyor...' : 'Aktivasyonu tamamla',
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
  bool _submitting = false;
  String? _status;

  @override
  void dispose() {
    _memberIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _status = null;
    });
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/activation/resend',
          body: {
            'id': _memberIdController.text.trim(),
            'email': _emailController.text.trim(),
          },
          decoder: (raw) => asJsonMap(raw),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _status = result.message.isNotEmpty
          ? result.message
          : (result.ok
                ? 'Aktivasyon e-postası yeniden gönderildi.'
                : 'İşlem başarısız.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Aktivasyon tekrar gönder',
      subtitle: 'Eski üyelik aktivasyon akışı için destek ekranı.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _memberIdController,
            decoration: const InputDecoration(labelText: 'Üye kimliği'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          if (_status != null) ...[const SizedBox(height: 12), Text(_status!)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Gönderiliyor...' : 'Tekrar gönder'),
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
  bool _submitting = false;
  String? _status;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _status = null;
    });
    final result = await ref
        .read(apiClientProvider)
        .post<JsonMap>(
          '/api/password-reset',
          body: {
            'kadi': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
          },
          decoder: (raw) => asJsonMap(raw),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _status = result.message.isNotEmpty
          ? result.message
          : (result.ok
                ? 'Şifre sıfırlama e-postası gönderildi.'
                : 'İşlem başarısız.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Şifre sıfırla',
      subtitle: 'Eski SDAL hesap kurtarma uç noktasını kullanır.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          if (_status != null) ...[const SizedBox(height: 12), Text(_status!)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting ? 'Gönderiliyor...' : 'Sıfırlama isteği gönder',
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
    return const _AuthFrame(
      title: 'OAuth',
      subtitle: 'Bu ekran genellikle kısa süreliğine görünür.',
      child: Text(
        'Tarayıcı akışı uygulamaya geri döndüğünde oturum otomatik açılır.',
      ),
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
    return Scaffold(
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
