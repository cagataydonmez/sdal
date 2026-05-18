import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/security/step_up_auth_dialog.dart';
import '../models/security_config_models.dart';
import '../state/security_config_state.dart';

class SecurityConfigView extends ConsumerWidget {
  const SecurityConfigView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(securityConfigControllerProvider);
    final controller = ref.read(securityConfigControllerProvider.notifier);
    return AdminStateView<SecurityConfigSnapshot>(
      state: state,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (snapshot) => AdminAdaptiveWorkspace(
        title: 'Hesap ve Altyapı Güvenliği',
        listPane: _SuspiciousLogins(snapshot: snapshot),
        detailPane: _AdminSessions(snapshot: snapshot),
        actionPane: _VerificationLimits(snapshot: snapshot),
      ),
    );
  }
}

class _SuspiciousLogins extends StatelessWidget {
  const _SuspiciousLogins({required this.snapshot});

  final SecurityConfigSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Şüpheli giriş denemeleri',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final attempt in snapshot.suspiciousLogins)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text('${attempt.ipPreview} · ${attempt.location}'),
              subtitle: Text('${attempt.deviceHash} · ${attempt.reason}'),
            ),
        ],
      ),
    );
  }
}

class _AdminSessions extends ConsumerWidget {
  const _AdminSessions({required this.snapshot});

  final SecurityConfigSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(securityConfigControllerProvider.notifier);
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'Aktif admin oturumları',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Admin')),
              DataColumn(label: Text('Cihaz')),
              DataColumn(label: Text('Son')),
              DataColumn(label: Text('İşlem')),
            ],
            rows: [
              for (final session in snapshot.adminSessions)
                DataRow(
                  cells: [
                    DataCell(Text(session.adminName)),
                    DataCell(Text(session.device)),
                    DataCell(Text(session.lastSeen)),
                    DataCell(
                      TextButton(
                        child: const Text('Oturumu Kapat'),
                        onPressed: () async {
                          final token = await StepUpAuthDialog.confirm(
                            context,
                            operationLabel: 'Oturumu Kapat (Revoke Token)',
                            riskDescription:
                                'Bu admin oturumu sonlandırılacak.',
                          );
                          if (token != null) {
                            await controller.revokeSession(
                              session.id,
                              token.token,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerificationLimits extends StatelessWidget {
  const _VerificationLimits({required this.snapshot});

  final SecurityConfigSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView(
        children: [
          Text(
            'SMS/Doğrulama deneme limit aşımı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final record in snapshot.limitRecords)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sms_failed_outlined),
              title: Text(record.userName),
              subtitle: Text(
                '${record.channel} · ${record.attemptCount} deneme',
              ),
            ),
        ],
      ),
    );
  }
}
