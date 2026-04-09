import 'package:flutter/material.dart';

import '../theme/sdal_theme_tokens.dart';

class SdalLogoBadge extends StatelessWidget {
  const SdalLogoBadge({super.key, required this.size, this.frameSize});

  final double size;
  final double? frameSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final brightness = Theme.of(context).brightness;
    final effectiveFrameSize = frameSize ?? size;
    final effectiveRadius = effectiveFrameSize >= 72
        ? SdalThemeTokens.radiusXl
        : SdalThemeTokens.radiusMd;
    const borderWidth = 1.2;
    final shadowOpacity = brightness == Brightness.dark ? 0.28 : 0.08;

    return SizedBox.square(
      dimension: effectiveFrameSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(color: tokens.panelBorder, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowOpacity),
              blurRadius: effectiveFrameSize >= 72 ? 18 : 10,
              offset: Offset(0, effectiveFrameSize >= 72 ? 8 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all((effectiveFrameSize - size) / 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              (effectiveRadius - borderWidth).clamp(0, effectiveRadius),
            ),
            child: Image.asset(
              'icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
