import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class DashboardRepository {
  const DashboardRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<DashboardSnapshot> fetchDashboard() async {
    final summary = await _adminRepository.fetchMobileSummary();
    final counts = summary.counts;
    final system = summary.system;
    final cpuValue = system?.cpuSupported == true
        ? '${system!.cpuUsagePct.toStringAsFixed(0)}%'
        : 'N/A';
    final dbValue = system == null
        ? 'N/A'
        : '${system.databaseSizeMb.toStringAsFixed(system.databaseSizeMb >= 10 ? 0 : 1)} MB';
    final pendingCount = summary.attention.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );
    return DashboardSnapshot(
      sourceLabel: '/api/admin/mobile/summary',
      systemStatus: pendingCount == 0
          ? 'Sistem Durumu: Stabil'
          : 'Sistem Durumu: ${summary.attention.length} uyarı izleniyor',
      metrics: [
        DashboardMetric(
          label: 'Bekleyen Üyelik',
          value: '${counts['pendingUsers'] ?? counts['pendingRequests'] ?? 0}',
          trendLabel: 'Backend kuyruğundan canlı',
        ),
        DashboardMetric(
          label: 'Raporlanan İçerik',
          value:
              '${(counts['posts'] ?? 0) + (counts['comments'] ?? 0) + (counts['stories'] ?? 0)}',
          trendLabel: 'Post, yorum ve hikaye toplamı',
        ),
        DashboardMetric(
          label: 'Açık İtirazlar',
          value: '${counts['appeals'] ?? 0}',
          trendLabel: 'İtiraz sayacı yoksa 0 döner',
        ),
        DashboardMetric(
          label: 'Sistem Sağlığı (CPU/DB)',
          value: cpuValue,
          trendLabel: 'DB: $dbValue',
        ),
      ],
      weeklyTraffic: _trafficFromAudit(summary.recentAudit),
      alerts: summary.attention
          .map(
            (item) => SystemAlert(
              title: item.label,
              message: '${item.count} kayıt işlem bekliyor.',
              severity: item.tone,
            ),
          )
          .toList(growable: false),
    );
  }

  List<WeeklyTrafficPoint> _trafficFromAudit(
    List<legacy.AdminAuditLogItem> audit,
  ) {
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final counts = List<int>.filled(7, 0);
    for (final item in audit) {
      final parsed = DateTime.tryParse(item.createdAt);
      if (parsed == null) continue;
      counts[parsed.weekday - 1] += 1;
    }
    return [
      for (var i = 0; i < labels.length; i++)
        WeeklyTrafficPoint(
          dayLabel: labels[i],
          traffic: counts[i],
          actions: counts[i],
        ),
    ];
  }
}
