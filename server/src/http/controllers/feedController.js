import { isHttpError } from '../../shared/httpError.js';
import { toLegacyFeedItem } from '../dto/legacyApiMappers.js';

export function createFeedController({
  feedService,
  enrichWithVariants,
  getImageVariants,
  sqlGet,
  uploadsDir,
  getModuleControlMap,
  buildFeedCacheKey,
  getCacheJson,
  setCacheJson,
  feedCacheTtlSeconds
}) {
  async function getFeed(req, res) {
    try {
      const limit = Math.min(Math.max(parseInt(req.query?.limit || '20', 10), 1), 50);
      const offset = Math.max(parseInt(req.query?.offset || '0', 10), 0);
      const cursor = Math.max(parseInt(req.query?.cursor || '0', 10), 0);
      const cacheEligible = cursor === 0 && offset === 0 && limit <= 30;
      const cacheKey = cacheEligible && typeof buildFeedCacheKey === 'function'
        ? await buildFeedCacheKey(req.session.userId, req.query)
        : '';
      if (cacheKey && typeof getCacheJson === 'function') {
        const cached = await getCacheJson(cacheKey);
        if (cached && Array.isArray(cached.items)) {
          return res.json(cached);
        }
      }

      const data = await feedService.findFeedPage({
        viewerId: req.session.userId,
        query: req.query,
        moduleMap: getModuleControlMap()
      });

      const items = data.items.map((post) => {
        const item = toLegacyFeedItem(post);
        enrichWithVariants({ ...post.legacy, ...item });
        if (post.imageRecordId) {
          const variants = getImageVariants(post.imageRecordId, sqlGet, uploadsDir);
          if (variants) {
            item.variants = {
              thumbUrl: variants.thumbUrl,
              feedUrl: variants.feedUrl,
              fullUrl: variants.fullUrl
            };
          }
        }
        return item;
      });

      const responsePayload = {
        items,
        hasMore: data.hasMore
      };

      if (cacheKey && typeof setCacheJson === 'function') {
        await setCacheJson(cacheKey, responsePayload, feedCacheTtlSeconds || 20);
      }

      return res.json(responsePayload);
    } catch (err) {
      if (isHttpError(err)) {
        if (err.details && typeof err.details === 'object') {
          return res.status(err.statusCode).json(err.details);
        }
        return res.status(err.statusCode).send(err.message);
      }
      console.error('feed.getFeed failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  return { getFeed };
}
