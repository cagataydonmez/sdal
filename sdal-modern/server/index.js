import 'dotenv/config';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import session from 'express-session';
import cookieParser from 'cookie-parser';
import morgan from 'morgan';
import { sqlGet, sqlAll, sqlRun, dbPath } from './db.js';
import { mapLegacyUrl } from './legacyRoutes.js';
import fs from 'fs';
import sharp from 'sharp';
import { metinDuzenle } from './textFormat.js';
import nodemailer from 'nodemailer';
import multer from 'multer';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 8787;

app.use(morgan('dev'));
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(
  session({
    secret: process.env.SDAL_SESSION_SECRET || 'sdal-dev-secret',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 1000 * 60 * 60 * 2
    }
  })
);

const legacyDir = path.resolve(__dirname, '../client/public/legacy');
app.use('/legacy', express.static(legacyDir));
app.use('/smiley', express.static(path.join(legacyDir, 'smiley')));

const uploadsDir = path.resolve(__dirname, '../uploads');
app.use('/uploads', express.static(uploadsDir));
const vesikalikDir = path.join(uploadsDir, 'vesikalik');
if (!fs.existsSync(vesikalikDir)) {
  fs.mkdirSync(vesikalikDir, { recursive: true });
}
const albumDir = path.join(uploadsDir, 'album');
if (!fs.existsSync(albumDir)) {
  fs.mkdirSync(albumDir, { recursive: true });
}

const allowedImageExts = new Set(['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif']);
const photoUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, vesikalikDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, `${req.session.userId}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmediniz.'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 5 * 1024 * 1024 }
});

const albumUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, albumDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const now = new Date();
      const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
      cb(null, `${req.session.userId}${stamp}${ext || '.jpg'}`);
    }
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!allowedImageExts.has(ext)) {
      cb(new Error('Geçerli bir resim dosyası girmedin. ( Geçerli dosya türleri : jpg,gif,png )'));
    } else {
      cb(null, true);
    }
  },
  limits: { fileSize: 5 * 1024 * 1024 }
});

let mailTransportPromise = null;
function getMailTransport() {
  if (mailTransportPromise) return mailTransportPromise;
  mailTransportPromise = (async () => {
    if (process.env.MAILTRAP_API_TOKEN) {
      try {
        const { MailtrapTransport } = await import('mailtrap');
        const inboxId = Number(process.env.MAILTRAP_INBOX_ID || 0) || undefined;
        return nodemailer.createTransport(
          MailtrapTransport({
            token: process.env.MAILTRAP_API_TOKEN,
            sandbox: true,
            testInboxId: inboxId
          })
        );
      } catch (err) {
        console.error('Mailtrap transport init failed:', err?.message || err);
      }
    }

    const host = process.env.SMTP_HOST;
    if (!host) return null;
    const port = Number(process.env.SMTP_PORT || 587);
    const secure =
      (process.env.SMTP_SECURE || '').toLowerCase() === 'true' || port === 465;
    return nodemailer.createTransport({
      host,
      port,
      secure,
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
      tls: process.env.SMTP_TLS_REJECT_UNAUTHORIZED
        ? { rejectUnauthorized: (process.env.SMTP_TLS_REJECT_UNAUTHORIZED || '').toLowerCase() !== 'false' }
        : undefined
    });
  })();
  return mailTransportPromise;
}


const baseUrl = process.env.SDAL_BASE_URL || `http://localhost:${port}`;
const adminPassword = process.env.SDAL_ADMIN_PASSWORD || 'guuk';
const legacyRoot = path.resolve(__dirname, '../..');
const hatalogDir = path.join(legacyRoot, 'hatalog');
const sayfalogDir = path.join(legacyRoot, 'sayfalog');
const uyedetaylogDir = path.join(legacyRoot, 'uyedetaylog');

// Ensure admin email tables exist
sqlRun(`CREATE TABLE IF NOT EXISTS email_kategori (
  id INTEGER PRIMARY KEY,
  ad TEXT,
  tur TEXT,
  deger TEXT,
  aciklama TEXT
)`);
sqlRun(`CREATE TABLE IF NOT EXISTS email_sablon (
  id INTEGER PRIMARY KEY,
  ad TEXT,
  konu TEXT,
  icerik TEXT,
  olusturma DateTime
)`);

function getCurrentUser(req) {
  if (!req.session.userId) return null;
  return sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.session.userId]);
}

function requireAuth(req, res, next) {
  if (!req.session.userId) return res.status(401).send('Login required');
  return next();
}

function requireAdmin(req, res, next) {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.admin !== 1) return res.status(403).send('Admin erişimi gerekli.');
  if (!req.session.adminOk) return res.status(403).send('Admin giriş gerekli.');
  req.adminUser = user;
  return next();
}

function requireAlbumAdmin(req, res, next) {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.albumadmin !== 1 && user.admin !== 1) return res.status(403).send('Albüm yönetimi yetkisi gerekli.');
  if (user.admin === 1 && !req.session.adminOk) return res.status(403).send('Admin giriş gerekli.');
  req.adminUser = user;
  return next();
}

function listLogFiles(dirPath) {
  if (!fs.existsSync(dirPath)) return [];
  const entries = fs.readdirSync(dirPath);
  return entries
    .map((name) => {
      const full = path.join(dirPath, name);
      const stat = fs.statSync(full);
      return { name, size: stat.size, mtime: stat.mtime };
    })
    .sort((a, b) => b.mtime - a.mtime);
}

function readLogFile(dirPath, name) {
  const safeName = String(name || '').replace(/[^a-zA-Z0-9._-]/g, '');
  if (!safeName) return null;
  const full = path.join(dirPath, safeName);
  if (!fs.existsSync(full)) return null;
  return fs.readFileSync(full, 'utf-8');
}

function createActivation() {
  const chars = 'abdefghijklmoprstuvyzABDEFGHIKLMOPRSTUVYZ';
  let out = 'SdAl';
  for (let i = 0; i < 20; i += 1) {
    const idx = Math.floor(Math.random() * chars.length);
    out += chars[idx];
  }
  return out;
}

async function sendMail({ to, subject, html, from }) {
  const mailTransport = await getMailTransport();
  if (!mailTransport) {
    console.log('MAIL (mock):', { to, subject });
    return;
  }
  const sender = from || process.env.SMTP_FROM || 'sdal@sdal.org';
  await mailTransport.sendMail({ from: sender, to, subject, html });
}

function normalizeEmail(email) {
  return String(email || '').trim();
}

function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeEmail(email));
}

function extractEmails(input) {
  const raw = String(input || '').trim();
  if (!raw) return [];
  // Handle "Name <email@example.com>" format
  const angleMatch = raw.match(/<([^>]+)>/);
  if (angleMatch) return [angleMatch[1].trim()];
  // Allow multiple emails separated by comma/semicolon/whitespace
  return raw
    .split(/[\\s,;]+/)
    .map((value) => value.trim())
    .filter(Boolean);
}

function filterKufur(text) {
  try {
    const rows = sqlAll('SELECT kufur FROM filtre');
    if (!rows.length) return null;
    const words = String(text || '').split(/\\s+/);
    for (const row of rows) {
      if (words.includes(row.kufur)) {
        return row.kufur;
      }
    }
    return null;
  } catch {
    return null;
  }
}

const legacyMediaDir = path.resolve(__dirname, '../client/public/legacy');

function resolveMediaFile(file) {
  if (!file) return null;
  const clean = String(file).replace(/\/+|\.\.+/g, '');
  const candidates = [
    path.join(uploadsDir, clean),
    path.join(uploadsDir, 'album', clean),
    path.join(uploadsDir, 'vesikalik', clean),
    path.join(legacyMediaDir, clean),
    path.join(legacyMediaDir, 'vesikalik', clean)
  ];
  return candidates.find((p) => fs.existsSync(p)) || null;
}

app.get('/api/media/vesikalik/:file', (req, res) => {
  const filePath = resolveMediaFile(req.params.file) || path.join(legacyMediaDir, 'vesikalik', 'nophoto.jpg');
  res.sendFile(filePath);
});

