import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.onTap != null) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 70),
        reverseDuration: const Duration(milliseconds: 130),
      );
      _scale = Tween<double>(begin: 1.0, end: 0.975).animate(
        CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut),
      );
    }
  }

  @override
  void didUpdateWidget(SurfaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onTap == null && widget.onTap != null && _ctrl == null) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 70),
        reverseDuration: const Duration(milliseconds: 130),
      );
      _scale = Tween<double>(begin: 1.0, end: 0.975).animate(
        CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut),
      );
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardChild = Padding(padding: widget.padding, child: widget.child);
    if (widget.onTap != null) {
      cardChild = InkWell(
        onTap: widget.onTap,
        onTapDown: (_) => _ctrl?.forward(),
        onTapUp: (_) => _ctrl?.reverse(),
        onTapCancel: () => _ctrl?.reverse(),
        child: cardChild,
      );
    }

    Widget card = Card(
      clipBehavior: Clip.antiAlias,
      color: widget.color,
      child: cardChild,
    );
    if (widget.tooltip != null) {
      card = Tooltip(message: widget.tooltip!, child: card);
    }

    if (_scale != null) {
      card = AnimatedBuilder(
        animation: _scale!,
        builder: (context, child) =>
            Transform.scale(scale: _scale!.value, child: child),
        child: card,
      );
    }

    final shouldWrapSemantics =
        widget.semanticLabel != null || widget.semanticContainer || widget.onTap != null;
    if (!shouldWrapSemantics) return card;

    final semantics = Semantics(
      button: widget.onTap != null,
      container: widget.semanticContainer || widget.onTap != null,
      label: widget.semanticLabel,
      child: widget.semanticLabel == null ? card : ExcludeSemantics(child: card),
    );
    return widget.onTap == null ? semantics : MergeSemantics(child: semantics);
  }
}
