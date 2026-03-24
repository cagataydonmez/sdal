export const MODULE_CONTROL_ITEMS = [
  { key: 'feed', path: '/new', labelKey: 'nav_feed', defaultLabel: 'Akış', menu: true, category: 'feed' },
  { key: 'main_feed', path: '', labelKey: '', defaultLabel: 'Ana Akış (Herkese Açık)', menu: false, category: 'feed' },
  { key: 'year_feed', path: '', labelKey: '', defaultLabel: 'Yıl Akışı (Dönemim)', menu: false, category: 'feed' },
  { key: 'groups', path: '/new/groups', labelKey: 'nav_groups', defaultLabel: 'Gruplar', menu: true, category: 'feed' },
  { key: 'albums', path: '/new/albums', labelKey: 'nav_photos', defaultLabel: 'Albüm/Fotolar', menu: true, category: 'feed' },
  { key: 'events', path: '/new/events', labelKey: 'nav_events', defaultLabel: 'Etkinlikler', menu: true, category: 'feed' },
  { key: 'announcements', path: '/new/announcements', labelKey: 'nav_announcements', defaultLabel: 'Duyurular', menu: true, category: 'feed' },
  { key: 'networking', path: '/new/network/hub', labelKey: 'nav_network_hub', defaultLabel: 'Ağ Merkezi', menu: true, category: 'network' },
  { key: 'explore', path: '/new/explore', labelKey: 'nav_explore', defaultLabel: 'Keşfet', menu: true, category: 'network' },
  { key: 'following', path: '/new/following', labelKey: 'nav_following', defaultLabel: 'Takip', menu: true, category: 'network' },
  { key: 'jobs', path: '/new/jobs', labelKey: 'nav_jobs', defaultLabel: 'İş İlanları', menu: true, category: 'network' },
  { key: 'opportunities', path: '/new/opportunities', labelKey: 'nav_opportunities', defaultLabel: 'Fırsatlar', menu: true, category: 'network' },
  { key: 'teachers_network', path: '/new/network/teachers', labelKey: 'nav_teacher_network', defaultLabel: 'Öğretmen Ağı', menu: true, category: 'network' },
  { key: 'messenger', path: '/new/messenger', labelKey: 'nav_messenger', defaultLabel: 'SDAL Mesajlaşma', menu: true, category: 'network' },
  { key: 'notifications', path: '/new/notifications', labelKey: 'nav_notifications', defaultLabel: 'Bildirimler', menu: true, category: 'global' },
  { key: 'messages', path: '/new/messages', labelKey: 'nav_messages', defaultLabel: 'SDAL Gelen Kutusu', menu: true, category: 'global' },
  { key: 'profile', path: '/new/profile', labelKey: 'nav_profile', defaultLabel: 'Profil', menu: true, category: 'global' },
  { key: 'help', path: '/new/help', labelKey: 'nav_help', defaultLabel: 'Yardım', menu: true, category: 'global' },
  { key: 'requests', path: '/new/requests', labelKey: 'requests_title', defaultLabel: 'Yönetim Talepleri', menu: true, category: 'global' },
  { key: 'games', path: '/new/games', labelKey: 'nav_games', defaultLabel: 'Oyunlar', menu: true, category: 'global' }
];

export const PRIMARY_NAV_CATEGORIES = [
  { key: 'feed', labelKey: 'nav_feed_category', defaultLabel: 'Akış' },
  { key: 'network', labelKey: 'nav_network_category', defaultLabel: 'Ağ ve Fırsatlar' }
];

export const GLOBAL_NAV_CATEGORY = { key: 'global', labelKey: 'nav_global_category', defaultLabel: 'Genel' };

export const MODULE_MENU_ITEMS = MODULE_CONTROL_ITEMS.filter((item) => item.menu && item.path);

export const MODULE_ROUTE_BY_KEY = Object.fromEntries(MODULE_CONTROL_ITEMS.filter((item) => item.path).map((item) => [item.key, item.path]));
export const MODULE_KEY_BY_ROUTE = Object.fromEntries(MODULE_CONTROL_ITEMS.filter((item) => item.path).map((item) => [item.path, item.key]));
export const MODULE_DEFINITION_BY_KEY = Object.fromEntries(MODULE_CONTROL_ITEMS.map((item) => [item.key, item]));

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

export function resolveVisibleMenuItems(siteAccess) {
  if (!siteAccess?.modules) return [];
  const menuVisibility = normalizeMenuVisibility(siteAccess.menuVisibility);
  const menuOrder = normalizeModuleOrder(siteAccess.moduleMenuOrder);
  const orderIndex = new Map(menuOrder.map((key, index) => [key, index]));

  return MODULE_MENU_ITEMS
    .filter((item) => siteAccess.modules[item.key] !== false)
    .filter((item) => menuVisibility[item.key] !== false)
    .sort((a, b) => {
      const aIndex = orderIndex.has(a.key) ? orderIndex.get(a.key) : Number.MAX_SAFE_INTEGER;
      const bIndex = orderIndex.has(b.key) ? orderIndex.get(b.key) : Number.MAX_SAFE_INTEGER;
      if (aIndex !== bIndex) return aIndex - bIndex;
      return MODULE_MENU_ITEMS.indexOf(a) - MODULE_MENU_ITEMS.indexOf(b);
    });
}

export function resolveModuleFromPath(pathname) {
  const path = String(pathname || '').trim();
  if (!path) return null;
  const candidates = MODULE_CONTROL_ITEMS
    .filter((item) => item.path)
    .sort((a, b) => b.path.length - a.path.length);
  return candidates.find((item) => path === item.path || path.startsWith(`${item.path}/`)) || null;
}

export function resolvePrimaryCategoryForPath(pathname) {
  const moduleItem = resolveModuleFromPath(pathname);
  const category = moduleItem?.category || 'feed';
  return category === 'network' ? 'network' : 'feed';
}

export function groupMenuItemsByCategory(items) {
  return items.reduce((acc, item) => {
    const category = item.category || 'global';
    if (!acc[category]) acc[category] = [];
    acc[category].push(item);
    return acc;
  }, {});
}
