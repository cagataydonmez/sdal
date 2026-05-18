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
        header: Text(
          'Bugün Bakılması Gerekenler',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        listPane: _DashboardOverview(snapshot: snapshot),
        detailPane: _TrafficChart(points: snapshot.weeklyTraffic),
        actionPane: _SystemAlerts(alerts: snapshot.alerts),
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in snapshot.metrics)
              SizedBox(
                width: 220,
                child: AdminPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.label),
                      const SizedBox(height: 8),
                      Text(
                        metric.value,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(metric.trendLabel),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        AdminPanelCard(
          child: Row(
            children: [
              const Icon(Icons.verified_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(snapshot.systemStatus)),
            ],
          ),
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
          Text(
            'Haftalık trafik ve işlem hacmi',
            style: Theme.of(context).textTheme.titleMedium,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
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
  const _SystemAlerts({required this.alerts});

  final List<SystemAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: ListView.separated(
        itemCount: alerts.length + 1,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Kritik Sistem Uyarıları',
              style: Theme.of(context).textTheme.titleMedium,
            );
          }
          final alert = alerts[index - 1];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.warning_amber_outlined,
              color: adminSeverityColor(context, alert.severity),
            ),
            title: Text(alert.title),
            subtitle: Text(alert.message),
          );
        },
      ),
    );
  }
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
    final maxTraffic = points.map((point) => point.traffic).reduce(math.max);
    final maxActions = points.map((point) => point.actions).reduce(math.max);
    final trafficPath = Path();
    final actionPath = Path();
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final trafficY =
          size.height - (size.height * points[index].traffic / maxTraffic);
      final actionY =
          size.height - (size.height * points[index].actions / maxActions);
      if (index == 0) {
        trafficPath.moveTo(x, trafficY);
        actionPath.moveTo(x, actionY);
      } else {
        trafficPath.lineTo(x, trafficY);
        actionPath.lineTo(x, actionY);
      }
    }
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawPath(
      trafficPath,
      Paint()
        ..color = trafficColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      actionPath,
      Paint()
        ..color = actionColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.trafficColor != trafficColor ||
      oldDelegate.actionColor != actionColor;
}
