import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/system_control_models.dart';

final systemControlRepositoryProvider = Provider<SystemControlRepository>(
  (ref) => SystemControlRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class SystemControlRepository {
  const SystemControlRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<SystemControlSnapshot> fetchSystemControl() async {
    final controls = await _adminRepository.fetchSiteControls();
    final trStrings = await _adminRepository.fetchLanguageStrings(
      lang: 'tr',
      limit: 20,
    );
    final enStrings = await _adminRepository.fetchLanguageStrings(
      lang: 'en',
      limit: 20,
    );
    final enByKey = {for (final item in enStrings) item.key: item.value};
    return SystemControlSnapshot(
      maintenanceMode: !controls.siteOpen,
      updateRules: const [
        PlatformUpdateRule(platform: 'iOS', minimumVersion: ''),
        PlatformUpdateRule(platform: 'Android', minimumVersion: ''),
      ],
      localizationRows: [
        for (final item in trStrings)
          LocalizationRow(
            keyName: item.key,
            trValue: item.value,
            enValue: enByKey[item.key] ?? '',
          ),
      ],
    );
  }

  Future<void> saveSettings(
    SystemControlSnapshot snapshot,
    String securityToken,
  ) async {
    if (securityToken.isEmpty) {
      throw ArgumentError(
        'Sistem ayarı değişikliği için step-up token zorunlu.',
      );
    }
    await _adminRepository.updateSiteControls(
      siteOpen: !snapshot.maintenanceMode,
    );
  }
}
