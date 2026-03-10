import { HttpError } from '../shared/httpError.js';

const LEGACY_SCOPE_MAP = {
  all: { feedType: 'main', filter: 'latest' },
  popular: { feedType: 'main', filter: 'popular' },
  following: { feedType: 'main', filter: 'following' },
  cohort: { feedType: 'community', filter: 'latest' }
};

export class FeedService {
  constructor({ userRepository, groupRepository, feedRepository }) {
    this.userRepository = userRepository;
    this.groupRepository = groupRepository;
    this.feedRepository = feedRepository;
  }

  async findFeedPage({ viewerId, query, moduleMap }) {
    const limit = Math.min(Math.max(parseInt(query?.limit || '20', 10), 1), 50);
    const offset = Math.max(parseInt(query?.offset || '0', 10), 0);
    const cursor = Math.max(parseInt(query?.cursor || '0', 10), 0);
    const legacyScope = String(query?.scope || '').trim();
    const modeRaw = String(query?.mode || '').trim().toLowerCase();
    const feedTypeRaw = String(query?.feedType || query?.feed || '').trim();
    const filterRaw = String(query?.filter || query?.sort || '').trim();
    const legacyResolved = LEGACY_SCOPE_MAP[legacyScope] || null;
    const modeResolvedFeedType = modeRaw === 'year'
      ? 'community'
      : (modeRaw === 'global' ? 'main' : '');
    const feedType = ['main', 'community'].includes(feedTypeRaw)
      ? feedTypeRaw
      : (modeResolvedFeedType || legacyResolved?.feedType || 'main');
    const filter = ['latest', 'popular', 'following'].includes(filterRaw)
      ? filterRaw
      : (legacyResolved?.filter || 'latest');

    if (feedType === 'main' && moduleMap?.main_feed === false) {
      throw new HttpError(403, 'Ana akış geçici olarak kapatıldı.', {
        error: 'MODULE_CLOSED',
        moduleKey: 'main_feed',
        message: 'Ana akış geçici olarak kapatıldı.'
      });
    }

    if (feedType === 'community' && moduleMap?.year_feed === false) {
      throw new HttpError(403, 'Dönem akışı geçici olarak kapatıldı.', {
        error: 'MODULE_CLOSED',
        moduleKey: 'year_feed',
        message: 'Dönem akışı geçici olarak kapatıldı.'
      });
    }

    let whereSql = feedType === 'main' ? 'WHERE p.group_id IS NULL' : 'WHERE 1=0';
    const whereParams = [];

    if (feedType === 'community') {
      const year = await this.userRepository.findGraduationYearById(viewerId);
      if (!Number.isNaN(year) && Number(year) > 1900) {
        const cohortName = `${year} Mezunları`;
        const group = await this.groupRepository.findByName(cohortName);
        if (group) {
          whereSql = 'WHERE p.group_id = ?';
          whereParams.push(group.id);
        }
      }
    }

    if (filter === 'following') {
      whereSql += ' AND p.user_id <> ? AND p.user_id IN (SELECT following_id FROM follows WHERE follower_id = ?)';
      whereParams.push(viewerId, viewerId);
    }

    const items = await this.feedRepository.findFeedPage({
      whereSql,
      whereParams,
      limit,
      offset: cursor > 0 ? 0 : offset,
      cursorId: cursor,
      filter,
      viewerId
    });

    const nextCursor = items.length === limit
      ? Number(items[items.length - 1]?.id || 0)
      : 0;

    return {
      items,
      hasMore: items.length === limit,
      paging: {
        limit,
        offset: cursor > 0 ? 0 : offset,
        cursor: cursor > 0 ? cursor : null,
        nextCursor: nextCursor > 0 ? nextCursor : null
      },
      feedType,
      filter
    };
  }
}
