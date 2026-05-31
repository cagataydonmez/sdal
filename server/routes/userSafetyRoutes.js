// User-safety routes for App Store Guideline 1.2 (User-Generated Content):
// - Zero-tolerance EULA acceptance (served + accepted + status)
// - Report (flag) objectionable posts/comments
// - Block / unblock abusive users (blocked content is filtered from the feed)
//
// Tables are created with portable SQL so the same code works on both SQLite
// (local/dev) and Postgres (production), mirroring routes/authSecurityRoutes.js.

export const EULA_DOCUMENT_KEY = 'eula';
export const EULA_DOCUMENT_VERSION = 'v1';
export const EULA_PATH = '/kullanim-kosullari';

const EULA_HTML = `<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SDAL Sosyal – Kullanım Koşulları (EULA)</title></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;line-height:1.6;color:#1f2937;padding:16px;max-width:720px;margin:0 auto;">
<h1>Kullanım Koşulları (Son Kullanıcı Lisans Sözleşmesi)</h1>
<p>SDAL Sosyal uygulamasını kullanarak aşağıdaki koşulları kabul etmiş olursunuz. Bu uygulama,
üyelerin gönderi, yorum, fotoğraf ve mesaj gibi içerikler paylaşabildiği bir topluluk platformudur.</p>

<h2>Uygunsuz İçeriğe ve Kötüye Kullanıma Sıfır Tolerans</h2>
<p><strong>Uygunsuz, saldırgan, nefret söylemi içeren, taciz edici, müstehcen, yasa dışı veya
başkalarının haklarını ihlal eden içeriklere ve kötüye kullanan kullanıcılara karşı sıfır tolerans
politikamız vardır.</strong> Bu tür içerik veya davranış kesinlikle yasaktır ve hesabınızın derhal
askıya alınmasına veya kalıcı olarak kapatılmasına yol açabilir.</p>

<h2>Topluluk Kuralları</h2>
<ul>
<li>Diğer kullanıcılara saygılı davranın; taciz, zorbalık veya tehdit içeren davranışlar yasaktır.</li>
<li>Müstehcen, şiddet içeren, nefret söylemi barındıran veya yasa dışı içerik paylaşmayın.</li>
<li>Spam, dolandırıcılık veya başkalarının kimliğine bürünme yasaktır.</li>
<li>Yalnızca paylaşma hakkına sahip olduğunuz içerikleri paylaşın.</li>
</ul>

<h2>İçerik Denetimi ve Bildirim</h2>
<p>Uygulama içinde her gönderi ve yorum için <strong>bildirme (şikayet)</strong> ve her kullanıcı için
<strong>engelleme</strong> araçları sunulur. Bir kullanıcıyı engellediğinizde, o kullanıcının içerikleri
akışınızdan anında kaldırılır ve durum yöneticilere bildirilir.</p>
<p>Bildirilen uygunsuz içerikler <strong>24 saat içinde</strong> incelenir; ihlal tespit edilen içerik
kaldırılır ve ihlali yapan kullanıcının hesabına gerekli yaptırım uygulanır.</p>

<h2>Sorumluluk</h2>
<p>Paylaştığınız içeriklerden yalnızca siz sorumlusunuz. Bu koşulları kabul etmeyen kullanıcılar
uygulamayı kullanamaz.</p>
<p style="color:#6b7280;font-size:13px;margin-top:24px;">Sürüm: ${EULA_DOCUMENT_VERSION}</p>
</body></html>`;

