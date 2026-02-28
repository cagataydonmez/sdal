/**
 * Wipe Legacy Media Script
 *
 * This script drops backward compatibility for legacy images by:
 * 1. Setting legacy `image` string columns to NULL in posts, stories, events, and groups.
 *    (Only post/story records WITHOUT an `image_record_id` will be completely cleared/deleted
 *     if they have no content, otherwise the image reference is just scrubbed).
 * 2. Purging physical files in old directories:
 *    - uploads/posts
 *    - uploads/stories
 *    - uploads/events
 *    - uploads/groups
 *
 * It leaves the new `uploads/images` directory intact where the variant pipeline operates.
 *
 * Paths: Use SDAL_DB_PATH / SDAL_UPLOADS_DIR env vars, or resolve from script location.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '../..');

console.log('--- SDAL Legacy Media Wipe Script ---');

// Setup Paths (env vars or project-relative defaults)
const dbPath = process.env.SDAL_DB_PATH || path.join(projectRoot, 'db', 'sdal.sqlite');
const uploadsDir = process.env.SDAL_UPLOADS_DIR || path.join(projectRoot, 'server', 'uploads');

const targets = [
  path.join(uploadsDir, 'posts'),
  path.join(uploadsDir, 'stories'),
  path.join(uploadsDir, 'events'),
  path.join(uploadsDir, 'groups'),
  path.join(uploadsDir, 'album'),
  path.join(uploadsDir, 'vesikalik')
];

let db;
try {
  db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  
  console.log('1. Wiping DB Legacy image columns...');
  
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map(r => r.name);
  const tableSet = new Set(tables);

  const wipeStatements = [
    { table: 'posts', stmt: `UPDATE posts SET image = NULL WHERE image IS NOT NULL` },
    { table: 'stories', stmt: `UPDATE stories SET image = NULL WHERE image IS NOT NULL` },
    { table: 'events', stmt: `UPDATE events SET image = NULL WHERE image IS NOT NULL` },
    { table: 'groups', stmt: `UPDATE groups SET cover_image = NULL WHERE cover_image IS NOT NULL` },
    { table: 'uyeler', stmt: `UPDATE uyeler SET resim = 'yok' WHERE resim IS NOT NULL` }
  ];
  
  db.transaction(() => {
    for (const item of wipeStatements) {
      if (tableSet.has(item.table)) {
        const info = db.prepare(item.stmt).run();
        console.log(` Executed: ${item.stmt} (Rows updated: ${info.changes})`);
      } else {
        console.log(` Skipping Table (Not found): ${item.table}`);
      }
    }
  })();
  
  // Clean up empty posts/stories that ONLY consisted of an old image
  // (if they have no text content and no new image_record_id)
  const emptyCleanups = [
    { table: 'posts', stmt: `DELETE FROM posts WHERE (content IS NULL OR TRIM(content) = '') AND image_record_id IS NULL` },
    { table: 'stories', stmt: `DELETE FROM stories WHERE image_record_id IS NULL` }
  ];
  
  db.transaction(() => {
    for (const item of emptyCleanups) {
      if (tableSet.has(item.table)) {
        const info = db.prepare(item.stmt).run();
        console.log(` Executed Cleanup: ${item.stmt} (Rows deleted: ${info.changes})`);
      }
    }
  })();

  console.log('\n2. Purging Physical Legacy Directories...');
  
  targets.forEach(dirPath => {
    if (fs.existsSync(dirPath)) {
      console.log(` RMDIR: ${dirPath}`);
      // Recursive delete using vanilla fs methods
      fs.rmSync(dirPath, { recursive: true, force: true });
    } else {
      console.log(` SKIP (Not found): ${dirPath}`);
    }
  });
  
  console.log('\n✅ Legacy data wipe complete. The app now relies exclusively on the Variant Image Pipeline (thumb/feed/full).');
} catch (err) {
  console.error('\n❌ Error executing wipe script:', err);
} finally {
  if (db) db.close();
}