app.get('/api/media/kucukresim', async (req, res) => {
  const width = parseInt(req.query.width || req.query.iwidth || '0', 10);
  const height = parseInt(req.query.height || req.query.iheight || '0', 10);
  const file = req.query.file || req.query.r;
  const filePath = resolveMediaFile(file);
  if (!filePath) return res.status(404).send('File not found');

  try {
    let image = sharp(filePath);
    if (width || height) {
      image = image.resize({ width: width || null, height: height || null, fit: 'inside' });
    }
    res.type('image/jpeg');
    const buf = await image.jpeg({ quality: 85 }).toBuffer();
    res.send(buf);
  } catch (err) {
    res.status(500).send('Image processing failed');
  }
});

app.get('/api/health', (req, res) => {
  res.json({ ok: true, dbPath });
});

app.get('/api/captcha', (req, res) => {
  const code = String(Math.floor(100000 + Math.random() * 900000));
  req.session.captcha = code;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="140" height="40">\n` +
    `<rect width="100%" height="100%" fill="#33ff55"/>\n` +
    `<text x="10" y="27" font-family="Tahoma" font-size="20" fill="#000033">${code}</text>\n` +
    `</svg>`;
  res.setHeader('Content-Type', 'image/svg+xml');
  res.setHeader('Cache-Control', 'no-store');
  res.send(svg);
});

app.get('/api/session', (req, res) => {
  if (!req.session.userId) {
    return res.json({ user: null });
  }
  const user = sqlGet('SELECT id, kadi, isim, soyisim, resim AS photo, admin FROM uyeler WHERE id = ?', [req.session.userId]);
  res.json({ user: user || null });
});

app.post('/api/auth/login', (req, res) => {
  const { kadi, sifre } = req.body || {};
  if (!kadi) return res.status(400).send('Kullanıcı adını yazmazsan siteye giremezsin.');
  if (!sifre) return res.status(400).send('Siteye girmek için şifreni de yazman gerekiyor.');

  const user = sqlGet('SELECT * FROM uyeler WHERE kadi = ?', [kadi]);
  if (!user) {
    return res.status(400).send('Sdal.org sitesinde böyle bir kullanıcı henüz kayıtlı değil.');
  }
  if (user.yasak === 1) {
    return res.status(400).send(`Merhaba ${user.isim || ''} ${user.soyisim || ''}, siteye girişiniz yasaklanmış!`);
  }
  if (user.aktiv === 0) {
    return res.status(400).send(`Onay işleminizi henüz tamamlamamışsınız. Aktivasyon maili için /aktivasyon-gonder?id=${user.id}`);
  }
  if (String(user.sifre || '') !== String(sifre)) {
    return res.status(400).send('Girdiğin şifre yanlış!');
  }

  const now = new Date();
  const prevDate = user.sonislemtarih && user.sonislemsaat ? `${user.sonislemtarih} ${user.sonislemsaat}` : null;
  sqlRun(
    `UPDATE uyeler
     SET online = 1,
         hit = COALESCE(hit, 0) + 1,
         sontarih = ?,
         oncekisontarih = ?,
         sonislemtarih = ?,
         sonislemsaat = ?,
         sonip = ?
     WHERE id = ?`,
    [now.toISOString(), prevDate || now.toISOString(), now.toISOString().slice(0, 10), now.toTimeString().slice(0, 8), req.ip, user.id]
  );

  req.session.userId = user.id;
  res.cookie('uyegiris', 'evet');
  res.cookie('uyeid', String(user.id));
  res.cookie('kadi', user.kadi);

  res.json({
    user: { id: user.id, kadi: user.kadi, isim: user.isim, soyisim: user.soyisim, photo: user.resim, admin: user.admin },
    needsProfile: user.ilkbd === 0
  });
});

app.post('/api/auth/logout', (req, res) => {
  if (req.session.userId) {
    sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [req.session.userId]);
  }
  req.session.destroy(() => {
    res.clearCookie('uyegiris');
    res.clearCookie('uyeid');
    res.clearCookie('kadi');
    res.clearCookie('admingiris');
    res.status(204).send();
  });
});

app.get('/api/admin/session', (req, res) => {
  if (!req.session.userId) return res.json({ user: null, adminOk: false });
  const user = sqlGet('SELECT id, kadi, isim, soyisim, admin, albumadmin FROM uyeler WHERE id = ?', [req.session.userId]);
  res.json({ user: user || null, adminOk: !!req.session.adminOk });
});

app.post('/api/admin/login', (req, res) => {
  const user = getCurrentUser(req);
  if (!user) return res.status(401).send('Login required');
  if (user.admin !== 1) return res.status(403).send('Admin erişimi gerekli.');
  const password = String(req.body?.password || '');
  if (!password) return res.status(400).send('Şifre girmedin.');
  if (password !== adminPassword) return res.status(400).send('Şifre yanlış.');
  req.session.adminOk = true;
  res.cookie('admingiris', 'evet');
  res.json({ ok: true });
});

app.post('/api/admin/logout', (req, res) => {
  req.session.adminOk = false;
  res.clearCookie('admingiris');
  res.json({ ok: true });
});

app.get('/api/admin/users/lists', requireAdmin, (req, res) => {
  const filter = String(req.query.filter || 'all');
  let where = '';
  let order = 'kadi';
  if (filter === 'active') where = 'aktiv = 1 AND yasak = 0';
  if (filter === 'pending') where = 'aktiv = 0 AND yasak = 0';
  if (filter === 'banned') where = 'yasak = 1';
  if (filter === 'online') where = 'online = 1';
  if (filter === 'recent') order = 'sontarih DESC';
  const query = `SELECT id, kadi, isim, soyisim, aktiv, yasak, online, sontarih FROM uyeler ${where ? `WHERE ${where}` : ''} ORDER BY ${order}`;
  res.json({ users: sqlAll(query) });
});

app.get('/api/admin/users/search', requireAdmin, (req, res) => {
  const query = String(req.query.q || '');
  const onlyWithPhoto = String(req.query.res || '') === '1';
  if (onlyWithPhoto) {
    const users = sqlAll("SELECT id, kadi, isim, soyisim, resim FROM uyeler WHERE resim <> 'yok' ORDER BY kadi");
    return res.json({ users });
  }
  if (!query) return res.status(400).send('Aranacak anahtar kelime girmedin.');
  const term = `%${query}%`;
  const users = sqlAll(
    'SELECT id, kadi, isim, soyisim, resim FROM uyeler WHERE kadi LIKE ? OR isim LIKE ? OR soyisim LIKE ? ORDER BY kadi',
    [term, term, term]
  );
  res.json({ users });
});

app.get('/api/admin/users/:id', requireAdmin, (req, res) => {
  const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.params.id]);
  if (!user) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  res.json({ user });
});

app.put('/api/admin/users/:id', requireAdmin, (req, res) => {
  const target = sqlGet('SELECT * FROM uyeler WHERE id = ?', [req.params.id]);
  if (!target) return res.status(404).send('Böyle bir üye bulunmamaktadır.');
  if (String(req.adminUser.id) !== '1' && String(target.id) === '1') {
    return res.status(403).send('Bu kullanıcıyı düzenleyemezsiniz.');
  }
  const payload = req.body || {};
  const sifre = String(payload.sifre || '');
  const fields = {
    isim: String(payload.isim || '').trim(),
    soyisim: String(payload.soyisim || '').trim(),
    aktivasyon: String(payload.aktivasyon || '').trim(),
    email: normalizeEmail(payload.email),
    aktiv: Number(payload.aktiv),
    yasak: Number(payload.yasak),
    ilkbd: Number(payload.ilkbd),
    websitesi: String(payload.websitesi || '').trim(),
    imza: String(payload.imza || ''),
    meslek: String(payload.meslek || '').trim(),
    sehir: String(payload.sehir || '').trim(),
    mailkapali: Number(payload.mailkapali),
    hit: Number(payload.hit),
    mezuniyetyili: String(payload.mezuniyetyili || '').trim(),
    universite: String(payload.universite || '').trim(),
    dogumgun: String(payload.dogumgun || '').trim(),
    dogumay: String(payload.dogumay || '').trim(),
    dogumyil: String(payload.dogumyil || '').trim(),
    admin: Number(payload.admin),
    resim: String(payload.resim || '').trim() || 'yok'
  };

  if (!fields.isim) return res.status(400).send('İsmini girmedin.');
  if (!fields.soyisim) return res.status(400).send('Soyisim girmedin.');
  if (!fields.aktivasyon) return res.status(400).send('Aktivasyon Kodu girmedin.');
  if (!fields.email) return res.status(400).send('E-mail girmedin.');
  if (!validateEmail(fields.email)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const numericFields = ['aktiv', 'yasak', 'ilkbd', 'mailkapali', 'hit', 'admin'];
  for (const key of numericFields) {
    if (Number.isNaN(fields[key])) return res.status(400).send(`${key} bir sayı olmalıdır.`);
  }

  if (String(req.adminUser.id) === '1') {
    if (!sifre) return res.status(400).send('Şifre girmedin.');
    sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [sifre, target.id]);
  }

  sqlRun(
    `UPDATE uyeler
     SET isim = ?, soyisim = ?, aktivasyon = ?, email = ?, aktiv = ?, yasak = ?, ilkbd = ?, websitesi = ?,
         imza = ?, meslek = ?, sehir = ?, mailkapali = ?, hit = ?, mezuniyetyili = ?, universite = ?,
         dogumgun = ?, dogumay = ?, dogumyil = ?, admin = ?, resim = ?
     WHERE id = ?`,
    [
      fields.isim, fields.soyisim, fields.aktivasyon, fields.email, fields.aktiv, fields.yasak, fields.ilkbd,
      fields.websitesi, fields.imza, fields.meslek, fields.sehir, fields.mailkapali, fields.hit,
      fields.mezuniyetyili, fields.universite, fields.dogumgun, fields.dogumay, fields.dogumyil,
      fields.admin, fields.resim, target.id
    ]
  );
  res.json({ ok: true });
});

app.get('/api/admin/pages', requireAdmin, (_req, res) => {
  const pages = sqlAll('SELECT * FROM sayfalar ORDER BY sayfaismi');
  res.json({ pages });
});

app.post('/api/admin/pages', requireAdmin, (req, res) => {
  const body = req.body || {};
  const sayfaismi = String(body.sayfaismi || '').trim();
  const sayfaurl = String(body.sayfaurl || '').trim();
  const babaid = String(body.babaid || '0').trim();
  const menugorun = Number(body.menugorun);
  const yonlendir = Number(body.yonlendir);
  const mozellik = Number(body.mozellik);
  const resim = String(body.resim || '').trim();
  if (!sayfaismi) return res.status(400).send('Sayfa ismini girmedin.');
  if (!sayfaurl) return res.status(400).send('Sayfa adresini girmedin.');
  if (Number.isNaN(Number(babaid))) return res.status(400).send('BabaID bir sayı olmalıdır.');
  if (!resim) return res.status(400).send('Resim girmedin. Eğer resim yoksa yok yazmalısın.');
  sqlRun(
    `INSERT INTO sayfalar (sayfaismi, sayfaurl, babaid, menugorun, yonlendir, mozellik, resim)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [sayfaismi, sayfaurl, Number(babaid), menugorun, yonlendir, mozellik, resim]
  );
  res.json({ ok: true });
});

