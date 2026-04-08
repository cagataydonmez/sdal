import 'package:flutter/material.dart';
import '../network/legacy_media_value.dart';
import '../theme/sdal_theme_tokens.dart';

class RemoteAvatar extends StatelessWidget {
  const RemoteAvatar({
    super.key,
    required this.label,
    this.imageUrl = '',
    this.radius = 24,
    this.excludeFromSemantics = false,
  });

  final String label;
  final String imageUrl;
  final double radius;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeImageUrl(imageUrl);
    final initials = _initialsFor(label);
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    final avatar = SizedBox.square(
      dimension: radius * 2,
      child: ClipOval(
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: normalizedUrl.isEmpty
              ? tokens.imageError
              : tokens.imagePlaceholder,
          child: normalizedUrl.isEmpty
              ? _AvatarInitials(initials: initials)
              : Image.network(
                  normalizedUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _AvatarInitials(initials: initials);
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      _AvatarInitials(initials: initials),
                ),
        ),
      ),
    );
    if (excludeFromSemantics) {
      return ExcludeSemantics(child: avatar);
    }
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: avatar),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return Center(
      child: Text(
        initials,
        style: theme.textTheme.titleSmall?.copyWith(
          color: tokens.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _normalizeImageUrl(String raw) {
  return normalizeLegacyMediaValue(raw);
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
