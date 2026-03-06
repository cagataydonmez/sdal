import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationsDir = path.resolve(__dirname, '../migrations');

function listSqlFiles(suffix) {
  return fs.readdirSync(migrationsDir)
    .filter((file) => file.endsWith(suffix))
    .sort((a, b) => a.localeCompare(b));
}

function baseName(file, suffix) {
  return file.slice(0, file.length - suffix.length);
}

function validateName(name) {
  return /^\d{3}_[a-z0-9_]+$/.test(name);
}

function checkTransactionMarkers(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const hasBegin = /\bBEGIN\b/i.test(text);
  const hasCommit = /\bCOMMIT\b/i.test(text);
  return hasBegin && hasCommit;
}

function run() {
  if (!fs.existsSync(migrationsDir)) {
    throw new Error(`migrations directory not found: ${migrationsDir}`);
  }

  const upFiles = listSqlFiles('.up.sql');
  const downFiles = listSqlFiles('.down.sql');

  if (!upFiles.length) {
    throw new Error('no .up.sql migration files found');
  }

  const upNames = upFiles.map((f) => baseName(f, '.up.sql'));
  const downNames = downFiles.map((f) => baseName(f, '.down.sql'));

  const upSet = new Set(upNames);
  const downSet = new Set(downNames);

  for (const name of upNames) {
    if (!validateName(name)) {
      throw new Error(`invalid migration name format: ${name}`);
    }
    if (!downSet.has(name)) {
      throw new Error(`missing down migration for: ${name}`);
    }
  }

  for (const name of downNames) {
    if (!validateName(name)) {
      throw new Error(`invalid down migration name format: ${name}`);
    }
    if (!upSet.has(name)) {
      throw new Error(`down migration has no matching up migration: ${name}`);
    }
  }

  const duplicateUp = upNames.find((name, i) => upNames.indexOf(name) !== i);
  if (duplicateUp) {
    throw new Error(`duplicate up migration name: ${duplicateUp}`);
  }
  const duplicateDown = downNames.find((name, i) => downNames.indexOf(name) !== i);
  if (duplicateDown) {
    throw new Error(`duplicate down migration name: ${duplicateDown}`);
  }

  for (const file of [...upFiles, ...downFiles]) {
    const fullPath = path.join(migrationsDir, file);
    if (!checkTransactionMarkers(fullPath)) {
      throw new Error(`migration file must include BEGIN/COMMIT: ${file}`);
    }
  }

  console.log(`[migrate:verify] ok. up=${upFiles.length} down=${downFiles.length}`);
}

try {
  run();
} catch (err) {
  console.error('[migrate:verify] failed:', err?.message || err);
  process.exit(1);
}
