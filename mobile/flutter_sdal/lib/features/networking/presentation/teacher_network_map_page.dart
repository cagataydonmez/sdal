import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../data/networking_repository.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const double _kCanvasSize = 2200.0;
const double _kCanvasCenter = _kCanvasSize / 2;
const double _kTeacherAvatarRadius = 40.0; // 80px diameter on canvas

const double _kMemberAvatarDiameter = 44.0;
const double _kMemberAvatarOverlapStep = 28.0; // center-to-center for overlap
const int _kMaxVisibleAvatars = 5;

// Labels become readable at this canvas-space scale.
const double _kLodNameThreshold = 1.1;

// ── Geometry helpers ──────────────────────────────────────────────────────────

double _orbitalRadius(int cohortCount) {
  if (cohortCount <= 3) return 280.0;
  if (cohortCount <= 6) return 340.0;
  if (cohortCount <= 10) return 400.0;
  if (cohortCount <= 15) return 460.0;
  return 520.0;
}

Offset _cohortCenter(int index, int total, double animValue) {
  // Start from top (–π/2) and distribute evenly clockwise.
  final angle = (2 * math.pi * index / total) - (math.pi / 2);
  final r = _orbitalRadius(total) * animValue;
  return Offset(
    _kCanvasCenter + r * math.cos(angle),
    _kCanvasCenter + r * math.sin(angle),
  );
}

// Width of an overlapping avatar stack.
double _clusterWidth(int count) {
  final visible = math.min(count, _kMaxVisibleAvatars);
  if (visible <= 1) return _kMemberAvatarDiameter;
  return _kMemberAvatarDiameter + (visible - 1) * _kMemberAvatarOverlapStep;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class TeacherNetworkMapPage extends ConsumerStatefulWidget {
  const TeacherNetworkMapPage({super.key, required this.teacherId});

  final int teacherId;

  @override
  ConsumerState<TeacherNetworkMapPage> createState() =>
      _TeacherNetworkMapPageState();
}

class _TeacherNetworkMapPageState extends ConsumerState<TeacherNetworkMapPage>
    with TickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _revealController;
  late final Animation<double> _revealAnim;
  bool _initialTransformSet = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    );
    _revealAnim = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _startReveal() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _revealController.value = 1.0;
    } else {
      _revealController.forward();
    }
  }

  void _setInitialTransform(Size viewport) {
    if (_initialTransformSet) return;
    _initialTransformSet = true;

    // Show the star with small padding around the orbital area.
    final visibleDiameter = (_orbitalRadius(20) + 160) * 2;
    final scale = math.min(viewport.width, viewport.height - kToolbarHeight) /
        visibleDiameter *
        0.88;

    final dx = (viewport.width - _kCanvasSize * scale) / 2.0;
    final dy = ((viewport.height - kToolbarHeight) - _kCanvasSize * scale) / 2.0;

    // M = T * S: child is scaled then translated.
    _transformController.value = Matrix4(
      scale, 0, 0, 0,
      0, scale, 0, 0,
      0, 0, 1, 0,
      dx, dy, 0, 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherNetworkMapProvider(widget.teacherId));
    return Scaffold(
      backgroundColor: const Color(0xFF17120F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1610),
        foregroundColor: const Color(0xFFF5EDE4),
        elevation: 0,
        title: state.maybeWhen(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.teacherName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFF5EDE4),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${data.totalLinks} üye · ${data.cohorts.length} kohort',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9E8C7D),
                ),
              ),
            ],
          ),
          orElse: () => const Text(
            'Ağ Haritası',
            style: TextStyle(color: Color(0xFFF5EDE4)),
          ),
        ),
        actions: [
          state.maybeWhen(
            data: (_) => LayoutBuilder(
              builder: (ctx, _) => IconButton(
                tooltip: 'Sıfırla',
                icon: const Icon(Icons.center_focus_strong_outlined),
                onPressed: () {
                  final viewport = MediaQuery.sizeOf(context);
                  _initialTransformSet = false;
                  _setInitialTransform(viewport);
                },
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFB45637)),
        ),
        error: (error, _) => Center(
          child: ErrorView(
            compact: true,
            kind: ErrorViewKind.network,
            onRetry: () => ref.invalidate(teacherNetworkMapProvider(widget.teacherId)),
          ),
        ),
        data: (data) {
          if (data.cohorts.isEmpty) {
            return _EmptyMapView(data: data);
          }
          return _MapView(
            data: data,
            transformController: _transformController,
            revealAnim: _revealAnim,
            onFirstLayout: (viewport) {
              _setInitialTransform(viewport);
              _startReveal();
            },
          );
        },
      ),
    );
  }
}

