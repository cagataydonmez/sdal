import 'package:flutter/material.dart';

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
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDCE7F3),
      foregroundImage: normalizedUrl.isNotEmpty
          ? NetworkImage(normalizedUrl)
          : null,
      onForegroundImageError: normalizedUrl.isNotEmpty ? (_, _) {} : null,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: const Color(0xFF0D2238),
          fontWeight: FontWeight.w700,
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
