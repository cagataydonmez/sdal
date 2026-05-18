class PlatformUpdateRule {
  const PlatformUpdateRule({
    required this.platform,
    required this.minimumVersion,
  });

  final String platform;
  final String minimumVersion;

  PlatformUpdateRule copyWith({String? minimumVersion}) {
    return PlatformUpdateRule(
      platform: platform,
      minimumVersion: minimumVersion ?? this.minimumVersion,
    );
  }
}

class LocalizationRow {
  const LocalizationRow({
    required this.keyName,
    required this.trValue,
    required this.enValue,
  });

  final String keyName;
  final String trValue;
  final String enValue;
}

class SystemControlSnapshot {
  const SystemControlSnapshot({
    required this.maintenanceMode,
    required this.updateRules,
    required this.localizationRows,
  });

  final bool maintenanceMode;
  final List<PlatformUpdateRule> updateRules;
  final List<LocalizationRow> localizationRows;

  SystemControlSnapshot copyWith({
    bool? maintenanceMode,
    List<PlatformUpdateRule>? updateRules,
    List<LocalizationRow>? localizationRows,
  }) {
    return SystemControlSnapshot(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      updateRules: updateRules ?? this.updateRules,
      localizationRows: localizationRows ?? this.localizationRows,
    );
  }
}