// ── Map view ─────────────────────────────────────────────────────────────────

class _MapView extends ConsumerWidget {
  const _MapView({
    required this.data,
    required this.transformController,
    required this.revealAnim,
    required this.onFirstLayout,
  });

  final TeacherNetworkMapData data;
  final TransformationController transformController;
  final Animation<double> revealAnim;
  final ValueChanged<Size> onFirstLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onFirstLayout(viewport);
        });

        return Stack(
          children: [
            // ── Interactive canvas ──────────────────────────────────────────
            InteractiveViewer(
              transformationController: transformController,
              constrained: false,
              minScale: 0.08,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: SizedBox.square(
                dimension: _kCanvasSize,
                child: AnimatedBuilder(
                  animation: revealAnim,
                  builder: (context, _) {
                    final animValue = revealAnim.value;
                    final cohortPositions = List.generate(
                      data.cohorts.length,
                      (i) => _cohortCenter(i, data.cohorts.length, animValue),
                    );

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background + connection lines
                        CustomPaint(
                          size: const Size(_kCanvasSize, _kCanvasSize),
                          painter: _NetworkLinePainter(
                            teacherCenter: const Offset(_kCanvasCenter, _kCanvasCenter),
                            cohortPositions: cohortPositions,
                            animValue: animValue,
                            accent: const Color(0xFFB45637),
                          ),
                        ),

                        // Cohort clusters
                        ...List.generate(data.cohorts.length, (i) {
                          final cohort = data.cohorts[i];
                          final center = cohortPositions[i];
                          final visible = math.min(
                            cohort.members.length,
                            _kMaxVisibleAvatars,
                          );
                          final clusterW = _clusterWidth(cohort.members.length);

                          return Positioned(
                            left: center.dx - clusterW / 2,
                            top: center.dy - _kMemberAvatarDiameter / 2 - 28,
                            child: Opacity(
                              opacity: animValue.clamp(0.0, 1.0),
                              child: _CohortCluster(
                                cohort: cohort,
                                visible: visible,
                                clusterWidth: clusterW,
                                transformController: transformController,
                                config: config,
                                onMemberTap: (id) => context.push('/members/$id'),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ── Teacher node overlay (always legible) ─────────────────────
            ValueListenableBuilder<Matrix4>(
              valueListenable: transformController,
              builder: (context, matrix, _) {
                // Map canvas center → screen coordinates.
                const canvasCenter = Offset(_kCanvasCenter, _kCanvasCenter);
                final m = matrix;
                final scaleX = m.entry(0, 0);
                final scaleY = m.entry(1, 1);
                final tx = m.entry(0, 3);
                final ty = m.entry(1, 3);
                final screenX = canvasCenter.dx * scaleX + tx;
                final screenY = canvasCenter.dy * scaleY + ty;

                // Clamp to a comfortable on-screen region so the node
                // always stays partly visible even when panned far out.
                final safeX = screenX.clamp(
                  -_kTeacherAvatarRadius,
                  viewport.width + _kTeacherAvatarRadius,
                );
                final safeY = screenY.clamp(
                  kToolbarHeight.toDouble(),
                  viewport.height + _kTeacherAvatarRadius,
                );

                return Positioned(
                  left: safeX - _kTeacherAvatarRadius - 2,
                  top: safeY - _kTeacherAvatarRadius - 2,
                  child: GestureDetector(
                    onTap: () => context.push('/members/${data.teacherId}'),
                    child: _TeacherCenterNode(
                      name: data.teacherName,
                      photoUrl: config.resolveUrl(data.teacherPhoto).toString(),
                      verified: data.teacherVerified,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Teacher center node ───────────────────────────────────────────────────────

class _TeacherCenterNode extends StatelessWidget {
  const _TeacherCenterNode({
    required this.name,
    required this.photoUrl,
    required this.verified,
  });

  final String name;
  final String photoUrl;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Öğretmen profili: $name',
      child: Container(
        width: (_kTeacherAvatarRadius + 2) * 2,
        height: (_kTeacherAvatarRadius + 2) * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFB45637),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB45637).withValues(alpha: 0.55),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFF17120F).withValues(alpha: 0.8),
              blurRadius: 4,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipOval(
          child: RemoteAvatar(
            label: name,
            imageUrl: photoUrl,
            radius: _kTeacherAvatarRadius,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

// ── Cohort cluster ────────────────────────────────────────────────────────────

class _CohortCluster extends StatelessWidget {
  const _CohortCluster({
    required this.cohort,
    required this.visible,
    required this.clusterWidth,
    required this.transformController,
    required this.config,
    required this.onMemberTap,
  });

  final TeacherNetworkCohort cohort;
  final int visible;
  final double clusterWidth;
  final TransformationController transformController;
  final dynamic config;
  final ValueChanged<int> onMemberTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar stack
        SizedBox(
          width: clusterWidth,
          height: _kMemberAvatarDiameter,
          child: Stack(
            children: [
              for (int i = 0; i < visible; i++)
                Positioned(
                  left: i * _kMemberAvatarOverlapStep,
                  child: i == _kMaxVisibleAvatars - 1 &&
                          cohort.members.length > _kMaxVisibleAvatars
                      ? _OverflowBadge(
                          extra: cohort.members.length - (_kMaxVisibleAvatars - 1),
                        )
                      : GestureDetector(
                          onTap: () => onMemberTap(cohort.members[i].id),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2A1F18),
                                width: 1.5,
                              ),
                            ),
                            child: RemoteAvatar(
                              label: cohort.members[i].name,
                              imageUrl: config
                                  .resolveUrl(cohort.members[i].photo)
                                  .toString(),
                              radius: _kMemberAvatarDiameter / 2,
                              excludeFromSemantics: false,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Cohort label — always visible
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1F18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF3D2E22),
              width: 1,
            ),
          ),
          child: Text(
            cohort.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB8A090),
              letterSpacing: 0.2,
            ),
          ),
        ),

        // Member names — revealed at higher zoom
        ValueListenableBuilder<Matrix4>(
          valueListenable: transformController,
          builder: (context, matrix, _) {
            final scale = matrix.entry(0, 0);
            final showNames = scale >= _kLodNameThreshold;

            return AnimatedOpacity(
              opacity: showNames ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: showNames
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < math.min(visible, cohort.members.length);
                              i++)
                            Text(
                              cohort.members[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9E8C7D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }
}

// ── Overflow badge ────────────────────────────────────────────────────────────

class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kMemberAvatarDiameter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF3D2E22),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '+$extra',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB8A090),
            ),
          ),
        ),
      ),
    );
  }
}

// ── CustomPainter: connection lines ──────────────────────────────────────────

class _NetworkLinePainter extends CustomPainter {
  const _NetworkLinePainter({
    required this.teacherCenter,
    required this.cohortPositions,
    required this.animValue,
    required this.accent,
  });

  final Offset teacherCenter;
  final List<Offset> cohortPositions;
  final double animValue;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF17120F),
    );

    if (animValue <= 0) return;

    // Central warm glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.14 * animValue),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: teacherCenter, radius: 220),
      );
    canvas.drawCircle(teacherCenter, 220, glowPaint);

    // Connection lines
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.16 * animValue)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final pos in cohortPositions) {
      // Slightly curved: quadratic bezier toward the midpoint offset
      final mid = Offset.lerp(teacherCenter, pos, 0.5)!;
      final controlPoint = mid.translate(
        (pos.dy - teacherCenter.dy) * 0.06,
        -(pos.dx - teacherCenter.dx) * 0.06,
      );
      final path = Path()
        ..moveTo(teacherCenter.dx, teacherCenter.dy)
        ..quadraticBezierTo(
          controlPoint.dx, controlPoint.dy,
          pos.dx, pos.dy,
        );
      canvas.drawPath(path, linePaint);

      // Small dot at cohort end
      final dotPaint = Paint()
        ..color = accent.withValues(alpha: 0.28 * animValue)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.5, dotPaint);
    }

    // Orbit ring (subtle dashed arc)
    if (cohortPositions.isNotEmpty) {
      final orbitalR = (cohortPositions.first - teacherCenter).distance;
      final ringPaint = Paint()
        ..color = accent.withValues(alpha: 0.06 * animValue)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(teacherCenter, orbitalR, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_NetworkLinePainter old) =>
      old.animValue != animValue ||
      old.cohortPositions.length != cohortPositions.length;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyMapView extends StatelessWidget {
  const _EmptyMapView({required this.data});

  final TeacherNetworkMapData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hub_outlined,
              size: 56,
              color: Color(0xFF4A3629),
            ),
            const SizedBox(height: 20),
            Text(
              data.teacherName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD4C4B4),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Henüz onaylı öğrenci bağlantısı yok.\nBağlantı eklendiğinde harita burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7A6558),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
