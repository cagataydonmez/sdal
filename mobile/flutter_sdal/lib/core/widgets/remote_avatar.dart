import 'package:flutter/material.dart';
import '../theme/sdal_theme_tokens.dart';
import 'sdal_network_image.dart';

class RemoteAvatar extends StatelessWidget {
  const RemoteAvatar({
    super.key,
    required this.label,
    this.imageUrl = '',
    this.radius = 24,
  });

  final String label;
  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeImageUrl(imageUrl);
    final initials = _initialsFor(label);
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: SdalNetworkImage(
          imageUrl: normalizedUrl,
          width: radius * 2,
          height: radius * 2,
          cacheWidth: (radius * 4).round(),
          cacheHeight: (radius * 4).round(),
          semanticLabel: label,
          placeholder: DecoratedBox(
            decoration: BoxDecoration(color: tokens.imagePlaceholder),
            child: Center(
              child: Text(
                initials,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tokens.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          errorFallback: DecoratedBox(
            decoration: BoxDecoration(color: tokens.imageError),
            child: Center(
              child: Text(
                initials,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tokens.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _normalizeImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.toLowerCase() == 'yok' || value.toLowerCase() == 'null') return '';
  return value;
}

String _initialsFor(String label) {
  final parts = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'S';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
