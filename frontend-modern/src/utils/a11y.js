function compactText(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function fullName(entity) {
  const name = compactText([entity?.isim, entity?.soyisim].filter(Boolean).join(' '));
  if (name) return name;
  const handle = compactText(entity?.kadi);
  return handle ? `@${handle}` : '';
}

export function avatarAlt(entity, fallback = 'Profil fotoğrafı') {
  const name = fullName(entity);
  return name ? `${name} profil fotoğrafı` : fallback;
}

export function storyImageAlt(story) {
  const name = fullName(story?.author || story);
  const caption = compactText(story?.caption);
  if (name && caption) return `${name} hikayesi: ${caption}`;
  if (name) return `${name} hikaye görseli`;
  if (caption) return `Hikaye görseli: ${caption}`;
  return 'Hikaye görseli';
}

export function postImageAlt(post) {
  const name = fullName(post?.author || post);
  const text = compactText(post?.content).replace(/<[^>]+>/g, ' ').trim();
  if (name && text) return `${name} gönderi görseli: ${text.slice(0, 90)}`;
  if (name) return `${name} gönderi görseli`;
  if (text) return `Gönderi görseli: ${text.slice(0, 90)}`;
  return 'Gönderi görseli';
}

export function contentImageAlt(label, summary = '') {
  const safeLabel = compactText(label) || 'İçerik';
  const safeSummary = compactText(summary);
  return safeSummary ? `${safeLabel}: ${safeSummary.slice(0, 90)}` : `${safeLabel} görseli`;
}
