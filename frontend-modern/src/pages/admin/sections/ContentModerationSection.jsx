import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import AdminBulkActionsBar from '../../../admin/components/AdminBulkActionsBar.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

function stripHtml(html) {
  return (html || '').replace(/<[^>]+>/g, ' ').trim();
}

function avatarUrl(resim) {
  return resim ? `/api/media/vesikalik/${resim}` : '/legacy/vesikalik/nophoto.jpg';
}

function imageUrl(image) {
  if (!image) return null;
  if (image.startsWith('http') || image.startsWith('/')) return image;
  return `/uploads/${image}`;
}

function photoPreviewUrl(fileName, width = 400) {
  if (!fileName) return null;
  return `/api/media/kucukresim?width=${width}&file=${encodeURIComponent(fileName)}`;
}

function toUserStatus(row, t) {
  if (Number(row?.yasak || 0) === 1) return t('yasaklı');
  if (Number(row?.aktiv || 0) === 1) return t('aktif');
  return t('beklemede');
}

/* ─── Content Preview Modal ─── */
function ContentPreviewModal({ item, kind, onClose }) {
  const { t } = useI18n();
  if (!item) return null;

  const previewMap = {
    posts: PostPreview,
    stories: StoryPreview,
    comments: CommentPreview,
    chat: ChatPreview,
    messages: MessagePreview,
    groups: GroupPreview,
    events: EventPreview,
    announcements: AnnouncementPreview,
    users: UserPreview,
    photos: PhotoPreview
  };
  const PreviewComponent = previewMap[kind];

  return createPortal(
    <div className="content-preview-backdrop" onClick={onClose}>
      <div className="content-preview-modal" onClick={(e) => e.stopPropagation()}>
        <div className="content-preview-header">
          <h4>{t('Önizleme')} - {t(KIND_CONFIG[kind]?.labelKey || kind)}</h4>
          <button className="btn ghost" onClick={onClose}>{t('Kapat')}</button>
        </div>
        <div className="content-preview-body">
          {PreviewComponent ? <PreviewComponent item={item} t={t} /> : <pre>{JSON.stringify(item, null, 2)}</pre>}
        </div>
      </div>
    </div>
  , document.body);
}

function PostPreview({ item, t }) {
  return (
    <article className="post-card">
      <div className="post-header">
        <img className="avatar" src={avatarUrl(item.resim)} alt="" />
        <div>
          <div className="name">
            {item.isim} {item.soyisim}
            {Number(item.verified) === 1 && <span className="badge">✓</span>}
          </div>
          <div className="handle">@{item.kadi}</div>
        </div>
        <div className="post-meta-col">
          <div className="meta">{formatDate(item.created_at)}</div>
        </div>
      </div>
      <div className="post-body">
        {item.content ? (
          <div className="post-rich-body" dangerouslySetInnerHTML={{ __html: item.content }} />
        ) : (
          <div className="muted">{t('(boş)')}</div>
        )}
        {item.image && <img className="post-image" src={imageUrl(item.image)} alt="" loading="lazy" />}
      </div>
    </article>
  );
}

function StoryPreview({ item, t }) {
  return (
    <div className="content-preview-story">
      <div className="content-preview-story-frame">
        <div className="content-preview-story-head">
          <img className="avatar" src={avatarUrl(item.resim)} alt="" style={{ width: 36, height: 36 }} />
          <div>
            <div className="name" style={{ color: '#fff' }}>
              {item.isim} {item.soyisim}
            </div>
            <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.7)' }}>@{item.kadi}</div>
          </div>
        </div>
        {item.image && <img className="content-preview-story-img" src={imageUrl(item.image)} alt="" />}
        {item.caption && (
          <div className="content-preview-story-caption">{item.caption}</div>
        )}
        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', marginTop: 8 }}>
          {formatDate(item.created_at)}
          {item.expires_at && <span> - {t('Bitiş')} {formatDate(item.expires_at)}</span>}
        </div>
      </div>
    </div>
  );
}

