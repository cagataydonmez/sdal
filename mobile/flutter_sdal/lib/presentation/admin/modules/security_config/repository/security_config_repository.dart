import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/security_config_models.dart';

final securityConfigRepositoryProvider = Provider<SecurityConfigRepository>(
  (_) => const SecurityConfigRepository(),
);

class SecurityConfigRepository {
  const SecurityConfigRepository();

  Future<SecurityConfigSnapshot> fetchSecurityConfig() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const SecurityConfigSnapshot(
      suspiciousLogins: [
        SuspiciousLoginAttempt(
          ipPreview: '185.***.42',
          deviceHash: 'dev_8f2a',
          location: 'Istanbul, TR',
          reason: 'Yeni cihaz ve hızlı tekrar denemesi',
        ),
        SuspiciousLoginAttempt(
          ipPreview: '34.***.19',
          deviceHash: 'dev_44ac',
          location: 'Frankfurt, DE',
          reason: 'Beklenmeyen lokasyon',
        ),
      ],
      adminSessions: [
        AdminSessionRecord(
          id: 'sess-1',
          adminName: 'Root Admin',
          device: 'Safari iOS',
          lastSeen: '2 dakika önce',
        ),
        AdminSessionRecord(
          id: 'sess-2',
          adminName: 'Operasyon Admin',
          device: 'Chrome macOS',
          lastSeen: '18 dakika önce',
        ),
      ],
      limitRecords: [
        VerificationLimitRecord(
          userName: 'alper@example.com',
          channel: 'SMS',
          attemptCount: 6,
        ),
      ],
    );
  }

  Future<void> revokeSession(String sessionId, String securityToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (securityToken.isEmpty) {
      throw ArgumentError('Revoke için token zorunlu.');
    }
  }
}
