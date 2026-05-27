import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/sdal_theme_experience.dart';
import '../theme/sdal_theme_tokens.dart';
import '../theme/sdal_ux_profile.dart';

class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.tooltip,
    this.semanticLabel,
    this.semanticContainer = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;
  final String? semanticLabel;
  final bool semanticContainer;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _scale;
  SdalTapFeedback? _currentFeedback;

  void _ensureController(SdalTapFeedback feedback) {
    if (_currentFeedback == feedback) return;
    _currentFeedback = feedback;
    _ctrl?.dispose();
    _ctrl = null;
    _scale = null;

    if (widget.onTap == null) return;

    switch (feedback) {
      case SdalTapFeedback.scalePress:
        _ctrl = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 70),
          reverseDuration: const Duration(milliseconds: 130),
        );
        _scale = Tween<double>(
          begin: 1.0,
          end: 0.975,
        ).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut));
      case SdalTapFeedback.lift:
        _ctrl = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 100),
          reverseDuration: const Duration(milliseconds: 200),
        );
        _scale = Tween<double>(
          begin: 1.0,
          end: 1.02,
        ).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut));
      case SdalTapFeedback.ripple:
      case SdalTapFeedback.highlight:
      case SdalTapFeedback.none:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    // Controller is lazily created in build based on the token.
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final tapFeedback = widget.onTap != null
        ? tokens.tapFeedback
        : SdalTapFeedback.none;
    _ensureController(tapFeedback);

    final cardRadius = tokens.cardRadius.toDouble();

    Widget cardContent = Padding(padding: widget.padding, child: widget.child);

    // ── Tap feedback wrapper ───────────────────────────────────────────
    if (widget.onTap != null) {
      switch (tapFeedback) {
        case SdalTapFeedback.ripple:
          cardContent = InkWell(onTap: widget.onTap, child: cardContent);
        case SdalTapFeedback.scalePress:
        case SdalTapFeedback.lift:
          cardContent = InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _ctrl?.forward(),
            onTapUp: (_) => _ctrl?.reverse(),
            onTapCancel: () => _ctrl?.reverse(),
            child: cardContent,
          );
        case SdalTapFeedback.highlight:
          cardContent = InkWell(
            onTap: widget.onTap,
            highlightColor: tokens.accentMuted.withValues(alpha: 0.40),
            splashColor: tokens.accent.withValues(alpha: 0.12),
            child: cardContent,
          );
        case SdalTapFeedback.none:
          cardContent = GestureDetector(
            onTap: widget.onTap,
            child: cardContent,
          );
      }
    }

    // ── Card style ─────────────────────────────────────────────────────
    Widget card;
    switch (tokens.cardStyle) {
      case SdalCardStyle.glass:
        card = _buildGlassCard(cardContent, tokens, cardRadius);
      case SdalCardStyle.flat:
        card = _buildFlatCard(cardContent, tokens, cardRadius);
      case SdalCardStyle.outlined:
        card = _buildOutlinedCard(cardContent, tokens, cardRadius);
      case SdalCardStyle.tonal:
        card = _buildTonalCard(cardContent, tokens, cardRadius);
      case SdalCardStyle.fullBleed:
        card = _buildFullBleedCard(cardContent, tokens, cardRadius);
      case SdalCardStyle.elevated:
        card = _buildElevatedCard(cardContent, tokens);
    }

    // ── Tooltip ────────────────────────────────────────────────────────
    if (widget.tooltip != null) {
      card = Tooltip(message: widget.tooltip!, child: card);
    }

    // ── Scale animation wrapper ────────────────────────────────────────
    if (_scale != null) {
      card = AnimatedBuilder(
        animation: _scale!,
        builder: (context, child) =>
            Transform.scale(scale: _scale!.value, child: child),
        child: card,
      );
    }

    // ── Semantics ──────────────────────────────────────────────────────
    final shouldWrapSemantics =
        widget.semanticLabel != null ||
        widget.semanticContainer ||
        widget.onTap != null;
    if (!shouldWrapSemantics) return card;

    final semantics = Semantics(
      button: widget.onTap != null,
      container: widget.semanticContainer || widget.onTap != null,
      label: widget.semanticLabel,
      child: widget.semanticLabel == null
          ? card
          : ExcludeSemantics(child: card),
    );
    return widget.onTap == null ? semantics : MergeSemantics(child: semantics);
  }

  Widget _buildElevatedCard(Widget content, SdalThemeTokens tokens) {
    final material = Theme.of(
      context,
    ).sdalExperience.components.surfaceMaterial;
    final radius = BorderRadius.circular(tokens.cardRadius);
    final shadowColor = switch (material) {
      SdalSurfaceMaterial.archive => tokens.warning.withValues(alpha: 0.16),
      SdalSurfaceMaterial.social => tokens.accent.withValues(alpha: 0.14),
      SdalSurfaceMaterial.organic => tokens.success.withValues(alpha: 0.12),
      SdalSurfaceMaterial.paper => tokens.accent.withValues(alpha: 0.10),
      SdalSurfaceMaterial.ink => Colors.black.withValues(alpha: 0.12),
      _ => tokens.foreground.withValues(alpha: 0.08),
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.color ?? tokens.panel,
        borderRadius: radius,
        border: tokens.panelBorderWidth > 0
            ? Border.all(
                color: tokens.panelBorder,
                width: tokens.panelBorderWidth.clamp(0.5, 1.4),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: material == SdalSurfaceMaterial.archive ? 24 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(color: Colors.transparent, child: content),
    );
  }

  Widget _buildGlassCard(
    Widget content,
    SdalThemeTokens tokens,
    double radius,
  ) {
    final sigma = tokens.blurSigma.clamp(0.1, 50.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: (widget.color ?? tokens.panel).withValues(
              alpha: tokens.glassOpacity + 0.55,
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.panelBorder, width: 0.5),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildFlatCard(Widget content, SdalThemeTokens tokens, double radius) {
    return Container(
      decoration: BoxDecoration(
        color: widget.color ?? tokens.panel,
        borderRadius: BorderRadius.circular(radius),
        border: tokens.borderStyle != SdalBorderStyle.none
            ? _buildBorder(tokens)
            : Border.all(color: tokens.panelBorder, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildOutlinedCard(
    Widget content,
    SdalThemeTokens tokens,
    double radius,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: _buildBorder(tokens),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildTonalCard(
    Widget content,
    SdalThemeTokens tokens,
    double radius,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: widget.color ?? cs.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: content,
    );
  }

  Widget _buildFullBleedCard(
    Widget content,
    SdalThemeTokens tokens,
    double radius,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: widget.color,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: content,
    );
  }

  BoxBorder _buildBorder(SdalThemeTokens tokens) {
    return switch (tokens.borderStyle) {
      SdalBorderStyle.none => Border.all(color: Colors.transparent, width: 0),
      SdalBorderStyle.hairline => Border.all(
        color: tokens.panelBorder,
        width: 0.5,
      ),
      SdalBorderStyle.thin => Border.all(color: tokens.panelBorder, width: 1.0),
      SdalBorderStyle.medium => Border.all(
        color: tokens.panelBorder,
        width: 2.0,
      ),
      SdalBorderStyle.accent => Border.all(color: tokens.accent, width: 2.0),
    };
  }
}
