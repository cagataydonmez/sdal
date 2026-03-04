import { isHttpError } from '../../shared/httpError.js';
import { toLegacyFeedItem } from '../dto/legacyApiMappers.js';

export function createFeedController({ feedService, enrichWithVariants, getImageVariants, sqlGet, uploadsDir, getModuleControlMap }) {
  async function getFeed(req, res) {
    try {
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

      return res.json({
        items,
        hasMore: data.hasMore
      });
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