export function createUserSafetyRuntime({
  dbDriver,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  requireAuth,
  requireAdmin,
  writeAppLog,
  invalidateFeedCache
}) {
  const idColumn = dbDriver === 'postgres' ? 'BIGSERIAL PRIMARY KEY' : 'INTEGER PRIMARY KEY AUTOINCREMENT';
  const nowDefault = 'CURRENT_TIMESTAMP';
  let schemaReady = null;

  async function ensureSchema() {
    if (schemaReady) return schemaReady;
    schemaReady = (async () => {
      await sqlRunAsync(`CREATE TABLE IF NOT EXISTS user_legal_acceptances (
        id ${idColumn},
        user_id INTEGER NOT NULL,
        document_key TEXT NOT NULL,
        document_version TEXT,
        accepted_at TEXT NOT NULL DEFAULT ${nowDefault}
      )`);
      await sqlRunAsync('CREATE UNIQUE INDEX IF NOT EXISTS idx_user_legal_acceptances_user_doc ON user_legal_acceptances (user_id, document_key)');

      await sqlRunAsync(`CREATE TABLE IF NOT EXISTS content_reports (
        id ${idColumn},
        reporter_id INTEGER NOT NULL,
        content_type TEXT NOT NULL,
        content_id TEXT NOT NULL,
        reported_user_id INTEGER,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL DEFAULT ${nowDefault},
        resolved_at TEXT,
        resolved_by INTEGER
      )`);
      await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_content_reports_status_created ON content_reports (status, created_at)');
      await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_content_reports_content ON content_reports (content_type, content_id)');

      await sqlRunAsync(`CREATE TABLE IF NOT EXISTS user_blocks (
        id ${idColumn},
        blocker_id INTEGER NOT NULL,
        blocked_id INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT ${nowDefault}
      )`);
      await sqlRunAsync('CREATE UNIQUE INDEX IF NOT EXISTS idx_user_blocks_pair ON user_blocks (blocker_id, blocked_id)');
      await sqlRunAsync('CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks (blocker_id)');
    })();
    return schemaReady;
  }

  async function hasEulaAcceptance(userId) {
    const row = await sqlGetAsync(
      'SELECT id FROM user_legal_acceptances WHERE user_id = ? AND document_key = ? LIMIT 1',
      [userId, EULA_DOCUMENT_KEY]
    );
    return Boolean(row);
  }

  async function recordEulaAcceptance(userId) {
    if (!userId) return;
    await ensureSchema();
    const now = new Date().toISOString();
    const existing = await sqlGetAsync(
      'SELECT id FROM user_legal_acceptances WHERE user_id = ? AND document_key = ? LIMIT 1',
      [userId, EULA_DOCUMENT_KEY]
    );
    if (existing) {
      await sqlRunAsync(
        'UPDATE user_legal_acceptances SET document_version = ?, accepted_at = ? WHERE id = ?',
        [EULA_DOCUMENT_VERSION, now, existing.id]
      );
    } else {
      await sqlRunAsync(
        'INSERT INTO user_legal_acceptances (user_id, document_key, document_version, accepted_at) VALUES (?, ?, ?, ?)',
        [userId, EULA_DOCUMENT_KEY, EULA_DOCUMENT_VERSION, now]
      );
    }
  }

  async function getBlockedUserIds(userId) {
    if (!userId) return [];
    const rows = await sqlAllAsync('SELECT blocked_id FROM user_blocks WHERE blocker_id = ?', [userId]);
    return rows.map((row) => Number(row.blocked_id)).filter(Boolean);
  }

  async function resolveContentAuthorId(contentType, contentId) {
    try {
      if (contentType === 'post') {
        const row = await sqlGetAsync('SELECT user_id FROM posts WHERE id = ?', [contentId]);
        return row ? Number(row.user_id) : null;
      }
      if (contentType === 'comment') {
        const row = await sqlGetAsync('SELECT user_id FROM post_comments WHERE id = ?', [contentId]);
        return row ? Number(row.user_id) : null;
      }
    } catch {
      return null;
    }
    return null;
  }

  async function createReport({ reporterId, contentType, contentId, reason }) {
    await ensureSchema();
    const reportedUserId = await resolveContentAuthorId(contentType, contentId);
    const now = new Date().toISOString();
    await sqlRunAsync(
      `INSERT INTO content_reports (reporter_id, content_type, content_id, reported_user_id, reason, status, created_at)
       VALUES (?, ?, ?, ?, ?, 'open', ?)`,
      [reporterId, contentType, String(contentId), reportedUserId, String(reason || '').slice(0, 500), now]
    );
    // Notify the developer/moderators that objectionable content was flagged.
    writeAppLog?.('warn', 'content_report_created', {
      reporterId,
      contentType,
      contentId: String(contentId),
      reportedUserId
    });
  }

  function registerRoutes(app) {
    // Kick off table creation eagerly so the feed's user_blocks subquery has a
    // table to read even before onServerStarted awaits ensureSchema().
    ensureSchema().catch((err) => console.error('userSafety ensureSchema failed:', err));

    // Serve the zero-tolerance EULA document (no auth – shown before register/login).
    app.get(EULA_PATH, (_req, res) => {
      res.type('html').send(EULA_HTML);
    });

    app.get('/api/legal/eula/status', requireAuth, async (req, res) => {
      try {
        await ensureSchema();
        const accepted = await hasEulaAcceptance(req.session.userId);
        return res.json({
          accepted,
          documentKey: EULA_DOCUMENT_KEY,
          documentVersion: EULA_DOCUMENT_VERSION,
          path: EULA_PATH
        });
      } catch (err) {
        console.error('eula.status failed:', err);
        return res.status(500).json({ ok: false });
      }
    });

    app.post('/api/legal/eula/accept', requireAuth, async (req, res) => {
      try {
        await recordEulaAcceptance(req.session.userId);
        return res.json({ ok: true, accepted: true });
      } catch (err) {
        console.error('eula.accept failed:', err);
        return res.status(500).json({ ok: false });
      }
    });

    app.post('/api/new/posts/:id/report', requireAuth, async (req, res) => {
      try {
        const contentId = Number(req.params.id || 0);
        if (!contentId) return res.status(400).json({ ok: false, message: 'Geçersiz gönderi.' });
        await createReport({
          reporterId: req.session.userId,
          contentType: 'post',
          contentId,
          reason: req.body?.reason
        });
        return res.json({ ok: true });
      } catch (err) {
        console.error('report.post failed:', err);
        return res.status(500).json({ ok: false });
      }
    });

    app.post('/api/new/posts/:postId/comments/:commentId/report', requireAuth, async (req, res) => {
      try {
        const contentId = Number(req.params.commentId || 0);
        if (!contentId) return res.status(400).json({ ok: false, message: 'Geçersiz yorum.' });
        await createReport({
          reporterId: req.session.userId,
          contentType: 'comment',
          contentId,
          reason: req.body?.reason
        });
        return res.json({ ok: true });
      } catch (err) {
        console.error('report.comment failed:', err);
        return res.status(500).json({ ok: false });
      }
    });

    app.post('/api/new/users/:id/block', requireAuth, async (req, res) => {
      try {
        await ensureSchema();
        const blockerId = Number(req.session.userId);
        const blockedId = Number(req.params.id || 0);
        if (!blockedId) return res.status(400).json({ ok: false, message: 'Geçersiz kullanıcı.' });
        if (blockedId === blockerId) return res.status(400).json({ ok: false, message: 'Kendinizi engelleyemezsiniz.' });
        const target = await sqlGetAsync('SELECT id FROM uyeler WHERE id = ?', [blockedId]);
        if (!target) return res.status(404).json({ ok: false, message: 'Kullanıcı bulunamadı.' });

        const existing = await sqlGetAsync(
          'SELECT id FROM user_blocks WHERE blocker_id = ? AND blocked_id = ? LIMIT 1',
          [blockerId, blockedId]
        );
        if (!existing) {
          await sqlRunAsync(
            'INSERT INTO user_blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, ?)',
            [blockerId, blockedId, new Date().toISOString()]
          );
        }
        // Remove blocked content from the feed instantly + notify the developer.
        invalidateFeedCache?.();
        writeAppLog?.('warn', 'user_block_created', { blockerId, blockedId });
        return res.json({ ok: true, blocked: true });
      } catch (err) {
        console.error('block.create failed:', err);
        return res.status(500).json({ ok: false });
      }
    });

    app.delete('/api/new/users/:id/block', requireAuth, async (req, res) => {
      try {
        await ensureSchema();
        const blockerId = Number(req.session.userId);
        const blockedId = Number(req.params.id || 0);
        if (!blockedId) return res.status(400).json({ ok: false, message: 'Geçersiz kullanıcı.' });
        await sqlRunAsync('DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?', [blockerId, blockedId]);
        invalidateFeedCache?.();
        return res.json({ ok: true, blocked: false });
      } catch (err) {
        console.error('block.delete failed:', err);
        return res.status(500).json({ ok: false });
      }
    });

    app.get('/api/new/blocks', requireAuth, async (req, res) => {
      try {
        await ensureSchema();
        const rows = await sqlAllAsync(
          `SELECT b.blocked_id AS id, u.kadi, u.isim, u.soyisim, u.resim, b.created_at
           FROM user_blocks b
           LEFT JOIN uyeler u ON u.id = b.blocked_id
           WHERE b.blocker_id = ?
           ORDER BY b.created_at DESC`,
          [req.session.userId]
        );
        return res.json({ items: rows });
      } catch (err) {
        console.error('blocks.list failed:', err);
        return res.status(500).json({ ok: false, items: [] });
      }
    });

    // Moderator/admin surface so reports can be actioned within 24h.
    app.get('/api/new/admin/content-reports', requireAdmin, async (req, res) => {
      try {
        await ensureSchema();
        const status = String(req.query?.status || 'open').trim() || 'open';
        const rows = await sqlAllAsync(
          `SELECT r.*, u.kadi AS reporter_kadi, ru.kadi AS reported_kadi
           FROM content_reports r
           LEFT JOIN uyeler u ON u.id = r.reporter_id
           LEFT JOIN uyeler ru ON ru.id = r.reported_user_id
           WHERE r.status = ?
           ORDER BY r.created_at DESC
           LIMIT 200`,
          [status]
        );
        return res.json({ items: rows });
      } catch (err) {
        console.error('admin.contentReports failed:', err);
        return res.status(500).json({ ok: false, items: [] });
      }
    });

    app.post('/api/new/admin/content-reports/:id/resolve', requireAdmin, async (req, res) => {
      try {
        await ensureSchema();
        const reportId = Number(req.params.id || 0);
        if (!reportId) return res.status(400).json({ ok: false });
        await sqlRunAsync(
          'UPDATE content_reports SET status = ?, resolved_at = ?, resolved_by = ? WHERE id = ?',
          ['resolved', new Date().toISOString(), Number(req.session.userId), reportId]
        );
        return res.json({ ok: true });
      } catch (err) {
        console.error('admin.resolveReport failed:', err);
        return res.status(500).json({ ok: false });
      }
    });
  }

  return { ensureSchema, registerRoutes, recordEulaAcceptance, getBlockedUserIds, hasEulaAcceptance };
}
