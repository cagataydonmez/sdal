import { describe, expect, it } from 'vitest';
import {
  groupMenuItemsByCategory,
  normalizeMenuVisibility,
  normalizeModuleOrder,
  resolveLandingPathFromSiteAccess,
  resolveModuleFromPath,
  resolveVisibleMenuItems
} from '../utils/moduleNavigation.js';

describe('moduleNavigation helpers', () => {
  it('keeps configured order and appends missing menu modules', () => {
    expect(normalizeModuleOrder(['events', 'feed'])).toEqual([
      'events', 'feed', 'groups', 'albums', 'announcements', 'networking', 'explore', 'following', 'jobs', 'teachers_network', 'messenger', 'notifications', 'messages', 'profile', 'help', 'requests', 'games'
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

  it('resolves module definitions for nested routes', () => {
    expect(resolveModuleFromPath('/new/messages/compose')?.key).toBe('messages');
    expect(resolveModuleFromPath('/new/network/teachers')?.key).toBe('teachers_network');
  });

  it('groups visible menu items by category', () => {
    const items = resolveVisibleMenuItems({
      modules: {
        feed: true,
        groups: true,
        networking: true,
        profile: true,
        notifications: true,
        albums: false,
        events: false,
        announcements: false,
        explore: false,
        following: false,
        jobs: false,
        opportunities: false,
        teachers_network: false,
        messenger: false,
        messages: false,
        help: false,
        requests: false,
        games: false
      },
      menuVisibility: {
        feed: true,
        groups: true,
        networking: true,
        profile: true,
        notifications: true
      },
      moduleMenuOrder: ['networking', 'feed', 'groups', 'notifications', 'profile']
    });
    const grouped = groupMenuItemsByCategory(items);
    expect(grouped.feed.map((item) => item.key)).toEqual(['feed', 'groups']);
    expect(grouped.network.map((item) => item.key)).toEqual(['networking']);
    expect(grouped.global.map((item) => item.key)).toEqual(['notifications', 'profile']);
  });
});
