import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/security_config_models.dart';

final securityConfigRepositoryProvider = Provider<SecurityConfigRepository>(
  (ref) => SecurityConfigRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class SecurityConfigRepository {
  const SecurityConfigRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<SecurityConfigSnapshot> fetchSecurityConfig() async {
    final security = await _adminRepository.fetchAuthSecurity();
    return SecurityConfigSnapshot(
      suspiciousLogins: security.auditLogs
          .where(
            (item) =>
                item.riskLevel.trim().isNotEmpty &&
                item.riskLevel.trim().toLowerCase() != 'low',
          )
          .map(
            (item) => SuspiciousLoginAttempt(
              ipPreview: item.ipHashPreview,
              deviceHash: item.deviceHashPreview,
              location: item.eventType,
              reason: item.riskLevel,
            ),
          )
          .toList(growable: false),
      adminSessions: security.trustedDevices
          .map(
            (item) => AdminSessionRecord(
              id: '${item.id}',
              adminName: item.displayName,
              device: '${item.platform} ${item.deviceName}'.trim(),
              lastSeen: item.lastSeenAt,
            ),
          )
          .toList(growable: false),
      limitRecords: security.phoneAttempts
          .map(
            (item) => VerificationLimitRecord(
              userName: item.displayName,
              channel: item.status,
              attemptCount: 1,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> revokeSession(String sessionId, String securityToken) async {
    if (securityToken.isEmpty) {
      throw ArgumentError('Revoke için token zorunlu.');
    }
    final id = int.tryParse(sessionId) ?? 0;
    if (id <= 0) throw ArgumentError('Geçersiz cihaz kaydı.');
    await _adminRepository.revokeTrustedDevice(id: id);
  }
}
