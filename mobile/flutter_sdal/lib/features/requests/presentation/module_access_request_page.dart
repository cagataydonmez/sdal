import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/requests_repository.dart';

class ModuleAccessRequestPage extends ConsumerStatefulWidget {
  const ModuleAccessRequestPage({super.key, required this.moduleKey});

  final String moduleKey;

  @override
  ConsumerState<ModuleAccessRequestPage> createState() =>
      _ModuleAccessRequestPageState();
}

class _ModuleAccessRequestPageState
    extends ConsumerState<ModuleAccessRequestPage> {
  bool _submitting = false;
  bool _submitted = false;
  String? _statusMessage;

  Future<void> _submit() async {
    final moduleKey = widget.moduleKey.trim();
    if (moduleKey.isEmpty) {
      setState(() {
        _statusMessage = 'Hangi modül için erişim istendiği belirlenemedi.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    final result = await ref
        .read(requestsRepositoryProvider)
        .requestModuleAccess(moduleKey: moduleKey);
    if (!mounted) return;

    setState(() {
      _submitting = false;
      _submitted = result.ok;
      _statusMessage = result.ok
          ? 'Erişim talebiniz gönderildi. Yönetim onayından sonra bilgilendirileceksiniz.'
          : (result.message.isNotEmpty
                ? result.message
                : 'Erişim talebi gönderilemedi.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final moduleLabel = widget.moduleKey.trim().isEmpty
        ? l10n.moduleClosedDefaultMessage
        : l10n.moduleClosedWithName(widget.moduleKey.trim());

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.moduleClosedTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(moduleLabel),
                  const SizedBox(height: 12),
                  Text(
                    'Bu modül için erişim talebi bırakabilirsiniz. Talebiniz uygun kategoriyle yönetim ekranına düşer.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _submitted
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting || _submitted ? null : _submit,
                          child: Text(
                            _submitting
                                ? 'Gönderiliyor...'
                                : (_submitted
                                      ? 'Talep gönderildi'
                                      : 'Erişim talebi gönder'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.go('/feed'),
                      child: const Text('Akışa dön'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
