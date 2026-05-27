import 'package:flutter/material.dart';

import 'sdal_theme_tokens.dart';

enum SdalMicroAppMode {
  hearth,
  atlas,
  pulse,
  ink,
  archive,
  garden,
  spatial,
  bento,
  cinema,
  adaptive,
}

enum SdalPrimaryActionPlacement { pageFab, shellFab, navActionSlot, hidden }

enum SdalOverlayHitTestMode { opaque, controlsOnly }

enum SdalFeedLeadTreatment {
  composerCard,
  structuredControls,
  socialPulse,
  compactScan,
  archiveFeature,
  calmGuide,
  spatialFloat,
  bentoGrid,
  cinematic,
  adaptiveCompact,
}

enum SdalSurfaceMaterial {
  paper,
  precision,
  social,
  ink,
  archive,
  organic,
  glass,
  bento,
  cinema,
  tonal,
}

enum SdalEmptyStateTone {
  guided,
  structured,
  social,
  compact,
  archive,
  calm,
  minimal,
  modular,
  cinematic,
  inline,
}

@immutable
class SdalThemeIdentity {
  const SdalThemeIdentity({
    required this.id,
    required this.scene,
    required this.promise,
    required this.colorStrategy,
    required this.mode,
  });

  final String id;
  final String scene;
  final String promise;
  final String colorStrategy;
  final SdalMicroAppMode mode;
}

@immutable
class SdalLogoProfile {
  const SdalLogoProfile({
    required this.asset,
    required this.frame,
    required this.background,
    required this.border,
    required this.shadow,
    this.padding = 4.0,
    this.radius = SdalThemeTokens.radiusMd,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final Color frame;
  final Color background;
  final Color border;
  final Color shadow;
  final double padding;
  final double radius;
  final BoxFit fit;
}

@immutable
class SdalShellProfile {
  const SdalShellProfile({
    required this.primaryActionPlacement,
    required this.overlayHitTestMode,
    this.prominentActionOnTabs = false,
    this.passThroughTransparentChrome = false,
    this.minimumTapTarget = 44.0,
  });

  final SdalPrimaryActionPlacement primaryActionPlacement;
  final SdalOverlayHitTestMode overlayHitTestMode;
  final bool prominentActionOnTabs;
  final bool passThroughTransparentChrome;
  final double minimumTapTarget;
}

@immutable
class SdalCompositionProfile {
  const SdalCompositionProfile({
    required this.feedLeadTreatment,
    this.listRhythm = 1.0,
    this.controlDensity = 1.0,
    this.contentBreathingRoom = 1.0,
  });

  final SdalFeedLeadTreatment feedLeadTreatment;
  final double listRhythm;
  final double controlDensity;
  final double contentBreathingRoom;
}

@immutable
class SdalComponentProfile {
  const SdalComponentProfile({
    required this.surfaceMaterial,
    required this.emptyStateTone,
    this.preferInlineGuidance = true,
    this.allowDecorativeBlur = false,
  });

  final SdalSurfaceMaterial surfaceMaterial;
  final SdalEmptyStateTone emptyStateTone;
  final bool preferInlineGuidance;
  final bool allowDecorativeBlur;
}

@immutable
class SdalMotionProfile {
  const SdalMotionProfile({
    required this.pressScale,
    required this.routeDurationMs,
    required this.reducedMotionDurationMs,
    this.hapticIntensity = 0.0,
  });

  final double pressScale;
  final int routeDurationMs;
  final int reducedMotionDurationMs;
  final double hapticIntensity;
}

@immutable
class SdalMediaProfile {
  const SdalMediaProfile({
    required this.feedImageAspect,
    required this.avatarFrameWidth,
    this.preferImageOverlays = false,
    this.storyRingWidth = 2.0,
  });

  final double feedImageAspect;
  final double avatarFrameWidth;
  final bool preferImageOverlays;
  final double storyRingWidth;
}

@immutable
class SdalThemeExperience extends ThemeExtension<SdalThemeExperience> {
  const SdalThemeExperience({
    required this.identity,
    required this.logo,
    required this.shell,
    required this.composition,
    required this.components,
    required this.motion,
    required this.media,
  });

  final SdalThemeIdentity identity;
  final SdalLogoProfile logo;
  final SdalShellProfile shell;
  final SdalCompositionProfile composition;
  final SdalComponentProfile components;
  final SdalMotionProfile motion;
  final SdalMediaProfile media;

  factory SdalThemeExperience.fallback(SdalThemeTokens tokens) {
    return SdalThemeExperience(
      identity: const SdalThemeIdentity(
        id: 'fallback',
        scene: 'Community members use SDAL in normal ambient light.',
        promise: 'A familiar, readable SDAL interface.',
        colorStrategy: 'Restrained product palette',
        mode: SdalMicroAppMode.hearth,
      ),
      logo: SdalLogoProfile(
        asset: tokens.logoAsset,
        frame: tokens.panel,
        background: tokens.panelRaised,
        border: tokens.panelBorder,
        shadow: tokens.accent.withValues(alpha: 0.18),
      ),
      shell: const SdalShellProfile(
        primaryActionPlacement: SdalPrimaryActionPlacement.pageFab,
        overlayHitTestMode: SdalOverlayHitTestMode.opaque,
      ),
      composition: const SdalCompositionProfile(
        feedLeadTreatment: SdalFeedLeadTreatment.composerCard,
      ),
      components: const SdalComponentProfile(
        surfaceMaterial: SdalSurfaceMaterial.paper,
        emptyStateTone: SdalEmptyStateTone.guided,
      ),
      motion: const SdalMotionProfile(
        pressScale: 0.98,
        routeDurationMs: 220,
        reducedMotionDurationMs: 80,
      ),
      media: SdalMediaProfile(
        feedImageAspect: tokens.feedImageAspect,
        avatarFrameWidth: 1.0,
      ),
    );
  }

  @override
  SdalThemeExperience copyWith({
    SdalThemeIdentity? identity,
    SdalLogoProfile? logo,
    SdalShellProfile? shell,
    SdalCompositionProfile? composition,
    SdalComponentProfile? components,
    SdalMotionProfile? motion,
    SdalMediaProfile? media,
  }) {
    return SdalThemeExperience(
      identity: identity ?? this.identity,
      logo: logo ?? this.logo,
      shell: shell ?? this.shell,
      composition: composition ?? this.composition,
      components: components ?? this.components,
      motion: motion ?? this.motion,
      media: media ?? this.media,
    );
  }

  @override
  SdalThemeExperience lerp(
    ThemeExtension<SdalThemeExperience>? other,
    double t,
  ) {
    if (other is! SdalThemeExperience) return this;
    return t < 0.5 ? this : other;
  }
}

extension SdalThemeExperienceLookup on ThemeData {
  SdalThemeExperience get sdalExperience {
    final experience = extension<SdalThemeExperience>();
    if (experience != null) return experience;
    final tokens = extension<SdalThemeTokens>() ?? SdalThemeTokens.light;
    return SdalThemeExperience.fallback(tokens);
  }
}
