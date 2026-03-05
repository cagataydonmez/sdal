import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { getPostgresPool, closePostgresPool, isPostgresConfigured } from '../src/infra/postgresPool.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationsDir = path.resolve(__dirname, '../migrations');

function parseArgs(argv) {
  const args = { command: 'up', steps: 1, to: '' };
  const positional = [];

  for (let i = 0; i < argv.length; i += 1) {
    const part = String(argv[i] || '');
    if (part === '--steps' || part === '-s') {
      args.steps = Math.max(parseInt(argv[i + 1] || '1', 10) || 1, 1);
      i += 1;
      continue;
    }
    if (part === '--to') {
      args.to = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
    positional.push(part);
  }

  if (positional.length > 0) {
    args.command = positional[0];
  }

  return args;
}

function listMigrationFiles(direction) {
  const suffix = direction === 'down' ? '.down.sql' : '.up.sql';
  return fs.readdirSync(migrationsDir)
    .filter((file) => file.endsWith(suffix))
    .sort((a, b) => a.localeCompare(b))
    .map((file) => {
      const name = file.replace(suffix, '');
      return {
        name,
        file,
        fullPath: path.join(migrationsDir, file)
      };
    });
}

async function ensureMigrationsTable(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrationNames(pool) {
  const rows = await pool.query('SELECT name, applied_at FROM schema_migrations ORDER BY applied_at ASC, name ASC');
  return rows.rows.map((row) => String(row.name));
}

async function applyMigration(pool, migration) {
  const sql = fs.readFileSync(migration.fullPath, 'utf8');
  await pool.query(sql);
  await pool.query('INSERT INTO schema_migrations (name, applied_at) VALUES ($1, NOW()) ON CONFLICT(name) DO NOTHING', [migration.name]);
}

async function rollbackMigration(pool, migration) {
  const sql = fs.readFileSync(migration.fullPath, 'utf8');
  await pool.query(sql);
  await pool.query('DELETE FROM schema_migrations WHERE name = $1', [migration.name]);
}

async function runUp(pool) {
  const allUp = listMigrationFiles('up');
  const applied = new Set(await getAppliedMigrationNames(pool));
  const pending = allUp.filter((m) => !applied.has(m.name));

  if (!pending.length) {
    console.log('[migrate] no pending migrations');
    return;
  }

  for (const migration of pending) {
    console.log(`[migrate] applying ${migration.file}`);
    await applyMigration(pool, migration);
  }

  console.log(`[migrate] applied ${pending.length} migration(s)`);
}

async function runDown(pool, { steps, to }) {
  const allUp = listMigrationFiles('up');
  const allDown = listMigrationFiles('down');
  const downByName = new Map(allDown.map((m) => [m.name, m]));
  const upOrder = allUp.map((m) => m.name);

  const applied = await getAppliedMigrationNames(pool);
  const appliedInOrder = upOrder.filter((name) => applied.includes(name));

  if (!appliedInOrder.length) {
    console.log('[migrate] nothing to rollback');
    return;
  }

  let rollbackNames = [];
  if (to) {
    const targetIndex = upOrder.indexOf(to);
    if (targetIndex < 0) {
      throw new Error(`--to target not found in migrations: ${to}`);
    }
    rollbackNames = appliedInOrder.filter((name) => upOrder.indexOf(name) > targetIndex);
  } else {
    rollbackNames = appliedInOrder.slice(-steps);
  }

  rollbackNames = rollbackNames.reverse();

  if (!rollbackNames.length) {
    console.log('[migrate] already at requested target');
    return;
  }

  for (const name of rollbackNames) {
    const down = downByName.get(name);
    if (!down) {
      throw new Error(`missing down migration for ${name}`);
    }
    console.log(`[migrate] rolling back ${down.file}`);
    await rollbackMigration(pool, down);
  }

  console.log(`[migrate] rolled back ${rollbackNames.length} migration(s)`);
}

async function runStatus(pool) {
  const allUp = listMigrationFiles('up');
  const applied = new Set(await getAppliedMigrationNames(pool));

  if (!allUp.length) {
    console.log('[migrate] no migration files found');
    return;
  }

  for (const migration of allUp) {
    const status = applied.has(migration.name) ? 'APPLIED' : 'PENDING';
    console.log(`${status.padEnd(8)} ${migration.file}`);
  }
}

async function main() {
  if (!isPostgresConfigured()) {
    throw new Error('DATABASE_URL is required for migration runner');
  }

  const args = parseArgs(process.argv.slice(2));
  const pool = getPostgresPool();
  if (!pool) {
    throw new Error('Failed to initialize postgres pool');
  }

  await ensureMigrationsTable(pool);

  switch (args.command) {
    case 'up':
      await runUp(pool);
      break;
    case 'down':
      await runDown(pool, args);
      break;
    case 'status':
      await runStatus(pool);
      break;
    default:
      throw new Error(`Unknown command: ${args.command}. Use one of: up, down, status`);
  }
}

main()
  .then(async () => {
    await closePostgresPool();
  })
  .catch(async (err) => {
    console.error('[migrate] failed:', err?.message || err);
    await closePostgresPool();
    process.exit(1);
  });
