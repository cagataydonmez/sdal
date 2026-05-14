import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';
import sharp from 'sharp';

export const TEST_DATA_AREAS = Object.freeze([
  { key: 'feed', label: 'Akış', defaultCount: 2 },
  { key: 'stories', label: 'Hikayeler', defaultCount: 2 },
  { key: 'events', label: 'Etkinlikler', defaultCount: 2 },
  { key: 'announcements', label: 'Duyurular', defaultCount: 2 },
  { key: 'groups', label: 'Gruplar', defaultCount: 2 },
  { key: 'groupPosts', label: 'Grup gönderileri', defaultCount: 2 },
  { key: 'groupEvents', label: 'Grup etkinlikleri', defaultCount: 2 },
  { key: 'groupAnnouncements', label: 'Grup duyuruları', defaultCount: 2 },
  { key: 'jobs', label: 'İş ilanları', defaultCount: 2 },
  { key: 'jobApplications', label: 'İş başvuruları', defaultCount: 2 },
  { key: 'requests', label: 'Talepler', defaultCount: 2 },
  { key: 'messages', label: 'Mesajlar', defaultCount: 2 },
  { key: 'connections', label: 'Bağlantı istekleri', defaultCount: 2 },
  { key: 'mentorship', label: 'Mentorluk istekleri', defaultCount: 2 },
  { key: 'albums', label: 'Albümler', defaultCount: 2 }
]);

const MAX_PER_AREA = 10;
const MAX_TOTAL_REQUESTED = 90;
const MIN_DELAY_MS = 40;
const COOLDOWN_MS = 15_000;
let lastRunAt = 0;

const TURKISH_PROFILES = Object.freeze([
  ['Ayşe', 'Kaya', 'f'], ['Mehmet', 'Arslan', 'm'], ['Zeynep', 'Doğan', 'f'],
  ['Emre', 'Çelik', 'm'], ['Elif', 'Yılmaz', 'f'], ['Berk', 'Şahin', 'm'],
  ['Merve', 'Öztürk', 'f'], ['Kaan', 'Demir', 'm'], ['Selin', 'Aydın', 'f'],
  ['Mert', 'Kurt', 'm'], ['Derya', 'Polat', 'f'], ['Burak', 'Güneş', 'm'],
  ['Ceren', 'Kaplan', 'f'], ['Onur', 'İlhan', 'm'], ['Pınar', 'Kara', 'f'],
  ['Volkan', 'Aslan', 'm'], ['Gizem', 'Bulut', 'f'], ['Erdem', 'Taş', 'm'],
  ['Nazlı', 'Karaer', 'f'], ['Barış', 'Kılınç', 'm'], ['Seda', 'Aktaş', 'f'],
  ['Ozan', 'Çavuş', 'm'], ['Yağmur', 'Sert', 'f'], ['Umut', 'Özdemir', 'm']
]);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function boolParam(dbDriver, value) {
  return dbDriver === 'postgres' ? Boolean(value) : (value ? 1 : 0);
}

function normalizeCount(value) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed)) return 2;
  return Math.min(Math.max(parsed, 0), MAX_PER_AREA);
}

function createRunId() {
  return `admin-seed-${new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14)}-${crypto.randomBytes(3).toString('hex')}`;
}

function pick(list, index) {
  return list[index % list.length];
}

function htmlText(text) {
  return `<p>${String(text || '').replace(/[<>&]/g, (ch) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[ch]))}</p>`;
}

export function normalizeTestDataCounts(rawCounts = {}) {
  const counts = {};
  let total = 0;
  for (const area of TEST_DATA_AREAS) {
    const count = normalizeCount(rawCounts[area.key]);
    counts[area.key] = count;
    total += count;
  }
  if (total > MAX_TOTAL_REQUESTED) {
    const err = new Error(`Toplam test verisi istegi ${MAX_TOTAL_REQUESTED} kaydi asamaz.`);
    err.statusCode = 400;
    throw err;
  }
  return counts;
}

