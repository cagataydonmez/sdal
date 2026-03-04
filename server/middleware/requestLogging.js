import crypto from 'crypto';

function createRequestId() {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return crypto.randomBytes(16).toString('hex');
}

export function requestLoggingMiddleware({ writeAppLog, writeLegacyLog }) {
  return (req, res, next) => {
    const incomingRequestId = String(req.headers['x-request-id'] || '').trim();
    const requestId = incomingRequestId || createRequestId();
    req.requestId = requestId;
    res.setHeader('x-request-id', requestId);

    const start = Date.now();
    res.on('finish', () => {
      const durationMs = Date.now() - start;
      const meta = {
        requestId,
        method: req.method,
        path: req.path,
        status: res.statusCode,
        durationMs,
        userId: req.session?.userId || null,
        ip: req.ip,
        query: req.originalUrl?.includes('?') ? req.originalUrl.split('?')[1] : '',
        userAgent: req.headers['user-agent'] || '',
        referer: req.headers.referer || ''
      };

      if (req.path.startsWith('/api/')) {
        writeAppLog('info', 'http_request', meta);
      }

      // Hata logları: 4xx/5xx taleplerin tamamı
      if (res.statusCode >= 400) {
        writeLegacyLog('error', 'http_error', {
          ...meta
        });
      }

      // Üye logları: kimliği belli kullanıcıların yazma işlemleri
      const isWrite = req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH' || req.method === 'DELETE';
      if (req.session?.userId && req.path.startsWith('/api/') && isWrite) {
        writeLegacyLog('member', 'member_activity', meta);
      }

      // Sayfa logları: HTML sayfa görüntülemeleri
      const accept = String(req.headers.accept || '');
      const wantsHtml = accept.includes('text/html');
      const isPageView = req.method === 'GET'
        && !req.path.startsWith('/api/')
        && !req.path.startsWith('/uploads/')
        && !req.path.startsWith('/legacy/')
        && !req.path.startsWith('/smiley/')
        && wantsHtml
        && res.statusCode < 400;
      if (isPageView) {
        writeLegacyLog('page', 'page_view', {
          requestId,
          path: req.path,
          query: req.originalUrl?.includes('?') ? req.originalUrl.split('?')[1] : '',
          userId: req.session?.userId || null,
          ip: req.ip,
          referer: req.headers.referer || '',
          ua: req.headers['user-agent'] || ''
        });
      }
    });
    next();
  };
}
