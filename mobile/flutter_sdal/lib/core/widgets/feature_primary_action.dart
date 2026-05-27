import 'package:flutter/material.dart';

class FeaturePrimaryAction {
  const FeaturePrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    String? semanticLabel,
  }) : semanticLabel = semanticLabel ?? label;

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;
}

@immutable
class FeaturePrimaryActionSnapshot {
  const FeaturePrimaryActionSnapshot({
    required this.route,
    required this.action,
  });

  final String route;
  final FeaturePrimaryAction? action;
}

class FeaturePrimaryActionRegistry {
  FeaturePrimaryActionRegistry._();

  static FeaturePrimaryActionSnapshot? _current;
  static final Map<String, FeaturePrimaryAction?> _actionsByRoute =
      <String, FeaturePrimaryAction?>{};

  static final ValueNotifier<FeaturePrimaryActionSnapshot?> notifier =
      ValueNotifier<FeaturePrimaryActionSnapshot?>(null);

  static void update(String route, FeaturePrimaryAction? action) {
    final previousForRoute = _actionsByRoute[route];
    _actionsByRoute[route] = action;
    final next = FeaturePrimaryActionSnapshot(route: route, action: action);
    final current = _current;
    _current = next;
    if (current?.route == route &&
        _sameAction(current?.action, action) &&
        _sameAction(previousForRoute, action)) {
      return;
    }
    notifier.value = next;
  }

  static FeaturePrimaryAction? actionFor(String route) {
    return _actionsByRoute[route];
  }

  static bool _sameAction(
    FeaturePrimaryAction? previous,
    FeaturePrimaryAction? next,
  ) {
    if (previous == null || next == null) return previous == next;
    return previous.icon == next.icon &&
        previous.label == next.label &&
        previous.semanticLabel == next.semanticLabel;
  }
}
