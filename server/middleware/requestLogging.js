export function requestLoggingMiddleware({ writeAppLog, writeLegacyLog }) {
  return (req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const durationMs = Date.now() - start;
      const meta = {
        method: req.method,
        path: req.path,
        status: res.statusCode,
        durationMs,
        userId: req.session?.userId || null,
        ip: req.ip
      };

      if (req.path.startsWith('/api/')) {
        writeAppLog('info', 'http_request', meta);
      }

      // Hata logları: 4xx/5xx taleplerin tamamı
      if (res.statusCode >= 400) {
        writeLegacyLog('error', 'http_error', {
          ...meta,
          query: req.originalUrl?.includes('?') ? req.originalUrl.split('?')[1] : ''
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