app.put('/api/admin/pages/:id', requireAdmin, (req, res) => {
  const body = req.body || {};
  const sayfaismi = String(body.sayfaismi || '').trim();
  const sayfaurl = String(body.sayfaurl || '').trim();
  const babaid = String(body.babaid || '0').trim();
  const menugorun = Number(body.menugorun);
  const yonlendir = Number(body.yonlendir);
  const mozellik = Number(body.mozellik);
  const resim = String(body.resim || '').trim();
  if (!sayfaismi) return res.status(400).send('Sayfa ismini girmedin.');
  if (!sayfaurl) return res.status(400).send('Sayfa adresini girmedin.');
  if (Number.isNaN(Number(babaid))) return res.status(400).send('BabaID bir sayı olmalıdır.');
  if (!resim) return res.status(400).send('Resim girmedin. Eğer resim yoksa yok yazmalısın.');
  sqlRun(
    `UPDATE sayfalar SET sayfaismi = ?, sayfaurl = ?, babaid = ?, menugorun = ?, yonlendir = ?, mozellik = ?, resim = ?
     WHERE id = ?`,
    [sayfaismi, sayfaurl, Number(babaid), menugorun, yonlendir, mozellik, resim, req.params.id]
  );
  res.json({ ok: true });
});

app.delete('/api/admin/pages/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM sayfalar WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/logs', requireAdmin, (req, res) => {
  const type = String(req.query.type || 'error');
  const file = req.query.file;
  const map = {
    error: hatalogDir,
    page: sayfalogDir,
    member: uyedetaylogDir
  };
  const dir = map[type] || hatalogDir;
  if (file) {
    const content = readLogFile(dir, file);
    if (!content) return res.status(404).send('Dosya Bulunamadı!');
    return res.json({ file, content });
  }
  res.json({ files: listLogFiles(dir) });
});

app.post('/api/admin/email/send', requireAdmin, async (req, res) => {
  const { to, from, subject, html } = req.body || {};
  if (!to) return res.status(400).send('E-Mailin kime gideceğini girmedin.');
  if (!from) return res.status(400).send('E-Mailin kimden gideceğini girmedin.');
  if (!subject) return res.status(400).send('E-Mailin konusunu girmedin.');
  if (!html) return res.status(400).send('E-Mailin metnini girmedin.');
  await sendMail({ to, subject, html, from });
  res.json({ ok: true });
});

app.get('/api/admin/email/categories', requireAdmin, (_req, res) => {
  const rows = sqlAll('SELECT * FROM email_kategori ORDER BY id DESC');
  res.json({ categories: rows });
});

app.post('/api/admin/email/categories', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const tur = String(req.body?.tur || '').trim();
  const deger = String(req.body?.deger || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  if (!ad) return res.status(400).send('Kategori adı girmedin.');
  if (!tur) return res.status(400).send('Kategori türü girmedin.');
  sqlRun('INSERT INTO email_kategori (ad, tur, deger, aciklama) VALUES (?, ?, ?, ?)', [ad, tur, deger, aciklama]);
  res.json({ ok: true });
});

app.put('/api/admin/email/categories/:id', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const tur = String(req.body?.tur || '').trim();
  const deger = String(req.body?.deger || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  if (!ad) return res.status(400).send('Kategori adı girmedin.');
  if (!tur) return res.status(400).send('Kategori türü girmedin.');
  sqlRun('UPDATE email_kategori SET ad = ?, tur = ?, deger = ?, aciklama = ? WHERE id = ?', [ad, tur, deger, aciklama, req.params.id]);
  res.json({ ok: true });
});

app.delete('/api/admin/email/categories/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM email_kategori WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/email/templates', requireAdmin, (_req, res) => {
  const rows = sqlAll('SELECT * FROM email_sablon ORDER BY id DESC');
  res.json({ templates: rows });
});

app.post('/api/admin/email/templates', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const konu = String(req.body?.konu || '').trim();
  const icerik = String(req.body?.icerik || '').trim();
  if (!ad) return res.status(400).send('Şablon adı girmedin.');
  if (!konu) return res.status(400).send('Konu girmedin.');
  if (!icerik) return res.status(400).send('İçerik girmedin.');
  sqlRun('INSERT INTO email_sablon (ad, konu, icerik, olusturma) VALUES (?, ?, ?, ?)', [ad, konu, icerik, new Date().toISOString()]);
  res.json({ ok: true });
});

app.put('/api/admin/email/templates/:id', requireAdmin, (req, res) => {
  const ad = String(req.body?.ad || '').trim();
  const konu = String(req.body?.konu || '').trim();
  const icerik = String(req.body?.icerik || '').trim();
  if (!ad) return res.status(400).send('Şablon adı girmedin.');
  if (!konu) return res.status(400).send('Konu girmedin.');
  if (!icerik) return res.status(400).send('İçerik girmedin.');
  sqlRun('UPDATE email_sablon SET ad = ?, konu = ?, icerik = ? WHERE id = ?', [ad, konu, icerik, req.params.id]);
  res.json({ ok: true });
});

