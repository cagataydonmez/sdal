import { Capacitor } from '@capacitor/core';
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';

export function supportsNativeImagePicker() {
  return Capacitor.isNativePlatform();
}

function normalizeExtension(format, mimeType) {
  const raw = String(format || '').trim().toLowerCase();
  if (raw) return raw === 'jpeg' ? 'jpg' : raw;
  const mime = String(mimeType || '').toLowerCase();
  if (mime.includes('png')) return 'png';
  if (mime.includes('webp')) return 'webp';
  return 'jpg';
}

export async function pickImageFromNative(source = 'gallery') {
  if (!supportsNativeImagePicker()) return null;
  const photo = await Camera.getPhoto({
    quality: 90,
    allowEditing: false,
    resultType: CameraResultType.Uri,
    source: source === 'camera' ? CameraSource.Camera : CameraSource.Photos
  });
  if (!photo?.webPath) return null;
  const res = await fetch(photo.webPath);
  const blob = await res.blob();
  const ext = normalizeExtension(photo.format, blob.type);
  const mimeType = blob.type || `image/${ext}`;
  const file = new File([blob], `mobile-image-${Date.now()}.${ext}`, { type: mimeType });
  return file;
}
