import fs from 'fs';
import path from 'path';
import multer from 'multer';

const EICAR_SIGNATURE = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*';
const BLOCKED_EXECUTABLE_SIGNATURES = [
  Buffer.from([0x4d, 0x5a]),
  Buffer.from([0x7f, 0x45, 0x4c, 0x46]),
  Buffer.from([0xcf, 0xfa, 0xed, 0xfe]),
  Buffer.from([0xca, 0xfe, 0xba, 0xbe])
];
const allowedImageExts = new Set(['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.tiff', '.webp', '.heic', '.heif']);
const allowedImageSafetyMimes = Object.freeze([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/bmp',
  'image/tiff',
  'image/heic',
  'image/heif'
]);
const allowedProofExts = new Set(['.jpg', '.jpeg', '.png', '.pdf']);
const allowedRequestAttachmentExts = new Set(['.jpg', '.jpeg', '.png', '.pdf']);

function bufferStartsWith(buffer, signature) {
  if (!Buffer.isBuffer(buffer) || !Buffer.isBuffer(signature)) return false;
  if (buffer.length < signature.length) return false;
  return buffer.subarray(0, signature.length).equals(signature);
}

function detectMimeByMagicBytes(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return '';
  const bytes = fs.readFileSync(filePath);
  if (bytes.length >= 3 && bufferStartsWith(bytes, Buffer.from([0xff, 0xd8, 0xff]))) return 'image/jpeg';
  if (bytes.length >= 8 && bufferStartsWith(bytes, Buffer.from([0x89, 0x50, 0x4e, 0x47]))) return 'image/png';
  if (bytes.length >= 12 && bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp';
  if (bytes.length >= 6 && (bytes.subarray(0, 6).toString('ascii') === 'GIF87a' || bytes.subarray(0, 6).toString('ascii') === 'GIF89a')) return 'image/gif';
  if (bytes.length >= 2 && bytes[0] === 0x42 && bytes[1] === 0x4d) return 'image/bmp';
  if (bytes.length >= 4 && (
    bufferStartsWith(bytes, Buffer.from([0x49, 0x49, 0x2a, 0x00]))
    || bufferStartsWith(bytes, Buffer.from([0x4d, 0x4d, 0x00, 0x2a]))
  )) return 'image/tiff';
  if (bytes.length >= 12 && bytes.subarray(4, 8).toString('ascii') === 'ftyp') {
    const brand = bytes.subarray(8, 12).toString('ascii').toLowerCase();
    if (brand.startsWith('heic') || brand.startsWith('heix') || brand.startsWith('hevc') || brand.startsWith('hevx')) return 'image/heic';
    if (brand.startsWith('heif') || brand.startsWith('mif1') || brand.startsWith('msf1')) return 'image/heif';
  }
  if (bytes.length >= 4 && bufferStartsWith(bytes, Buffer.from([0x25, 0x50, 0x44, 0x46]))) return 'application/pdf';
  return '';
}

function buildStampedFilename(prefix, ext, userId = 'anon', separator = '') {
  const now = new Date();
  const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
  return `${prefix}${userId}${separator}${stamp}${ext || '.jpg'}`;
}

function buildImageDiskUpload(destination, filenameBuilder, errorMessage) {
  return multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, destination),
      filename: filenameBuilder
    }),
    fileFilter: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      if (!allowedImageExts.has(ext)) {
        cb(new Error(errorMessage));
      } else {
        cb(null, true);
      }
    },
    limits: { fileSize: 20 * 1024 * 1024 }
  });
}

