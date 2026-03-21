export const MODULE_CONTROL_ITEMS = [
  { key: 'feed', path: '/new', labelKey: 'nav_feed', defaultLabel: 'Akış', menu: true },
  { key: 'main_feed', path: '', labelKey: '', defaultLabel: 'Ana Akış (Herkese Açık)', menu: false },
  { key: 'year_feed', path: '', labelKey: '', defaultLabel: 'Yıl Akışı (Dönemim)', menu: false },
  { key: 'explore', path: '/new/explore', labelKey: 'nav_explore', defaultLabel: 'Keşfet', menu: true },
  { key: 'following', path: '/new/following', labelKey: 'nav_following', defaultLabel: 'Takip', menu: true },
  { key: 'groups', path: '/new/groups', labelKey: 'nav_groups', defaultLabel: 'Gruplar', menu: true },
  { key: 'messages', path: '/new/messages', labelKey: 'nav_messages', defaultLabel: 'Mesajlar', menu: true },
  { key: 'messenger', path: '/new/messenger', labelKey: 'nav_messenger', defaultLabel: 'Canlı Mesajlaşma', menu: true },
  { key: 'notifications', path: '/new/notifications', labelKey: 'nav_notifications', defaultLabel: 'Bildirimler', menu: true },
  { key: 'albums', path: '/new/albums', labelKey: 'nav_photos', defaultLabel: 'Albüm/Fotolar', menu: true },
  { key: 'games', path: '/new/games', labelKey: 'nav_games', defaultLabel: 'Oyunlar', menu: true },
  { key: 'events', path: '/new/events', labelKey: 'nav_events', defaultLabel: 'Etkinlikler', menu: true },
  { key: 'announcements', path: '/new/announcements', labelKey: 'nav_announcements', defaultLabel: 'Duyurular', menu: true },
  { key: 'jobs', path: '/new/jobs', labelKey: 'nav_jobs', defaultLabel: 'İş İlanları', menu: true },
  { key: 'opportunities', path: '/new/opportunities', labelKey: 'nav_opportunities', defaultLabel: 'Fırsatlar', menu: true },
  { key: 'networking', path: '/new/network/hub', labelKey: '', defaultLabel: 'Ağ Merkezi', menu: false },
  { key: 'teachers_network', path: '/new/network/teachers', labelKey: 'nav_teacher_network', defaultLabel: 'Öğretmen Ağı', menu: true },
  { key: 'profile', path: '/new/profile', labelKey: 'nav_profile', defaultLabel: 'Profil', menu: true },
  { key: 'help', path: '/new/help', labelKey: 'nav_help', defaultLabel: 'Yardım', menu: true },
  { key: 'requests', path: '/new/requests', labelKey: 'requests_title', defaultLabel: 'Üye Talepleri', menu: true }
];

export const MODULE_MENU_ITEMS = MODULE_CONTROL_ITEMS.filter((item) => item.menu && item.path);

export const MODULE_ROUTE_BY_KEY = Object.fromEntries(MODULE_CONTROL_ITEMS.filter((item) => item.path).map((item) => [item.key, item.path]));
export const MODULE_KEY_BY_ROUTE = Object.fromEntries(MODULE_CONTROL_ITEMS.filter((item) => item.path).map((item) => [item.path, item.key]));

export function normalizeModuleOrder(rawOrder, availableKeys = MODULE_MENU_ITEMS.map((item) => item.key)) {
  const allowed = new Set(availableKeys);
  const ordered = [];
  for (const value of Array.isArray(rawOrder) ? rawOrder : []) {
    const key = String(value || '').trim();
    if (!key || !allowed.has(key) || ordered.includes(key)) continue;
    ordered.push(key);
  }
  for (const key of availableKeys) {
    if (!ordered.includes(key)) ordered.push(key);
  }
  return ordered;
}

export function normalizeMenuVisibility(rawVisibility, availableKeys = MODULE_MENU_ITEMS.map((item) => item.key)) {
  const next = Object.fromEntries(availableKeys.map((key) => [key, true]));
  if (!rawVisibility || typeof rawVisibility !== 'object') return next;
  for (const key of availableKeys) {
    if (Object.prototype.hasOwnProperty.call(rawVisibility, key)) {
      next[key] = rawVisibility[key] !== false;
    }
  }
  return next;
}

export function resolveLandingPathFromSiteAccess(siteAccess) {
  const modules = siteAccess?.modules || {};
  const order = normalizeModuleOrder(siteAccess?.moduleMenuOrder, MODULE_MENU_ITEMS.map((item) => item.key));
  const menuVisibility = normalizeMenuVisibility(siteAccess?.menuVisibility, MODULE_MENU_ITEMS.map((item) => item.key));
  const preferredPath = String(siteAccess?.defaultLandingPage || '').trim();

  function isAllowedPath(path) {
    const moduleKey = MODULE_KEY_BY_ROUTE[path];
    if (!moduleKey) return false;
    if (modules[moduleKey] === false) return false;
    if (menuVisibility[moduleKey] === false) return false;
    return true;
  }

  if (preferredPath && preferredPath !== '/new' && isAllowedPath(preferredPath)) {
    return preferredPath;
  }
  if (preferredPath === '/new' && isAllowedPath('/new')) {
    return '/new';
  }

  for (const moduleKey of order) {
    const path = MODULE_ROUTE_BY_KEY[moduleKey];
    if (!path) continue;
    if (!isAllowedPath(path)) continue;
    return path;
  }

  for (const item of MODULE_MENU_ITEMS) {
    if (modules[item.key] === false) continue;
    return item.path;
  }

  return '/new';
}
