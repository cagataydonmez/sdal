import express from 'express';
import fs from 'fs';
import path from 'path';

export function registerMiscAppRoutes(app, {
  appRootDir,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  requireAdmin,
  hasAdminSession,
  formatUserText,
  normalizeRole,
  isRowOnlineNow,
  mapLegacyUrl
}) {
  const albumPhotoActiveExpr = "(COALESCE(CAST(f.aktif AS INTEGER), 0) = 1 OR LOWER(CAST(f.aktif AS TEXT)) IN ('true','evet','yes'))";

  app.get('/api/album/latest', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
      const rows = await sqlAllAsync(
        `SELECT f.id, f.katid, f.dosyaadi, f.tarih, f.hit, k.kategori
         FROM album_foto f
         LEFT JOIN album_kat k ON k.id = f.katid
         WHERE ${albumPhotoActiveExpr}
         ORDER BY f.id DESC
         LIMIT ? OFFSET ?`,
        [limit, offset]
      );
      res.json({ items: rows, hasMore: rows.length === limit });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/members/latest', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
      const rows = await sqlAllAsync(
        `SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, ilktarih
         FROM uyeler
         WHERE aktiv = 1 AND yasak = 0
         ORDER BY id DESC
         LIMIT ?`,
        [limit]
      );
      res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/tournament/register', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const {
        tisim,
        tktelefon,
        boyismi,
        boymezuniyet,
        ioyismi,
        ioymezuniyet,
        uoyismi,
        uoymezuniyet,
        doyismi,
        doymezuniyet
      } = req.body || {};

      if (!tisim) return res.status(400).send('Takım ismini girmen gerekiyor.');
      if (!tktelefon) return res.status(400).send('Takım kaptanının telefonunu yazman gerekiyor.');
      if (!boyismi || !ioyismi || !uoyismi || !doyismi) return res.status(400).send('Oyuncu isimlerini girmen gerekiyor.');
      if (!boymezuniyet || !ioymezuniyet || !uoymezuniyet || !doymezuniyet) return res.status(400).send('Oyuncu mezuniyetlerini girmen gerekiyor.');

      const cleanTeam = String(tisim).trim().replace(/\s+/g, '-').replace(/'/g, '');
      const cleanPhone = String(tktelefon).trim().replace(/\s+/g, '-').replace(/'/g, '');
      const now = new Date().toISOString();

      await sqlRunAsync(
        `INSERT INTO takimlar (tisim, tkid, tktelefon, boyismi, boymezuniyet, ioyismi, ioymezuniyet, uoyismi, uoymezuniyet, doyismi, doymezuniyet, tarih)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          cleanTeam,
          req.session.userId,
          cleanPhone,
          String(boyismi).trim().replace(/'/g, ''),
          String(boymezuniyet),
          String(ioyismi).trim().replace(/'/g, ''),
          String(ioymezuniyet),
          String(uoyismi).trim().replace(/'/g, ''),
          String(uoymezuniyet),
          String(doyismi).trim().replace(/'/g, ''),
          String(doymezuniyet),
          now
        ]
      );

      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/panolar', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const mkatidRaw = String(req.query.mkatid || '0');
      const mkatid = /^\d+$/.test(mkatidRaw) ? Number(mkatidRaw) : 0;
      let categoryName = 'Genel';
      if (mkatid !== 0) {
        const cat = await sqlGetAsync('SELECT * FROM mesaj_kategori WHERE id = ?', [mkatid]);
        if (!cat) {
          return res.status(400).send('Kategori bulunamadı.');
        }
        categoryName = cat.kategoriadi;
      }

      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const pageSize = 25;
      const [user, totalRow, rows] = await Promise.all([
        sqlGetAsync('SELECT id, mezuniyetyili, oncekisontarih, admin FROM uyeler WHERE id = ?', [req.session.userId]),
        sqlGetAsync('SELECT COUNT(*) AS cnt FROM mesaj WHERE kategori = ?', [mkatid]),
        sqlAllAsync('SELECT * FROM mesaj WHERE kategori = ? ORDER BY tarih DESC LIMIT ? OFFSET ?', [mkatid, pageSize, Math.max((page - 1) * pageSize, 0)])
      ]);
      const gradName = user?.mezuniyetyili ? `${user.mezuniyetyili} Mezunları` : null;
      const gradCategory = gradName ? await sqlGetAsync('SELECT * FROM mesaj_kategori WHERE kategoriadi = ?', [gradName]) : null;

      const total = totalRow?.cnt || 0;
      const pages = Math.max(Math.ceil(total / pageSize), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * pageSize;
      const safeRows = offset === Math.max((page - 1) * pageSize, 0)
        ? rows
        : await sqlAllAsync('SELECT * FROM mesaj WHERE kategori = ? ORDER BY tarih DESC LIMIT ? OFFSET ?', [mkatid, pageSize, offset]);

      const senderIds = Array.from(new Set(
        safeRows.map((row) => Number(row.gonderenid || 0)).filter((id) => Number.isInteger(id) && id > 0)
      ));
      const senderMap = new Map();
      if (senderIds.length > 0) {
        const placeholders = senderIds.map(() => '?').join(', ');
        const senderRows = await sqlAllAsync(
          `SELECT id, kadi, resim
           FROM uyeler
           WHERE id IN (${placeholders})`,
          senderIds
        );
        for (const sender of senderRows) {
          senderMap.set(Number(sender.id || 0), sender);
        }
      }

      const messages = safeRows.map((row) => {
        const userRow = senderMap.get(Number(row.gonderenid || 0)) || { id: row.gonderenid, kadi: 'Üye', resim: 'nophoto.jpg' };
        const msgDate = row.tarih ? new Date(row.tarih) : null;
        const lastDate = user?.oncekisontarih ? new Date(user.oncekisontarih) : null;
        const diffSeconds = msgDate && lastDate ? Math.floor((msgDate.getTime() - lastDate.getTime()) / 1000) : null;
        const isNew = diffSeconds != null && diffSeconds > 0;
        return {
          id: row.id,
          mesajHtml: row.mesaj || '',
          tarih: row.tarih,
          user: userRow,
          diffSeconds,
          isNew
        };
      });

      const pageList = [];
      let start = safePage - 5;
      if (start < 1) start = 1;
      let end = safePage + 5;
      if (end > pages) end = pages;
      for (let i = start; i <= end; i += 1) pageList.push(i);

      return res.json({
        categoryId: mkatid,
        categoryName,
        gradCategory,
        messages,
        total,
        page: safePage,
        pages,
        pageSize,
        pageList,
        canDelete: hasAdminSession(req, user)
      });
    } catch (err) {
      console.error('panolar.list failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/panolar', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const mesaj = String(req.body?.mesaj || '').trim();
      let katid = String(req.body?.katid || '0');
      if (!/^\d+$/.test(katid)) katid = '0';
      if (katid !== '0') {
        const cat = await sqlGetAsync('SELECT id FROM mesaj_kategori WHERE id = ?', [katid]);
        if (!cat) katid = '0';
      }
      if (!mesaj) return res.status(400).send('Mesaj yazmadın.');
      const formatted = formatUserText(mesaj);
      await sqlRunAsync(
        'INSERT INTO mesaj (gonderenid, mesaj, tarih, kategori) VALUES (?, ?, ?, ?)',
        [req.session.userId, formatted, new Date().toISOString(), Number(katid)]
      );
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/panolar/:id', requireAdmin, async (req, res) => {
    try {
      await sqlRunAsync('DELETE FROM mesaj WHERE id = ?', [req.params.id]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/quick-access', async (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const user = await sqlGetAsync('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
    const list = String(user?.hizliliste || '0')
      .split(',')
      .map((v) => v.trim())
      .filter((v) => v && v !== '0');
    const unique = Array.from(
      new Set(
        list
          .map((id) => Number(id))
          .filter((id) => Number.isInteger(id) && id > 0)
      )
    );
    if (!unique.length) return res.json({ users: [] });
    const rows = await sqlAllAsync(
      `SELECT id, kadi, resim, mezuniyetyili, online, sonislemtarih, sonislemsaat, role
       FROM uyeler
       WHERE id IN (${unique.map(() => '?').join(',')})`,
      unique
    );
    const rowMap = new Map(rows.map((row) => [Number(row.id), row]));
    const users = unique
      .map((id) => rowMap.get(id))
      .filter((row) => row && normalizeRole(row.role) !== 'root')
      .map((row) => ({
        id: row.id,
        kadi: row.kadi,
        resim: row.resim,
        mezuniyetyili: row.mezuniyetyili,
        online: isRowOnlineNow(row) ? 1 : 0
      }));
    res.json({ users });
  });

  app.post('/api/quick-access/add', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const id = String(req.body?.id || '').trim();
      if (!/^\d+$/.test(id)) return res.status(400).send('Üye bulunamadı.');
      const target = await sqlGetAsync('SELECT id, role FROM uyeler WHERE id = ?', [id]);
      if (!target || normalizeRole(target.role) === 'root') return res.status(404).send('Üye bulunamadı.');
      const row = await sqlGetAsync('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
      const list = String(row?.hizliliste || '0')
        .split(',')
        .map((v) => v.trim())
        .filter((v) => v && v !== '0');
      if (list.includes(id)) return res.status(400).send('Bu üye zaten hızlı erişim listenizde!');
      list.push(id);
      const updated = list.length ? `0,${list.join(',')}` : '0';
      await sqlRunAsync('UPDATE uyeler SET hizliliste = ? WHERE id = ?', [updated, req.session.userId]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/quick-access/remove', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const id = String(req.body?.id || '').trim();
      const row = await sqlGetAsync('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
      const list = String(row?.hizliliste || '0')
        .split(',')
        .map((v) => v.trim())
        .filter((v) => v && v !== '0' && v !== id);
      const updated = list.length ? `0,${list.join(',')}` : '0';
      await sqlRunAsync('UPDATE uyeler SET hizliliste = ? WHERE id = ?', [updated, req.session.userId]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/games/snake/leaderboard', async (_req, res) => {
    try {
      const rows = await sqlAllAsync('SELECT isim, skor, tarih FROM oyun_yilan ORDER BY skor DESC LIMIT 25');
      res.json({ rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/games/snake/score', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const score = Number(req.body?.score || 0);
      const user = await sqlGetAsync('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
      const name = user?.kadi || 'Misafir';
      const existing = await sqlGetAsync('SELECT * FROM oyun_yilan WHERE isim = ?', [name]);
      if (!existing) {
        await sqlRunAsync('INSERT INTO oyun_yilan (isim, skor, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
      } else if (score > Number(existing.skor || 0)) {
        await sqlRunAsync('UPDATE oyun_yilan SET skor = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/games/tetris/leaderboard', async (_req, res) => {
    try {
      const rows = await sqlAllAsync('SELECT isim, puan, tarih FROM oyun_tetris ORDER BY puan DESC LIMIT 25');
      res.json({ rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/games/tetris/score', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const score = Number(req.body?.score || 0);
      const user = await sqlGetAsync('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
      const name = user?.kadi || 'Misafir';
      const existing = await sqlGetAsync('SELECT * FROM oyun_tetris WHERE isim = ?', [name]);
      if (!existing) {
        await sqlRunAsync('INSERT INTO oyun_tetris (isim, puan, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
      } else if (score > Number(existing.puan || 0)) {
        await sqlRunAsync('UPDATE oyun_tetris SET puan = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/games/arcade/:game/leaderboard', async (req, res) => {
    try {
      const game = String(req.params.game || '').trim().toLowerCase();
      const allowed = new Set(['tap-rush', 'memory-pairs', 'puzzle-2048']);
      if (!allowed.has(game)) return res.status(404).send('Game not found');
      const rows = await sqlAllAsync(
        `SELECT name AS isim, score AS skor, created_at AS tarih
         FROM game_scores
         WHERE game_key = ?
         ORDER BY score DESC, created_at ASC
         LIMIT 25`,
        [game]
      );
      res.json({ rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/games/arcade/:game/score', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const game = String(req.params.game || '').trim().toLowerCase();
      const allowed = new Set(['tap-rush', 'memory-pairs', 'puzzle-2048']);
      if (!allowed.has(game)) return res.status(404).send('Game not found');
      const score = Math.max(0, Math.floor(Number(req.body?.score || 0)));
      const user = await sqlGetAsync('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
      const name = user?.kadi || 'Misafir';
      const existing = await sqlGetAsync('SELECT id, score FROM game_scores WHERE game_key = ? AND name = ?', [game, name]);
      if (!existing) {
        await sqlRunAsync('INSERT INTO game_scores (game_key, name, score, created_at) VALUES (?, ?, ?, ?)', [game, name, score, new Date().toISOString()]);
      } else if (score > Number(existing.score || 0)) {
        await sqlRunAsync('UPDATE game_scores SET score = ?, created_at = ? WHERE id = ?', [score, new Date().toISOString(), existing.id]);
      }
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  const modernDist = path.resolve(appRootDir, '../frontend-modern/dist');
  if (fs.existsSync(modernDist)) {
    const hashedAssetPattern = /[._-][A-Za-z0-9_-]{6,}\.(?:js|mjs|css|png|jpg|jpeg|gif|webp|svg|woff2?|ttf)$/i;
    const modernStaticOptions = {
      etag: true,
      lastModified: true,
      setHeaders(res, filePath) {
        const normalized = String(filePath || '').replace(/\\/g, '/');
        const base = path.basename(normalized);
        if (base === 'index.html') {
          res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
        } else if (hashedAssetPattern.test(base)) {
          res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
        } else {
          res.setHeader('Cache-Control', 'public, max-age=3600, must-revalidate');
        }
      }
    };
    app.use('/new', express.static(modernDist, modernStaticOptions));
    app.use('/sdal_new', express.static(modernDist, modernStaticOptions));
    app.get('/sdal_new', (_req, res) => {
      res.redirect(302, '/new');
    });
    app.get('/sdal_new/*', (req, res) => {
      const suffix = req.path.replace(/^\/sdal_new/, '') || '/';
      res.redirect(302, `/new${suffix}`);
    });
    app.get('/new/*', (_req, res) => {
      res.sendFile(path.join(modernDist, 'index.html'));
    });
  }

  app.get(/\/*.asp$/i, (req, res) => {
    const legacy = path.basename(req.path);
    let target = mapLegacyUrl(legacy);

    if (legacy === 'uyedetay.asp' && req.query.id) target = `/uyeler/${req.query.id}`;
    if (legacy === 'mesajgor.asp' && req.query.mid) target = `/mesajlar/${req.query.mid}?k=${req.query.kk || 0}`;
    if (legacy === 'albumkat.asp' && req.query.kat) target = `/album/${req.query.kat}`;
    if (legacy === 'aktgnd.asp' && req.query.id) target = `/aktivasyon-gonder?id=${req.query.id}`;
    if (legacy === 'aktivet.asp' && req.query.id && req.query.akt) target = `/aktivet?id=${req.query.id}&akt=${req.query.akt}`;
    if (legacy === 'fotogoster.asp' && req.query.fid) target = `/album/foto/${req.query.fid}`;
    if ((legacy === 'pano.asp' || legacy === 'panolar.asp' || legacy === 'mesajpanosu.asp') && req.query.mkatid) {
      target = `/panolar?mkatid=${req.query.mkatid}`;
    }
    if (legacy === 'hizlierisimekle.asp' && req.query.uid) target = `/hizli-erisim/ekle?uid=${req.query.uid}`;
    if (legacy === 'hizlierisimcikart.asp' && req.query.uid) target = `/hizli-erisim/cikart?uid=${req.query.uid}`;

    return res.redirect(302, target);
  });

  const clientDist = path.resolve(appRootDir, '../frontend-classic/dist');
  app.use(express.static(clientDist));
  app.get('*', (_req, res) => {
    res.sendFile(path.join(clientDist, 'index.html'));
  });
}
