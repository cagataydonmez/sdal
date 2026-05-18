class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.value,
    required this.trendLabel,
  });

  final String label;
  final String value;
  final String trendLabel;
}

class WeeklyTrafficPoint {
  const WeeklyTrafficPoint({
    required this.dayLabel,
    required this.traffic,
    required this.actions,
  });

  final String dayLabel;
  final int traffic;
  final int actions;
}

class SystemAlert {
  const SystemAlert({
    required this.title,
    required this.message,
    required this.severity,
  });

  final String title;
  final String message;
  final String severity;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.metrics,
    required this.weeklyTraffic,
    required this.alerts,
    required this.systemStatus,
  });

  final List<DashboardMetric> metrics;
  final List<WeeklyTrafficPoint> weeklyTraffic;
  final List<SystemAlert> alerts;
  final String systemStatus;

  bool get isEmpty => metrics.isEmpty && alerts.isEmpty;
}