export function createTestDataSeeder(deps) {
  const {
    dbDriver,
    sqlGetAsync,
    sqlAllAsync,
    sqlRunAsync,
    sqlGet,
    sqlRun,
    uploadsDir,
    hashPassword,
    processUpload,
    writeAppLog
  } = deps;

  const columnCache = new Map();
  const tableCache = new Map();

  async function tableExists(table) {
    if (tableCache.has(table)) return tableCache.get(table);
    const row = dbDriver === 'postgres'
      ? await sqlGetAsync('SELECT table_name AS name FROM information_schema.tables WHERE table_schema = ? AND table_name = ? LIMIT 1', ['public', table])
      : await sqlGetAsync("SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name = ? LIMIT 1", [table]);
    const exists = !!row;
    tableCache.set(table, exists);
    return exists;
  }

  async function columnsFor(table) {
    if (columnCache.has(table)) return columnCache.get(table);
    if (!(await tableExists(table))) {
      columnCache.set(table, new Set());
      return columnCache.get(table);
    }
    const rows = dbDriver === 'postgres'
      ? await sqlAllAsync('SELECT column_name AS name FROM information_schema.columns WHERE table_schema = ? AND table_name = ?', ['public', table])
      : await sqlAllAsync(`PRAGMA table_info(${table})`);
    const cols = new Set((rows || []).map((row) => String(row.name || row.column_name || '').trim()).filter(Boolean));
    columnCache.set(table, cols);
    return cols;
  }

  async function insertRow(table, values) {
    const cols = await columnsFor(table);
    const entries = Object.entries(values).filter(([key]) => cols.has(key));
    if (!entries.length) throw new Error(`${table} tablosu icin yazilabilir kolon bulunamadi.`);
    const names = entries.map(([key]) => key);
    const params = entries.map(([, value]) => value);
    const placeholders = names.map(() => '?').join(', ');
    return sqlRunAsync(`INSERT INTO ${table} (${names.join(', ')}) VALUES (${placeholders})`, params);
  }

  async function updateById(table, id, values) {
    const cols = await columnsFor(table);
    const entries = Object.entries(values).filter(([key]) => cols.has(key));
    if (!entries.length || !id) return;
    await sqlRunAsync(`UPDATE ${table} SET ${entries.map(([key]) => `${key} = ?`).join(', ')} WHERE id = ?`, [
      ...entries.map(([, value]) => value),
      id
    ]);
  }

  async function makeImageBuffer(label, index, { width = 1200, height = 760 } = {}) {
    const palette = [
      ['#f4ddd8', '#a44635', '#261b14'],
      ['#dcebe4', '#2a6a4c', '#18251d'],
      ['#dceaf0', '#2f6078', '#16252c'],
      ['#efe3cd', '#b45637', '#2d2018']
    ][index % 4];
    const safeLabel = String(label || 'SDAL').replace(/[<>&]/g, '');
    const svg = `
      <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="${palette[0]}"/>
        <circle cx="${width * 0.78}" cy="${height * 0.24}" r="${Math.min(width, height) * 0.22}" fill="${palette[1]}" opacity="0.18"/>
        <rect x="${width * 0.08}" y="${height * 0.15}" width="${width * 0.56}" height="${height * 0.56}" rx="36" fill="#fffcf7" opacity="0.82"/>
        <text x="${width * 0.13}" y="${height * 0.43}" font-family="Arial, sans-serif" font-size="74" font-weight="700" fill="${palette[2]}">${safeLabel}</text>
        <text x="${width * 0.13}" y="${height * 0.54}" font-family="Arial, sans-serif" font-size="34" fill="${palette[1]}">SDAL test yuklemesi</text>
      </svg>`;
    return sharp(Buffer.from(svg)).jpeg({ quality: 88 }).toBuffer();
  }

  async function uploadEntityImage({ userId, entityType, entityId, label, index }) {
    if (typeof processUpload !== 'function') return null;
    const buffer = await makeImageBuffer(label, index);
    const uploaded = await processUpload({
      buffer,
      mimeType: 'image/jpeg',
      userId,
      entityType,
      entityId,
      sqlGet,
      sqlRun,
      uploadsDir,
      writeAppLog
    });
    return uploaded;
  }

  async function writeAvatar(userId, profile, runId, index) {
    const dir = path.join(uploadsDir, 'vesikalik');
    await fs.mkdir(dir, { recursive: true });
    const initials = `${profile.isim[0] || 'S'}${profile.soyisim[0] || 'D'}`;
    const buffer = await makeImageBuffer(initials, index, { width: 960, height: 960 });
    const filename = `${runId}-avatar-${String(index).padStart(2, '0')}.jpg`;
    await fs.writeFile(path.join(dir, filename), buffer);
    if (dbDriver === 'postgres') {
      await updateById('users', userId, { avatar_path: filename, updated_at: new Date().toISOString() });
    } else {
      await updateById('uyeler', userId, { resim: filename });
    }
    return filename;
  }

  async function writeAlbumFile(runId, index) {
    const dir = path.join(uploadsDir, 'album');
    await fs.mkdir(dir, { recursive: true });
    const filename = `${runId}-album-${String(index).padStart(2, '0')}.jpg`;
    const buffer = await makeImageBuffer('Albüm', index, { width: 1600, height: 1100 });
    await fs.writeFile(path.join(dir, filename), buffer);
    return filename;
  }

  async function createUsers({ runId, actorCount, dryRun }) {
    const password = await hashPassword('Test1234!');
    const users = [];
    for (let i = 0; i < actorCount; i += 1) {
      const [isim, soyisim, gender] = pick(TURKISH_PROFILES, i);
      const profile = { isim, soyisim, gender };
      const handle = `test_${runId.replace(/[^a-z0-9]/gi, '').slice(-12)}_${String(i + 1).padStart(2, '0')}`.toLowerCase();
      if (dryRun) {
        users.push({ id: -(i + 1), kadi: handle, isim, soyisim });
        continue;
      }
      const now = new Date().toISOString();
      const table = dbDriver === 'postgres' ? 'users' : 'uyeler';
      const values = dbDriver === 'postgres'
        ? {
            username: handle,
            password_hash: password,
            email: `${handle}@test.sdal.local`,
            first_name: isim,
            last_name: soyisim,
            activation_token: runId,
            is_active: true,
            is_banned: false,
            is_profile_initialized: true,
            created_at: now,
            updated_at: now,
            graduation_year: 2015 + (i % 10),
            role: 'user',
            legacy_admin_flag: false,
            is_verified: true,
            verification_status: 'approved',
            privacy_consent_at: now,
            directory_consent_at: now
          }
        : {
            kadi: handle,
            sifre: password,
            email: `${handle}@test.sdal.local`,
            isim,
            soyisim,
            aktivasyon: runId,
            aktiv: 1,
            yasak: 0,
            ilktarih: now,
            resim: 'yok',
            mezuniyetyili: String(2015 + (i % 10)),
            ilkbd: 1,
            role: 'user',
            admin: 0,
            verified: 1,
            verification_status: 'approved',
            kvkk_consent_at: now,
            directory_consent_at: now
          };
      const result = await insertRow(table, values);
      const id = Number(result?.lastInsertRowid || 0);
      const user = { id, kadi: handle, isim, soyisim };
      user.resim = await writeAvatar(id, profile, runId, i);
      users.push(user);
      await sleep(MIN_DELAY_MS);
    }
    return users;
  }

  async function maybeCreateGroup(owner, runId, index) {
    const existing = await sqlGetAsync('SELECT id FROM groups WHERE name = ?', [`${runId} Test Grubu ${index + 1}`]);
    if (existing?.id) return Number(existing.id);
    const now = new Date().toISOString();
    const image = await uploadEntityImage({ userId: owner.id, entityType: 'group', entityId: 0, label: 'Grup', index });
    const result = await insertRow('groups', {
      name: `${runId} Test Grubu ${index + 1}`,
      description: htmlText('Admin test verisi ile olusturulan grup.'),
      created_at: now,
      created_by: owner.id,
      visibility: 'public',
      privacy: 'public',
      cover_image: image?.variants?.feedUrl || null,
      image: image?.variants?.feedUrl || null,
      is_cohort_group: boolParam(dbDriver, false)
    });
    const groupId = Number(result?.lastInsertRowid || 0);
    await insertRow('group_members', { group_id: groupId, user_id: owner.id, role: 'owner', created_at: now }).catch(() => null);
    return groupId;
  }

  async function ensureBaseGroups(users, runId, count) {
    const needed = Math.max(1, Math.min(count || 1, 4));
    const ids = [];
    for (let i = 0; i < needed; i += 1) {
      ids.push(await maybeCreateGroup(pick(users, i), runId, i));
    }
    return ids.filter(Boolean);
  }

  function userFor(users, index) {
    return pick(users, index);
  }

  async function seedArea(key, count, ctx) {
    const created = [];
    if (count <= 0) return created;
    if (ctx.dryRun) return Array.from({ length: count }, (_, i) => ({ endpoint: key, dryRun: true, index: i + 1 }));

    for (let i = 0; i < count; i += 1) {
      const user = userFor(ctx.users, i);
      const other = userFor(ctx.users, i + 1);
      const now = new Date().toISOString();
      const later = new Date(Date.now() + (i + 1) * 86400000).toISOString();

      if (key === 'feed') {
        const image = await uploadEntityImage({ userId: user.id, entityType: 'post', entityId: 0, label: 'Akis', index: i });
        const row = await insertRow('posts', {
          user_id: user.id,
          content: htmlText(`${user.isim} tarafindan olusturulan test akis gonderisi.`),
          image: image?.variants?.feedUrl || null,
          image_record_id: image?.imageId || null,
          created_at: now,
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        const id = Number(row?.lastInsertRowid || 0);
        if (image?.imageId) await sqlRunAsync('UPDATE image_records SET entity_id = ? WHERE id = ?', [id, image.imageId]).catch(() => null);
        await insertRow('post_comments', { post_id: id, user_id: other.id, content: htmlText('Test yorumu.'), created_at: now }).catch(() => null);
        await insertRow('post_likes', { post_id: id, user_id: other.id, created_at: now }).catch(() => null);
        created.push({ endpoint: 'POST /api/new/posts/upload', id });
      } else if (key === 'stories') {
        const image = await uploadEntityImage({ userId: user.id, entityType: 'story', entityId: 0, label: 'Hikaye', index: i });
        const row = await insertRow('stories', {
          user_id: user.id,
          image: image?.variants?.fullUrl || image?.variants?.feedUrl || null,
          image_record_id: image?.imageId || null,
          caption: `${user.isim} test hikayesi`,
          created_at: now,
          expires_at: new Date(Date.now() + 24 * 3600000).toISOString()
        });
        const id = Number(row?.lastInsertRowid || 0);
        if (image?.imageId) await sqlRunAsync('UPDATE image_records SET entity_id = ? WHERE id = ?', [id, image.imageId]).catch(() => null);
        created.push({ endpoint: 'POST /api/new/stories/upload', id });
      } else if (key === 'events') {
        const image = await uploadEntityImage({ userId: user.id, entityType: 'event', entityId: 0, label: 'Etkinlik', index: i });
        const row = await insertRow('events', {
          title: `${ctx.runId} Mezun bulusmasi ${i + 1}`,
          description: htmlText('API test verisi ile olusturulan etkinlik.'),
          location: 'Istanbul',
          starts_at: later,
          ends_at: new Date(new Date(later).getTime() + 7200000).toISOString(),
          image: image?.variants?.feedUrl || null,
          created_at: now,
          created_by: user.id,
          approved: boolParam(dbDriver, true),
          approved_by: user.id,
          approved_at: now,
          show_in_feed: boolParam(dbDriver, true),
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        created.push({ endpoint: 'POST /api/new/events/upload', id: Number(row?.lastInsertRowid || 0) });
      } else if (key === 'announcements') {
        const image = await uploadEntityImage({ userId: user.id, entityType: 'announcement', entityId: 0, label: 'Duyuru', index: i });
        const row = await insertRow('announcements', {
          title: `${ctx.runId} Duyuru ${i + 1}`,
          body: htmlText('API test verisi ile olusturulan duyuru.'),
          image: image?.variants?.feedUrl || null,
          created_at: now,
          created_by: user.id,
          approved: boolParam(dbDriver, true),
          approved_by: user.id,
          approved_at: now,
          show_in_feed: boolParam(dbDriver, true),
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        created.push({ endpoint: 'POST /api/new/announcements/upload', id: Number(row?.lastInsertRowid || 0) });
      } else if (key === 'groups') {
        const id = await maybeCreateGroup(user, ctx.runId, i + 10);
        await insertRow('group_members', { group_id: id, user_id: other.id, role: 'member', created_at: now }).catch(() => null);
        created.push({ endpoint: 'POST /api/new/groups', id });
      } else if (key === 'groupPosts') {
        const groupId = pick(ctx.groupIds, i);
        await insertRow('group_members', { group_id: groupId, user_id: user.id, role: 'member', created_at: now }).catch(() => null);
        const row = await insertRow('posts', {
          user_id: user.id,
          content: htmlText('Grup icin test gonderisi.'),
          created_at: now,
          group_id: groupId,
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        created.push({ endpoint: 'POST /api/new/groups/:id/posts', id: Number(row?.lastInsertRowid || 0), groupId });
      } else if (key === 'groupEvents') {
        const groupId = pick(ctx.groupIds, i);
        const row = await insertRow('group_events', {
          group_id: groupId,
          title: `Grup etkinligi ${i + 1}`,
          description: htmlText('Grup etkinligi test kaydi.'),
          location: 'Okul',
          starts_at: later,
          ends_at: new Date(new Date(later).getTime() + 7200000).toISOString(),
          created_at: now,
          created_by: user.id,
          show_in_feed: boolParam(dbDriver, true),
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        created.push({ endpoint: 'POST /api/new/groups/:id/events', id: Number(row?.lastInsertRowid || 0), groupId });
      } else if (key === 'groupAnnouncements') {
        const groupId = pick(ctx.groupIds, i);
        const row = await insertRow('group_announcements', {
          group_id: groupId,
          title: `Grup duyurusu ${i + 1}`,
          body: htmlText('Grup duyurusu test kaydi.'),
          created_at: now,
          created_by: user.id,
          show_in_feed: boolParam(dbDriver, true),
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        created.push({ endpoint: 'POST /api/new/groups/:id/announcements', id: Number(row?.lastInsertRowid || 0), groupId });
      } else if (key === 'jobs') {
        const image = await uploadEntityImage({ userId: user.id, entityType: 'job', entityId: 0, label: 'Is', index: i });
        const row = await insertRow('jobs', {
          poster_id: user.id,
          company: 'SDAL Test Sirketi',
          title: `Test is ilani ${i + 1}`,
          description: htmlText('API test verisi ile olusturulan is ilani.'),
          location: 'Istanbul',
          job_type: 'Tam zamanli',
          work_mode: 'Hibrit',
          link: 'https://example.com/sdal-test',
          image: image?.variants?.feedUrl || null,
          created_at: now,
          show_in_feed: boolParam(dbDriver, true),
          publication_status: 'published',
          approval_status: 'approved',
          published_at: now
        });
        ctx.jobIds.push(Number(row?.lastInsertRowid || 0));
        created.push({ endpoint: 'POST /api/new/jobs', id: Number(row?.lastInsertRowid || 0) });
      } else if (key === 'jobApplications') {
        if (!ctx.jobIds.length) await seedArea('jobs', 1, ctx);
        const jobId = pick(ctx.jobIds, i);
        const row = await insertRow('job_applications', {
          job_id: jobId,
          applicant_id: user.id,
          note: 'Test basvuru notu.',
          message: 'Test basvuru notu.',
          cv_link: 'https://example.com/cv.pdf',
          contact_channel: 'email',
          contact_value: `${user.kadi}@test.sdal.local`,
          city: 'Istanbul',
          status: 'pending',
          created_at: now
        });
        created.push({ endpoint: 'POST /api/new/jobs/:id/apply', id: Number(row?.lastInsertRowid || 0), jobId });
      } else if (key === 'requests') {
        const table = dbDriver === 'postgres' ? 'support_requests' : 'member_requests';
        const row = await insertRow(table, {
          user_id: user.id,
          requester_user_id: user.id,
          type: 'support',
          request_type: 'support',
          subject: `Test talep ${i + 1}`,
          message: 'Admin seed tarafindan olusturuldu.',
          note: 'Admin seed tarafindan olusturuldu.',
          status: 'pending',
          created_at: now,
          updated_at: now
        });
        created.push({ endpoint: 'POST /api/new/requests', id: Number(row?.lastInsertRowid || 0) });
      } else if (key === 'messages') {
        const thread = await insertRow('sdal_messenger_threads', {
          user_a_id: user.id,
          user_b_id: other.id,
          created_at: now,
          updated_at: now,
          last_message_at: now
        });
        const threadId = Number(thread?.lastInsertRowid || 0);
        const row = await insertRow('sdal_messenger_messages', {
          thread_id: threadId,
          sender_id: user.id,
          receiver_id: other.id,
          body: 'Test mesajı.',
          client_written_at: now,
          server_received_at: now,
          created_at: now,
          deleted_by_sender: boolParam(dbDriver, false),
          deleted_by_receiver: boolParam(dbDriver, false)
        });
        created.push({ endpoint: 'POST /api/sdal-messenger/threads/:id/messages', id: Number(row?.lastInsertRowid || 0), threadId });
      } else if (key === 'connections') {
        const row = await insertRow('connection_requests', {
          sender_id: user.id,
          receiver_id: other.id,
          status: 'pending',
          note: 'Test baglanti istegi.',
          created_at: now,
          updated_at: now
        });
        created.push({ endpoint: 'POST /api/new/connections/request/:id', id: Number(row?.lastInsertRowid || 0) });
      } else if (key === 'mentorship') {
        await updateById(dbDriver === 'postgres' ? 'users' : 'uyeler', other.id, { mentor_opt_in: boolParam(dbDriver, true), role: 'teacher' }).catch(() => null);
        const row = await insertRow('mentorship_requests', {
          requester_id: user.id,
          mentor_id: other.id,
          status: 'pending',
          message: 'Test mentorluk istegi.',
          created_at: now,
          updated_at: now
        });
        created.push({ endpoint: 'POST /api/new/mentorship/request/:id', id: Number(row?.lastInsertRowid || 0) });
      } else if (key === 'albums') {
        const categoryTable = dbDriver === 'postgres' ? 'album_categories' : 'album_kat';
        const photoTable = dbDriver === 'postgres' ? 'album_photos' : 'album_foto';
        const cat = await insertRow(categoryTable, dbDriver === 'postgres'
          ? {
              name: `${ctx.runId} Album ${i + 1}`,
              description: 'Test albumu.',
              created_at: now,
              last_upload_at: now,
              last_uploaded_by_user_id: user.id,
              is_active: true,
              visibility_scope: 'public',
              album_type: 'general',
              owner_user_id: user.id,
              is_system_album: false
            }
          : {
              kategori: `${ctx.runId} Album ${i + 1}`,
              aciklama: 'Test albumu.',
              ilktarih: now,
              sonekleme: now,
              sonekleyen: user.kadi,
              aktif: 1,
              visibility_scope: 'public',
              album_type: 'general',
              owner_user_id: user.id,
              is_system_album: 0
            });
        const categoryId = Number(cat?.lastInsertRowid || 0);
        const filename = await writeAlbumFile(ctx.runId, i);
        const photo = await insertRow(photoTable, dbDriver === 'postgres'
          ? {
              category_id: categoryId,
              file_name: filename,
              title: `Album fotografi ${i + 1}`,
              description: 'Test fotografi.',
              is_active: true,
              uploaded_by_user_id: user.id,
              created_at: now,
              updated_at: now,
              view_count: 0,
              allow_comments: true,
              tagged_user_ids_json: '[]'
            }
          : {
              katid: categoryId,
              dosyaadi: filename,
              baslik: `Album fotografi ${i + 1}`,
              aciklama: 'Test fotografi.',
              aktif: 1,
              ekleyenid: user.id,
              tarih: now,
              updated_at: now,
              hit: 0,
              allow_comments: 1,
              tagged_user_ids_json: '[]'
            });
        created.push({ endpoint: 'POST /api/album/upload', id: Number(photo?.lastInsertRowid || 0), categoryId });
      }

      await sleep(MIN_DELAY_MS);
    }
    return created;
  }

  async function run({ counts: rawCounts, actor, dryRun = false }) {
    const nowMs = Date.now();
    if (nowMs - lastRunAt < COOLDOWN_MS) {
      const err = new Error('Test verisi calistirma islemi cok sik tetiklendi. Biraz bekleyip tekrar deneyin.');
      err.statusCode = 429;
      throw err;
    }
    lastRunAt = nowMs;

    const counts = normalizeTestDataCounts(rawCounts);
    const runId = createRunId();
    const requestedMax = Math.max(...Object.values(counts), 1);
    const totalRequested = Object.values(counts).reduce((sum, item) => sum + item, 0);
    const actorCount = totalRequested > 0
      ? Math.min(Math.max(requestedMax + 4, 6), TURKISH_PROFILES.length)
      : 0;
    const startedAt = new Date().toISOString();
    const summary = {};
    const errors = [];

    const ctx = {
      runId,
      dryRun,
      users: await createUsers({ runId, actorCount, dryRun }),
      groupIds: [],
      jobIds: []
    };
    const groupNeed = Math.max(counts.groups, counts.groupPosts, counts.groupEvents, counts.groupAnnouncements);
    ctx.groupIds = dryRun || groupNeed === 0
      ? [-1]
      : await ensureBaseGroups(ctx.users, runId, groupNeed);

    for (const area of TEST_DATA_AREAS) {
      try {
        const items = await seedArea(area.key, counts[area.key], ctx);
        summary[area.key] = { requested: counts[area.key], created: items.length, items };
      } catch (err) {
        summary[area.key] = { requested: counts[area.key], created: 0, items: [] };
        errors.push({ area: area.key, message: err?.message || 'Bilinmeyen hata' });
        writeAppLog?.('error', 'admin_test_data_seed_area_failed', { area: area.key, message: err?.message });
      }
    }

    writeAppLog?.('info', 'admin_test_data_seed_run', {
      actorId: actor?.id || null,
      runId,
      dryRun,
      totalRequested,
      errors: errors.length
    });

    return {
      ok: errors.length === 0,
      runId,
      dryRun,
      startedAt,
      finishedAt: new Date().toISOString(),
      limits: { maxPerArea: MAX_PER_AREA, maxTotal: MAX_TOTAL_REQUESTED, cooldownMs: COOLDOWN_MS, delayMs: MIN_DELAY_MS },
      users: ctx.users.map((user) => ({ id: user.id, kadi: user.kadi, isim: user.isim, soyisim: user.soyisim, resim: user.resim || null })),
      counts,
      summary,
      errors
    };
  }

  return { run };
}
