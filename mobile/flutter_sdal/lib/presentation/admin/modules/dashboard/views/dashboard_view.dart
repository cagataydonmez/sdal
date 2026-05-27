import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive_admin_scaffold.dart';
import '../../../core/admin_theme.dart';
import '../models/dashboard_models.dart';
import '../state/dashboard_state.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    return AdminStateView<DashboardSnapshot>(
      state: state,
      onRetry: controller.refresh,
      onResetFilters: controller.resetFilters,
      builder: (snapshot) => AdminAdaptiveWorkspace(
        title: 'Yönetim Komuta Merkezi',
        header: _DashboardHeader(snapshot: snapshot),
        listPane: _DashboardOverview(snapshot: snapshot),
        detailPane: _TrafficChart(points: snapshot.weeklyTraffic),
        actionPane: _SystemAlerts(
          alerts: snapshot.alerts,
          points: snapshot.weeklyTraffic,
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminPanelTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasAlerts = snapshot.alerts.isNotEmpty;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatusPulse(
          label: hasAlerts
              ? '${snapshot.alerts.length} canlı uyarı'
              : 'Akış stabil',
          color: hasAlerts ? tokens.warning : tokens.success,
          icon: hasAlerts
              ? Icons.sensors_outlined
              : Icons.check_circle_outline_rounded,
        ),
        _StatusPulse(
          label: snapshot.sourceLabel ?? 'Özet kaynağı aktif',
          color: scheme.primary,
          icon: Icons.route_outlined,
        ),
      ],
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ExecutiveMetricGrid(metrics: snapshot.metrics),
        const SizedBox(height: 14),
        AdminPanelCard(child: _RealtimeStatusStrip(snapshot: snapshot)),
      ],
    );
  }
}

class _ExecutiveMetricGrid extends StatelessWidget {
  const _ExecutiveMetricGrid({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 128,
          ),
          itemBuilder: (context, index) =>
              _ExecutiveMetricCard(metric: metrics[index], index: index),
        );
      },
    );
  }
}

class _ExecutiveMetricCard extends StatelessWidget {
  const _ExecutiveMetricCard({required this.metric, required this.index});

