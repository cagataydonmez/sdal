import 'package:flutter/material.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.tooltip,
    this.semanticLabel,
    this.semanticContainer = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? semanticLabel;
  final bool semanticContainer;

  @override
  Widget build(BuildContext context) {
    Widget cardChild = Padding(padding: padding, child: child);
    if (onTap != null) {
      cardChild = InkWell(onTap: onTap, child: cardChild);
    }

    Widget card = Card(clipBehavior: Clip.antiAlias, child: cardChild);
    if (tooltip != null) {
      card = Tooltip(message: tooltip!, child: card);
    }

    final shouldWrapSemantics =
        semanticLabel != null || semanticContainer || onTap != null;
    if (!shouldWrapSemantics) return card;

    final semantics = Semantics(
      button: onTap != null,
      container: semanticContainer || onTap != null,
      label: semanticLabel,
      child: semanticLabel == null ? card : ExcludeSemantics(child: card),
    );
    return onTap == null ? semantics : MergeSemantics(child: semantics);
  }
}