app.delete('/api/admin/email/templates/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM email_sablon WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.post('/api/admin/email/bulk', requireAdmin, async (req, res) => {
  const { categoryId, subject, html, from } = req.body || {};
  if (!categoryId) return res.status(400).send('Kategori seçmelisin.');
  if (!subject) return res.status(400).send('Konu girmedin.');
  if (!html) return res.status(400).send('İçerik girmedin.');

  const cat = sqlGet('SELECT * FROM email_kategori WHERE id = ?', [categoryId]);
  if (!cat) return res.status(400).send('Kategori bulunamadı.');

  let recipients = [];
  if (cat.tur === 'all') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'active') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE aktiv = 1 AND yasak = 0 AND email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'pending') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE aktiv = 0 AND yasak = 0 AND email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'banned') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE yasak = 1 AND email IS NOT NULL AND email <> ""');
  } else if (cat.tur === 'year') {
    recipients = sqlAll('SELECT email FROM uyeler WHERE mezuniyetyili = ? AND email IS NOT NULL AND email <> ""', [cat.deger]);
  } else if (cat.tur === 'custom') {
    const list = extractEmails(cat.deger);
    recipients = list.map((email) => ({ email }));
  }

  if (!recipients.length) return res.status(400).send('Gönderilecek e-mail bulunamadı.');
  for (const row of recipients) {
    if (!row.email || !validateEmail(row.email)) continue;
    await sendMail({ to: row.email, subject, html, from });
  }
  res.json({ ok: true, count: recipients.length });
});

app.get('/api/admin/album/categories', requireAlbumAdmin, (_req, res) => {
  const cats = sqlAll('SELECT * FROM album_kat ORDER BY aktif DESC');
  const counts = {};
  for (const cat of cats) {
    const activeCount = sqlGet('SELECT COUNT(*) AS c FROM album_foto WHERE aktif = 1 AND katid = ?', [cat.id])?.c || 0;
    const inactiveCount = sqlGet('SELECT COUNT(*) AS c FROM album_foto WHERE aktif = 0 AND katid = ?', [cat.id])?.c || 0;
    counts[cat.id] = { activeCount, inactiveCount };
  }
  res.json({ categories: cats, counts });
});

