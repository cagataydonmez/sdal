String? mapNotificationWebRouteToApp(String rawRoute) {
  final value = rawRoute.trim();
  if (value.isEmpty) return null;
  final uri = _parseMaybeRelativeUri(value);
  final path = uri?.path ?? value;
  final query = uri != null && uri.hasQuery ? '?${uri.query}' : '';

  if (path.startsWith('/new/network/hub')) return '/network/hub$query';
  if (path.startsWith('/new/network/inbox')) return '/network/inbox$query';
  if (path.startsWith('/new/profile/verification')) {
    return '/profile/verification';
  }
  if (path.startsWith('/new/profile')) return '/profile$query';
  if (path.startsWith('/new/following')) return '/following$query';
  if (path.startsWith('/new/requests')) return '/requests$query';
  if (path.startsWith('/new/groups/')) {
    final id = path.split('/').last;
    return '/groups/$id$query';
  }
  if (path.startsWith('/new/groups')) return '/groups$query';
  if (path.startsWith('/new/events')) return '/events$query';
  if (path.startsWith('/new/announcements')) return '/announcements$query';
  if (path.startsWith('/new/jobs')) return '/jobs$query';
  if (path.startsWith('/new/opportunities')) return '/explore$query';
  if (path.startsWith('/new/albums/photo/')) {
    final id = path.split('/').last;
    return '/albums/photo/$id$query';
  }
  if (path.startsWith('/new/albums/upload')) return '/albums/upload$query';
  if (path.startsWith('/new/albums/')) {
    final id = path.split('/').last;
    return '/albums/$id$query';
  }
  if (path.startsWith('/new/albums')) return '/albums$query';
  if (path.startsWith('/new/members/')) {
    final id = path.split('/').last;
    return '/members/$id';
  }
  if (path.startsWith('/new/messages/')) {
    final id = path.split('/').last;
    return '/messages/$id';
  }
  if (path.startsWith('/new/notifications')) return '/notifications$query';
  return null;
}

Uri? _parseMaybeRelativeUri(String value) {
  final absolute = Uri.tryParse(value);
  if (absolute != null && absolute.hasScheme) return absolute;
  return Uri.tryParse('https://sdal.local$value');
}
