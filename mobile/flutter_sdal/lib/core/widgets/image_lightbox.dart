import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/sdal_theme_tokens.dart';

class SdalLightboxImage extends StatelessWidget {
  const SdalLightboxImage({
    super.key,
    required this.child,
    required this.imageProvider,
    this.semanticLabel,
    this.enabled = true,
    this.heroTag,
    this.dismissHint = 'Kapatmak için fotoğrafa dokun',
  });

  final Widget child;
  final ImageProvider<Object> imageProvider;
  final String? semanticLabel;
  final bool enabled;
  final Object? heroTag;
  final String dismissHint;

  @override
  Widget build(BuildContext context) {
    final resolvedHeroTag = heroTag ?? Object();
    final content = Hero(tag: resolvedHeroTag, child: child);
    if (!enabled) return content;

    return Semantics(
      button: true,
      image: true,
      label: semanticLabel == null
          ? 'Fotoğrafı tam ekran aç'
          : '$semanticLabel tam ekran aç',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openSdalImageLightbox(
          context,
          imageProvider: imageProvider,
          heroTag: resolvedHeroTag,
          semanticLabel: semanticLabel,
          dismissHint: dismissHint,
        ),
        child: content,
      ),
    );
  }
}

Future<void> openSdalImageLightbox(
  BuildContext context, {
  required ImageProvider<Object> imageProvider,
  required Object heroTag,
  String? semanticLabel,
  String dismissHint = 'Kapatmak için fotoğrafa dokun',
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _ImageLightboxPage(
            imageProvider: imageProvider,
            heroTag: heroTag,
            semanticLabel: semanticLabel,
            dismissHint: dismissHint,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

Future<void> openSdalFileLightbox(
  BuildContext context, {
  required File file,
  required Object heroTag,
  String? semanticLabel,
  String dismissHint = 'Kapatmak için fotoğrafa dokun',
}) {
  return openSdalImageLightbox(
    context,
    imageProvider: FileImage(file),
    heroTag: heroTag,
    semanticLabel: semanticLabel,
    dismissHint: dismissHint,
  );
}

Future<void> openSdalNetworkLightbox(
  BuildContext context, {
  required String imageUrl,
  required Object heroTag,
  String? semanticLabel,
  String dismissHint = 'Kapatmak için fotoğrafa dokun',
}) {
  return openSdalImageLightbox(
    context,
    imageProvider: NetworkImage(imageUrl),
    heroTag: heroTag,
    semanticLabel: semanticLabel,
    dismissHint: dismissHint,
  );
}

class _ImageLightboxPage extends StatelessWidget {
  const _ImageLightboxPage({
    required this.imageProvider,
    required this.heroTag,
    required this.semanticLabel,
    required this.dismissHint,
  });

  final ImageProvider<Object> imageProvider;
  final Object heroTag;
  final String? semanticLabel;
  final String dismissHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;

    return Material(
      color: tokens.storyOverlay,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    clipBehavior: Clip.none,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Hero(
                        tag: heroTag,
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                          semanticLabel: semanticLabel,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.panel.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(
                        SdalThemeTokens.radiusPill,
                      ),
                      border: Border.all(color: tokens.panelBorder),
                    ),
                    child: IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded, color: tokens.foreground),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.panel.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(
                        SdalThemeTokens.radiusPill,
                      ),
                      border: Border.all(color: tokens.panelBorder),
                    ),
                    child: Text(
                      'Yakınlaştır, sürükle, dokun ve kapan',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                dismissHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.foregroundOnAccent.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
