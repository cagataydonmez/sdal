import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (_) => const DashboardRepository(),
);

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSnapshot> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return const DashboardSnapshot(
      systemStatus: 'Sistem Durumu: Stabil',
      metrics: [
        DashboardMetric(
          label: 'Bekleyen Üyelik',
          value: '18',
          trendLabel: '7 kayıt bugün geldi',
        ),
        DashboardMetric(
          label: 'Raporlanan İçerik',
          value: '11',
          trendLabel: '3 yüksek öncelik',
        ),
        DashboardMetric(
          label: 'Açık İtirazlar',
          value: '4',
          trendLabel: 'En eskisi 21 saat',
        ),
        DashboardMetric(
          label: 'Sistem Sağlığı (CPU/DB)',
          value: '96%',
          trendLabel: 'DB gecikmesi normal',
        ),
      ],
      weeklyTraffic: [
        WeeklyTrafficPoint(dayLabel: 'Pzt', traffic: 240, actions: 28),
        WeeklyTrafficPoint(dayLabel: 'Sal', traffic: 310, actions: 34),
        WeeklyTrafficPoint(dayLabel: 'Çar', traffic: 280, actions: 31),
        WeeklyTrafficPoint(dayLabel: 'Per', traffic: 360, actions: 44),
        WeeklyTrafficPoint(dayLabel: 'Cum', traffic: 410, actions: 48),
        WeeklyTrafficPoint(dayLabel: 'Cmt', traffic: 260, actions: 22),
        WeeklyTrafficPoint(dayLabel: 'Paz', traffic: 220, actions: 19),
      ],
      alerts: [
        SystemAlert(
          title: 'Push teslimat izleme',
          message: 'Son 1 saatte 2 cihaz token hatası verdi.',
          severity: 'medium',
        ),
        SystemAlert(
          title: 'Moderasyon SLA',
          message: '1 kritik içerik 4 saat sınırına yaklaşıyor.',
          severity: 'high',
        ),
      ],
    );
  }
}
