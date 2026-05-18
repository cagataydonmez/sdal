import 'package:flutter/material.dart';

class StepUpAuthResult {
  const StepUpAuthResult({required this.token, required this.verifiedAt});

  final String token;
  final DateTime verifiedAt;
}

class StepUpAuthDialog extends StatefulWidget {
  const StepUpAuthDialog({
    super.key,
    required this.operationLabel,
    required this.riskDescription,
  });

  final String operationLabel;
  final String riskDescription;

  static Future<StepUpAuthResult?> confirm(
    BuildContext context, {
    required String operationLabel,
    required String riskDescription,
  }) {
    return showDialog<StepUpAuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StepUpAuthDialog(
        operationLabel: operationLabel,
        riskDescription: riskDescription,
      ),
    );
  }

  @override
  State<StepUpAuthDialog> createState() => _StepUpAuthDialogState();
}

class _StepUpAuthDialogState extends State<StepUpAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.operationLabel),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.riskDescription),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Admin şifresi',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Kritik işlem için şifre zorunlu.';
                if (text.length < 4) {
                  return 'Şifre en az 4 karakter olmalı.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Onayla'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final verifiedAt = DateTime.now();
    final token =
        'step-up-${verifiedAt.microsecondsSinceEpoch}-${_passwordController.text.trim().length}';
    Navigator.of(
      context,
    ).pop(StepUpAuthResult(token: token, verifiedAt: verifiedAt));
  }
}
