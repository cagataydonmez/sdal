import 'package:flutter/material.dart';

import '../theme/sdal_theme_tokens.dart';

class ChatJumpToLatestButton extends StatelessWidget {
  const ChatJumpToLatestButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: highlighted ? tokens.accentMuted : tokens.panelRaised,
        foregroundColor: highlighted ? tokens.accent : tokens.foreground,
        side: BorderSide(
          color: highlighted ? tokens.accent : tokens.panelBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      label: Text(label),
    );
  }
}
