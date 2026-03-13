import path from 'path';
import Database from 'better-sqlite3';

export const defaultModuleKeys = [
  'feed',
  'main_feed',
  'explore',
  'following',
  'groups',
  'messages',
  'messenger',
  'notifications',
  'albums',
  'games',
  'events',
  'announcements',
  'jobs',
  'profile',
  'help',
  'requests'
];

function execSafely(db, sql) {
  try {
    db.exec(sql);
  } catch {
    // ignore duplicate or already-exists errors
  }
}

function hasTable(db, tableName) {
  const row = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?")
    .get(String(tableName || ''));
  return Boolean(row);
}

function hasColumn(db, tableName, columnName) {
  try {
    const cols = db.prepare(`PRAGMA table_info("${String(tableName || '').replace(/"/g, '""')}")`).all();
    return cols.some((row) => String(row?.name || '') === String(columnName || ''));
  } catch {
    return false;
  }
}

function ensureTableColumns(db, tableName, columns) {
  if (!hasTable(db, tableName)) return;
  for (const [columnName, columnDef] of columns) {
    if (hasColumn(db, tableName, columnName)) continue;
    execSafely(
      db,
      `ALTER TABLE "${String(tableName).replace(/"/g, '""')}" ADD COLUMN ${columnDef}`
    );
  }
}

export function ensureUyelerCompatibilityColumns(db) {
  const alterStatements = [
    "ALTER TABLE uyeler ADD COLUMN role TEXT DEFAULT 'user'",
    'ALTER TABLE uyeler ADD COLUMN verified INTEGER DEFAULT 0',
    "ALTER TABLE uyeler ADD COLUMN verification_status TEXT DEFAULT 'pending'",
    'ALTER TABLE uyeler ADD COLUMN kvkk_consent_at TEXT',
    'ALTER TABLE uyeler ADD COLUMN directory_consent_at TEXT',
    'ALTER TABLE uyeler ADD COLUMN sehir TEXT',
    'ALTER TABLE uyeler ADD COLUMN meslek TEXT',
    'ALTER TABLE uyeler ADD COLUMN websitesi TEXT',
    'ALTER TABLE uyeler ADD COLUMN universite TEXT',
    'ALTER TABLE uyeler ADD COLUMN dogumgun INTEGER DEFAULT 0',
    'ALTER TABLE uyeler ADD COLUMN dogumay INTEGER DEFAULT 0',
    'ALTER TABLE uyeler ADD COLUMN dogumyil INTEGER DEFAULT 0',
    'ALTER TABLE uyeler ADD COLUMN mailkapali INTEGER DEFAULT 0',
    'ALTER TABLE uyeler ADD COLUMN imza TEXT',
    'ALTER TABLE uyeler ADD COLUMN sirket TEXT',
    'ALTER TABLE uyeler ADD COLUMN unvan TEXT',
    'ALTER TABLE uyeler ADD COLUMN uzmanlik TEXT',
    'ALTER TABLE uyeler ADD COLUMN linkedin_url TEXT',
    'ALTER TABLE uyeler ADD COLUMN universite_bolum TEXT',
    'ALTER TABLE uyeler ADD COLUMN mentor_opt_in INTEGER DEFAULT 0',
    'ALTER TABLE uyeler ADD COLUMN mentor_konulari TEXT',
    'ALTER TABLE uyeler ADD COLUMN online INTEGER DEFAULT 0',
    'ALTER TABLE uyeler ADD COLUMN sontarih TEXT',
    'ALTER TABLE uyeler ADD COLUMN sonislemtarih TEXT',
    'ALTER TABLE uyeler ADD COLUMN sonislemsaat TEXT',
    'ALTER TABLE uyeler ADD COLUMN sonip TEXT',
    'ALTER TABLE uyeler ADD COLUMN yasak INTEGER DEFAULT 0'
  ];
  for (const sql of alterStatements) execSafely(db, sql);
}

