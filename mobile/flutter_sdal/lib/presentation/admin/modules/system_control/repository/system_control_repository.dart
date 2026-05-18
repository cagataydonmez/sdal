import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_control_models.dart';

final systemControlRepositoryProvider = Provider<SystemControlRepository>(
  (_) => const SystemControlRepository(),
);

class SystemControlRepository {
  const SystemControlRepository();

  Future<SystemControlSnapshot> fetchSystemControl() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const SystemControlSnapshot(
      maintenanceMode: false,
      updateRules: [
        PlatformUpdateRule(platform: 'iOS', minimumVersion: '0.3.0'),
        PlatformUpdateRule(platform: 'Android', minimumVersion: '0.3.0'),
      ],
      localizationRows: [
        LocalizationRow(
          keyName: 'adminPanelTitle',
          trValue: 'Admin paneli',
          enValue: 'Admin panel',
        ),
        LocalizationRow(
          keyName: 'approveAction',
          trValue: 'Onayla',
          enValue: 'Approve',
        ),
      ],
    );
  }

  Future<void> saveSettings(
    SystemControlSnapshot snapshot,
    String securityToken,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (securityToken.isEmpty) {
      throw ArgumentError(
        'Sistem ayarı değişikliği için step-up token zorunlu.',
      );
    }
  }
}