app.post('/api/admin/album/categories', requireAlbumAdmin, (req, res) => {
  const kategori = String(req.body?.kategori || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  const aktif = Number(req.body?.aktif);
  if (!kategori) return res.status(400).send('Kategori girmedin.');
  if (!aciklama) return res.status(400).send('Açıklama girmedin.');
  const existing = sqlGet('SELECT id FROM album_kat WHERE kategori = ?', [kategori]);
  if (existing) return res.status(400).send('Girdiğin kategori ismi zaten kayıtlı.');
  sqlRun(
    'INSERT INTO album_kat (kategori, aciklama, ilktarih, aktif) VALUES (?, ?, ?, ?)',
    [kategori, aciklama, new Date().toISOString(), aktif]
  );
  res.json({ ok: true });
});

app.put('/api/admin/album/categories/:id', requireAlbumAdmin, (req, res) => {
  const kategori = String(req.body?.kategori || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  const aktif = Number(req.body?.aktif);
  if (!kategori) return res.status(400).send('Bir kategori adı girmedin.');
  if (!aciklama) return res.status(400).send('Bir açıklama girmedin.');
  const dup = sqlGet('SELECT id, kategori FROM album_kat WHERE kategori = ?', [kategori]);
  if (dup && String(dup.id) !== String(req.params.id)) {
    return res.status(400).send('Böyle bir kategori zaten kayıtlı!');
  }
  sqlRun('UPDATE album_kat SET kategori = ?, aciklama = ?, aktif = ? WHERE id = ?', [kategori, aciklama, aktif, req.params.id]);
  res.json({ ok: true });
});

app.delete('/api/admin/album/categories/:id', requireAlbumAdmin, (req, res) => {
  const hasPhotos = sqlGet('SELECT id FROM album_foto WHERE katid = ? LIMIT 1', [req.params.id]);
  if (hasPhotos) return res.status(400).send('Kategori boş değil. Önce fotoğrafları silmelisiniz.');
  sqlRun('DELETE FROM album_kat WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/album/photos', requireAlbumAdmin, (req, res) => {
  const krt = String(req.query.krt || '');
  const kid = String(req.query.kid || '');
  const diz = String(req.query.diz || '');
  let where = '';
  let params = [];
  if (krt === 'onaybekleyen') {
    where = 'WHERE aktif = 0';
  } else if (krt === 'kategori' && kid) {
    where = 'WHERE katid = ?';
    params = [kid];
  }
  const orderMap = {
    baslikartan: 'baslik',
    baslikazalan: 'baslik DESC',
    acikartan: 'aciklama',
    acikazalan: 'aciklama DESC',
    aktifartan: 'aktif',
    aktifazalan: 'aktif DESC',
    ekleyenartan: 'ekleyenid',
    ekleyenazalan: 'ekleyenid DESC',
    tarihartan: 'tarih',
    tarihazalan: 'tarih DESC',
    hitartan: 'hit',
    hitazalan: 'hit DESC'
  };
  const orderBy = orderMap[diz] || 'aktif DESC';
  const photos = sqlAll(`SELECT * FROM album_foto ${where} ORDER BY ${orderBy}`, params);
  const categories = sqlAll('SELECT * FROM album_kat');
  const userMap = {};
  const commentCounts = {};
  for (const photo of photos) {
    const user = sqlGet('SELECT id, kadi FROM uyeler WHERE id = ?', [photo.ekleyenid]);
    if (user) userMap[photo.ekleyenid] = user.kadi;
    commentCounts[photo.id] = sqlGet('SELECT COUNT(*) AS c FROM album_fotoyorum WHERE fotoid = ?', [photo.id])?.c || 0;
  }
  res.json({ photos, categories, userMap, commentCounts });
});

app.post('/api/admin/album/photos/bulk', requireAlbumAdmin, (req, res) => {
  const { ids = [], action } = req.body || {};
  const activeValue = action === 'deaktiv' ? 0 : 1;
  for (const id of ids) {
    sqlRun('UPDATE album_foto SET aktif = ? WHERE id = ?', [activeValue, id]);
  }
  res.json({ ok: true });
});

app.put('/api/admin/album/photos/:id', requireAlbumAdmin, (req, res) => {
  const baslik = String(req.body?.baslik || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();
  const aktif = Number(req.body?.aktif);
  const katid = String(req.body?.katid || '').trim();
  sqlRun(
    'UPDATE album_foto SET baslik = ?, aciklama = ?, aktif = ?, katid = ? WHERE id = ?',
    [baslik, aciklama, aktif, katid, req.params.id]
  );
  res.json({ ok: true });
});

app.delete('/api/admin/album/photos/:id', requireAlbumAdmin, (req, res) => {
  const photo = sqlGet('SELECT * FROM album_foto WHERE id = ?', [req.params.id]);
  if (!photo) return res.status(404).send('Böyle bir fotoğraf yok.');
  const albumDir = path.join(uploadsDir, 'album');
  const filePath = path.join(albumDir, photo.dosyaadi || '');
  if (photo.dosyaadi && fs.existsSync(filePath)) {
    try { fs.unlinkSync(filePath); } catch {}
  }
  sqlRun('DELETE FROM album_fotoyorum WHERE fotoid = ?', [req.params.id]);
  sqlRun('DELETE FROM album_foto WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/admin/album/photos/:id/comments', requireAlbumAdmin, (req, res) => {
  const comments = sqlAll('SELECT * FROM album_fotoyorum WHERE fotoid = ?', [req.params.id]);
  res.json({ comments });
});

app.delete('/api/admin/album/photos/:id/comments/:commentId', requireAlbumAdmin, (req, res) => {
  sqlRun('DELETE FROM album_fotoyorum WHERE id = ?', [req.params.commentId]);
  res.json({ ok: true });
});

app.get('/api/admin/tournament', requireAdmin, (_req, res) => {
  const teams = sqlAll('SELECT * FROM takimlar ORDER BY tarih DESC');
  res.json({ teams });
});

app.delete('/api/admin/tournament/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM takimlar WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});


app.post('/api/register/preview', (req, res) => {
  if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
  const {
    kadi = '',
    sifre = '',
    sifre2 = '',
    email = '',
    isim = '',
    soyisim = '',
    mezuniyetyili = '0',
    gkodu = ''
  } = req.body || {};
  const cleanKadi = String(kadi || '').trim();
  const cleanEmail = normalizeEmail(email);
  const cleanIsim = String(isim || '').trim();
  const cleanSoyisim = String(soyisim || '').trim();

  if (String(req.session.captcha || '') !== String(gkodu || '')) {
    return res.status(400).send('Güvenlik kodu yanlış girildi.');
  }
  if (!cleanKadi) return res.status(400).send('Kullanıcı adını girmedin.');
  if (String(cleanKadi).length > 15) return res.status(400).send('Kullanıcı adı 15 karakterden fazla olmamalıdır.');
  const kufur = filterKufur(cleanKadi);
  if (kufur) return res.status(400).send(`Girdiğiniz kullanıcı adı uygun olmayan bir kelime içeriyor. (${kufur})`);
  if (!sifre) return res.status(400).send('Şifreni girmedin.');
  if (String(sifre).length > 20) return res.status(400).send('Şifre 20 karakterden fazla olmamalıdır.');
  if (sifre !== sifre2) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor.');
  if (!cleanEmail) return res.status(400).send('Email adresini girmedin.');
  if (String(cleanEmail).length > 50) return res.status(400).send('E-mail adresi 50 karakterden fazla olmamalıdır.');
  if (!validateEmail(cleanEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  if (mezuniyetyili == '0') return res.status(400).send('Bir mezuniyet yılı seçmeniz gerekmektedir.');
  if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
  if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
  if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

  const existingUser = sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
  if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
  const existingMail = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
  if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');

  res.json({
    ok: true,
    fields: { kadi: cleanKadi, email: cleanEmail, mezuniyetyili, isim: cleanIsim, soyisim: cleanSoyisim }
  });
});

app.post('/api/register', async (req, res) => {
  if (req.session.userId) return res.status(400).send('Zaten giriş yaptınız.');
  const {
    kadi = '',
    sifre = '',
    sifre2 = '',
    email = '',
    isim = '',
    soyisim = '',
    mezuniyetyili = '0',
    gkodu = ''
  } = req.body || {};
  const cleanKadi = String(kadi || '').trim();
  const cleanEmail = normalizeEmail(email);
  const cleanIsim = String(isim || '').trim();
  const cleanSoyisim = String(soyisim || '').trim();

  if (String(req.session.captcha || '') !== String(gkodu || '')) return res.status(400).send('Güvenlik kodu yanlış girildi.');
  if (!cleanKadi) return res.status(400).send('Kullanıcı adını girmedin.');
  if (String(cleanKadi).length > 15) return res.status(400).send('Kullanıcı adı 15 karakterden fazla olmamalıdır.');
  const kufur = filterKufur(cleanKadi);
  if (kufur) return res.status(400).send(`Girdiğiniz kullanıcı adı uygun olmayan bir kelime içeriyor. (${kufur})`);
  if (!sifre) return res.status(400).send('Şifreni girmedin.');
  if (String(sifre).length > 20) return res.status(400).send('Şifre 20 karakterden fazla olmamalıdır.');
  if (sifre !== sifre2) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor.');
  if (!cleanEmail) return res.status(400).send('Email adresini girmedin.');
  if (String(cleanEmail).length > 50) return res.status(400).send('E-mail adresi 50 karakterden fazla olmamalıdır.');
  if (!validateEmail(cleanEmail)) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  if (mezuniyetyili == '0') return res.status(400).send('Bir mezuniyet yılı seçmeniz gerekmektedir.');
  if (!cleanIsim) return res.status(400).send('İsmini girmedin.');
  if (String(cleanIsim).length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!cleanSoyisim) return res.status(400).send('Soyismini girmedin.');
  if (String(cleanSoyisim).length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

  const existingUser = sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [cleanKadi]);
  if (existingUser) return res.status(400).send('Girdiğiniz kullanıcı adı zaten kayıtlıdır.');
  const existingMail = sqlGet('SELECT id FROM uyeler WHERE lower(email) = lower(?)', [cleanEmail]);
  if (existingMail) return res.status(400).send('Girdiğiniz e-mail adresi zaten kayıtlıdır.');

  const aktivasyon = createActivation();
  const now = new Date().toISOString();
  const result = sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, resim, mezuniyetyili, ilkbd)
     VALUES (?, ?, ?, ?, ?, ?, 0, ?, 'yok', ?, 0)`,
    [cleanKadi, sifre, cleanEmail, cleanIsim, cleanSoyisim, aktivasyon, now, mezuniyetyili]
  );
  const newId = result?.lastInsertRowid;

  const welcome = sqlGet('SELECT id FROM uyeler WHERE id = 1');
  if (welcome) {
    sqlRun(
      `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, aktifgiden, yeni, konu, mesaj, tarih)
       VALUES (?, 1, 1, 1, 1, 'Hoşgeldiniz!', ?, ?)`,
      [String(newId), 'Sdal.org - Süleyman Demirel Anadolu Lisesi Mezunları Web Sitesine hoşgeldiniz!<br><br>Bu <b>mesaj paneli</b> sayesinde diğer üyeler ile haberleşebilirsiniz.<br><br>Hoşça vakit geçirmeniz dileğiyle...<br><b><i>sdal.org</b></i>', now]
    );
  }

  const activationLink = `${baseUrl}/aktivet?id=${newId}&akt=${aktivasyon}`;
  const html = `
    <body bgcolor="#663300" topmargin=0 leftmargin=0>
    <table border=0 width=100% height=100% cellpadding=0 cellspacing=0>
    <tr><td width=100% height=100% bgcolor="#663300" align=center valign=center>
    <table border=0 width=100% height=300 cellpadding=0 cellspacing=0>
    <tr><td width=100% height=50 align=left valign=bottom style="background:#663300;">
    <a href="${baseUrl}/" title="Anasayfaya gider..." target="_blank"><img src="${baseUrl}/legacy/logo.gif" border=0></a>
    </td></tr><tr><td width=100% height=8 align=left valign=bottom background="${baseUrl}/legacy/upback.gif"></td></tr>
    <tr><td width=100% height=150 align=center valign=center style="background:#FFCC99;">
    Sayın <b>${isim} ${soyisim}</b>,<br>
    <a href="${activationLink}" target="_blank">Üyelik işleminizin tamamlanabilmesi için lütfen burayı tıklayınız!!</a><br><br>
    Kullanıcı adınız : ${kadi}<br>Şifreniz : ${sifre}
    <br><br>Aktivasyon adresi : ${activationLink}
    </td></tr>
    <tr><td width=100% height=5 align=left valign=bottom background="${baseUrl}/legacy/downback.gif"></td></tr>
    <tr><td width=100% height=50 align=left valign=bottom style="background:#663300;font-size:10;color:#FFFFCC;font-family:verdana;">
    <b>&nbsp; <a href="${baseUrl}/" style="color:#FFFFCC;" target="_blank">sdal.org</a> bir sdal kuruluşudur.</b>
    </td></tr></table></td></tr></table>
  `;

  await sendMail({ to: email, subject: 'SDAL.ORG - Üyelik Başvurusu', html });

  res.json({ ok: true });
});

app.get('/api/activate', (req, res) => {
  const id = req.query.id;
  const akt = req.query.akt;
  if (!id || !akt) return res.status(400).send('Aktivasyon kodu eksik');
  const user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [id]);
  if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');
  if (user.aktiv === 1) return res.status(400).send('Aktivasyon zaten tamamlanmış');
  if (user.aktivasyon !== akt) return res.status(400).send('Aktivasyon kodu yanlış');
  const newAkt = createActivation();
  sqlRun('UPDATE uyeler SET aktiv = 1, aktivasyon = ? WHERE id = ?', [newAkt, id]);
  res.json({ ok: true, kadi: user.kadi });
});

app.post('/api/activation/resend', async (req, res) => {
  const { id, email } = req.body || {};
  let user = null;
  if (id) user = sqlGet('SELECT * FROM uyeler WHERE id = ?', [id]);
  if (!user && email) user = sqlGet('SELECT * FROM uyeler WHERE email = ?', [email]);
  if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');
  const activationLink = `${baseUrl}/aktivet?id=${user.id}&akt=${user.aktivasyon}`;
  const html = `Aktivasyon bağlantınız: <a href="${activationLink}">${activationLink}</a>`;
  await sendMail({ to: user.email, subject: 'SDAL - Aktivasyon', html });
  res.json({ ok: true });
});

app.post('/api/password-reset', async (req, res) => {
  const { kadi, email } = req.body || {};
  let user = null;
  if (kadi) user = sqlGet('SELECT * FROM uyeler WHERE kadi = ?', [kadi]);
  if (!user && email) user = sqlGet('SELECT * FROM uyeler WHERE email = ?', [email]);
  if (!user) return res.status(404).send('Böyle bir kullanıcı kayıtlı değil');

  const html = `Sayın <b>${user.isim} ${user.soyisim}</b>,<br><br>
    Kullanıcı adınız : ${user.kadi}<br>Şifreniz : ${user.sifre}
    <br><br><a href="${baseUrl}/">Siteye girmek için tıklayınız</a>`;
  await sendMail({ to: user.email, subject: 'SDAL.ORG - ŞİFRE HATIRLAMA', html });
  res.json({ ok: true });
});

app.post('/api/mail/test', async (req, res) => {
  const fallback = process.env.SMTP_FROM || process.env.SMTP_USER || '';
  const candidates = extractEmails(req.body?.to || fallback);
  if (!candidates.length) return res.status(400).send('Test e-mail adresi eksik.');
  const invalid = candidates.find((value) => !validateEmail(value));
  if (invalid) return res.status(400).send('E-mail adresi doğru görünmüyor.');
  const to = candidates.join(', ');
  try {
    await sendMail({
      to,
      subject: 'SDAL SMTP Test',
      html: 'Bu bir SMTP test e-postasıdır.'
    });
    res.json({ ok: true, to });
  } catch (err) {
    console.error('SMTP test error:', err);
    res.status(500).send('SMTP test başarısız.');
  }
});

app.get('/api/profile', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const user = sqlGet(`
    SELECT id, kadi, isim, soyisim, email, mezuniyetyili, sehir, meslek, websitesi, universite,
           dogumgun, dogumay, dogumyil, mailkapali, imza, resim, ilkbd
    FROM uyeler WHERE id = ?`, [req.session.userId]);
  res.json({ user });
});

app.put('/api/profile', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const isim = String(req.body.isim || '').trim();
  const soyisim = String(req.body.soyisim || '').trim();
  if (!isim) return res.status(400).send('İsmini girmedin');
  if (isim.length > 20) return res.status(400).send('İsim 20 karakterden fazla olmamalıdır.');
  if (!soyisim) return res.status(400).send('Soyismini girmedin');
  if (soyisim.length > 20) return res.status(400).send('Soyisim 20 karakterden fazla olmamalıdır.');

  const sehir = String(req.body.sehir || '');
  const meslek = String(req.body.meslek || '');
  const websitesi = String(req.body.websitesi || '');
  const universite = String(req.body.universite || '');
  const dogumgun = parseInt(req.body.dogumgun || '0', 10) || 0;
  const dogumay = parseInt(req.body.dogumay || '0', 10) || 0;
  const dogumyil = parseInt(req.body.dogumyil || '0', 10) || 0;
  const mailkapali = String(req.body.mailkapali || '0') === '1' ? 1 : 0;
  const imza = String(req.body.imza || '');

  const current = sqlGet('SELECT ilkbd FROM uyeler WHERE id = ?', [req.session.userId]);
  const nextIlkbd = current && current.ilkbd === 0 ? 1 : (current?.ilkbd || 1);

  sqlRun(`
    UPDATE uyeler
    SET isim = ?, soyisim = ?, sehir = ?, meslek = ?, websitesi = ?, universite = ?,
        dogumgun = ?, dogumay = ?, dogumyil = ?, mailkapali = ?, imza = ?, ilkbd = ?
    WHERE id = ?`,
    [isim, soyisim, sehir, meslek, websitesi, universite, dogumgun, dogumay, dogumyil, mailkapali, imza, nextIlkbd, req.session.userId]
  );
  res.json({ ok: true });
});

app.post('/api/profile/password', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const { eskisifre = '', yenisifre = '', yenisifretekrar = '' } = req.body || {};
  if (!eskisifre) return res.status(400).send('Şifreni değiştirebilmek için eski şifreni girmen gerekiyor');
  if (!yenisifre) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni girmen gerekiyor');
  if (!yenisifretekrar) return res.status(400).send('Şifreni değiştirebilmek için yeni şifreni tekrar girmen gerekiyor');
  if (String(yenisifre).length > 20) return res.status(400).send('Yeni şifre 20 karakterden fazla olmamalıdır.');

  const user = sqlGet('SELECT sifre FROM uyeler WHERE id = ?', [req.session.userId]);
  if (user?.sifre !== eskisifre) return res.status(400).send('Şifreni yanlış girdin');
  if (yenisifre !== yenisifretekrar) return res.status(400).send('Girdiğin şifreler birbirleriyle uyuşmuyor');

  sqlRun('UPDATE uyeler SET sifre = ? WHERE id = ?', [yenisifre, req.session.userId]);
  res.json({ ok: true });
});

app.post('/api/profile/photo', (req, res, next) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  return next();
}, photoUpload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).send('Fotoğraf seçilmedi');
  const filename = req.file.filename;
  sqlRun('UPDATE uyeler SET resim = ? WHERE id = ?', [filename, req.session.userId]);
  res.json({ ok: true, photo: filename });
});

app.get('/api/menu', (req, res) => {
  if (!req.session.userId) return res.json({ items: [] });
  const items = sqlAll('SELECT sayfaismi, sayfaurl FROM sayfalar WHERE menugorun = 1 ORDER BY sayfaismi');
  const mapped = items
    .filter((row) => !['sifrehatirla.asp', 'uyekayit.asp'].includes((row.sayfaurl || '').toLowerCase()))
    .map((row) => ({
      label: row.sayfaismi,
      url: mapLegacyUrl(row.sayfaurl),
      legacyUrl: row.sayfaurl
    }));
  res.json({ items: mapped });
});

app.get('/api/sidebar', (req, res) => {
  if (!req.session.userId) return res.json({ onlineUsers: [], newMembers: [], newPhotos: [], topSnake: [], topTetris: [], newMessagesCount: 0 });

  // Online users cleanup (5 minutes)
  const onlineUsers = [];
  const now = Date.now();
  const onlineRows = sqlAll('SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, sonislemtarih, sonislemsaat FROM uyeler WHERE online = 1 ORDER BY kadi');
  onlineRows.forEach((row) => {
    const last = row.sonislemtarih && row.sonislemsaat ? new Date(`${row.sonislemtarih} ${row.sonislemsaat}`) : null;
    if (last && now - last.getTime() > 5 * 60 * 1000) {
      sqlRun('UPDATE uyeler SET online = 0 WHERE id = ?', [row.id]);
      return;
    }
    onlineUsers.push(row);
  });

  const newMembers = sqlAll('SELECT id, kadi, isim, soyisim, resim, mezuniyetyili FROM uyeler WHERE aktiv = 1 AND yasak = 0 ORDER BY id DESC LIMIT 5');

  const newPhotos = sqlAll(`\n    SELECT f.id, f.katid, f.dosyaadi, k.kategori\n    FROM album_foto f\n    LEFT JOIN album_kat k ON k.id = f.katid\n    WHERE f.aktif = 1\n    ORDER BY f.id DESC\n    LIMIT 10\n  `);

  const topSnake = sqlAll('SELECT isim, skor, tarih FROM oyun_yilan ORDER BY skor DESC LIMIT 5');
  const topTetris = sqlAll('SELECT isim, puan, tarih FROM oyun_tetris ORDER BY puan DESC LIMIT 5');

  const newMessagesCountRow = sqlGet('SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE yeni = 1 AND kime = ? AND aktifgelen = 1', [req.session.userId]);
  const newMessagesCount = newMessagesCountRow ? newMessagesCountRow.cnt : 0;

  res.json({ onlineUsers, newMembers, newPhotos, topSnake, topTetris, newMessagesCount });
});

app.get('/api/members', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '10', 10), 1), 50);
  const term = req.query.term ? String(req.query.term).replace(/'/g, '') : '';
  const where = term
    ? `aktiv = 1 AND yasak = 0 AND (kadi LIKE ? OR isim LIKE ? OR soyisim LIKE ? OR meslek LIKE ? OR email LIKE ?)`
    : 'aktiv = 1 AND yasak = 0';
  const params = term ? Array(5).fill(`%${term}%`) : [];

  const totalRow = sqlGet(`SELECT COUNT(*) AS cnt FROM uyeler WHERE ${where}`, params);
  const total = totalRow ? totalRow.cnt : 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const rows = sqlAll(`
    SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
           sehir, universite, meslek, websitesi, imza, resim, online, sontarih
    FROM uyeler
    WHERE ${where}
    ORDER BY isim
    LIMIT ? OFFSET ?
  `, [...params, pageSize, offset]);

  const rangeRows = term ? [] : sqlAll('SELECT isim FROM uyeler WHERE aktiv = 1 AND yasak = 0 ORDER BY isim');
  const ranges = [];
  for (let i = 0; i < rangeRows.length; i += pageSize) {
    const start = rangeRows[i]?.isim ? rangeRows[i].isim.slice(0, 2) : '--';
    const end = rangeRows[Math.min(i + pageSize - 1, rangeRows.length - 1)]?.isim?.slice(0, 2) || '--';
    ranges.push({ start, end });
  }

  res.json({ rows, page: safePage, pages, total, ranges, pageSize, term });
});

app.get('/api/members/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet(`
    SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
           sehir, universite, meslek, websitesi, imza, resim, online, sontarih
    FROM uyeler
    WHERE id = ?
  `, [req.params.id]);
  if (!row) return res.status(404).send('Üye bulunamadı');
  res.json({ row });
});

app.get('/api/messages', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const box = req.query.box === 'outbox' ? 'outbox' : 'inbox';
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '5', 10), 1), 50);
  const where = box === 'inbox' ? 'kime = ? AND aktifgelen = 1' : 'kimden = ? AND aktifgiden = 1';
  const totalRow = sqlGet(`SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE ${where}`, [req.session.userId]);
  const total = totalRow ? totalRow.cnt : 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;

  const rows = sqlAll(`
    SELECT g.*, u1.kadi AS kimden_kadi, u1.resim AS kimden_resim, u2.kadi AS kime_kadi, u2.resim AS kime_resim
    FROM gelenkutusu g
    LEFT JOIN uyeler u1 ON u1.id = g.kimden
    LEFT JOIN uyeler u2 ON u2.id = g.kime
    WHERE ${where}
    ORDER BY g.tarih DESC
    LIMIT ? OFFSET ?
  `, [req.session.userId, pageSize, offset]);

  res.json({ rows, page: safePage, pages, total, box, pageSize });
});

app.get('/api/messages/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('Mesaj bulunamadı');
  if (String(row.kime) !== String(req.session.userId) && String(row.kimden) !== String(req.session.userId)) {
    return res.status(403).send('Yetkisiz');
  }
  const sender = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [row.kimden]);
  const receiver = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [row.kime]);

  if (String(row.kime) === String(req.session.userId) && row.yeni === 1) {
    sqlRun('UPDATE gelenkutusu SET yeni = 0 WHERE id = ?', [row.id]);
  }

  res.json({ row, sender, receiver });
});

app.post('/api/messages', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const { kime, konu, mesaj } = req.body || {};
  if (!kime) return res.status(400).send('Alıcı seçilmedi');
  const subject = (konu && String(konu).trim()) ? String(konu).slice(0, 50) : 'Konusuz';
  const body = (mesaj && String(mesaj).trim()) ? metinDuzenle(String(mesaj)) : 'Sistem Bilgisi : [b]Boş Mesaj Gönderildi![/b]';
  const now = new Date().toISOString();

  sqlRun(
    `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, konu, mesaj, yeni, tarih, aktifgiden)
     VALUES (?, ?, 1, ?, ?, 1, ?, 1)`,
    [kime, req.session.userId, subject, body, now]
  );

  res.status(201).json({ ok: true });
});

app.delete('/api/messages/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
  if (!row) return res.status(404).send('Mesaj bulunamadı');
  if (String(row.kime) !== String(req.session.userId) && String(row.kimden) !== String(req.session.userId)) {
    return res.status(403).send('Yetkisiz');
  }
  if (String(row.kime) === String(req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgelen = 0 WHERE id = ?', [row.id]);
  }
  if (String(row.kimden) === String(req.session.userId)) {
    sqlRun('UPDATE gelenkutusu SET aktifgiden = 0 WHERE id = ?', [row.id]);
  }
  res.status(204).send();
});

app.get('/api/albums', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const categories = sqlAll('SELECT id, kategori, aciklama FROM album_kat WHERE aktif = 1 ORDER BY id');
  const items = categories.map((cat) => {
    const countRow = sqlGet('SELECT COUNT(*) AS cnt FROM album_foto WHERE aktif = 1 AND katid = ?', [cat.id]);
    const previews = sqlAll('SELECT dosyaadi FROM album_foto WHERE aktif = 1 AND katid = ? ORDER BY id DESC LIMIT 5', [cat.id]);
    return { ...cat, count: countRow?.cnt || 0, previews: previews.map((p) => p.dosyaadi) };
  });
  res.json({ items });
});

app.get('/api/album/categories/active', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const categories = sqlAll('SELECT id, kategori FROM album_kat WHERE aktif = 1 ORDER BY kategori');
  res.json({ categories });
});

app.post('/api/album/upload', (req, res, next) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  return albumUpload.single('file')(req, res, (err) => {
    if (err) return next(err);
    next();
  });
}, (req, res) => {
  const kat = String(req.body?.kat || '').trim();
  const baslik = String(req.body?.baslik || '').trim();
  const aciklama = String(req.body?.aciklama || '').trim();

  if (!baslik) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
  if (!kat) return res.status(400).send('Kategori seçmelisin.');
  const category = sqlGet('SELECT * FROM album_kat WHERE id = ? AND aktif = 1', [kat]);
  if (!category) return res.status(400).send('Seçtiğin kategori bulunamadı.');
  if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

  sqlRun('UPDATE album_kat SET sonekleme = ?, sonekleyen = ? WHERE id = ?', [new Date().toISOString(), req.session.userId, category.id]);
  sqlRun(
    `INSERT INTO album_foto (dosyaadi, katid, baslik, aciklama, aktif, ekleyenid, tarih, hit)
     VALUES (?, ?, ?, ?, 0, ?, ?, 0)`,
    [req.file.filename, String(category.id), baslik, aciklama, req.session.userId, new Date().toISOString()]
  );

  res.json({ ok: true, file: req.file.filename, categoryId: category.id });
});

app.get('/api/albums/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '20', 10), 1), 50);
  const category = sqlGet('SELECT id, kategori, aciklama FROM album_kat WHERE id = ? AND aktif = 1', [req.params.id]);
  if (!category) return res.status(404).send('Kategori bulunamadı');
  const totalRow = sqlGet('SELECT COUNT(*) AS cnt FROM album_foto WHERE aktif = 1 AND katid = ?', [req.params.id]);
  const total = totalRow?.cnt || 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const photos = sqlAll('SELECT id, dosyaadi, baslik, tarih FROM album_foto WHERE aktif = 1 AND katid = ? ORDER BY tarih LIMIT ? OFFSET ?', [req.params.id, pageSize, offset]);
  res.json({ category, photos, page: safePage, pages, total, pageSize });
});

app.get('/api/photos/:id', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const row = sqlGet('SELECT id, katid, dosyaadi, baslik, aciklama, tarih FROM album_foto WHERE id = ? AND aktif = 1', [req.params.id]);
  if (!row) return res.status(404).send('Fotoğraf bulunamadı');
  const category = sqlGet('SELECT id, kategori FROM album_kat WHERE id = ?', [row.katid]);
  res.json({ row, category });
});

app.get('/api/album/latest', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
  const rows = sqlAll(
    `SELECT f.id, f.katid, f.dosyaadi, f.tarih, f.hit, k.kategori
     FROM album_foto f
     LEFT JOIN album_kat k ON k.id = f.katid
     WHERE f.aktif = 1
     ORDER BY f.id DESC
     LIMIT ?`,
    [limit]
  );
  res.json({ items: rows });
});

app.get('/api/members/latest', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 200);
  const rows = sqlAll(
    `SELECT id, kadi, isim, soyisim, resim, mezuniyetyili, ilktarih
     FROM uyeler
     WHERE aktiv = 1 AND yasak = 0
     ORDER BY id DESC
     LIMIT ?`,
    [limit]
  );
  res.json({ items: rows });
});

app.get('/api/panolar', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const mkatidRaw = String(req.query.mkatid || '0');
  const mkatid = /^\d+$/.test(mkatidRaw) ? Number(mkatidRaw) : 0;
  let categoryName = 'Genel';
  if (mkatid !== 0) {
    const cat = sqlGet('SELECT * FROM mesaj_kategori WHERE id = ?', [mkatid]);
    if (!cat) {
      return res.status(400).send('Kategori bulunamadı.');
    }
    categoryName = cat.kategoriadi;
  }

  const user = sqlGet('SELECT id, mezuniyetyili, oncekisontarih, admin FROM uyeler WHERE id = ?', [req.session.userId]);
  const gradName = user?.mezuniyetyili ? `${user.mezuniyetyili} Mezunları` : null;
  const gradCategory = gradName ? sqlGet('SELECT * FROM mesaj_kategori WHERE kategoriadi = ?', [gradName]) : null;

  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const pageSize = 25;
  const totalRow = sqlGet('SELECT COUNT(*) AS cnt FROM mesaj WHERE kategori = ?', [mkatid]);
  const total = totalRow?.cnt || 0;
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const offset = (safePage - 1) * pageSize;
  const rows = sqlAll('SELECT * FROM mesaj WHERE kategori = ? ORDER BY tarih DESC LIMIT ? OFFSET ?', [mkatid, pageSize, offset]);

  const messages = rows.map((row) => {
    const u = sqlGet('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [row.gonderenid]) || { id: row.gonderenid, kadi: 'Üye', resim: 'nophoto.jpg' };
    const msgDate = row.tarih ? new Date(row.tarih) : null;
    const lastDate = user?.oncekisontarih ? new Date(user.oncekisontarih) : null;
    const diffSeconds = msgDate && lastDate ? Math.floor((msgDate.getTime() - lastDate.getTime()) / 1000) : null;
    const isNew = diffSeconds != null && diffSeconds > 0;
    return {
      id: row.id,
      mesajHtml: row.mesaj || '',
      tarih: row.tarih,
      user: u,
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

  res.json({
    categoryId: mkatid,
    categoryName,
    gradCategory,
    messages,
    total,
    page: safePage,
    pages,
    pageSize,
    pageList,
    canDelete: !!req.session.adminOk && user?.admin === 1
  });
});

app.post('/api/panolar', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const mesaj = String(req.body?.mesaj || '').trim();
  let katid = String(req.body?.katid || '0');
  if (!/^\d+$/.test(katid)) katid = '0';
  if (katid !== '0') {
    const cat = sqlGet('SELECT id FROM mesaj_kategori WHERE id = ?', [katid]);
    if (!cat) katid = '0';
  }
  if (!mesaj) return res.status(400).send('Mesaj yazmadın.');
  const formatted = metinDuzenle(mesaj);
  sqlRun(
    'INSERT INTO mesaj (gonderenid, mesaj, tarih, kategori) VALUES (?, ?, ?, ?)',
    [req.session.userId, formatted, new Date().toISOString(), Number(katid)]
  );
  res.json({ ok: true });
});

app.delete('/api/panolar/:id', requireAdmin, (req, res) => {
  sqlRun('DELETE FROM mesaj WHERE id = ?', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/quick-access', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const user = sqlGet('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(user?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0');
  const unique = Array.from(new Set(list));
  const users = unique.map((id) => sqlGet('SELECT id, kadi, resim, mezuniyetyili, online FROM uyeler WHERE id = ?', [id]))
    .filter(Boolean);
  res.json({ users });
});

app.post('/api/quick-access/add', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const id = String(req.body?.id || '').trim();
  if (!/^\d+$/.test(id)) return res.status(400).send('Üye bulunamadı.');
  const target = sqlGet('SELECT id FROM uyeler WHERE id = ?', [id]);
  if (!target) return res.status(404).send('Üye bulunamadı.');
  const row = sqlGet('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(row?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0');
  if (list.includes(id)) return res.status(400).send('Bu üye zaten hızlı erişim listenizde!');
  list.push(id);
  const updated = list.length ? `0,${list.join(',')}` : '0';
  sqlRun('UPDATE uyeler SET hizliliste = ? WHERE id = ?', [updated, req.session.userId]);
  res.json({ ok: true });
});

app.post('/api/quick-access/remove', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const id = String(req.body?.id || '').trim();
  const row = sqlGet('SELECT hizliliste FROM uyeler WHERE id = ?', [req.session.userId]);
  const list = String(row?.hizliliste || '0')
    .split(',')
    .map((v) => v.trim())
    .filter((v) => v && v !== '0' && v !== id);
  const updated = list.length ? `0,${list.join(',')}` : '0';
  sqlRun('UPDATE uyeler SET hizliliste = ? WHERE id = ?', [updated, req.session.userId]);
  res.json({ ok: true });
});

app.get('/api/games/snake/leaderboard', (req, res) => {
  const rows = sqlAll('SELECT isim, skor, tarih FROM oyun_yilan ORDER BY skor DESC LIMIT 25');
  res.json({ rows });
});

app.post('/api/games/snake/score', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const score = Number(req.body?.score || 0);
  const user = sqlGet('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
  const name = user?.kadi || 'Misafir';
  const existing = sqlGet('SELECT * FROM oyun_yilan WHERE isim = ?', [name]);
  if (!existing) {
    sqlRun('INSERT INTO oyun_yilan (isim, skor, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
  } else if (score > Number(existing.skor || 0)) {
    sqlRun('UPDATE oyun_yilan SET skor = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
  }
  res.json({ ok: true });
});

app.get('/api/games/tetris/leaderboard', (req, res) => {
  const rows = sqlAll('SELECT isim, puan, tarih FROM oyun_tetris ORDER BY puan DESC LIMIT 25');
  res.json({ rows });
});

app.post('/api/games/tetris/score', (req, res) => {
  if (!req.session.userId) return res.status(401).send('Login required');
  const score = Number(req.body?.score || 0);
  const user = sqlGet('SELECT kadi FROM uyeler WHERE id = ?', [req.session.userId]);
  const name = user?.kadi || 'Misafir';
  const existing = sqlGet('SELECT * FROM oyun_tetris WHERE isim = ?', [name]);
  if (!existing) {
    sqlRun('INSERT INTO oyun_tetris (isim, puan, tarih) VALUES (?, ?, ?)', [name, score, new Date().toISOString()]);
  } else if (score > Number(existing.puan || 0)) {
    sqlRun('UPDATE oyun_tetris SET puan = ?, tarih = ? WHERE isim = ?', [score, new Date().toISOString(), name]);
  }
  res.json({ ok: true });
});

app.use((err, req, res, next) => {
  if (err) return res.status(400).send(err.message || 'Hata');
  return next();
});

// Legacy .asp redirects
app.get(/\/*.asp$/i, (req, res) => {
  const legacy = path.basename(req.path);
  let target = mapLegacyUrl(legacy);

  // Map common query-based routes
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

// Serve frontend build in production
const clientDist = path.resolve(__dirname, '../client/dist');
app.use(express.static(clientDist));
app.get('*', (req, res) => {
  res.sendFile(path.join(clientDist, 'index.html'));
});

app.listen(port, () => {
  console.log(`SDAL server running on http://localhost:${port}`);
});
