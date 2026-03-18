import { describe, expect, it } from 'vitest';
import { normalizeMenuVisibility, normalizeModuleOrder, resolveLandingPathFromSiteAccess } from '../utils/moduleNavigation.js';

describe('moduleNavigation helpers', () => {
  it('keeps configured order and appends missing menu modules', () => {
    expect(normalizeModuleOrder(['events', 'feed'])).toEqual([
      'events', 'feed', 'explore', 'following', 'groups', 'messages', 'messenger', 'notifications', 'albums', 'games', 'announcements', 'jobs', 'profile', 'help', 'requests'
    ]);
  });

  it('defaults hidden map entries to visible', () => {
    const visibility = normalizeMenuVisibility({ feed: false, messages: true });
    expect(visibility.feed).toBe(false);
    expect(visibility.messages).toBe(true);
    expect(visibility.events).toBe(true);
  });

  it('resolves the first visible and open module when no explicit default exists', () => {
    const landing = resolveLandingPathFromSiteAccess({
      modules: { feed: false, explore: true, events: true },
      menuVisibility: { feed: false, explore: true, events: true },
      moduleMenuOrder: ['events', 'explore', 'feed']
    });
    expect(landing).toBe('/new/events');
  });

  it('ignores explicit defaults that are hidden from the menu', () => {
    const landing = resolveLandingPathFromSiteAccess({
      defaultLandingPage: '/new/events',
      modules: { feed: true, events: true },
      menuVisibility: { feed: true, events: false },
      moduleMenuOrder: ['feed', 'events']
    });
    expect(landing).toBe('/new');
  });
});
