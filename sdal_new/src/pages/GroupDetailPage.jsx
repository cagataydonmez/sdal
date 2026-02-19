import React, { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostCard from '../components/PostCard.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import { isRichTextEmpty } from '../utils/richText.js';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  return res.json();
}

export default function GroupDetailPage() {
  const { id } = useParams();
  const { user } = useAuth();
  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [posts, setPosts] = useState([]);
  const [groupEvents, setGroupEvents] = useState([]);
  const [groupAnnouncements, setGroupAnnouncements] = useState([]);
  const [joinRequests, setJoinRequests] = useState([]);
  const [pendingInvites, setPendingInvites] = useState([]);
  const [membershipStatus, setMembershipStatus] = useState('none');
  const [managers, setManagers] = useState([]);
  const [accessDenied, setAccessDenied] = useState(false);
  const [accessMessage, setAccessMessage] = useState('');
  const [content, setContent] = useState('');
  const [filter, setFilter] = useState('');
  const [image, setImage] = useState(null);
  const [coverFile, setCoverFile] = useState(null);
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [eventForm, setEventForm] = useState({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
  const [announcementForm, setAnnouncementForm] = useState({ title: '', body: '' });
  const [visibility, setVisibility] = useState('public');
  const [showContactHint, setShowContactHint] = useState(false);
  const [inviteQuery, setInviteQuery] = useState('');
  const [inviteResults, setInviteResults] = useState([]);
  const [selectedInviteIds, setSelectedInviteIds] = useState([]);

  async function load() {
    setLoading(true);
    const res = await fetch(`/api/new/groups/${id}`, { credentials: 'include' });
    let data = {};
    try {
      data = await res.json();
    } catch {
      data = {};
    }
    if (!res.ok) {
      setGroup(data.group || null);
      setMembers([]);
      setPosts([]);
      setGroupEvents([]);
      setGroupAnnouncements([]);
      setJoinRequests([]);
      setPendingInvites([]);
      setManagers(data.managers || []);
      setMembershipStatus(data.membershipStatus || 'none');
      setAccessDenied(true);
      setAccessMessage(data.message || 'Bu grup içeriği yalnızca üyeler için açık.');
      setVisibility(data.group?.visibility || 'public');
      setShowContactHint(Number(data.group?.show_contact_hint || 0) === 1);
      setLoading(false);
      return;
    }

    setGroup(data.group || null);
    setMembers(data.members || []);
    setPosts(data.posts || []);
    setGroupEvents(data.groupEvents || []);
    setGroupAnnouncements(data.groupAnnouncements || []);
    setJoinRequests(data.joinRequests || []);
    setPendingInvites(data.pendingInvites || []);
    setManagers(data.managers || []);
    setMembershipStatus(data.membershipStatus || 'member');
    setVisibility(data.group?.visibility || 'public');
    setShowContactHint(Number(data.group?.show_contact_hint || 0) === 1);
    setAccessDenied(false);
    setAccessMessage('');
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, [id]);

  async function submit(e) {
    e.preventDefault();
    setStatus('');
    if (!image && isRichTextEmpty(content)) {
      setStatus('İçerik boş olamaz.');
      return;
    }
    try {
      if (image) {
        const form = new FormData();
        form.append('content', content);
        form.append('filter', filter);
        form.append('image', image);
        const res = await fetch(`/api/new/groups/${id}/posts/upload`, { method: 'POST', credentials: 'include', body: form });
        if (!res.ok) throw new Error(await res.text());
      } else {
        await apiJson(`/api/new/groups/${id}/posts`, { method: 'POST', body: JSON.stringify({ content }) });
      }
      setContent('');
      setImage(null);
      setFilter('');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function toggleJoinRequest() {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/join`, { method: 'POST' });
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function respondInvite(action) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/invitations/respond`, { method: 'POST', body: JSON.stringify({ action }) });
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  const myRole = useMemo(() => {
    if (!user?.id) return null;
    const row = members.find((m) => m.id === user.id);
    return row?.role || null;
  }, [members, user]);

  const canManageRoles = myRole === 'owner';
  const canUpdateCover = myRole === 'owner' || myRole === 'moderator';
  const canReviewRequests = myRole === 'owner' || myRole === 'moderator';

  async function updateRole(targetId, role) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/role`, { method: 'POST', body: JSON.stringify({ userId: targetId, role }) });
      setStatus('Rol güncellendi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function reviewJoinRequest(requestId, action) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/requests/${requestId}`, {
        method: 'POST',
        body: JSON.stringify({ action })
      });
      setStatus(action === 'approve' ? 'Katılım isteği onaylandı.' : 'Katılım isteği reddedildi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function uploadCover(e) {
    e.preventDefault();
    if (!coverFile) return;
    setStatus('');
    const form = new FormData();
    form.append('image', coverFile);
    const res = await fetch(`/api/new/groups/${id}/cover`, { method: 'POST', credentials: 'include', body: form });
    if (!res.ok) {
      setStatus(await res.text());
      return;
    }
    setCoverFile(null);
    await load();
  }

  async function createGroupEvent() {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/events`, { method: 'POST', body: JSON.stringify(eventForm) });
      setEventForm({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
      setStatus('Grup etkinliği eklendi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function removeGroupEvent(eventId) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/events/${eventId}`, { method: 'DELETE' });
      setStatus('Grup etkinliği silindi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function createGroupAnnouncement() {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/announcements`, { method: 'POST', body: JSON.stringify(announcementForm) });
      setAnnouncementForm({ title: '', body: '' });
      setStatus('Grup duyurusu eklendi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function removeGroupAnnouncement(announcementId) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/announcements/${announcementId}`, { method: 'DELETE' });
      setStatus('Grup duyurusu silindi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function saveVisibility() {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/settings`, {
        method: 'POST',
        body: JSON.stringify({ visibility, showContactHint })
      });
      setStatus('Grup ayarları güncellendi.');
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  function showManagersHint() {
    if (!managers.length) {
      window.alert('Bu grup için henüz yönetici bilgisi paylaşılmamış.');
      return;
    }
    const message = managers
      .map((m) => `${m.role === 'owner' ? 'Sahip' : 'Moderatör'}: ${[m.isim, m.soyisim].filter(Boolean).join(' ')} (@${m.kadi || 'uye'})`)
      .join('\n');
    window.alert(`Grup yöneticileri:\n${message}\n\nKatılım isteğin bu kişiler tarafından onaylanır.`);
  }

  async function searchInviteCandidates(term) {
    const q = String(term || '').trim().replace(/^@+/, '');
    if (q.length < 1) {
      setInviteResults([]);
      return;
    }
    const res = await fetch(`/api/messages/recipients?q=${encodeURIComponent(q)}&limit=20`, { credentials: 'include' });
    if (!res.ok) {
      setInviteResults([]);
      return;
    }
    const payload = await res.json();
    setInviteResults(payload.items || []);
  }

  useEffect(() => {
    if (!canReviewRequests) return;
    const t = setTimeout(() => {
      searchInviteCandidates(inviteQuery);
    }, 220);
    return () => clearTimeout(t);
  }, [inviteQuery, canReviewRequests]);

  function toggleInviteSelect(userId) {
    setSelectedInviteIds((prev) => (prev.includes(userId) ? prev.filter((x) => x !== userId) : [...prev, userId]));
  }

  async function sendInvites() {
    if (!selectedInviteIds.length) return;
    setStatus('');
    try {
      const payload = await apiJson(`/api/new/groups/${id}/invitations`, {
        method: 'POST',
        body: JSON.stringify({ userIds: selectedInviteIds })
      });
      setStatus(`${payload.sent || 0} kullanıcıya davet gönderildi.`);
      setSelectedInviteIds([]);
      setInviteQuery('');
      setInviteResults([]);
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  if (loading && !group) {
    return <Layout title="Grup">Yükleniyor...</Layout>;
  }

  if (accessDenied) {
    return (
      <Layout title={group?.name || 'Grup'}>
        {group ? (
          <div className="panel">
            <div className="group-hero">
              {group?.cover_image ? <img src={group.cover_image} alt="" /> : <div className="group-cover-empty">Kapak Görseli</div>}
              <div>
                <h3>{group?.name || 'Grup'}</h3>
                <div className="panel-body">{group?.description || ''}</div>
                {group?.members ? <div className="meta">{group.members} üye</div> : null}
              </div>
            </div>
          </div>
        ) : null}
        <div className="panel">
          <div className="panel-body">
            <div className="muted">{group ? accessMessage : 'Bu grubu görüntüleme yetkin yok veya grup bulunamadı.'}</div>
            {group && Number(group.show_contact_hint || 0) === 1 ? (
              <button className="btn ghost" onClick={showManagersHint}>Yönetici İpucu</button>
            ) : null}
            {group ? (
              membershipStatus === 'invited' ? (
                <div className="composer-actions">
                  <button className="btn primary" onClick={() => respondInvite('accept')}>Daveti Kabul Et</button>
                  <button className="btn ghost" onClick={() => respondInvite('reject')}>Daveti Reddet</button>
                </div>
              ) : (
                <button className="btn primary" onClick={toggleJoinRequest}>
                  {membershipStatus === 'pending' ? 'İsteği İptal Et' : 'Katılım İsteği Gönder'}
                </button>
              )
            ) : null}
            {status ? <div className="error">{status}</div> : null}
          </div>
        </div>
      </Layout>
    );
  }

  if (!group) {
    return <Layout title="Grup">Grup bulunamadı.</Layout>;
  }

  return (
    <Layout title={group.name}>
      <div className="panel">
        <div className="group-hero">
          {group.cover_image ? <img src={group.cover_image} alt="" /> : <div className="group-cover-empty">Kapak Görseli</div>}
          <div>
            <h3>{group.name}</h3>
            <TranslatableHtml html={group.description || ''} className="panel-body" />
          </div>
        </div>
        {canUpdateCover ? (
          <div className="stack">
            <form className="group-cover-form" onSubmit={uploadCover}>
              <input type="file" accept="image/*" onChange={(e) => setCoverFile(e.target.files?.[0] || null)} />
              <button className="btn ghost" type="submit">Kapak Güncelle</button>
            </form>
            <div className="composer-actions">
              <select className="input" value={visibility} onChange={(e) => setVisibility(e.target.value)}>
                <option value="public">Herkese Görünür</option>
                <option value="members_only">Sadece Üyeler ve Davetliler</option>
              </select>
              <label className="meta" style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                <input
                  type="checkbox"
                  checked={showContactHint}
                  onChange={(e) => setShowContactHint(e.target.checked)}
                />
                Üye olmayanlara yönetici ipucu göster
              </label>
              <button className="btn ghost" onClick={saveVisibility}>Görünürlüğü Kaydet</button>
            </div>
          </div>
        ) : null}
      </div>
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={submit} className="stack">
            <RichTextEditor value={content} onChange={setContent} placeholder="Gruba bir şey yaz..." minHeight={120} />
            <div className="composer-actions">
              <input type="file" accept="image/*" onChange={(e) => setImage(e.target.files?.[0] || null)} />
              <select className="input" value={filter} onChange={(e) => setFilter(e.target.value)}>
                <option value="">Filtre yok</option>
                <option value="grayscale">Siyah Beyaz</option>
                <option value="sepia">Sepya</option>
                <option value="vivid">Canlı</option>
                <option value="cool">Soğuk</option>
                <option value="warm">Sıcak</option>
                <option value="blur">Blur</option>
                <option value="sharp">Sharp</option>
              </select>
              <button className="btn primary">Paylaş</button>
            </div>
          </form>
        </div>
      </div>
      <div className="grid">
        <div className="col-main">
          <div className="panel">
            <h3>Grup Etkinlikleri</h3>
            <div className="panel-body">
              {canReviewRequests ? (
                <div className="stack">
                  <input className="input" placeholder="Başlık" value={eventForm.title} onChange={(e) => setEventForm((prev) => ({ ...prev, title: e.target.value }))} />
                  <input className="input" placeholder="Konum" value={eventForm.location} onChange={(e) => setEventForm((prev) => ({ ...prev, location: e.target.value }))} />
                  <RichTextEditor
                    value={eventForm.description}
                    onChange={(next) => setEventForm((prev) => ({ ...prev, description: next }))}
                    placeholder="Açıklama"
                    minHeight={110}
                  />
                  <input className="input" type="datetime-local" value={eventForm.starts_at} onChange={(e) => setEventForm((prev) => ({ ...prev, starts_at: e.target.value }))} />
                  <input className="input" type="datetime-local" value={eventForm.ends_at} onChange={(e) => setEventForm((prev) => ({ ...prev, ends_at: e.target.value }))} />
                  <button className="btn" onClick={createGroupEvent}>Etkinlik Ekle</button>
                </div>
              ) : null}
              {!groupEvents.length ? <div className="muted">Henüz grup etkinliği yok.</div> : null}
              {groupEvents.map((e) => (
                <div key={e.id} className="panel">
                  <h3>{e.title}</h3>
                  <div className="panel-body">
                    <div className="meta">{e.location || '-'} · {formatDateTime(e.starts_at || e.created_at)}{e.ends_at ? ` - ${formatDateTime(e.ends_at)}` : ''}</div>
                    <TranslatableHtml html={e.description || ''} />
                    <div className="meta">@{e.creator_kadi || 'uye'}</div>
                    {canReviewRequests ? <button className="btn ghost" onClick={() => removeGroupEvent(e.id)}>Sil</button> : null}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="panel">
            <h3>Grup Duyuruları</h3>
            <div className="panel-body">
              {canReviewRequests ? (
                <div className="stack">
                  <input className="input" placeholder="Başlık" value={announcementForm.title} onChange={(e) => setAnnouncementForm((prev) => ({ ...prev, title: e.target.value }))} />
                  <RichTextEditor
                    value={announcementForm.body}
                    onChange={(next) => setAnnouncementForm((prev) => ({ ...prev, body: next }))}
                    placeholder="Duyuru içeriği"
                    minHeight={110}
                  />
                  <button className="btn" onClick={createGroupAnnouncement}>Duyuru Ekle</button>
                </div>
              ) : null}
              {!groupAnnouncements.length ? <div className="muted">Henüz grup duyurusu yok.</div> : null}
              {groupAnnouncements.map((a) => (
                <div key={a.id} className="panel">
                  <h3>{a.title}</h3>
                  <div className="panel-body">
                    <div className="meta">{formatDateTime(a.created_at)} · @{a.creator_kadi || 'uye'}</div>
                    <TranslatableHtml html={a.body || ''} />
                    {canReviewRequests ? <button className="btn ghost" onClick={() => removeGroupAnnouncement(a.id)}>Sil</button> : null}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {posts.map((p) => (
            <PostCard key={p.id} post={{
              ...p,
              author: {
                id: p.user_id,
                kadi: p.kadi,
                isim: p.isim,
                soyisim: p.soyisim,
                resim: p.resim,
                verified: p.verified
              },
              likeCount: Number(p.likeCount || 0),
              commentCount: Number(p.commentCount || 0),
              liked: Boolean(p.liked)
            }} onRefresh={load} />
          ))}
        </div>
        <div className="col-side">
          <div className="panel">
            <h3>Üyeler</h3>
            <div className="panel-body">
              {members.map((m) => (
                <div key={m.id} className="notif">
                  <a href={`/new/members/${m.id}`} aria-label={`${m.kadi || 'uye'} profiline git`}>
                    <img className="avatar" src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                  </a>
                  <div>
                    <b>{m.isim} {m.soyisim}</b>{m.verified ? <span className="badge">✓</span> : null}
                    <div className="meta">@{m.kadi}</div>
                    <div className="meta role">{m.role}</div>
                    {canManageRoles && m.id !== user?.id ? (
                      <select className="input role-select" value={m.role} onChange={(e) => updateRole(m.id, e.target.value)}>
                        <option value="member">Üye</option>
                        <option value="moderator">Moderatör</option>
                        <option value="owner">Sahip</option>
                      </select>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {canReviewRequests ? (
            <div className="panel">
              <h3>Katılım İstekleri</h3>
              <div className="panel-body">
                {!joinRequests.length ? <div className="muted">Bekleyen istek yok.</div> : null}
                {joinRequests.map((r) => (
                  <div key={r.id} className="notif">
                    <a href={`/new/members/${r.user_id}`} aria-label={`${r.kadi || 'uye'} profiline git`}>
                      <img className="avatar" src={r.resim ? `/api/media/vesikalik/${r.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                    </a>
                    <div>
                      <b>{r.isim} {r.soyisim}</b>{r.verified ? <span className="badge">✓</span> : null}
                      <div className="meta">@{r.kadi}</div>
                      <div className="composer-actions">
                        <button className="btn" onClick={() => reviewJoinRequest(r.id, 'approve')}>Onayla</button>
                        <button className="btn ghost" onClick={() => reviewJoinRequest(r.id, 'reject')}>Reddet</button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
          {canReviewRequests ? (
            <div className="panel">
              <h3>Toplu Davet</h3>
              <div className="panel-body stack">
                <input className="input" placeholder="Üye ara (@kullanici)..." value={inviteQuery} onChange={(e) => setInviteQuery(e.target.value)} />
                <div className="list">
                  {inviteResults.map((u) => (
                    <button
                      key={u.id}
                      type="button"
                      className="list-item"
                      onClick={() => toggleInviteSelect(Number(u.id))}
                    >
                      <div>
                        <div className="name">{u.isim} {u.soyisim}</div>
                        <div className="meta">@{u.kadi}</div>
                      </div>
                      <span className="chip">{selectedInviteIds.includes(Number(u.id)) ? 'Seçili' : 'Seç'}</span>
                    </button>
                  ))}
                  {!inviteResults.length && inviteQuery.trim() ? <div className="muted">Sonuç bulunamadı.</div> : null}
                </div>
                <button className="btn" onClick={sendInvites} disabled={!selectedInviteIds.length}>Seçilenlere Davet Gönder</button>
              </div>
            </div>
          ) : null}
          {canReviewRequests ? (
            <div className="panel">
              <h3>Bekleyen Davetler</h3>
              <div className="panel-body">
                {!pendingInvites.length ? <div className="muted">Bekleyen davet yok.</div> : null}
                {pendingInvites.map((inv) => (
                  <div key={inv.id} className="notif">
                    <a href={`/new/members/${inv.invited_user_id}`} aria-label={`${inv.kadi || 'uye'} profiline git`}>
                      <img className="avatar" src={inv.resim ? `/api/media/vesikalik/${inv.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                    </a>
                    <div>
                      <b>{inv.isim} {inv.soyisim}</b>{inv.verified ? <span className="badge">✓</span> : null}
                      <div className="meta">@{inv.kadi}</div>
                      <div className="meta">{formatDateTime(inv.created_at)}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
          {status ? <div className="muted">{status}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
