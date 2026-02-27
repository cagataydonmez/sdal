/**
 * Spaces Migration Prep Script
 *
 * This is a placeholder/template for a future migration script.
 * When the app is ready to move entirely to DigitalOcean Spaces,
 * this script would:
 *
 * 1. Read all local image records from the database
 * 2. Upload their thumb/feed/full variants to Spaces
 * 3. Update the `provider` column in `image_records` to 'spaces'
 * 4. (Optional) Delete the local files once confirmed
 *
 * To use this, you would need to initialize the DB connection
 * and import the SpacesStorageProvider.
 */

import { SpacesStorageProvider } from '../media/storageProvider.js';
import fs from 'fs';
import path from 'path';

// Load env vars
// import 'dotenv/config';

console.log('--- SDAL Spaces Migration Script (Template) ---');
console.log('To run a real migration, implement the DB loop here.');

/*
Example implementation flow:

import { getDb } from '../db.js';
const db = getDb();

const spacesConfig = {
  endpoint: process.env.SPACES_ENDPOINT,
  region: process.env.SPACES_REGION,
  bucket: process.env.SPACES_BUCKET,
  accessKeyId: process.env.SPACES_KEY,
  secretAccessKey: process.env.SPACES_SECRET,
};

const spaces = new SpacesStorageProvider(spacesConfig);
const localUploadsDir = path.resolve('../uploads');

async function runMigration() {
  const records = db.prepare(`SELECT * FROM image_records WHERE provider = 'local'`).all();
  console.log(`Found ${records.length} local images to migrate.`);

  for (const record of records) {
    try {
      console.log(`Migrating image: ${record.id}`);

      // Helper to upload a single variant
      const migrateVariant = async (localPath) => {
        if (!localPath) return;
        const fullLocalPath = path.join(localUploadsDir, localPath);
        if (!fs.existsSync(fullLocalPath)) return;

        const buffer = fs.readFileSync(fullLocalPath);
        await spaces.saveVariant(localPath, buffer, 'image/webp');
      };

      await Promise.all([
        migrateVariant(record.thumb_path),
        migrateVariant(record.feed_path),
        migrateVariant(record.full_path)
      ]);

      // Update DB
      db.prepare(`UPDATE image_records SET provider = 'spaces' WHERE id = ?`).run(record.id);

      console.log(`Successfully migrated ${record.id}`);
    } catch (err) {
      console.error(`Failed to migrate ${record.id}:`, err);
    }
  }

  console.log('Migration complete.');
}

// runMigration().catch(console.error);
*/
