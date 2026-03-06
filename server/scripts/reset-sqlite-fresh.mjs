import crypto from 'crypto';
import path from 'path';
import { promisify } from 'util';
import Database from 'better-sqlite3';
import {
  ensureSqliteRuntimeSchema,
  seedSqliteRuntimeDefaults
} from './sqlite-runtime-schema.mjs';

const scryptAsync = promisify(crypto.scrypt);
const PASSWORD_HASH_PREFIX = 'scrypt$';

function parseArgs(argv) {
  const args = {
    dbPath: '',
    rootPassword: '',
    cagatayPassword: '',
    cagatayEmail: 'cagatay@localhost',
    cagatayFirstName: 'Cagatay',
    cagatayLastName: 'Donmez',
    cagatayGraduationYear: '2011'
  };

  for (let i = 0; i < argv.length; i += 1) {
    const key = String(argv[i] || '').trim();
    const next = String(argv[i + 1] || '');
    switch (key) {
      case '--db':
      case '--db-path':
        args.dbPath = next.trim();
        i += 1;
        break;
      case '--root-password':
        args.rootPassword = next;
        i += 1;
        break;
      case '--cagatay-password':
        args.cagatayPassword = next;
        i += 1;
        break;
      case '--cagatay-email':
        args.cagatayEmail = next.trim() || args.cagatayEmail;
        i += 1;
        break;
      case '--cagatay-first-name':
        args.cagatayFirstName = next.trim() || args.cagatayFirstName;
        i += 1;
        break;
      case '--cagatay-last-name':
        args.cagatayLastName = next.trim() || args.cagatayLastName;
        i += 1;
        break;
      case '--cagatay-graduation-year':
        args.cagatayGraduationYear = next.trim() || args.cagatayGraduationYear;
        i += 1;
        break;
      default:
        break;
    }
  }

  return args;
}

function assertRequired(value, name) {
  if (!String(value || '').trim()) {
    throw new Error(`${name} is required`);
  }
}

function safeIdent(name) {
  return `"${String(name || '').replace(/"/g, '""')}"`;
}

function hasTable(db, tableName) {
  const row = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name = ?").get(tableName);
  return Boolean(row);
}

async function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = await scryptAsync(String(password), salt, 64);
  return `${PASSWORD_HASH_PREFIX}${salt}$${Buffer.from(derived).toString('hex')}`;
}

function buildUserInsert(db, userPatch = {}) {
  const now = new Date().toISOString();
  const values = {
    kadi: '',
    sifre: '',
    email: '',
    isim: '',
    soyisim: '',
    aktivasyon: `${Math.random().toString(36).slice(2)}${Date.now()}`,
    aktiv: 1,
    ilktarih: now,
    resim: '',
    mezuniyetyili: '0',
    ilkbd: 1,
    role: 'user',
    admin: 0,
    verified: 1,
    verification_status: 'approved',
    kvkk_consent_at: now,
    directory_consent_at: now,
    sonislemtarih: now.slice(0, 10),
    sonislemsaat: now.slice(11, 19)
  };

  for (const [key, value] of Object.entries(userPatch || {})) {
    values[key] = value;
  }

  const columnRows = db.prepare('PRAGMA table_info(uyeler)').all();
  const available = new Set(columnRows.map((row) => String(row.name || '')));
  const columns = Object.keys(values).filter((key) => available.has(key));
  const placeholders = columns.map(() => '?').join(', ');
  const sql = `INSERT INTO uyeler (${columns.map((c) => safeIdent(c)).join(', ')}) VALUES (${placeholders})`;
  const params = columns.map((c) => values[c]);
  return { sql, params };
}

function wipeAllData(db) {
  const tables = db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
  ).all().map((row) => String(row.name || '')).filter(Boolean);

  db.exec('PRAGMA foreign_keys = OFF');
  const tx = db.transaction(() => {
    for (const table of tables) {
      db.prepare(`DELETE FROM ${safeIdent(table)}`).run();
    }
    if (hasTable(db, 'sqlite_sequence')) {
      db.prepare('DELETE FROM sqlite_sequence').run();
    }
  });
  tx();
  db.exec('PRAGMA foreign_keys = ON');
}

function seedBaselineRows(db, uploadsDir) {
  seedSqliteRuntimeDefaults(db, uploadsDir);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  assertRequired(args.dbPath, '--db-path');
  assertRequired(args.rootPassword, '--root-password');
  assertRequired(args.cagatayPassword, '--cagatay-password');

  const dbPath = path.resolve(args.dbPath);
  const db = new Database(dbPath);
  try {
    if (!hasTable(db, 'uyeler')) {
      throw new Error(`uyeler table not found in sqlite database: ${dbPath}`);
    }

    ensureSqliteRuntimeSchema(db);
    wipeAllData(db);

    const rootHash = await hashPassword(args.rootPassword);
    const cagatayHash = await hashPassword(args.cagatayPassword);

    const rootInsert = buildUserInsert(db, {
      kadi: 'root',
      sifre: rootHash,
      email: 'root@localhost',
      isim: 'System',
      soyisim: 'Root',
      mezuniyetyili: '0',
      role: 'root',
      admin: 1
    });
    db.prepare(rootInsert.sql).run(rootInsert.params);

    const cagatayInsert = buildUserInsert(db, {
      kadi: 'cagatay',
      sifre: cagatayHash,
      email: args.cagatayEmail,
      isim: args.cagatayFirstName,
      soyisim: args.cagatayLastName,
      mezuniyetyili: args.cagatayGraduationYear,
      role: 'admin',
      admin: 1
    });
    db.prepare(cagatayInsert.sql).run(cagatayInsert.params);

    seedBaselineRows(db, String(process.env.SDAL_UPLOADS_DIR || '/var/lib/sdal/uploads'));

    const users = db.prepare('SELECT id, kadi, role, admin, aktiv FROM uyeler ORDER BY id').all();
    console.log('[reset-sqlite] database reset complete');
    console.log('[reset-sqlite] users:', JSON.stringify(users));
  } finally {
    try { db.close(); } catch {}
  }
}

main().catch((err) => {
  console.error('[reset-sqlite] failed:', err?.message || err);
  process.exit(1);
});