  final DashboardMetric metric;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminPanelTokens.of(context);
    final tones = [tokens.info, tokens.warning, tokens.danger, tokens.success];
    final color = tones[index % tones.length];
    return AdminPanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            metric.trendLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RealtimeStatusStrip extends StatelessWidget {
  const _RealtimeStatusStrip({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminPanelTokens.of(context);
    final traffic = snapshot.weeklyTraffic.fold<int>(
      0,
      (sum, point) => sum + point.traffic,
    );
    final actions = snapshot.weeklyTraffic.fold<int>(
      0,
      (sum, point) => sum + point.actions,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monitor_heart_outlined, color: tokens.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                snapshot.systemStatus,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusPulse(
              label: '$traffic trafik',
              color: tokens.info,
              icon: Icons.show_chart_rounded,
            ),
            _StatusPulse(
              label: '$actions işlem',
              color: tokens.warning,
              icon: Icons.bolt_outlined,
            ),
            _StatusPulse(
              label: snapshot.alerts.isEmpty ? 'risk düşük' : 'izleme aktif',
              color: snapshot.alerts.isEmpty ? tokens.success : tokens.danger,
              icon: Icons.radar_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _TrafficChart extends StatelessWidget {
  const _TrafficChart({required this.points});

  final List<WeeklyTrafficPoint> points;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Haftalık trafik ve işlem hacmi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const _LegendDot(label: 'Trafik', colorRole: _LegendRole.info),
              const SizedBox(width: 10),
              const _LegendDot(label: 'İşlem', colorRole: _LegendRole.warning),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _TrafficChartPainter(
                points: points,
                trafficColor: Theme.of(context).colorScheme.primary,
                actionColor: AdminPanelTokens.of(context).warning,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final point in points)
                Chip(label: Text('${point.dayLabel}: ${point.actions} işlem')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemAlerts extends StatelessWidget {
  const _SystemAlerts({required this.alerts, required this.points});

  final List<SystemAlert> alerts;
  final List<WeeklyTrafficPoint> points;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _BehaviorHeatmap(points: points),
        const SizedBox(height: 14),
        AdminPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kritik Sistem Uyarıları',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (alerts.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle_outline_rounded),
                  title: Text('Açık kritik uyarı yok'),
                  subtitle: Text('Operasyon kuyruğu normal aralıkta.'),
                )
              else
                for (final alert in alerts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.warning_amber_outlined,
                      color: adminSeverityColor(context, alert.severity),
                    ),
                    title: Text(alert.title),
                    subtitle: Text(alert.message),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BehaviorHeatmap extends StatelessWidget {
  const _BehaviorHeatmap({required this.points});

  final List<WeeklyTrafficPoint> points;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminPanelTokens.of(context);
    final maxValue = points.fold<int>(
      1,
      (maxValue, point) =>
          math.max(maxValue, math.max(point.traffic, point.actions)),
    );
    return AdminPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Davranış yoğunluğu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Günlük trafik ve aksiyon sıcaklığı',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          for (final row in const [
            _HeatRow('Trafik', _HeatMetric.traffic),
            _HeatRow('İşlem', _HeatMetric.actions),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (final point in points)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _HeatCell(
                                label: point.dayLabel,
                                value: row.metric == _HeatMetric.traffic
                                    ? point.traffic
                                    : point.actions,
                                maxValue: maxValue,
                                low: tokens.surfaceTint,
                                mid: tokens.info,
                                high: row.metric == _HeatMetric.traffic
                                    ? tokens.success
                                    : tokens.warning,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.low,
    required this.mid,
    required this.high,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color low;
  final Color mid;
  final Color high;

  @override
  Widget build(BuildContext context) {
    final intensity = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final color = intensity < 0.55
        ? Color.lerp(low, mid, intensity / 0.55)!
        : Color.lerp(mid, high, (intensity - 0.55) / 0.45)!;
    return Tooltip(
      message: '$label: $value',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.28 + intensity * 0.38),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.72)),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StatusPulse extends StatelessWidget {
  const _StatusPulse({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.56)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

enum _LegendRole { info, warning }

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.colorRole});

  final String label;
  final _LegendRole colorRole;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminPanelTokens.of(context);
    final color = colorRole == _LegendRole.info ? tokens.info : tokens.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

enum _HeatMetric { traffic, actions }

class _HeatRow {
  const _HeatRow(this.label, this.metric);

  final String label;
  final _HeatMetric metric;
}

class _TrafficChartPainter extends CustomPainter {
  const _TrafficChartPainter({
    required this.points,
    required this.trafficColor,
    required this.actionColor,
  });

  final List<WeeklyTrafficPoint> points;
  final Color trafficColor;
  final Color actionColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxTraffic = math.max(
      1,
      points.map((point) => point.traffic).reduce(math.max),
    );
    final maxActions = math.max(
      1,
      points.map((point) => point.actions).reduce(math.max),
    );
    final trafficPath = Path();
    final actionPath = Path();
    final trafficFillPath = Path();
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final trafficY =
          size.height - (size.height * points[index].traffic / maxTraffic);
      final actionY =
          size.height - (size.height * points[index].actions / maxActions);
      if (index == 0) {
        trafficPath.moveTo(x, trafficY);
        actionPath.moveTo(x, actionY);
        trafficFillPath.moveTo(x, size.height);
        trafficFillPath.lineTo(x, trafficY);
      } else {
        trafficPath.lineTo(x, trafficY);
        actionPath.lineTo(x, actionY);
        trafficFillPath.lineTo(x, trafficY);
      }
    }
    trafficFillPath
      ..lineTo(size.width, size.height)
      ..close();
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawPath(
      trafficFillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            trafficColor.withValues(alpha: 0.28),
            trafficColor.withValues(alpha: 0.03),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      trafficPath,
      Paint()
        ..color = trafficColor
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      actionPath,
      Paint()
        ..color = actionColor
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.trafficColor != trafficColor ||
      oldDelegate.actionColor != actionColor;
}
