import 'package:flutter/material.dart';

import '../theme/sdal_theme_tokens.dart';

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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final box = Container(
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

    if (MediaQuery.of(context).disableAnimations) return box;

    return FadeTransition(opacity: _opacity, child: box);
  }
}

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
