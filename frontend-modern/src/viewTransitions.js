function normalizePathname(pathname) {
  if (!pathname) return '/new';
  try {
    if (typeof pathname === 'string') {
      if (pathname.startsWith('http://') || pathname.startsWith('https://')) {
        return new URL(pathname).pathname || '/new';
      }
      return pathname.startsWith('/') ? pathname : `/${pathname}`;
    }
    if (pathname.pathname) return pathname.pathname;
  } catch {
    return '/new';
  }
  return '/new';
}

export function getRouteTransitionMeta(target) {
  const pathname = normalizePathname(target);
  const segments = pathname.replace(/^\/+|\/+$/g, '').split('/').filter(Boolean);
  const appSegments = segments[0] === 'new' ? segments.slice(1) : segments;
  const [section = '', sub = ''] = appSegments;

  let family = 'default';
  let kind = 'hub';

  if (!section) {
    family = 'feed';
  } else if (['login', 'root-login', 'register', 'activate', 'activation', 'password-reset'].includes(section)) {
    family = 'auth';
    kind = 'form';
  } else if (section === 'messages' || section === 'messenger' || section === 'notifications') {
    family = 'messages';
    kind = section === 'messages' && sub && sub !== 'compose' ? 'detail' : sub === 'compose' ? 'form' : 'hub';
  } else if (section === 'profile' || section === 'requests') {
    family = 'profile';
    kind = sub ? 'form' : section === 'requests' ? 'detail' : 'hub';
  } else if (section === 'albums') {
    family = 'media';
    kind = sub === 'upload' ? 'form' : sub ? 'detail' : 'hub';
  } else if (section === 'games') {
    family = 'games';
    kind = sub ? 'play' : 'hub';
  } else if (section === 'network') {
    family = 'network';
    kind = 'hub';
  } else if (section === 'admin') {
    family = 'admin';
    kind = 'dashboard';
  } else if (section === 'events' || section === 'announcements' || section === 'jobs') {
    family = 'bulletin';
    kind = section === 'jobs' ? 'detail' : 'hub';
  } else if (section === 'explore' || section === 'following' || section === 'members' || section === 'groups') {
    family = 'social';
    kind = section === 'members' || (section === 'groups' && sub) ? 'detail' : 'hub';
  } else if (section === 'help') {
    family = 'default';
    kind = 'detail';
  }

  return { pathname, family, kind };
}

export function applyViewTransitionContext(target) {
  if (typeof document === 'undefined') return;
  const meta = getRouteTransitionMeta(target);
  document.documentElement.dataset.routeTransition = meta.family;
  document.documentElement.dataset.routeKind = meta.kind;
}

export function syncViewTransitionContext(target) {
  if (typeof document === 'undefined') return;
  const meta = getRouteTransitionMeta(target);
  document.documentElement.dataset.routeFamily = meta.family;
  document.documentElement.dataset.routeTransition = meta.family;
  document.documentElement.dataset.routeKind = meta.kind;
  if (document.body) {
    document.body.dataset.routeFamily = meta.family;
    document.body.dataset.routeKind = meta.kind;
  }
}