function CommentPreview({ item, t }) {
  return (
    <div className="content-preview-comment">
      <div className="comment-line" style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
        <img className="avatar" src={avatarUrl(item.resim)} alt="" style={{ width: 32, height: 32 }} />
        <div>
          <div className="name" style={{ fontWeight: 700 }}>@{item.kadi}</div>
          <div dangerouslySetInnerHTML={{ __html: item.body || '' }} />
          <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>
            {t('Gönderi')} #{item.post_id} - {formatDate(item.created_at)}
          </div>
        </div>
      </div>
    </div>
  );
}

function ChatPreview({ item }) {
  return (
    <div className="content-preview-chat">
      <div className="chat-line" style={{ padding: '10px 0', borderBottom: '1px dashed var(--line)' }}>
        <div className="chat-line-head" style={{ fontWeight: 700, marginBottom: 4 }}>
          @{item.kadi}
        </div>
        <div className="chat-text" dangerouslySetInnerHTML={{ __html: item.message || '' }} />
        <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>{formatDate(item.created_at)}</div>
      </div>
    </div>
  );
}

function MessagePreview({ item, t }) {
  return (
    <div className="content-preview-message">
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
        <div>
          <span style={{ fontWeight: 700 }}>{t('Kimden')}:</span> @{item.kimden_kadi}
        </div>
        <div>
          <span style={{ fontWeight: 700 }}>{t('Kime')}:</span> @{item.kime_kadi}
        </div>
      </div>
      {item.konu && (
        <div style={{ fontWeight: 700, fontSize: 16, marginBottom: 8 }}>{item.konu}</div>
      )}
      <div className="message-bubble" style={{
        background: 'var(--soft-panel)',
        padding: 12,
        borderRadius: 12,
        marginBottom: 8
      }}>
        <div dangerouslySetInnerHTML={{ __html: item.mesaj || '' }} />
      </div>
      <div className="muted" style={{ fontSize: 12 }}>{formatDate(item.tarih)}</div>
    </div>
  );
}

function GroupPreview({ item, t }) {
  return (
    <div className="content-preview-group">
      {item.cover_image && (
        <img src={imageUrl(item.cover_image)} alt="" style={{ width: '100%', maxHeight: 200, objectFit: 'cover', borderRadius: 12, marginBottom: 12 }} />
      )}
      <h3>{item.name}</h3>
      {item.description && <p>{item.description}</p>}
      <div className="muted" style={{ marginTop: 8, fontSize: 12 }}>
        {t('Sahibi')}: @{item.owner_kadi || '-'} - {t('Oluşturulma')} {formatDate(item.created_at)}
      </div>
    </div>
  );
}

function EventPreview({ item, t }) {
  return (
    <div className="content-preview-event">
      <h3>{item.title}</h3>
      {item.description && <p>{item.description}</p>}
      {item.location && <div><span style={{ fontWeight: 700 }}>{t('Konum')}:</span> {item.location}</div>}
      <div className="muted" style={{ marginTop: 8, fontSize: 12 }}>
        {t('Başlangıç')}: {formatDate(item.starts_at)} - {t('Oluşturan')} @{item.creator_kadi || '-'}
        <br />{t('Durum')}: {Number(item.approved || 0) === 1 ? t('Onaylandı') : t('Beklemede')}
      </div>
    </div>
  );
}

function AnnouncementPreview({ item, t }) {
  return (
    <div className="content-preview-announcement">
      <h3>{item.title}</h3>
      {item.body && <div dangerouslySetInnerHTML={{ __html: item.body }} />}
      <div className="muted" style={{ marginTop: 8, fontSize: 12 }}>
        {t('Oluşturan')} @{item.creator_kadi || '-'} - {formatDate(item.created_at)}
        <br />{t('Durum')}: {Number(item.approved || 0) === 1 ? t('Onaylandı') : t('Beklemede')}
      </div>
    </div>
  );
}

