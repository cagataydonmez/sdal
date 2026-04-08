import 'package:flutter/material.dart';

import '../theme/sdal_theme_tokens.dart';

class SkeletonBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius ?? SdalThemeTokens.radiusMd),
        border: Border.all(color: tokens.panelBorder.withValues(alpha: 0.45)),
      ),
    );
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