export function createUploadSecurity({
  vesikalikDir,
  albumDir,
  postDir,
  storyDir,
  groupDir,
  verificationProofDir,
  requestAttachmentDir,
  dbBackupIncomingDir,
  dbDriver
}) {
  function validateUploadedFileSafety(filePath, { allowedMimes = [] } = {}) {
    if (!filePath || !fs.existsSync(filePath)) return { ok: false, reason: 'Dosya bulunamadı.' };
    const bytes = fs.readFileSync(filePath);
    const sniffedMime = detectMimeByMagicBytes(filePath);
    if (allowedMimes.length && (!sniffedMime || !allowedMimes.includes(sniffedMime))) {
      return { ok: false, reason: 'Dosya içeriği beklenen türle eşleşmiyor.' };
    }
    for (const sig of BLOCKED_EXECUTABLE_SIGNATURES) {
      if (bufferStartsWith(bytes, sig)) return { ok: false, reason: 'Yüklenen dosya yürütülebilir içerik içeriyor.' };
    }
    if (bytes.toString('latin1').includes(EICAR_SIGNATURE)) {
      return { ok: false, reason: 'Yüklenen dosya zararlı içerik testi imzası içeriyor.' };
    }
    return { ok: true, mime: sniffedMime };
  }

  function cleanupUploadedFile(filePath) {
    try {
      if (filePath && fs.existsSync(filePath)) fs.unlinkSync(filePath);
    } catch {
      // best effort
    }
  }

  const photoUpload = buildImageDiskUpload(
    vesikalikDir,
    (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, `${req.session.userId}${ext || '.jpg'}`);
    },
    'Geçerli bir resim dosyası girmediniz.'
  );

  const albumUpload = buildImageDiskUpload(
    albumDir,
    (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, buildStampedFilename('', ext, req.session.userId));
    },
    'Geçerli bir resim dosyası girmedin. ( Geçerli dosya türleri : jpg,gif,png )'
  );

  const postUpload = buildImageDiskUpload(
    postDir,
    (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, buildStampedFilename('', ext, req.session.userId || 'anon', '_'));
    },
    'Geçerli bir resim dosyası girmediniz.'
  );

  const storyUpload = buildImageDiskUpload(
    storyDir,
    (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, buildStampedFilename('', ext, req.session.userId || 'anon', '_'));
    },
    'Geçerli bir resim dosyası girmediniz.'
  );

  const groupUpload = buildImageDiskUpload(
    groupDir,
    (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      const now = new Date();
      const stamp = `${now.getMonth() + 1}${now.getDate()}${now.getFullYear()}${now.getHours()}${now.getMinutes()}${now.getSeconds()}`;
      cb(null, `group_${req.params.id || 'new'}_${stamp}${ext || '.jpg'}`);
    },
    'Geçerli bir resim dosyası girmediniz.'
  );

  const verificationProofUpload = multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, verificationProofDir),
      filename: (req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const stamp = `${Date.now()}_${Math.round(Math.random() * 1e9)}`;
        cb(null, `proof_${req.session.userId || 'anon'}_${stamp}${ext || '.jpg'}`);
      }
    }),
    fileFilter: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      if (!allowedProofExts.has(ext)) {
        cb(new Error('Sadece JPG, PNG veya PDF dosyaları yükleyebilirsiniz.'));
        return;
      }
      cb(null, true);
    },
    limits: { fileSize: 10 * 1024 * 1024 }
  });

  const requestAttachmentUpload = multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, requestAttachmentDir),
      filename: (req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        cb(null, `request_${req.session.userId || 'anon'}_${Date.now()}_${Math.round(Math.random() * 1e6)}${ext || '.jpg'}`);
      }
    }),
    fileFilter: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      if (!allowedRequestAttachmentExts.has(ext)) {
        cb(new Error('Sadece JPG, PNG veya PDF yükleyebilirsiniz.'));
        return;
      }
      cb(null, true);
    },
    limits: { fileSize: 10 * 1024 * 1024 }
  });

  const dbBackupUpload = multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, dbBackupIncomingDir),
      filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase() || (dbDriver === 'postgres' ? '.dump' : '.sqlite');
        cb(null, `incoming-${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
      }
    }),
    limits: { fileSize: 1024 * 1024 * 1024 }
  });

  const imageUpload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 20 * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
      if (!allowedImageSafetyMimes.includes(file.mimetype?.toLowerCase())) {
        cb(new Error('Desteklenmeyen dosya türü.'));
      } else {
        cb(null, true);
      }
    }
  });

  return {
    allowedImageSafetyMimes,
    validateUploadedFileSafety,
    cleanupUploadedFile,
    photoUpload,
    albumUpload,
    postUpload,
    storyUpload,
    groupUpload,
    verificationProofUpload,
    requestAttachmentUpload,
    dbBackupUpload,
    imageUpload
  };
}
