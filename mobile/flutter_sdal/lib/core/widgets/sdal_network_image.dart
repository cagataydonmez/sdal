import 'package:flutter/material.dart';
import 'image_lightbox.dart';
import '../network/legacy_media_value.dart';
import '../theme/sdal_theme_tokens.dart';

class SdalNetworkImage extends StatelessWidget {
  const SdalNetworkImage({
    super.key,
    required this.imageUrl,
    this.lightboxImageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorFallback,
    this.enableFade = true,
    this.enableLightbox = true,
  });

  final String imageUrl;
  final String? lightboxImageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorFallback;
  final bool enableFade;
  final bool enableLightbox;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final fallbackPlaceholder =
        placeholder ??
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.imagePlaceholder,
            borderRadius: borderRadius,
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
    final fallbackError =
        errorFallback ??
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.imageError,
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: tokens.foregroundMuted,
            ),
          ),
        );

    final trimmed = normalizeLegacyMediaValue(imageUrl);
    if (trimmed.isEmpty) {
      return SizedBox(width: width, height: height, child: fallbackError);
    }

    Widget child = Image.network(
      trimmed,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      semanticLabel: semanticLabel,
      frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
        if (!enableFade || wasSynchronouslyLoaded) {
          return image;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: image,
        );
      },
      loadingBuilder: (context, image, loadingProgress) {
        if (loadingProgress == null) return image;
        return fallbackPlaceholder;
      },
      errorBuilder: (context, error, stackTrace) => fallbackError,
    );

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    final lightboxUrl = normalizeLegacyMediaValue(lightboxImageUrl ?? '');
    child = SdalLightboxImage(
      imageProvider: NetworkImage(lightboxUrl.isEmpty ? trimmed : lightboxUrl),
      semanticLabel: semanticLabel,
      enabled: enableLightbox,
      child: child,
    );

    return SizedBox(width: width, height: height, child: child);
  }
}