export function ensureSqliteRuntimeSchema(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS site_controls (
      id INTEGER PRIMARY KEY,
      site_open INTEGER DEFAULT 1,
      maintenance_message TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS module_controls (
      module_key TEXT PRIMARY KEY,
      is_open INTEGER DEFAULT 1,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS media_settings (
      id INTEGER PRIMARY KEY,
      storage_provider TEXT DEFAULT 'local',
      local_base_path TEXT,
      thumb_width INTEGER DEFAULT 200,
      feed_width INTEGER DEFAULT 800,
      full_width INTEGER DEFAULT 1600,
      webp_quality INTEGER DEFAULT 80,
      max_upload_bytes INTEGER DEFAULT 10485760,
      avif_enabled INTEGER DEFAULT 0,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS verification_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      status TEXT DEFAULT 'pending',
      request_type TEXT,
      note TEXT,
      proof_path TEXT,
      proof_image_record_id TEXT,
      reviewer_id INTEGER,
      reviewer_note TEXT,
      resolution_note TEXT,
      created_at TEXT,
      updated_at TEXT,
      reviewed_at TEXT
    );
    CREATE TABLE IF NOT EXISTS stories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      image TEXT,
      image_record_id TEXT,
      caption TEXT,
      created_at TEXT,
      expires_at TEXT
    );
    CREATE TABLE IF NOT EXISTS story_views (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      story_id INTEGER,
      user_id INTEGER,
      created_at TEXT
    );
    CREATE TABLE IF NOT EXISTS image_records (
      id TEXT PRIMARY KEY,
      user_id INTEGER,
      entity_type TEXT,
      entity_id TEXT,
      provider TEXT DEFAULT 'local',
      thumb_path TEXT,
      feed_path TEXT,
      full_path TEXT,
      width INTEGER,
      height INTEGER,
      mime TEXT,
      size_bytes INTEGER,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS chat_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      message TEXT,
      created_at TEXT
    );
    CREATE TABLE IF NOT EXISTS groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      owner_id INTEGER NOT NULL,
      privacy TEXT DEFAULT 'public',
      image TEXT,
      image_record_id TEXT,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS group_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      role TEXT DEFAULT 'member',
      created_at TEXT,
      approved_at TEXT,
      UNIQUE(group_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS group_join_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      status TEXT DEFAULT 'pending',
      note TEXT,
      reviewed_by INTEGER,
      reviewed_at TEXT,
      created_at TEXT,
      updated_at TEXT,
      UNIQUE(group_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS group_invites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      invited_user_id INTEGER NOT NULL,
      invited_by INTEGER,
      status TEXT DEFAULT 'pending',
      created_at TEXT,
      responded_at TEXT,
      UNIQUE(group_id, invited_user_id)
    );
    CREATE TABLE IF NOT EXISTS group_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      event_at TEXT,
      location TEXT,
      created_by INTEGER,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS group_announcements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      body TEXT,
      created_by INTEGER,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS event_comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      comment TEXT NOT NULL,
      created_at TEXT
    );
    CREATE TABLE IF NOT EXISTS event_responses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      response TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      UNIQUE(event_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS request_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_key TEXT UNIQUE NOT NULL,
      label TEXT NOT NULL,
      description TEXT,
      active INTEGER DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS member_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      category_key TEXT NOT NULL,
      payload_json TEXT,
      status TEXT DEFAULT 'pending',
      resolution_note TEXT,
      reviewer_id INTEGER,
      reviewed_at TEXT,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS connection_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender_id INTEGER NOT NULL,
      receiver_id INTEGER NOT NULL,
      status TEXT DEFAULT 'pending',
      created_at TEXT,
      updated_at TEXT,
      responded_at TEXT,
      UNIQUE(sender_id, receiver_id)
    );
    CREATE TABLE IF NOT EXISTS mentorship_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      requester_id INTEGER NOT NULL,
      mentor_id INTEGER NOT NULL,
      status TEXT DEFAULT 'requested',
      focus_area TEXT,
      message TEXT,
      created_at TEXT,
      updated_at TEXT,
      responded_at TEXT,
      UNIQUE(requester_id, mentor_id)
    );
    CREATE TABLE IF NOT EXISTS jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      poster_id INTEGER NOT NULL,
      company TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      location TEXT,
      job_type TEXT,
      link TEXT,
      created_at TEXT
    );
    CREATE TABLE IF NOT EXISTS job_applications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      job_id INTEGER NOT NULL,
      applicant_id INTEGER NOT NULL,
      cover_letter TEXT,
      created_at TEXT,
      UNIQUE(job_id, applicant_id)
    );
    CREATE TABLE IF NOT EXISTS email_change_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      new_email TEXT NOT NULL,
      token TEXT NOT NULL UNIQUE,
      status TEXT DEFAULT 'pending',
      expires_at TEXT,
      created_at TEXT,
      verified_at TEXT
    );
    CREATE TABLE IF NOT EXISTS engagement_ab_config (
      variant TEXT PRIMARY KEY,
      label TEXT,
      is_enabled INTEGER DEFAULT 1,
      is_default INTEGER DEFAULT 0,
      weight REAL DEFAULT 1,
      description TEXT,
      created_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS engagement_ab_assignments (
      user_id INTEGER PRIMARY KEY,
      variant TEXT NOT NULL,
      assigned_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS network_suggestion_ab_config (
      variant TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      traffic_pct INTEGER NOT NULL DEFAULT 0,
      enabled INTEGER NOT NULL DEFAULT 1,
      params_json TEXT,
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS network_suggestion_ab_assignments (
      user_id INTEGER PRIMARY KEY,
      variant TEXT NOT NULL,
      assigned_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS network_suggestion_ab_change_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action_type TEXT NOT NULL DEFAULT 'apply',
      related_change_id INTEGER,
      actor_user_id INTEGER,
      recommendation_index INTEGER,
      cohort TEXT,
      window_days INTEGER,
      payload_json TEXT,
      before_snapshot_json TEXT,
      after_snapshot_json TEXT,
      created_at TEXT NOT NULL,
      rolled_back_at TEXT,
      rollback_change_id INTEGER
    );
    CREATE TABLE IF NOT EXISTS member_engagement_scores (
      user_id INTEGER PRIMARY KEY,
      ab_variant TEXT,
      score REAL DEFAULT 0,
      raw_score REAL DEFAULT 0,
      creator_score REAL DEFAULT 0,
      engagement_received_score REAL DEFAULT 0,
      community_score REAL DEFAULT 0,
      network_score REAL DEFAULT 0,
      quality_score REAL DEFAULT 0,
      penalty_score REAL DEFAULT 0,
      posts_30d INTEGER DEFAULT 0,
      posts_7d INTEGER DEFAULT 0,
      likes_received_30d INTEGER DEFAULT 0,
      comments_received_30d INTEGER DEFAULT 0,
      likes_given_30d INTEGER DEFAULT 0,
      comments_given_30d INTEGER DEFAULT 0,
      followers_count INTEGER DEFAULT 0,
      following_count INTEGER DEFAULT 0,
      follows_gained_30d INTEGER DEFAULT 0,
      follows_given_30d INTEGER DEFAULT 0,
      stories_30d INTEGER DEFAULT 0,
      story_views_received_30d INTEGER DEFAULT 0,
      chat_messages_30d INTEGER DEFAULT 0,
      last_activity_at TEXT,
      computed_at TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS game_scores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      game_key TEXT,
      score INTEGER,
      payload_json TEXT,
      created_at TEXT
    );
  `);

  ensureTableColumns(db, 'posts', [
    ['group_id', 'group_id INTEGER'],
    ['image_record_id', 'image_record_id TEXT']
  ]);

  ensureTableColumns(db, 'events', [
    ['title', 'title TEXT'],
    ['description', 'description TEXT'],
    ['location', 'location TEXT'],
    ['starts_at', 'starts_at TEXT'],
    ['ends_at', 'ends_at TEXT'],
    ['image', 'image TEXT'],
    ['created_at', 'created_at TEXT'],
    ['created_by', 'created_by INTEGER'],
    ['approved', 'approved INTEGER DEFAULT 1'],
    ['approved_by', 'approved_by INTEGER'],
    ['approved_at', 'approved_at TEXT'],
    ['show_response_counts', 'show_response_counts INTEGER DEFAULT 1'],
    ['show_attendee_names', 'show_attendee_names INTEGER DEFAULT 0'],
    ['show_decliner_names', 'show_decliner_names INTEGER DEFAULT 0']
  ]);

  ensureTableColumns(db, 'announcements', [
    ['title', 'title TEXT'],
    ['body', 'body TEXT'],
    ['image', 'image TEXT'],
    ['created_at', 'created_at TEXT'],
    ['created_by', 'created_by INTEGER'],
    ['approved', 'approved INTEGER DEFAULT 1'],
    ['approved_by', 'approved_by INTEGER'],
    ['approved_at', 'approved_at TEXT']
  ]);

  ensureTableColumns(db, 'verification_requests', [
    ['status', 'status TEXT DEFAULT \'pending\''],
    ['reviewer_id', 'reviewer_id INTEGER'],
    ['reviewed_at', 'reviewed_at TEXT'],
    ['created_at', 'created_at TEXT']
  ]);

  ensureTableColumns(db, 'member_engagement_scores', [
    ['score', 'score REAL DEFAULT 0'],
    ['updated_at', 'updated_at TEXT']
  ]);

  ensureTableColumns(db, 'group_events', [
    ['created_by', 'created_by INTEGER']
  ]);

  ensureTableColumns(db, 'group_announcements', [
    ['created_by', 'created_by INTEGER']
  ]);

  if (hasTable(db, 'stories')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id)');
  }
  if (hasTable(db, 'story_views')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_story_views_user_id ON story_views(user_id)');
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_story_views_story_id ON story_views(story_id)');
  }
  if (hasTable(db, 'notifications')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at)');
  }
  if (hasTable(db, 'posts')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts(user_id, created_at)');
  }
  if (hasTable(db, 'post_comments')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_post_comments_post_created ON post_comments(post_id, created_at)');
  }
  if (hasTable(db, 'group_members')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_group_members_group_user ON group_members(group_id, user_id)');
  }
  if (hasTable(db, 'member_requests')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_member_requests_user_status ON member_requests(user_id, status)');
  }
  if (hasTable(db, 'connection_requests')) {
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_connection_requests_receiver_status ON connection_requests(receiver_id, status, created_at DESC)');
    execSafely(db, 'CREATE INDEX IF NOT EXISTS idx_connection_requests_sender_status ON connection_requests(sender_id, status, created_at DESC)');
  }

  ensureUyelerCompatibilityColumns(db);
}

export function seedSqliteRuntimeDefaults(db, uploadsDir = '/var/lib/sdal/uploads') {
  const now = new Date().toISOString();
  db.prepare(
    'INSERT OR IGNORE INTO site_controls (id, site_open, maintenance_message, updated_at) VALUES (1, 1, ?, ?)'
  ).run('Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.', now);

  const moduleStmt = db.prepare(
    'INSERT OR IGNORE INTO module_controls (module_key, is_open, updated_at) VALUES (?, 1, ?)'
  );
  for (const moduleKey of defaultModuleKeys) moduleStmt.run(moduleKey, now);

  db.prepare(
    `INSERT OR IGNORE INTO media_settings
      (id, storage_provider, local_base_path, thumb_width, feed_width, full_width, webp_quality, max_upload_bytes, avif_enabled, updated_at)
     VALUES (1, 'local', ?, 200, 800, 1600, 80, 10485760, 0, ?)`
  ).run(String(uploadsDir || '/var/lib/sdal/uploads'), now);

  db.prepare(
    `INSERT OR IGNORE INTO request_categories
      (category_key, label, description, active, created_at, updated_at)
     VALUES
      ('general_support', 'Genel Destek', 'Genel destek talepleri', 1, ?, ?),
      ('verification', 'Doğrulama', 'Hesap doğrulama talepleri', 1, ?, ?),
      ('graduation_year_change', 'Mezuniyet Yılı Değişikliği', 'Mezuniyet yılı değişiklik talepleri', 1, ?, ?)`
  ).run(now, now, now, now, now, now);

  db.prepare(
    `INSERT OR IGNORE INTO engagement_ab_config
      (variant, label, is_enabled, is_default, weight, description, created_at, updated_at)
     VALUES
      ('control', 'Control', 1, 1, 1.0, 'Default ranking', ?, ?),
      ('boosted', 'Boosted', 1, 0, 1.0, 'Alternative ranking', ?, ?)`
  ).run(now, now, now, now);
}

function parseArgs(argv) {
  const args = {
    dbPath: '',
    seed: true
  };
  for (let i = 0; i < argv.length; i += 1) {
    const key = String(argv[i] || '').trim();
    const next = String(argv[i + 1] || '').trim();
    if (key === '--db' || key === '--db-path') {
      args.dbPath = next;
      i += 1;
    } else if (key === '--no-seed') {
      args.seed = false;
    }
  }
  return args;
}

function runCli() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.dbPath) {
    throw new Error('--db-path is required');
  }
  const dbPath = path.resolve(args.dbPath);
  const db = new Database(dbPath);
  try {
    ensureSqliteRuntimeSchema(db);
    if (args.seed) seedSqliteRuntimeDefaults(db, process.env.SDAL_UPLOADS_DIR || '/var/lib/sdal/uploads');
  } finally {
    db.close();
  }
  console.log(`[sqlite-schema] ensured runtime schema for ${dbPath}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runCli();
}
