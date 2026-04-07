import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/status_views.dart';
import '../data/profile_repository.dart';

class EmailChangeVerifyPage extends ConsumerStatefulWidget {
  const EmailChangeVerifyPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<EmailChangeVerifyPage> createState() =>
      _EmailChangeVerifyPageState();
}

class _EmailChangeVerifyPageState extends ConsumerState<EmailChangeVerifyPage> {
  bool _loading = true;
  bool _success = false;
  String _message = 'Doğrulama bağlantısı kontrol ediliyor...';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_verify);
  }

  Future<void> _verify() async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = false;
        _message = 'Doğrulama bağlantısı eksik veya bozuk.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = 'Doğrulama bağlantısı kontrol ediliyor...';
    });

    final result = await ref
        .read(profileRepositoryProvider)
        .verifyEmailChange(token);
    if (!mounted) return;

    if (result.ok) {
      ref.invalidate(profileProvider);
      setState(() {
        _loading = false;
        _success = true;
        _message =
            'E-posta adresiniz doğrulandı. Profil ekranına dönüp yeni adresinizi görebilirsiniz.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _success = false;
      _message = result.message.isNotEmpty
          ? result.message
          : 'E-posta doğrulaması tamamlanamadı.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const StatusScaffold(
        title: 'E-posta doğrulama',
        message: 'Doğrulama bağlantısı kontrol ediliyor...',
      );
    }

    return StatusScaffold(
      title: 'E-posta doğrulama',
      message: _message,
      actionLabel: _success ? 'Profile git' : 'Tekrar dene',
      onAction: _success ? () => context.go('/profile') : _verify,
    );
  }
}