function UserPreview({ item, t }) {
  const status = toUserStatus(item, t);
  return (
    <div className="content-preview-user">
      <div className="panel">
        <div className="panel-body" style={{ textAlign: 'center' }}>
          <img
            className="profile-avatar-xl"
            src={avatarUrl(item.resim)}
            alt=""
            style={{ width: 96, height: 96, borderRadius: '50%', objectFit: 'cover', margin: '0 auto 12px' }}
          />
          <div className="name" style={{ fontSize: 18 }}>
            {item.isim} {item.soyisim}
            {Number(item.verified) === 1 && <span className="badge">✓</span>}
          </div>
          <div className="handle" style={{ marginBottom: 8 }}>@{item.kadi}</div>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'center', flexWrap: 'wrap', marginBottom: 12 }}>
            <span className="chip">{status}</span>
            <span className="chip">{item.role || t('kullanıcı')}</span>
            {item.mezuniyetyili && <span className="chip">{t('Mezuniyet Yılı')}: {item.mezuniyetyili}</span>}
          </div>
        </div>
      </div>
      <div className="stack" style={{ marginTop: 12 }}>
        <div className="list">
          {item.email && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('E-posta')}</span>
              <span>{item.email}</span>
            </div>
          )}
          {item.sehir && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('Şehir')}</span>
              <span>{item.sehir}</span>
            </div>
          )}
          {item.meslek && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('Meslek')}</span>
              <span>{item.meslek}</span>
            </div>
          )}
          {item.universite && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('Üniversite')}</span>
              <span>{item.universite}</span>
            </div>
          )}
          {item.websitesi && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('Web sitesi')}</span>
              <span>{item.websitesi}</span>
            </div>
          )}
          {item.engagement_score != null && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('Etkileşim')}</span>
              <span>{Number(item.engagement_score || 0).toFixed(2)}</span>
            </div>
          )}
          {item.sontarih && (
            <div className="list-item">
              <span style={{ fontWeight: 700, minWidth: 100 }}>{t('Son görülme')}</span>
              <span>{formatDate(item.sontarih)}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function PhotoPreview({ item, t }) {
  const src = photoPreviewUrl(item.dosyaadi, 1200);
  return (
    <div className="content-preview-photo">
      {src ? (
        <img
          src={src}
          alt={item.baslik || ''}
          style={{ width: '100%', maxHeight: 500, objectFit: 'contain', borderRadius: 12, marginBottom: 12 }}
        />
      ) : (
        <div className="muted" style={{ marginBottom: 12 }}>{t('(görsel dosyası yok)')}</div>
      )}
      <h3>{item.baslik || t('(başlıksız)')}</h3>
      {item.aciklama && <p>{item.aciklama}</p>}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
        <span className="chip">
          {Number(item.aktif || 0) === 1 ? t('Aktif') : t('Beklemede')}
        </span>
        {item.categoryName && <span className="chip">{item.categoryName}</span>}
        {item.uploaderName && <span className="chip">{t('Yükleyen')} @{item.uploaderName}</span>}
      </div>
      <div className="muted" style={{ fontSize: 12, marginTop: 8 }}>
        {t('Görüntülenme')}: {item.hit || 0} - {t('Yorumlar')}: {item.commentCount || 0} - {t('Yüklendi')} {formatDate(item.tarih)}
      </div>
    </div>
  );
}

/* ─── Kind configuration ─── */
const KIND_CONFIG = {
  posts: {
    labelKey: 'Gönderiler',
    endpoint: '/api/new/admin/posts',
    deleteEndpoint: (id) => `/api/new/admin/posts/${id}`,
    permView: 'posts',
    permDelete: 'posts',
    defaultLimit: 50
  },
  stories: {
    labelKey: 'Hikayeler',
    endpoint: '/api/new/admin/stories',
    deleteEndpoint: (id) => `/api/new/admin/stories/${id}`,
    permView: 'stories',
    permDelete: 'stories',
    defaultLimit: 50
  },
  comments: {
    labelKey: 'Yorumlar',
    endpoint: '/api/new/admin/comments',
    deleteEndpoint: (id) => `/api/new/admin/comments/${id}`,
    permView: 'posts',
    permDelete: 'posts',
    defaultLimit: 50
  },
  users: {
    labelKey: 'Kullanıcılar',
    endpoint: '/api/admin/users/lists',
    deleteEndpoint: (id) => `/api/admin/users/${id}`,
    permView: 'users',
    permDelete: 'users',
    defaultLimit: 20,
    customLoader: true
  },
  photos: {
    labelKey: 'Fotoğraflar',
    endpoint: '/api/admin/album/photos',
    deleteEndpoint: (id) => `/api/admin/album/photos/${id}`,
    permView: 'photos',
    permDelete: 'photos',
    defaultLimit: 50,
    customLoader: true
  },
  chat: {
    labelKey: 'Sohbet Mesajları',
    endpoint: '/api/new/admin/chat/messages',
    deleteEndpoint: (id) => `/api/new/admin/chat/messages/${id}`,
    permView: 'chat',
    permDelete: 'chat',
    defaultLimit: 80
  },
  messages: {
    labelKey: 'Direkt Mesajlar',
    endpoint: '/api/new/admin/messages',
    deleteEndpoint: (id) => `/api/new/admin/messages/${id}`,
    permView: 'messages',
    permDelete: 'messages',
    defaultLimit: 80
  },
  groups: {
    labelKey: 'Gruplar',
    endpoint: '/api/new/admin/groups',
    deleteEndpoint: (id) => `/api/new/admin/groups/${id}`,
    permView: 'groups',
    permDelete: 'groups',
    defaultLimit: 40
  },
  events: {
    labelKey: 'Etkinlikler',
    endpoint: '/api/new/events',
    permView: 'events',
    defaultLimit: 40,
    clientFilter: true
  },
  announcements: {
    labelKey: 'Duyurular',
    endpoint: '/api/new/announcements',
    permView: 'announcements',
    defaultLimit: 40,
    clientFilter: true
  }
};

/* ─── Main Section ─── */
export default function ContentModerationSection({
  canViewPosts = false,
  canViewStories = false,
  canDeletePosts = false,
  canDeleteStories = false,
  canViewChat = false,
  canDeleteChat = false,
  canViewMessages = false,
  canDeleteMessages = false,
  canViewGroups = false,
  canDeleteGroups = false,
  canViewUsers = false,
  canDeleteUsers = false,
  canViewPhotos = false,
  canDeletePhotos = false,
  isAdmin = false
}) {
  const { t } = useI18n();
  const permissions = useMemo(() => ({
    posts: { view: canViewPosts, delete: canDeletePosts },
    stories: { view: canViewStories, delete: canDeleteStories },
    comments: { view: canViewPosts, delete: canDeletePosts },
    users: { view: canViewUsers, delete: canDeleteUsers },
    photos: { view: canViewPhotos, delete: canDeletePhotos },
    chat: { view: canViewChat, delete: canDeleteChat },
    messages: { view: canViewMessages, delete: canDeleteMessages },
    groups: { view: canViewGroups, delete: canDeleteGroups },
    events: { view: isAdmin, delete: isAdmin },
    announcements: { view: isAdmin, delete: isAdmin }
  }), [canViewPosts, canViewStories, canDeletePosts, canDeleteStories, canViewChat, canDeleteChat, canViewMessages, canDeleteMessages, canViewGroups, canDeleteGroups, canViewUsers, canDeleteUsers, canViewPhotos, canDeletePhotos, isAdmin]);

  const availableKinds = useMemo(() =>
    Object.keys(KIND_CONFIG).filter((k) => permissions[k]?.view),
    [permissions]
  );

  const [kind, setKind] = useState(availableKinds[0] || 'posts');
  const { query, patchQuery, setSearch, setPage } = useAdminQueryState({ q: '', page: 1, limit: 50 });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 50 });
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [previewItem, setPreviewItem] = useState(null);

  // Users-specific filters
  const [userFilter, setUserFilter] = useState('active');
  const [userSort, setUserSort] = useState('engagement_desc');

  // Photos-specific state
  const [photoCategories, setPhotoCategories] = useState([]);
  const [photoScope, setPhotoScope] = useState('pending');

  const config = KIND_CONFIG[kind] || KIND_CONFIG.posts;
  const canDelete = permissions[kind]?.delete || false;

  useEffect(() => {
    if (!availableKinds.includes(kind)) {
      setKind(availableKinds[0] || 'posts');
    }
  }, [availableKinds, kind]);

  const load = useCallback(async () => {
    if (!availableKinds.length) return;
    setLoading(true);
    setError('');
    try {
      const cfg = KIND_CONFIG[kind] || KIND_CONFIG.posts;

      if (kind === 'users') {
        const data = await adminClient.get(withQuery(cfg.endpoint, {
          filter: userFilter,
          sort: userSort,
          q: query.q,
          page: query.page,
          limit: query.limit || cfg.defaultLimit
        }));
        setRows(data.users || []);
        setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || cfg.defaultLimit });
        setSelectedIds(new Set());
        return;
      }

      if (kind === 'photos') {
        const photoQuery = { diz: 'aktifazalan' };
        if (photoScope === 'pending') photoQuery.krt = 'onaybekleyen';
        const data = await adminClient.get(withQuery(cfg.endpoint, photoQuery));
        const commentCounts = data.commentCounts || {};
        const userMap = data.userMap || {};
        const categories = data.categories || [];
        if (categories.length) setPhotoCategories(categories);
        let items = (data.photos || []).map((row) => ({
          ...row,
          commentCount: Number(commentCounts[row.id] || 0),
          uploaderName: userMap[row.ekleyenid] || '',
          categoryName: categories.find((c) => String(c.id) === String(row.katid))?.kategori || ''
        }));
        if (query.q) {
          const needle = String(query.q).toLowerCase();
          items = items.filter((row) => {
            const haystack = `${row.baslik || ''} ${row.aciklama || ''} ${row.uploaderName || ''}`.toLowerCase();
            return haystack.includes(needle);
          });
        }
        setRows(items);
        setMeta({ page: 1, pages: 1, total: items.length, limit: items.length || 50 });
        setSelectedIds(new Set());
        return;
      }

      if (cfg.clientFilter) {
        const limit = Number(query.limit) || cfg.defaultLimit;
        const page = Number(query.page) || 1;
        const offset = (page - 1) * limit;
        const data = await adminClient.get(withQuery(cfg.endpoint, { limit, offset }));
        let items = data.items || [];
        if (query.q) {
          const needle = String(query.q).toLowerCase();
          items = items.filter((row) => {
            const haystack = Object.values(row).join(' ').toLowerCase();
            return haystack.includes(needle);
          });
        }
        setRows(items);
        setMeta({ page, pages: data.hasMore ? page + 1 : page, total: null, limit });
      } else {
        const data = await adminClient.get(withQuery(cfg.endpoint, query));
        setRows(data.items || []);
        setMeta(data.meta || { page: 1, pages: 1, total: (data.items || []).length, limit: query.limit });
      }
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || t('İçerik yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [availableKinds.length, kind, query, t, userFilter, userSort, photoScope]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setSelectedIds(new Set()); }, [kind]);

  const toggleRow = useCallback((row, checked) => {
    const id = Number(row.id);
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (checked) next.add(id); else next.delete(id);
      return next;
    });
  }, []);

  const toggleAll = useCallback((checked) => {
    if (!checked) { setSelectedIds(new Set()); return; }
    setSelectedIds(new Set((rows || []).map((r) => Number(r.id))));
  }, [rows]);

  const removeOne = useCallback(async (id) => {
    if (!canDelete) return;
    const cfg = KIND_CONFIG[kind];
    if (!cfg?.deleteEndpoint) return;
    await adminClient.del(cfg.deleteEndpoint(id));
    await load();
  }, [canDelete, kind, load]);

  const removeSelected = useCallback(async () => {
    if (!selectedIds.size || !canDelete) return;
    const cfg = KIND_CONFIG[kind];
    if (!cfg?.deleteEndpoint) return;
    if (kind === 'photos') {
      await adminClient.post('/api/admin/album/photos/bulk', {
        ids: Array.from(selectedIds),
        action: 'sil'
      });
    } else {
      await Promise.all([...selectedIds].map((id) => adminClient.del(cfg.deleteEndpoint(id))));
    }
    await load();
  }, [canDelete, kind, load, selectedIds]);

  const photoBulkAction = useCallback(async (action) => {
    if (!selectedIds.size) return;
    await adminClient.post('/api/admin/album/photos/bulk', {
      ids: Array.from(selectedIds),
      action
    });
    await load();
  }, [load, selectedIds]);

  const moderateEvent = useCallback(async (eventId, approved) => {
    await adminClient.post(`/api/new/events/${eventId}/approve`, { approved: approved ? '1' : '0' });
    await load();
  }, [load]);

  const removeEvent = useCallback(async (eventId) => {
    await adminClient.del(`/api/new/events/${eventId}`);
    await load();
  }, [load]);

  const moderateAnnouncement = useCallback(async (announcementId, approved) => {
    await adminClient.post(`/api/new/announcements/${announcementId}/approve`, { approved: approved ? '1' : '0' });
    await load();
  }, [load]);

  const removeAnnouncement = useCallback(async (announcementId) => {
    await adminClient.del(`/api/new/announcements/${announcementId}`);
    await load();
  }, [load]);

  const previewBtn = useCallback((row) => (
    <button className="btn ghost" onClick={(e) => { e.stopPropagation(); setPreviewItem(row); }}>{t('Önizleme')}</button>
  ), [t]);

  const columns = useMemo(() => {
    const actionsCol = (row) => {
      if (kind === 'events') {
        return (
          <div className="ops-inline-actions">
            {previewBtn(row)}
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateEvent(row.id, true).catch(() => {}); }}>{t('Onayla')}</button>
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateEvent(row.id, false).catch(() => {}); }}>{t('Reddet')}</button>
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeEvent(row.id).catch(() => {}); }}>{t('Sil')}</button>
          </div>
        );
      }
      if (kind === 'announcements') {
        return (
          <div className="ops-inline-actions">
            {previewBtn(row)}
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateAnnouncement(row.id, true).catch(() => {}); }}>{t('Onayla')}</button>
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateAnnouncement(row.id, false).catch(() => {}); }}>{t('Reddet')}</button>
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeAnnouncement(row.id).catch(() => {}); }}>{t('Sil')}</button>
          </div>
        );
      }
      return (
        <div className="ops-inline-actions">
          {previewBtn(row)}
          {canDelete
            ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeOne(row.id).catch(() => {}); }}>{t('Sil')}</button>
            : <span className="muted">{t('Salt okunur')}</span>}
        </div>
      );
    };

    switch (kind) {
      case 'posts':
        return [
          { key: 'id', label: 'ID' },
          { key: 'kadi', label: t('Yazar'), render: (r) => `@${r.kadi || '-'}` },
          { key: 'content', label: t('İçerik'), render: (r) => stripHtml(r.content).slice(0, 140) || t('(boş)') },
          { key: 'image', label: t('Görsel'), render: (r) => r.image ? <img src={imageUrl(r.image)} alt="" style={{ width: 40, height: 40, objectFit: 'cover', borderRadius: 6 }} /> : '-' },
          { key: 'created_at', label: t('Oluşturulma'), render: (r) => formatDate(r.created_at) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'stories':
        return [
          { key: 'id', label: 'ID' },
          { key: 'kadi', label: t('Yazar'), render: (r) => `@${r.kadi || '-'}` },
          { key: 'caption', label: t('Açıklama'), render: (r) => (r.caption || '').slice(0, 100) || t('(açıklama yok)') },
          { key: 'image', label: t('Görsel'), render: (r) => r.image ? <img src={imageUrl(r.image)} alt="" style={{ width: 40, height: 40, objectFit: 'cover', borderRadius: 6 }} /> : '-' },
          { key: 'created_at', label: t('Oluşturulma'), render: (r) => formatDate(r.created_at) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'comments':
        return [
          { key: 'id', label: 'ID' },
          { key: 'kadi', label: t('Yazar'), render: (r) => `@${r.kadi || '-'}` },
          { key: 'body', label: t('Yorum'), render: (r) => stripHtml(r.body).slice(0, 140) || t('(boş)') },
          { key: 'post_id', label: t('Gönderi ID') },
          { key: 'created_at', label: t('Oluşturulma'), render: (r) => formatDate(r.created_at) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'users':
        return [
          {
            key: 'avatar',
            label: '',
            render: (r) => <img src={avatarUrl(r.resim)} alt="" style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover' }} />
          },
          { key: 'kadi', label: t('Kullanıcı Adı'), render: (r) => `@${r.kadi || '-'}` },
          {
            key: 'name',
            label: t('Ad Soyad'),
            render: (r) => `${r.isim || ''} ${r.soyisim || ''}`.trim() || '-'
          },
          { key: 'mezuniyetyili', label: t('Mezuniyet Yılı') },
          {
            key: 'status',
            label: t('Durum'),
            render: (r) => toUserStatus(r, t)
          },
          { key: 'role', label: t('Rol'), render: (r) => r.role || t('kullanıcı') },
          {
            key: 'engagement_score',
            label: t('Skor'),
            render: (r) => Number(r.engagement_score || 0).toFixed(2)
          },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'photos':
        return [
          {
            key: 'preview_thumb',
            label: t('Önizleme'),
            render: (r) => r.dosyaadi
              ? <img src={photoPreviewUrl(r.dosyaadi, 120)} alt="" style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 8 }} />
              : <span className="muted">-</span>
          },
          { key: 'id', label: 'ID' },
          { key: 'baslik', label: t('Başlık'), render: (r) => r.baslik || t('(başlıksız)') },
          { key: 'categoryName', label: t('Kategori'), render: (r) => r.categoryName || '-' },
          { key: 'uploaderName', label: t('Yükleyen'), render: (r) => r.uploaderName ? `@${r.uploaderName}` : '-' },
          {
            key: 'aktif',
            label: t('Durum'),
            render: (r) => Number(r.aktif || 0) === 1 ? t('Aktif') : t('Beklemede')
          },
          { key: 'hit', label: t('Görüntülenme'), render: (r) => r.hit || 0 },
          { key: 'tarih', label: t('Oluşturulma'), render: (r) => formatDate(r.tarih) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'chat':
        return [
          { key: 'id', label: 'ID' },
          { key: 'kadi', label: t('Kullanıcı'), render: (r) => `@${r.kadi || '-'}` },
          { key: 'message', label: t('Mesaj'), render: (r) => stripHtml(r.message).slice(0, 140) || t('(boş)') },
          { key: 'created_at', label: t('Oluşturulma'), render: (r) => formatDate(r.created_at) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'messages':
        return [
          { key: 'id', label: 'ID' },
          { key: 'kimden_kadi', label: t('Kimden'), render: (r) => `@${r.kimden_kadi || '-'}` },
          { key: 'kime_kadi', label: t('Kime'), render: (r) => `@${r.kime_kadi || '-'}` },
          { key: 'konu', label: t('Konu'), render: (r) => (r.konu || '').slice(0, 80) || t('(konu yok)') },
          { key: 'tarih', label: t('Tarih'), render: (r) => formatDate(r.tarih) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'groups':
        return [
          { key: 'id', label: 'ID' },
          { key: 'name', label: t('Grup') },
          { key: 'owner_kadi', label: t('Sahibi'), render: (r) => `@${r.owner_kadi || '-'}` },
          { key: 'created_at', label: t('Oluşturulma'), render: (r) => formatDate(r.created_at) },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'events':
        return [
          { key: 'id', label: 'ID' },
          { key: 'title', label: t('Başlık') },
          { key: 'creator_kadi', label: t('Oluşturan'), render: (r) => `@${r.creator_kadi || '-'}` },
          { key: 'starts_at', label: t('Başlangıç'), render: (r) => formatDate(r.starts_at) },
          { key: 'approved', label: t('Durum'), render: (r) => Number(r.approved || 0) === 1 ? t('onaylandı') : t('beklemede') },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      case 'announcements':
        return [
          { key: 'id', label: 'ID' },
          { key: 'title', label: t('Başlık') },
          { key: 'creator_kadi', label: t('Oluşturan'), render: (r) => `@${r.creator_kadi || '-'}` },
          { key: 'created_at', label: t('Oluşturulma'), render: (r) => formatDate(r.created_at) },
          { key: 'approved', label: t('Durum'), render: (r) => Number(r.approved || 0) === 1 ? t('onaylandı') : t('beklemede') },
          { key: 'actions', label: t('Aksiyonlar'), render: actionsCol }
        ];
      default:
        return [];
    }
  }, [canDelete, kind, moderateAnnouncement, moderateEvent, previewBtn, removeAnnouncement, removeEvent, removeOne, t]);

  if (!availableKinds.length) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('İçerik moderasyonu yetkiniz yok.')}</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('İçerik Moderasyonu')}</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>{t('Yenile')}</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder={t('Yazar veya metin ara')}
      >
        <select className="input" value={kind} onChange={(e) => { setKind(e.target.value); setPage(1); }}>
          {availableKinds.map((k) => (
            <option key={k} value={k}>{t(KIND_CONFIG[k].labelKey)}</option>
          ))}
        </select>
        {kind === 'users' && (
          <>
            <select className="input" value={userFilter} onChange={(e) => { setUserFilter(e.target.value); setPage(1); }}>
              <option value="all">{t('Tümü')}</option>
              <option value="active">{t('Aktif')}</option>
              <option value="pending">{t('Beklemede')}</option>
              <option value="banned">{t('Yasaklı')}</option>
              <option value="online">{t('Çevrimiçi')}</option>
            </select>
            <select className="input" value={userSort} onChange={(e) => { setUserSort(e.target.value); setPage(1); }}>
              <option value="engagement_desc">{t('Skor azalan')}</option>
              <option value="engagement_asc">{t('Skor artan')}</option>
              <option value="recent">{t('En yeni')}</option>
              <option value="name">{t('Ada göre')}</option>
            </select>
          </>
        )}
        {kind === 'photos' && (
          <select className="input" value={photoScope} onChange={(e) => setPhotoScope(e.target.value)}>
            <option value="pending">{t('Sadece bekleyenler')}</option>
            <option value="all">{t('Tüm fotoğraflar')}</option>
          </select>
        )}
      </AdminFilterBar>

      {error ? <div className="muted">{error}</div> : null}

      {kind === 'photos' && canDelete ? (
        <AdminBulkActionsBar selectedCount={selectedIds.size} onClear={() => setSelectedIds(new Set())}>
          <button className="btn" onClick={() => photoBulkAction('aktiv').catch(() => {})}>{t('Aktifleştir')}</button>
          <button className="btn" onClick={() => photoBulkAction('deaktiv').catch(() => {})}>{t('Pasifleştir')}</button>
          <button className="btn" onClick={() => photoBulkAction('sil').catch(() => {})}>{t('Sil')}</button>
        </AdminBulkActionsBar>
      ) : canDelete && config.deleteEndpoint ? (
        <AdminBulkActionsBar selectedCount={selectedIds.size} onClear={() => setSelectedIds(new Set())}>
          <button className="btn" onClick={() => removeSelected().catch(() => {})}>{t('Seçilileri sil')}</button>
        </AdminBulkActionsBar>
      ) : null}

      <AdminDataTable
        columns={columns}
        rows={rows}
        loading={loading}
        selectable={canDelete && !!(config.deleteEndpoint || kind === 'photos')}
        selectedIds={selectedIds}
        onToggleRow={toggleRow}
        onToggleAll={toggleAll}
        pagination={meta}
        onPageChange={setPage}
        emptyText={t('Moderasyon öğesi yok.')}
      />

      {previewItem ? (
        <ContentPreviewModal item={previewItem} kind={kind} onClose={() => setPreviewItem(null)} />
      ) : null}
    </section>
  );
}
