import 'package:flutter/material.dart';

import '../theme/sdal_theme_experience.dart';
import '../theme/sdal_theme_tokens.dart';

class SdalLogoBadge extends StatelessWidget {
  const SdalLogoBadge({super.key, required this.size, this.frameSize});

  final double size;
  final double? frameSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final logo = Theme.of(context).sdalExperience.logo;
    final brightness = Theme.of(context).brightness;
    final effectiveFrameSize = frameSize ?? size;
    final effectiveRadius = effectiveFrameSize >= 72
        ? logo.radius.clamp(SdalThemeTokens.radiusMd, SdalThemeTokens.radius2xl)
        : logo.radius.clamp(SdalThemeTokens.radiusXs, SdalThemeTokens.radiusXl);
    const borderWidth = 1.2;
    final shadowOpacity = brightness == Brightness.dark ? 0.28 : 0.08;

    final isLarge = effectiveFrameSize >= 72;
    return SizedBox.square(
      dimension: effectiveFrameSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: logo.frame,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(color: logo.border, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: logo.shadow,
              blurRadius: isLarge ? 32 : 14,
              spreadRadius: isLarge ? 2 : 1,
              offset: Offset(0, isLarge ? 4 : 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowOpacity),
              blurRadius: isLarge ? 18 : 10,
              offset: Offset(0, isLarge ? 8 : 4),
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
              logo.asset,
              width: size,
              height: size,
              fit: logo.fit,
              colorBlendMode: BlendMode.srcOver,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: logo.background,
                child: Center(
                  child: Text(
                    'SDAL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
