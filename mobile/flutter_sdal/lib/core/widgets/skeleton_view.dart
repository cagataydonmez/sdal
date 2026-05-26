import 'package:flutter/material.dart';

import '../theme/sdal_theme_tokens.dart';
import '../theme/sdal_ux_profile.dart';

/// A single placeholder block that adapts to the theme's `loadingStyle`.
/// Callers don't need to change — SkeletonBox reads the token automatically.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double? borderRadius;
  final BoxShape shape;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _shimmerPos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _opacity = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _shimmerPos = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  void _reconfigure(SdalLoadingStyle style) {
    switch (style) {
      case SdalLoadingStyle.shimmer:
        _ctrl.duration = const Duration(milliseconds: 1400);
        if (!_ctrl.isAnimating) _ctrl.repeat();
      case SdalLoadingStyle.pulse:
        _ctrl.duration = const Duration(milliseconds: 600);
        if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
      case SdalLoadingStyle.skeleton:
        _ctrl.duration = const Duration(milliseconds: 950);
        if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
      case SdalLoadingStyle.spinner:
      case SdalLoadingStyle.dots:
        _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final style = tokens.loadingStyle;

    if (MediaQuery.of(context).disableAnimations ||
        style == SdalLoadingStyle.spinner ||
        style == SdalLoadingStyle.dots) {
      return _solidBox(tokens);
    }

    _reconfigure(style);

    final br = widget.borderRadius ?? SdalThemeTokens.radiusMd;
    final borderRadius = widget.shape == BoxShape.circle
        ? null
        : BorderRadius.circular(br);

    if (style == SdalLoadingStyle.shimmer) {
      return AnimatedBuilder(
        animation: _shimmerPos,
        builder: (context, child) {
          final pos = _shimmerPos.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment(pos - 1, 0),
                end: Alignment(pos + 1, 0),
                colors: [
                  tokens.panelMuted,
                  tokens.panel.withValues(alpha: 0.95),
                  tokens.panelMuted,
                ],
              ),
            ),
          );
        },
      );
    }

    // skeleton / pulse: opacity pulse
    return FadeTransition(
      opacity: _opacity,
      child: _solidBox(tokens),
    );
  }

  Widget _solidBox(SdalThemeTokens tokens) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle
            ? null
            : BorderRadius.circular(
                widget.borderRadius ?? SdalThemeTokens.radiusMd,
              ),
      ),
    );
  }
}

/// Multi-line skeleton placeholder that adapts to the theme's `loadingStyle`.
/// For `spinner` / `dots` styles this shows a centered indicator instead.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({
    super.key,
    required this.widthFactors,
    this.lineHeight = 12,
    this.spacing = 8,
  });

  final List<double> widthFactors;
  final double lineHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;

    if (tokens.loadingStyle == SdalLoadingStyle.spinner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
            color: tokens.accent,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (tokens.loadingStyle == SdalLoadingStyle.dots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: _BouncingDots(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < widthFactors.length; index++) ...[
            SkeletonBox(
              width: constraints.maxWidth * widthFactors[index],
              height: lineHeight,
              borderRadius: SdalThemeTokens.radiusXs,
            ),
            if (index != widthFactors.length - 1) SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (index / 3.0);
            final t = (_ctrl.value - phase).remainder(1.0).abs();
            final dy = -6.0 * (1 - (t * 2 - 1).abs().clamp(0.0, 1.0));
            return Transform.translate(
              offset: Offset(0, dy),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
