import fs from 'fs';
import path from 'path';
import sharp from 'sharp';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import { generateVariants } from '../media/imageProcessor.js';
import { LocalStorageProvider } from '../media/storageProvider.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runTest() {
  console.log('--- Image Pipeline Smoke Test ---');

  // 1. Create a test image buffer
  console.log('1. Generating test image...');
  const testBuffer = await sharp({
    create: {
      width: 2000,
      height: 2000,
      channels: 4,
      background: { r: 255, g: 0, b: 0, alpha: 1 }
    }
  })
    .jpeg()
    .toBuffer();

  const settings = {
    thumbWidth: 200,
    feedWidth: 800,
    fullWidth: 1600,
    webpQuality: 80
  };

  // 2. Test variant generation
  console.log('2. Generating variants...');
  const result = await generateVariants(testBuffer, settings);

  console.log(`   Thumb size: ${result.thumb.length} bytes`);
  console.log(`   Feed size: ${result.feed.length} bytes`);
  console.log(`   Full size: ${result.full.length} bytes`);
  console.log(`   Metadata:`, result.metadata);

  if (!result.thumb || !result.feed || !result.full) {
    throw new Error('Variant generation missing some outputs.');
  }

  // 3. Test LocalStorageProvider
  console.log('3. Testing LocalStorageProvider...');
  const uploadsDir = path.resolve(__dirname, '../uploads');
  const provider = new LocalStorageProvider(uploadsDir);

  const uuid = crypto.randomUUID();
  const testKey = `images/testUser/testEntity_${uuid}/thumb.webp`;

  const saveResult = await provider.saveVariant(testKey, result.thumb, 'image/webp');
  console.log('   Save result:', saveResult);

  const fullPath = path.join(uploadsDir, saveResult.path);
  if (!fs.existsSync(fullPath)) {
    throw new Error('Saved file not found on disk at ' + fullPath);
  }
  console.log('   File exists on disk.');

  // 4. Test provider delete prefix
  console.log('4. Testing LocalStorageProvider deletePrefix...');
  const prefix = `images/testUser/testEntity_${uuid}`;
  await provider.deletePrefix(prefix);

  if (fs.existsSync(fullPath)) {
    throw new Error('File still exists after deletePrefix.');
  }
  console.log('   Directory successfully deleted.');

  console.log('--- All tests passed! ---');
}

runTest().catch((err) => {
  console.error('Smoke test failed:', err);
  process.exit(1);
});
