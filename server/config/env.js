import path from 'path';
import { getDirname } from './paths.js';

const __dirname = getDirname(import.meta.url);
const serverDir = path.resolve(__dirname, '..');

export const port = process.env.PORT || 8787;
export const isProd = process.env.NODE_ENV === 'production';
export const ONLINE_HEARTBEAT_MS = 20 * 1000;
export const legacyDir = path.resolve(serverDir, '../frontend-classic/public/legacy');
export const uploadsDir = path.resolve(serverDir, String(process.env.SDAL_UPLOADS_DIR || '../uploads'));

