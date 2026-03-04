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
    const legacyScope = String(query?.scope || '').trim();
    const feedTypeRaw = String(query?.feedType || query?.feed || '').trim();
    const filterRaw = String(query?.filter || query?.sort || '').trim();
    const legacyResolved = LEGACY_SCOPE_MAP[legacyScope] || null;
    const feedType = ['main', 'community'].includes(feedTypeRaw)
      ? feedTypeRaw
      : (legacyResolved?.feedType || 'main');
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

    let whereSql = feedType === 'main' ? 'WHERE p.group_id IS NULL' : 'WHERE 1=0';
    const whereParams = [];

    if (feedType === 'community') {
      const year = this.userRepository.findGraduationYearById(viewerId);
      if (!Number.isNaN(year) && Number(year) > 1900) {
        const cohortName = `${year} Mezunları`;
        const group = this.groupRepository.findByName(cohortName);
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

    const items = this.feedRepository.findFeedPage({
      whereSql,
      whereParams,
      limit,
      offset,
      filter,
      viewerId
    });

    return {
      items,
      hasMore: items.length === limit,
      paging: { limit, offset },
      feedType,
      filter
    };
  }
}
