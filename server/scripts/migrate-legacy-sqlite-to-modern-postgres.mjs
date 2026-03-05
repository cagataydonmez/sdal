import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';
import { getPostgresPool, closePostgresPool, isPostgresConfigured } from '../src/infra/postgresPool.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '../..');

function parseArgs(argv) {
  const args = {
    truncate: true,
    sqlitePath: '',
    reportPath: ''
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = String(argv[i] || '');
    if (arg === '--no-truncate') {
      args.truncate = false;
      continue;
    }
    if (arg === '--truncate') {
      args.truncate = true;
      continue;
    }
    if (arg === '--sqlite' || arg === '--sqlite-path') {
      args.sqlitePath = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (arg === '--report') {
      args.reportPath = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
  }

  return args;
}

function toTimestamp(value) {
  if (value == null) return null;
  const raw = String(value).trim();
  if (!raw) return null;
  const ms = Date.parse(raw);
  if (!Number.isFinite(ms)) return null;
  return new Date(ms).toISOString();
}

function toDateOnly(value) {
  const ts = toTimestamp(value);
  if (!ts) return null;
  return ts.slice(0, 10);
}

function toText(value) {
  if (value == null) return null;
  const text = String(value).trim();
  return text ? text : null;
}

function toInt(value) {
  if (value == null || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.trunc(n);
}

function toFloat(value) {
  if (value == null || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return n;
}

function toBool(value) {
  if (value == null || value === '') return false;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  const text = String(value).trim().toLowerCase();
  return ['1', 'true', 'evet', 'yes'].includes(text);
}

function toJson(value) {
  if (value == null || value === '') return null;
  if (typeof value === 'object') return JSON.stringify(value);
  const text = String(value).trim();
  if (!text) return null;
  try {
    const parsed = JSON.parse(text);
    return JSON.stringify(parsed);
  } catch {
    return null;
  }
}

function normalizeRole(row) {
  const role = String(row?.role || '').trim().toLowerCase();
  if (['root', 'admin', 'mod', 'user'].includes(role)) return role;
  return toBool(row?.admin) ? 'admin' : 'user';
}

function qident(name) {
  return `"${String(name).replace(/"/g, '""')}"`;
}

function buildInsertSql(table, columns, rowCount, onConflict) {
  const columnSql = columns.map((c) => qident(c)).join(', ');
  const valuesSql = [];
  for (let i = 0; i < rowCount; i += 1) {
    const start = i * columns.length;
    const placeholders = columns.map((_, idx) => `$${start + idx + 1}`);
    valuesSql.push(`(${placeholders.join(', ')})`);
  }
  return `INSERT INTO ${qident(table)} (${columnSql}) VALUES ${valuesSql.join(', ')} ${onConflict || ''}`.trim();
}

function tableExistsSqlite(sqlite, table) {
  const row = sqlite.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?").get(table);
  return Boolean(row);
}

async function tableExistsPg(pgPool, table) {
  const row = await pgPool.query(
    `SELECT 1
     FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = $1
     LIMIT 1`,
    [table]
  );
  return row.rows.length > 0;
}

async function syncIdentitySequence(pgPool, table, column = 'id') {
  await pgPool.query(
    `SELECT setval(
      pg_get_serial_sequence($1, $2),
      COALESCE((SELECT MAX(${qident(column)}) FROM ${qident(table)}), 1),
      TRUE
    )`,
    [table, column]
  );
}

function mapRows(rows, map) {
  const mappedRows = [];
  const targetColumns = map.targetColumns;

  for (const row of rows) {
    const out = {};
    for (const column of targetColumns) {
      const mapper = map.map[column];
      if (typeof mapper === 'function') {
        out[column] = mapper(row);
      } else if (typeof mapper === 'string') {
        out[column] = row[mapper];
      } else {
        out[column] = null;
      }
    }
    mappedRows.push(out);
  }

  return mappedRows;
}

async function copyMapping(sqlite, pgPool, mapping, report, { truncate }) {
  const source = mapping.source;
  const target = mapping.target;
  const reportEntry = {
    source,
    target,
    sourceTableExists: true,
    targetTableExists: true,
    sourceCount: 0,
    targetCount: 0,
    insertedCount: 0,
    skipped: false,
    notes: []
  };

  const sourceExists = mapping.syntheticSource ? true : tableExistsSqlite(sqlite, source);
  reportEntry.sourceTableExists = sourceExists;
  if (!sourceExists) {
    reportEntry.skipped = true;
    reportEntry.sourceCount = 0;
    reportEntry.targetCount = Number((await pgPool.query(`SELECT COUNT(*)::bigint AS cnt FROM ${qident(target)}`)).rows[0]?.cnt || 0);
    reportEntry.notes.push('source table not found in sqlite; skipped');
    report.tables.push(reportEntry);
    return;
  }

  const targetExists = await tableExistsPg(pgPool, target);
  reportEntry.targetTableExists = targetExists;
  if (!targetExists) {
    reportEntry.skipped = true;
    reportEntry.notes.push('target table not found in postgres schema');
    report.tables.push(reportEntry);
    report.mismatches.push({
      source,
      target,
      reason: 'target_missing'
    });
    return;
  }

  const sourceRows = mapping.syntheticSource
    ? mapping.syntheticSource(sqlite)
    : sqlite.prepare(mapping.selectSql || `SELECT * FROM ${qident(source)}`).all();

  reportEntry.sourceCount = sourceRows.length;

  if (!sourceRows.length) {
    reportEntry.targetCount = Number((await pgPool.query(`SELECT COUNT(*)::bigint AS cnt FROM ${qident(target)}`)).rows[0]?.cnt || 0);
    report.tables.push(reportEntry);
    return;
  }

  const mappedRows = mapRows(sourceRows, mapping);
  const columns = mapping.targetColumns;
  const batchSize = mapping.batchSize || 500;
  const onConflict = mapping.onConflict || '';

  if (truncate && mapping.resetTarget !== false) {
    await pgPool.query(`TRUNCATE TABLE ${qident(target)} RESTART IDENTITY CASCADE`);
  }

  for (let offset = 0; offset < mappedRows.length; offset += batchSize) {
    const batch = mappedRows.slice(offset, offset + batchSize);
    const values = [];
    for (const row of batch) {
      for (const column of columns) {
        values.push(row[column]);
      }
    }
    const sql = buildInsertSql(target, columns, batch.length, onConflict);
    const result = await pgPool.query(sql, values);
    reportEntry.insertedCount += Number(result.rowCount || 0);
  }

  const targetCountRow = await pgPool.query(`SELECT COUNT(*)::bigint AS cnt FROM ${qident(target)}`);
  reportEntry.targetCount = Number(targetCountRow.rows[0]?.cnt || 0);

  if (reportEntry.sourceCount !== reportEntry.targetCount) {
    report.mismatches.push({
      source,
      target,
      sourceCount: reportEntry.sourceCount,
      targetCount: reportEntry.targetCount,
      reason: 'row_count_mismatch'
    });
  }

  report.tables.push(reportEntry);
}

function buildMappings() {
  return [
    {
      source: 'uyeler',
      target: 'users',
      targetColumns: [
        'id', 'username', 'password_hash', 'first_name', 'last_name', 'activation_token', 'email',
        'is_active', 'is_banned', 'is_profile_initialized', 'website_url', 'signature', 'profession', 'city',
        'is_email_hidden', 'profile_view_count', 'homepage_page_id', 'graduation_year', 'university_name',
        'birth_day', 'birth_month', 'birth_year', 'last_activity_date', 'last_activity_time', 'is_online',
        'created_at', 'last_seen_at', 'legacy_admin_flag', 'last_ip', 'avatar_path', 'is_album_admin',
        'quick_access_ids_json', 'legacy_status_last_activity_at', 'legacy_status_is_online',
        'previous_last_seen_at', 'role', 'is_verified', 'verification_status', 'privacy_consent_at',
        'directory_consent_at', 'company_name', 'job_title', 'expertise', 'linkedin_url',
        'university_department', 'is_mentor_opted_in', 'mentor_topics', 'oauth_provider',
        'oauth_subject', 'oauth_email_verified', 'updated_at'
      ],
      map: {
        id: (r) => toInt(r.id),
        username: (r) => toText(r.kadi),
        password_hash: (r) => toText(r.sifre),
        first_name: (r) => toText(r.isim),
        last_name: (r) => toText(r.soyisim),
        activation_token: (r) => toText(r.aktivasyon),
        email: (r) => toText(r.email),
        is_active: (r) => toBool(r.aktiv),
        is_banned: (r) => toBool(r.yasak),
        is_profile_initialized: (r) => toBool(r.ilkbd),
        website_url: (r) => toText(r.websitesi),
        signature: (r) => toText(r.imza),
        profession: (r) => toText(r.meslek),
        city: (r) => toText(r.sehir),
        is_email_hidden: (r) => toBool(r.mailkapali),
        profile_view_count: (r) => toInt(r.hit) || 0,
        homepage_page_id: (r) => toInt(r.ilksayfa),
        graduation_year: (r) => toInt(r.mezuniyetyili),
        university_name: (r) => toText(r.universite),
        birth_day: (r) => toInt(r.dogumgun),
        birth_month: (r) => toInt(r.dogumay),
        birth_year: (r) => toInt(r.dogumyil),
        last_activity_date: (r) => toDateOnly(r.sonislemtarih),
        last_activity_time: (r) => toText(r.sonislemsaat),
        is_online: (r) => toBool(r.online),
        created_at: (r) => toTimestamp(r.ilktarih),
        last_seen_at: (r) => toTimestamp(r.sontarih),
        legacy_admin_flag: (r) => toBool(r.admin),
        last_ip: (r) => toText(r.sonip),
        avatar_path: (r) => toText(r.resim),
        is_album_admin: (r) => toBool(r.albumadmin),
        quick_access_ids_json: (r) => toText(r.hizliliste),
        legacy_status_last_activity_at: (r) => toTimestamp(r.s_sonislem),
        legacy_status_is_online: (r) => toBool(r.s_online),
        previous_last_seen_at: (r) => toTimestamp(r.oncekisontarih),
        role: (r) => normalizeRole(r),
        is_verified: (r) => toBool(r.verified),
        verification_status: (r) => toText(r.verification_status) || (toBool(r.verified) ? 'verified' : 'pending'),
        privacy_consent_at: (r) => toTimestamp(r.kvkk_consent_at),
        directory_consent_at: (r) => toTimestamp(r.directory_consent_at),
        company_name: (r) => toText(r.sirket),
        job_title: (r) => toText(r.unvan),
        expertise: (r) => toText(r.uzmanlik),
        linkedin_url: (r) => toText(r.linkedin_url),
        university_department: (r) => toText(r.universite_bolum),
        is_mentor_opted_in: (r) => toBool(r.mentor_opt_in),
        mentor_topics: (r) => toText(r.mentor_konulari),
        oauth_provider: (r) => toText(r.oauth_provider),
        oauth_subject: (r) => toText(r.oauth_subject),
        oauth_email_verified: (r) => toBool(r.oauth_email_verified),
        updated_at: (r) => toTimestamp(r.sontarih) || toTimestamp(r.ilktarih) || new Date().toISOString()
      }
    },
    {
      source: 'oauth_accounts',
      target: 'oauth_identities',
      targetColumns: ['id', 'user_id', 'provider', 'provider_subject', 'email', 'profile_json', 'created_at', 'updated_at'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        provider: (r) => toText(r.provider),
        provider_subject: (r) => toText(r.provider_user_id),
        email: (r) => toText(r.email),
        profile_json: (r) => toJson(r.profile_json),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'site_controls',
      target: 'site_settings',
      targetColumns: ['id', 'site_open', 'maintenance_message', 'updated_at'],
      map: {
        id: (r) => toInt(r.id) || 1,
        site_open: (r) => toBool(r.site_open),
        maintenance_message: (r) => toText(r.maintenance_message),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'module_controls',
      target: 'module_settings',
      targetColumns: ['module_key', 'is_open', 'updated_at'],
      map: {
        module_key: (r) => toText(r.module_key),
        is_open: (r) => toBool(r.is_open),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'media_settings',
      target: 'media_settings',
      targetColumns: ['id', 'storage_provider', 'local_base_path', 'thumb_width', 'feed_width', 'full_width', 'webp_quality', 'max_upload_bytes', 'avif_enabled', 'updated_at'],
      map: {
        id: (r) => toInt(r.id) || 1,
        storage_provider: (r) => toText(r.storage_provider) || 'local',
        local_base_path: (r) => toText(r.local_base_path),
        thumb_width: (r) => toInt(r.thumb_width),
        feed_width: (r) => toInt(r.feed_width),
        full_width: (r) => toInt(r.full_width),
        webp_quality: (r) => toInt(r.webp_quality),
        max_upload_bytes: (r) => toInt(r.max_upload_bytes),
        avif_enabled: (r) => toBool(r.avif_enabled),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'engagement_ab_config',
      target: 'engagement_variants',
      targetColumns: ['variant', 'name', 'description', 'traffic_pct', 'enabled', 'params_json', 'updated_at'],
      map: {
        variant: (r) => toText(r.variant),
        name: (r) => toText(r.name),
        description: (r) => toText(r.description),
        traffic_pct: (r) => toInt(r.traffic_pct),
        enabled: (r) => toBool(r.enabled),
        params_json: (r) => toJson(r.params_json),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'groups',
      target: 'groups',
      targetColumns: ['id', 'name', 'description', 'cover_image_url', 'owner_id', 'visibility', 'show_contact_hint', 'created_at', 'updated_at'],
      map: {
        id: (r) => toInt(r.id),
        name: (r) => toText(r.name),
        description: (r) => toText(r.description),
        cover_image_url: (r) => toText(r.cover_image),
        owner_id: (r) => toInt(r.owner_id),
        visibility: (r) => toText(r.visibility) || 'public',
        show_contact_hint: (r) => toBool(r.show_contact_hint),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'request_categories',
      target: 'support_request_categories',
      targetColumns: ['id', 'category_key', 'label', 'description', 'is_active', 'created_at', 'updated_at'],
      map: {
        id: (r) => toInt(r.id),
        category_key: (r) => toText(r.category_key),
        label: (r) => toText(r.label),
        description: (r) => toText(r.description),
        is_active: (r) => toBool(r.active),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'email_kategori',
      target: 'email_categories',
      targetColumns: ['id', 'name', 'type', 'value', 'description'],
      map: {
        id: (r) => toInt(r.id),
        name: (r) => toText(r.ad),
        type: (r) => toText(r.tur),
        value: (r) => toText(r.deger),
        description: (r) => toText(r.aciklama)
      }
    },
    {
      source: 'email_sablon',
      target: 'email_templates',
      targetColumns: ['id', 'name', 'subject', 'body_html', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        name: (r) => toText(r.ad),
        subject: (r) => toText(r.konu),
        body_html: (r) => toText(r.icerik),
        created_at: (r) => toTimestamp(r.olusturma)
      }
    },
    {
      source: 'mesaj_kategori',
      target: 'board_categories',
      targetColumns: ['id', 'name', 'description'],
      map: {
        id: (r) => toInt(r.id),
        name: (r) => toText(r.kategoriadi),
        description: (r) => toText(r.aciklama)
      }
    },
    {
      source: 'sayfalar',
      target: 'cms_pages',
      targetColumns: ['id', 'name', 'slug', 'view_count', 'last_viewed_at', 'last_editor_username', 'parent_page_id', 'is_visible_in_menu', 'is_redirect', 'body_html', 'layout_option', 'image_url', 'last_editor_ip'],
      map: {
        id: (r) => toInt(r.id),
        name: (r) => toText(r.sayfaismi),
        slug: (r) => toText(r.sayfaurl),
        view_count: (r) => toInt(r.hit) || 0,
        last_viewed_at: (r) => toTimestamp(r.sontarih),
        last_editor_username: (r) => toText(r.sonuye),
        parent_page_id: (r) => toInt(r.babaid),
        is_visible_in_menu: (r) => toBool(r.menugorun),
        is_redirect: (r) => toBool(r.yonlendir),
        body_html: (r) => toText(r.sayfametin),
        layout_option: (r) => toInt(r.mozellik),
        image_url: (r) => toText(r.resim),
        last_editor_ip: (r) => toText(r.sonip)
      }
    },
    {
      source: 'album_kat',
      target: 'album_categories',
      targetColumns: ['id', 'name', 'description', 'created_at', 'last_upload_at', 'last_uploaded_by_user_id', 'is_active'],
      map: {
        id: (r) => toInt(r.id),
        name: (r) => toText(r.kategori),
        description: (r) => toText(r.aciklama),
        created_at: (r) => toTimestamp(r.ilktarih),
        last_upload_at: (r) => toTimestamp(r.sonekleme),
        last_uploaded_by_user_id: (r) => toInt(r.sonekleyen),
        is_active: (r) => toBool(r.aktif)
      }
    },
    {
      source: 'image_records',
      target: 'media_assets',
      targetColumns: ['id', 'user_id', 'entity_type', 'entity_id', 'provider', 'thumb_path', 'feed_path', 'full_path', 'width', 'height', 'created_at'],
      map: {
        id: (r) => toText(r.id),
        user_id: (r) => toInt(r.user_id),
        entity_type: (r) => toText(r.entity_type),
        entity_id: (r) => toInt(r.entity_id),
        provider: (r) => toText(r.provider),
        thumb_path: (r) => toText(r.thumb_path),
        feed_path: (r) => toText(r.feed_path),
        full_path: (r) => toText(r.full_path),
        width: (r) => toInt(r.width),
        height: (r) => toInt(r.height),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'posts',
      target: 'posts',
      targetColumns: ['id', 'author_id', 'content', 'image_url', 'media_asset_id', 'group_id', 'created_at', 'updated_at', 'deleted_at'],
      map: {
        id: (r) => toInt(r.id),
        author_id: (r) => toInt(r.user_id),
        content: (r) => toText(r.content),
        image_url: (r) => toText(r.image),
        media_asset_id: (r) => toText(r.image_record_id),
        group_id: (r) => toInt(r.group_id),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.created_at),
        deleted_at: () => null
      }
    },
    {
      source: 'post_comments',
      target: 'post_comments',
      targetColumns: ['id', 'post_id', 'author_id', 'body', 'created_at', 'updated_at', 'deleted_at'],
      map: {
        id: (r) => toInt(r.id),
        post_id: (r) => toInt(r.post_id),
        author_id: (r) => toInt(r.user_id),
        body: (r) => toText(r.comment),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.created_at),
        deleted_at: () => null
      }
    },
    {
      source: 'post_likes',
      target: 'post_reactions',
      targetColumns: ['id', 'post_id', 'user_id', 'reaction_type', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        post_id: (r) => toInt(r.post_id),
        user_id: (r) => toInt(r.user_id),
        reaction_type: () => 'like',
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'follows',
      target: 'user_follows',
      targetColumns: ['id', 'follower_id', 'following_id', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        follower_id: (r) => toInt(r.follower_id),
        following_id: (r) => toInt(r.following_id),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'stories',
      target: 'stories',
      targetColumns: ['id', 'author_id', 'image_url', 'media_asset_id', 'caption', 'created_at', 'expires_at', 'deleted_at'],
      map: {
        id: (r) => toInt(r.id),
        author_id: (r) => toInt(r.user_id),
        image_url: (r) => toText(r.image),
        media_asset_id: (r) => toText(r.image_record_id),
        caption: (r) => toText(r.caption),
        created_at: (r) => toTimestamp(r.created_at),
        expires_at: (r) => toTimestamp(r.expires_at),
        deleted_at: () => null
      }
    },
    {
      source: 'story_views',
      target: 'story_views',
      targetColumns: ['id', 'story_id', 'user_id', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        story_id: (r) => toInt(r.story_id),
        user_id: (r) => toInt(r.user_id),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'notifications',
      target: 'notifications',
      targetColumns: ['id', 'user_id', 'type', 'source_user_id', 'entity_id', 'message', 'read_at', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        type: (r) => toText(r.type),
        source_user_id: (r) => toInt(r.source_user_id),
        entity_id: (r) => toInt(r.entity_id),
        message: (r) => toText(r.message),
        read_at: (r) => toTimestamp(r.read_at),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'sdal_messenger_threads',
      target: 'conversations',
      targetColumns: ['id', 'participant_a_id', 'participant_b_id', 'created_at', 'updated_at', 'last_message_at'],
      map: {
        id: (r) => toInt(r.id),
        participant_a_id: (r) => toInt(r.user_a_id),
        participant_b_id: (r) => toInt(r.user_b_id),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.updated_at),
        last_message_at: (r) => toTimestamp(r.last_message_at)
      }
    },
    {
      source: 'sdal_messenger_threads',
      target: 'conversation_members',
      syntheticSource: (sqlite) => {
        if (!tableExistsSqlite(sqlite, 'sdal_messenger_threads')) return [];
        const threads = sqlite.prepare('SELECT id, user_a_id, user_b_id, created_at FROM sdal_messenger_threads').all();
        const rows = [];
        for (const t of threads) {
          rows.push({
            conversation_id: toInt(t.id),
            user_id: toInt(t.user_a_id),
            joined_at: toTimestamp(t.created_at)
          });
          rows.push({
            conversation_id: toInt(t.id),
            user_id: toInt(t.user_b_id),
            joined_at: toTimestamp(t.created_at)
          });
        }
        return rows;
      },
      targetColumns: ['conversation_id', 'user_id', 'role', 'joined_at', 'last_read_at'],
      map: {
        conversation_id: (r) => toInt(r.conversation_id),
        user_id: (r) => toInt(r.user_id),
        role: () => 'member',
        joined_at: (r) => r.joined_at || new Date().toISOString(),
        last_read_at: () => null
      },
      onConflict: 'ON CONFLICT (conversation_id, user_id) DO NOTHING',
      resetTarget: true
    },
    {
      source: 'sdal_messenger_messages',
      target: 'conversation_messages',
      targetColumns: ['id', 'conversation_id', 'sender_id', 'recipient_id', 'body', 'client_written_at', 'server_received_at', 'delivered_at', 'read_at', 'created_at', 'deleted_by_sender', 'deleted_by_recipient'],
      map: {
        id: (r) => toInt(r.id),
        conversation_id: (r) => toInt(r.thread_id),
        sender_id: (r) => toInt(r.sender_id),
        recipient_id: (r) => toInt(r.receiver_id),
        body: (r) => toText(r.body),
        client_written_at: (r) => toTimestamp(r.client_written_at),
        server_received_at: (r) => toTimestamp(r.server_received_at),
        delivered_at: (r) => toTimestamp(r.delivered_at),
        read_at: (r) => toTimestamp(r.read_at),
        created_at: (r) => toTimestamp(r.created_at),
        deleted_by_sender: (r) => toBool(r.deleted_by_sender),
        deleted_by_recipient: (r) => toBool(r.deleted_by_receiver)
      }
    },
    {
      source: 'chat_messages',
      target: 'live_chat_messages',
      targetColumns: ['id', 'user_id', 'body', 'created_at', 'updated_at'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        body: (r) => toText(r.message),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'events',
      target: 'events',
      targetColumns: ['id', 'title', 'description', 'location', 'starts_at', 'ends_at', 'created_at', 'created_by', 'approved', 'approved_by', 'approved_at', 'image_url', 'show_response_counts', 'show_attendee_names', 'show_decliner_names'],
      map: {
        id: (r) => toInt(r.id),
        title: (r) => toText(r.title),
        description: (r) => toText(r.description),
        location: (r) => toText(r.location),
        starts_at: (r) => toTimestamp(r.starts_at),
        ends_at: (r) => toTimestamp(r.ends_at),
        created_at: (r) => toTimestamp(r.created_at),
        created_by: (r) => toInt(r.created_by),
        approved: (r) => r.approved == null ? true : toBool(r.approved),
        approved_by: (r) => toInt(r.approved_by),
        approved_at: (r) => toTimestamp(r.approved_at),
        image_url: (r) => toText(r.image),
        show_response_counts: (r) => r.show_response_counts == null ? true : toBool(r.show_response_counts),
        show_attendee_names: (r) => toBool(r.show_attendee_names),
        show_decliner_names: (r) => toBool(r.show_decliner_names)
      }
    },
    {
      source: 'event_comments',
      target: 'event_comments',
      targetColumns: ['id', 'event_id', 'user_id', 'comment_body', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        event_id: (r) => toInt(r.event_id),
        user_id: (r) => toInt(r.user_id),
        comment_body: (r) => toText(r.comment),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'event_responses',
      target: 'event_responses',
      targetColumns: ['id', 'event_id', 'user_id', 'response', 'created_at', 'updated_at'],
      map: {
        id: (r) => toInt(r.id),
        event_id: (r) => toInt(r.event_id),
        user_id: (r) => toInt(r.user_id),
        response: (r) => toText(r.response),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'announcements',
      target: 'announcements',
      targetColumns: ['id', 'title', 'body', 'created_at', 'created_by', 'approved', 'approved_by', 'approved_at', 'image_url'],
      map: {
        id: (r) => toInt(r.id),
        title: (r) => toText(r.title),
        body: (r) => toText(r.body),
        created_at: (r) => toTimestamp(r.created_at),
        created_by: (r) => toInt(r.created_by),
        approved: (r) => r.approved == null ? true : toBool(r.approved),
        approved_by: (r) => toInt(r.approved_by),
        approved_at: (r) => toTimestamp(r.approved_at),
        image_url: (r) => toText(r.image)
      }
    },
    {
      source: 'jobs',
      target: 'jobs',
      targetColumns: ['id', 'poster_id', 'company', 'title', 'description', 'location', 'job_type', 'link', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        poster_id: (r) => toInt(r.poster_id),
        company: (r) => toText(r.company),
        title: (r) => toText(r.title),
        description: (r) => toText(r.description),
        location: (r) => toText(r.location),
        job_type: (r) => toText(r.job_type),
        link: (r) => toText(r.link),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'group_members',
      target: 'group_members',
      targetColumns: ['id', 'group_id', 'user_id', 'role', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        group_id: (r) => toInt(r.group_id),
        user_id: (r) => toInt(r.user_id),
        role: (r) => toText(r.role) || 'member',
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'group_join_requests',
      target: 'group_join_requests',
      targetColumns: ['id', 'group_id', 'user_id', 'status', 'created_at', 'reviewed_at', 'reviewed_by'],
      map: {
        id: (r) => toInt(r.id),
        group_id: (r) => toInt(r.group_id),
        user_id: (r) => toInt(r.user_id),
        status: (r) => toText(r.status),
        created_at: (r) => toTimestamp(r.created_at),
        reviewed_at: (r) => toTimestamp(r.reviewed_at),
        reviewed_by: (r) => toInt(r.reviewed_by)
      }
    },
    {
      source: 'group_invites',
      target: 'group_invites',
      targetColumns: ['id', 'group_id', 'invited_user_id', 'invited_by', 'status', 'created_at', 'responded_at'],
      map: {
        id: (r) => toInt(r.id),
        group_id: (r) => toInt(r.group_id),
        invited_user_id: (r) => toInt(r.invited_user_id),
        invited_by: (r) => toInt(r.invited_by),
        status: (r) => toText(r.status),
        created_at: (r) => toTimestamp(r.created_at),
        responded_at: (r) => toTimestamp(r.responded_at)
      }
    },
    {
      source: 'group_events',
      target: 'group_events',
      targetColumns: ['id', 'group_id', 'title', 'description', 'location', 'starts_at', 'ends_at', 'created_at', 'created_by'],
      map: {
        id: (r) => toInt(r.id),
        group_id: (r) => toInt(r.group_id),
        title: (r) => toText(r.title),
        description: (r) => toText(r.description),
        location: (r) => toText(r.location),
        starts_at: (r) => toTimestamp(r.starts_at),
        ends_at: (r) => toTimestamp(r.ends_at),
        created_at: (r) => toTimestamp(r.created_at),
        created_by: (r) => toInt(r.created_by)
      }
    },
    {
      source: 'group_announcements',
      target: 'group_announcements',
      targetColumns: ['id', 'group_id', 'title', 'body', 'created_at', 'created_by'],
      map: {
        id: (r) => toInt(r.id),
        group_id: (r) => toInt(r.group_id),
        title: (r) => toText(r.title),
        body: (r) => toText(r.body),
        created_at: (r) => toTimestamp(r.created_at),
        created_by: (r) => toInt(r.created_by)
      }
    },
    {
      source: 'gelenkutusu',
      target: 'direct_messages',
      targetColumns: ['id', 'recipient_id', 'sender_id', 'recipient_visible', 'subject', 'body_html', 'is_unread', 'created_at', 'sender_visible'],
      map: {
        id: (r) => toInt(r.id),
        recipient_id: (r) => toInt(r.kime),
        sender_id: (r) => toInt(r.kimden),
        recipient_visible: (r) => toBool(r.aktifgelen),
        subject: (r) => toText(r.konu),
        body_html: (r) => toText(r.mesaj),
        is_unread: (r) => toBool(r.yeni),
        created_at: (r) => toTimestamp(r.tarih),
        sender_visible: (r) => toBool(r.aktifgiden)
      }
    },
    {
      source: 'mesaj',
      target: 'board_messages',
      targetColumns: ['id', 'author_user_id', 'body_html', 'category_id', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        author_user_id: (r) => toInt(r.gonderenid),
        body_html: (r) => toText(r.mesaj),
        category_id: (r) => toInt(r.kategori),
        created_at: (r) => toTimestamp(r.tarih)
      }
    },
    {
      source: 'album_foto',
      target: 'album_photos',
      targetColumns: ['id', 'category_id', 'file_name', 'title', 'description', 'is_active', 'uploaded_by_user_id', 'created_at', 'view_count'],
      map: {
        id: (r) => toInt(r.id),
        category_id: (r) => toInt(r.katid),
        file_name: (r) => toText(r.dosyaadi),
        title: (r) => toText(r.baslik),
        description: (r) => toText(r.aciklama),
        is_active: (r) => toBool(r.aktif),
        uploaded_by_user_id: (r) => toInt(r.ekleyenid),
        created_at: (r) => toTimestamp(r.tarih),
        view_count: (r) => toInt(r.hit) || 0
      }
    },
    {
      source: 'album_fotoyorum',
      target: 'album_photo_comments',
      targetColumns: ['id', 'photo_id', 'author_username', 'comment_body', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        photo_id: (r) => toInt(r.fotoid),
        author_username: (r) => toText(r.uyeadi),
        comment_body: (r) => toText(r.yorum),
        created_at: (r) => toTimestamp(r.tarih)
      }
    },
    {
      source: 'filtre',
      target: 'blocked_terms',
      targetColumns: ['id', 'term'],
      map: {
        id: (r) => toInt(r.id),
        term: (r) => toText(r.kufur)
      }
    },
    {
      source: 'hmes',
      target: 'shoutbox_messages',
      targetColumns: ['id', 'username', 'message_body', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        username: (r) => toText(r.kadi),
        message_body: (r) => toText(r.metin),
        created_at: (r) => toTimestamp(r.tarih)
      }
    },
    {
      source: 'oyun_yilan',
      target: 'snake_scores',
      targetColumns: ['id', 'username', 'score', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        username: (r) => toText(r.isim),
        score: (r) => toInt(r.skor) || 0,
        created_at: (r) => toTimestamp(r.tarih)
      }
    },
    {
      source: 'oyun_tetris',
      target: 'tetris_scores',
      targetColumns: ['id', 'username', 'score', 'level', 'lines', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        username: (r) => toText(r.isim),
        score: (r) => toInt(r.puan) || 0,
        level: (r) => toInt(r.seviye),
        lines: (r) => toInt(r.satir),
        created_at: (r) => toTimestamp(r.tarih)
      }
    },
    {
      source: 'takimlar',
      target: 'tournament_teams',
      targetColumns: ['id', 'team_name', 'team_category_id', 'team_phone', 'captain_name', 'captain_graduation_year', 'player1_name', 'player1_graduation_year', 'player2_name', 'player2_graduation_year', 'player3_name', 'player3_graduation_year', 'player4_name', 'player4_graduation_year', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        team_name: (r) => toText(r.tisim),
        team_category_id: (r) => toInt(r.tkid),
        team_phone: (r) => toText(r.tktelefon),
        captain_name: (r) => toText(r.boyismi),
        captain_graduation_year: (r) => toText(r.boymezuniyet),
        player1_name: (r) => toText(r.ioyismi),
        player1_graduation_year: (r) => toText(r.ioymezuniyet),
        player2_name: (r) => toText(r.uoyismi),
        player2_graduation_year: (r) => toText(r.uoymezuniyet),
        player3_name: (r) => toText(r.doyismi),
        player3_graduation_year: (r) => toText(r.doymezuniyet),
        player4_name: () => null,
        player4_graduation_year: () => null,
        created_at: (r) => toTimestamp(r.tarih)
      }
    },
    {
      source: 'verification_requests',
      target: 'identity_verification_requests',
      targetColumns: ['id', 'user_id', 'status', 'proof_path', 'proof_media_asset_id', 'created_at', 'reviewed_at', 'reviewer_id'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        status: (r) => toText(r.status),
        proof_path: (r) => toText(r.proof_path),
        proof_media_asset_id: (r) => toText(r.proof_image_record_id),
        created_at: (r) => toTimestamp(r.created_at),
        reviewed_at: (r) => toTimestamp(r.reviewed_at),
        reviewer_id: (r) => toInt(r.reviewer_id)
      }
    },
    {
      source: 'member_requests',
      target: 'support_requests',
      targetColumns: ['id', 'user_id', 'category_key', 'payload_json', 'status', 'created_at', 'reviewed_at', 'reviewer_id', 'resolution_note'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        category_key: (r) => toText(r.category_key),
        payload_json: (r) => toJson(r.payload_json),
        status: (r) => toText(r.status),
        created_at: (r) => toTimestamp(r.created_at),
        reviewed_at: (r) => toTimestamp(r.reviewed_at),
        reviewer_id: (r) => toInt(r.reviewer_id),
        resolution_note: (r) => toText(r.resolution_note)
      }
    },
    {
      source: 'email_change_requests',
      target: 'email_change_requests',
      targetColumns: ['id', 'user_id', 'current_email', 'new_email', 'token', 'status', 'created_at', 'expires_at', 'verified_at', 'ip', 'user_agent'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        current_email: (r) => toText(r.current_email),
        new_email: (r) => toText(r.new_email),
        token: (r) => toText(r.token),
        status: (r) => toText(r.status),
        created_at: (r) => toTimestamp(r.created_at),
        expires_at: (r) => toTimestamp(r.expires_at),
        verified_at: (r) => toTimestamp(r.verified_at),
        ip: (r) => toText(r.ip),
        user_agent: (r) => toText(r.user_agent)
      }
    },
    {
      source: 'moderator_scopes',
      target: 'moderation_scopes',
      targetColumns: ['id', 'user_id', 'scope_type', 'scope_value', 'graduation_year', 'created_by', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        scope_type: (r) => toText(r.scope_type),
        scope_value: (r) => toText(r.scope_value),
        graduation_year: (r) => toInt(r.graduation_year),
        created_by: (r) => toInt(r.created_by),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'moderator_permissions',
      target: 'moderation_permissions',
      targetColumns: ['id', 'user_id', 'permission_key', 'enabled', 'created_by', 'updated_by', 'created_at', 'updated_at'],
      map: {
        id: (r) => toInt(r.id),
        user_id: (r) => toInt(r.user_id),
        permission_key: (r) => toText(r.permission_key),
        enabled: (r) => toBool(r.enabled),
        created_by: (r) => toInt(r.created_by),
        updated_by: (r) => toInt(r.updated_by),
        created_at: (r) => toTimestamp(r.created_at),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'audit_log',
      target: 'audit_logs',
      targetColumns: ['id', 'actor_user_id', 'action', 'target_type', 'target_id', 'metadata', 'ip', 'user_agent', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        actor_user_id: (r) => toInt(r.actor_user_id),
        action: (r) => toText(r.action),
        target_type: (r) => toText(r.target_type),
        target_id: (r) => toText(r.target_id),
        metadata: (r) => toJson(r.metadata),
        ip: (r) => toText(r.ip),
        user_agent: (r) => toText(r.user_agent),
        created_at: (r) => toTimestamp(r.created_at)
      }
    },
    {
      source: 'engagement_ab_assignments',
      target: 'engagement_variant_assignments',
      targetColumns: ['user_id', 'variant', 'assigned_at', 'updated_at'],
      map: {
        user_id: (r) => toInt(r.user_id),
        variant: (r) => toText(r.variant),
        assigned_at: (r) => toTimestamp(r.assigned_at),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'member_engagement_scores',
      target: 'user_engagement_scores',
      targetColumns: [
        'user_id', 'ab_variant', 'score', 'raw_score', 'creator_score', 'engagement_received_score',
        'community_score', 'network_score', 'quality_score', 'penalty_score', 'posts_30d', 'posts_7d',
        'likes_received_30d', 'comments_received_30d', 'likes_given_30d', 'comments_given_30d',
        'followers_count', 'following_count', 'follows_gained_30d', 'follows_given_30d', 'stories_30d',
        'story_views_received_30d', 'chat_messages_30d', 'last_activity_at', 'updated_at'
      ],
      map: {
        user_id: (r) => toInt(r.user_id),
        ab_variant: (r) => toText(r.ab_variant),
        score: (r) => toFloat(r.score),
        raw_score: (r) => toFloat(r.raw_score),
        creator_score: (r) => toFloat(r.creator_score),
        engagement_received_score: (r) => toFloat(r.engagement_received_score),
        community_score: (r) => toFloat(r.community_score),
        network_score: (r) => toFloat(r.network_score),
        quality_score: (r) => toFloat(r.quality_score),
        penalty_score: (r) => toFloat(r.penalty_score),
        posts_30d: (r) => toInt(r.posts_30d),
        posts_7d: (r) => toInt(r.posts_7d),
        likes_received_30d: (r) => toInt(r.likes_received_30d),
        comments_received_30d: (r) => toInt(r.comments_received_30d),
        likes_given_30d: (r) => toInt(r.likes_given_30d),
        comments_given_30d: (r) => toInt(r.comments_given_30d),
        followers_count: (r) => toInt(r.followers_count),
        following_count: (r) => toInt(r.following_count),
        follows_gained_30d: (r) => toInt(r.follows_gained_30d),
        follows_given_30d: (r) => toInt(r.follows_given_30d),
        stories_30d: (r) => toInt(r.stories_30d),
        story_views_received_30d: (r) => toInt(r.story_views_received_30d),
        chat_messages_30d: (r) => toInt(r.chat_messages_30d),
        last_activity_at: (r) => toTimestamp(r.last_activity_at),
        updated_at: (r) => toTimestamp(r.updated_at)
      }
    },
    {
      source: 'game_scores',
      target: 'game_scores',
      targetColumns: ['id', 'game_key', 'name', 'score', 'created_at'],
      map: {
        id: (r) => toInt(r.id),
        game_key: (r) => toText(r.game_key),
        name: (r) => toText(r.name),
        score: (r) => toInt(r.score),
        created_at: (r) => toTimestamp(r.created_at)
      }
    }
  ];
}

function fkChecks() {
  return [
    {
      name: 'posts.author_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM posts p LEFT JOIN users u ON u.id = p.author_id WHERE u.id IS NULL'
    },
    {
      name: 'post_comments.post_id -> posts.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM post_comments c LEFT JOIN posts p ON p.id = c.post_id WHERE p.id IS NULL'
    },
    {
      name: 'post_comments.author_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM post_comments c LEFT JOIN users u ON u.id = c.author_id WHERE u.id IS NULL'
    },
    {
      name: 'post_reactions.user_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM post_reactions r LEFT JOIN users u ON u.id = r.user_id WHERE u.id IS NULL'
    },
    {
      name: 'stories.author_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM stories s LEFT JOIN users u ON u.id = s.author_id WHERE u.id IS NULL'
    },
    {
      name: 'conversation_members.user_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM conversation_members m LEFT JOIN users u ON u.id = m.user_id WHERE u.id IS NULL'
    },
    {
      name: 'conversation_messages.conversation_id -> conversations.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM conversation_messages m LEFT JOIN conversations c ON c.id = m.conversation_id WHERE c.id IS NULL'
    },
    {
      name: 'notifications.user_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM notifications n LEFT JOIN users u ON u.id = n.user_id WHERE u.id IS NULL'
    },
    {
      name: 'group_members.group_id -> groups.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM group_members gm LEFT JOIN groups g ON g.id = gm.group_id WHERE g.id IS NULL'
    },
    {
      name: 'direct_messages.sender_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM direct_messages d LEFT JOIN users u ON u.id = d.sender_id WHERE u.id IS NULL'
    }
  ];
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!isPostgresConfigured()) {
    throw new Error('DATABASE_URL is required for sqlite -> modern postgres migration');
  }

  const sqlitePath = args.sqlitePath
    ? path.resolve(args.sqlitePath)
    : process.env.SQLITE_PATH
      ? path.resolve(process.env.SQLITE_PATH)
      : path.resolve(projectRoot, 'db/sdal.sqlite');

  const reportPath = args.reportPath
    ? path.resolve(args.reportPath)
    : process.env.MIGRATION_REPORT_PATH
      ? path.resolve(process.env.MIGRATION_REPORT_PATH)
      : path.resolve(projectRoot, 'migration_report.json');

  if (!fs.existsSync(sqlitePath)) {
    throw new Error(`SQLite source not found at ${sqlitePath}`);
  }

  const sqlite = new Database(sqlitePath, { readonly: true, fileMustExist: true });
  const pgPool = getPostgresPool();
  if (!pgPool) {
    throw new Error('Failed to initialize postgres pool');
  }

  const report = {
    startedAt: new Date().toISOString(),
    finishedAt: null,
    source: {
      sqlitePath
    },
    target: {
      databaseUrlHost: String(process.env.DATABASE_URL || '').replace(/:[^:@/]+@/, ':***@')
    },
    options: {
      truncate: args.truncate,
      reportPath
    },
    tables: [],
    mismatches: [],
    fkIntegrity: [],
    summary: {
      sourceRows: 0,
      targetRows: 0,
      mismatchCount: 0,
      fkViolationCount: 0
    }
  };

  try {
    const mappings = buildMappings();

    if (args.truncate) {
      const truncateTargets = mappings
        .map((m) => m.target)
        .filter((v, i, arr) => arr.indexOf(v) === i)
        .map((name) => qident(name))
        .join(', ');
      await pgPool.query(`TRUNCATE TABLE ${truncateTargets} RESTART IDENTITY CASCADE`);
    }

    for (const mapping of mappings) {
      console.log(`[data-migrate] ${mapping.source} -> ${mapping.target}`);
      await copyMapping(sqlite, pgPool, mapping, report, { truncate: false });
    }

    const sequenceTables = [
      'users', 'oauth_identities', 'groups', 'support_request_categories', 'email_categories',
      'email_templates', 'board_categories', 'cms_pages', 'album_categories', 'posts', 'post_comments',
      'post_reactions', 'user_follows', 'stories', 'story_views', 'notifications', 'conversations',
      'conversation_members', 'conversation_messages', 'live_chat_messages', 'events', 'event_comments',
      'event_responses', 'announcements', 'jobs', 'group_members', 'group_join_requests', 'group_invites',
      'group_events', 'group_announcements', 'direct_messages', 'board_messages', 'album_photos',
      'album_photo_comments', 'blocked_terms', 'shoutbox_messages', 'snake_scores', 'tetris_scores',
      'tournament_teams', 'identity_verification_requests', 'support_requests', 'email_change_requests',
      'moderation_scopes', 'moderation_permissions', 'audit_logs', 'game_scores'
    ];

    for (const table of sequenceTables) {
      try {
        await syncIdentitySequence(pgPool, table);
      } catch {
        // some tables may not have identity sequences in older pg versions/configs
      }
    }

    for (const check of fkChecks()) {
      try {
        const row = await pgPool.query(check.sql);
        const violations = Number(row.rows[0]?.violations || 0);
        report.fkIntegrity.push({ name: check.name, violations });
        if (violations > 0) {
          report.mismatches.push({
            source: 'fk_check',
            target: check.name,
            reason: 'fk_violation',
            violations
          });
        }
      } catch (err) {
        report.fkIntegrity.push({
          name: check.name,
          violations: null,
          error: err?.message || 'failed'
        });
        report.mismatches.push({
          source: 'fk_check',
          target: check.name,
          reason: 'fk_check_failed',
          error: err?.message || 'failed'
        });
      }
    }

    report.summary.sourceRows = report.tables.reduce((sum, item) => sum + Number(item.sourceCount || 0), 0);
    report.summary.targetRows = report.tables.reduce((sum, item) => sum + Number(item.targetCount || 0), 0);
    report.summary.mismatchCount = report.mismatches.length;
    report.summary.fkViolationCount = report.fkIntegrity.reduce(
      (sum, item) => sum + (Number.isFinite(item.violations) ? Number(item.violations) : 0),
      0
    );
    report.finishedAt = new Date().toISOString();

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

    if (report.summary.mismatchCount > 0 || report.summary.fkViolationCount > 0) {
      console.error(
        `[data-migrate] completed with issues. mismatches=${report.summary.mismatchCount} fkViolations=${report.summary.fkViolationCount}`
      );
      process.exitCode = 2;
      return;
    }

    console.log('[data-migrate] completed successfully');
    console.log(`[data-migrate] report written: ${reportPath}`);
  } finally {
    try {
      sqlite.close();
    } catch {
      // no-op
    }
    await closePostgresPool();
  }
}

main().catch(async (err) => {
  console.error('[data-migrate] failed:', err?.message || err);
  await closePostgresPool();
  process.exit(1);
});
