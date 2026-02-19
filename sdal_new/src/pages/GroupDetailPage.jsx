import React, { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostCard from '../components/PostCard.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';

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
  const { t } = useI18n();
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
      setAccessMessage(data.message || t('group_access_members_only'));
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
      setStatus(t('group_content_empty'));
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
      setStatus(t('group_role_updated'));
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
      setStatus(action === 'approve' ? t('group_join_approved') : t('group_join_rejected'));
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
      setStatus(t('group_event_added'));
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function removeGroupEvent(eventId) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/events/${eventId}`, { method: 'DELETE' });
      setStatus(t('group_event_deleted'));
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
      setStatus(t('group_announcement_added'));
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function removeGroupAnnouncement(announcementId) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/announcements/${announcementId}`, { method: 'DELETE' });
      setStatus(t('group_announcement_deleted'));
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
      setStatus(t('group_settings_updated'));
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  function showManagersHint() {
    if (!managers.length) {
      window.alert(t('group_manager_info_missing'));
      return;
    }
    const message = managers
      .map((m) => `${m.role === 'owner' ? t('role_owner') : t('role_moderator')}: ${[m.isim, m.soyisim].filter(Boolean).join(' ')} (@${m.kadi || t('member_fallback')})`)
      .join('\n');
    window.alert(`${t('group_managers_label')}:\n${message}\n\n${t('group_managers_hint')}`);
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
      setStatus(t('group_invites_sent_count', { count: payload.sent || 0 }));
      setSelectedInviteIds([]);
      setInviteQuery('');
      setInviteResults([]);
      await load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  if (loading && !group) {
    return <Layout title={t('group_title')}>{t('loading')}</Layout>;
  }

  if (accessDenied) {
    return (
      <Layout title={group?.name || t('group_title')}>
        {group ? (
          <div className="panel">
            <div className="group-hero">
              {group?.cover_image ? <img src={group.cover_image} alt="" /> : <div className="group-cover-empty">{t('group_cover_image')}</div>}
              <div>
                <h3>{group?.name || t('group_title')}</h3>
                <div className="panel-body">{group?.description || ''}</div>
                {group?.members ? <div className="meta">{t('groups_member_count', { count: group.members })}</div> : null}
              </div>
            </div>
          </div>
        ) : null}
        <div className="panel">
          <div className="panel-body">
            <div className="muted">{group ? accessMessage : t('group_access_not_allowed')}</div>
            {group && Number(group.show_contact_hint || 0) === 1 ? (
              <button className="btn ghost" onClick={showManagersHint}>{t('group_manager_hint_button')}</button>
            ) : null}
            {group ? (
              membershipStatus === 'invited' ? (
                <div className="composer-actions">
                  <button className="btn primary" onClick={() => respondInvite('accept')}>{t('group_invite_accept')}</button>
                  <button className="btn ghost" onClick={() => respondInvite('reject')}>{t('group_invite_reject')}</button>
                </div>
              ) : (
                <button className="btn primary" onClick={toggleJoinRequest}>
                  {membershipStatus === 'pending' ? t('group_request_cancel') : t('group_request_join')}
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
    return <Layout title={t('group_title')}>{t('group_not_found')}</Layout>;
  }

  return (
    <Layout title={group.name}>
      <div className="panel">
        <div className="group-hero">
          {group.cover_image ? <img src={group.cover_image} alt="" /> : <div className="group-cover-empty">{t('group_cover_image')}</div>}
          <div>
            <h3>{group.name}</h3>
            <TranslatableHtml html={group.description || ''} className="panel-body" />
          </div>
        </div>
        {canUpdateCover ? (
          <div className="stack">
            <form className="group-cover-form" onSubmit={uploadCover}>
              <input type="file" accept="image/*" onChange={(e) => setCoverFile(e.target.files?.[0] || null)} />
              <button className="btn ghost" type="submit">{t('group_cover_update')}</button>
            </form>
            <div className="composer-actions">
              <select className="input" value={visibility} onChange={(e) => setVisibility(e.target.value)}>
                <option value="public">{t('group_visibility_public')}</option>
                <option value="members_only">{t('group_visibility_members_only')}</option>
              </select>
              <label className="meta" style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                <input
                  type="checkbox"
                  checked={showContactHint}
                  onChange={(e) => setShowContactHint(e.target.checked)}
                />
                {t('group_visibility_show_contact_hint')}
              </label>
              <button className="btn ghost" onClick={saveVisibility}>{t('save_visibility')}</button>
            </div>
          </div>
        ) : null}
      </div>
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={submit} className="stack">
            <RichTextEditor value={content} onChange={setContent} placeholder={t('group_post_placeholder')} minHeight={120} />
            <div className="composer-actions">
              <input type="file" accept="image/*" onChange={(e) => setImage(e.target.files?.[0] || null)} />
              <select className="input" value={filter} onChange={(e) => setFilter(e.target.value)}>
                <option value="">{t('filter_none')}</option>
                <option value="grayscale">{t('filter_grayscale')}</option>
                <option value="sepia">{t('filter_sepia')}</option>
                <option value="vivid">{t('filter_vivid')}</option>
                <option value="cool">{t('filter_cool')}</option>
                <option value="warm">{t('filter_warm')}</option>
                <option value="blur">{t('filter_blur')}</option>
                <option value="sharp">{t('filter_sharp')}</option>
              </select>
              <button className="btn primary">{t('post_share')}</button>
            </div>
          </form>
        </div>
      </div>
      <div className="grid">
        <div className="col-main">
          <div className="panel">
            <h3>{t('group_events_title')}</h3>
            <div className="panel-body">
              {canReviewRequests ? (
                <div className="stack">
                  <input className="input" placeholder={t('title')} value={eventForm.title} onChange={(e) => setEventForm((prev) => ({ ...prev, title: e.target.value }))} />
                  <input className="input" placeholder={t('location')} value={eventForm.location} onChange={(e) => setEventForm((prev) => ({ ...prev, location: e.target.value }))} />
                  <RichTextEditor
                    value={eventForm.description}
                    onChange={(next) => setEventForm((prev) => ({ ...prev, description: next }))}
                    placeholder={t('description')}
                    minHeight={110}
                  />
                  <input className="input" type="datetime-local" value={eventForm.starts_at} onChange={(e) => setEventForm((prev) => ({ ...prev, starts_at: e.target.value }))} />
                  <input className="input" type="datetime-local" value={eventForm.ends_at} onChange={(e) => setEventForm((prev) => ({ ...prev, ends_at: e.target.value }))} />
                  <button className="btn" onClick={createGroupEvent}>{t('group_event_add')}</button>
                </div>
              ) : null}
              {!groupEvents.length ? <div className="muted">{t('group_events_empty')}</div> : null}
              {groupEvents.map((e) => (
                <div key={e.id} className="panel">
                  <h3>{e.title}</h3>
                  <div className="panel-body">
                    <div className="meta">{e.location || '-'} · {formatDateTime(e.starts_at || e.created_at)}{e.ends_at ? ` - ${formatDateTime(e.ends_at)}` : ''}</div>
                    <TranslatableHtml html={e.description || ''} />
                    <div className="meta">@{e.creator_kadi || t('member_fallback')}</div>
                    {canReviewRequests ? <button className="btn ghost" onClick={() => removeGroupEvent(e.id)}>{t('delete')}</button> : null}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="panel">
            <h3>{t('group_announcements_title')}</h3>
            <div className="panel-body">
              {canReviewRequests ? (
                <div className="stack">
                  <input className="input" placeholder={t('title')} value={announcementForm.title} onChange={(e) => setAnnouncementForm((prev) => ({ ...prev, title: e.target.value }))} />
                  <RichTextEditor
                    value={announcementForm.body}
                    onChange={(next) => setAnnouncementForm((prev) => ({ ...prev, body: next }))}
                    placeholder={t('announcements_body_placeholder')}
                    minHeight={110}
                  />
                  <button className="btn" onClick={createGroupAnnouncement}>{t('group_announcement_add')}</button>
                </div>
              ) : null}
              {!groupAnnouncements.length ? <div className="muted">{t('group_announcements_empty')}</div> : null}
              {groupAnnouncements.map((a) => (
                <div key={a.id} className="panel">
                  <h3>{a.title}</h3>
                  <div className="panel-body">
                    <div className="meta">{formatDateTime(a.created_at)} · @{a.creator_kadi || t('member_fallback')}</div>
                    <TranslatableHtml html={a.body || ''} />
                    {canReviewRequests ? <button className="btn ghost" onClick={() => removeGroupAnnouncement(a.id)}>{t('delete')}</button> : null}
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
            <h3>{t('members')}</h3>
            <div className="panel-body">
              {members.map((m) => (
                <div key={m.id} className="notif">
                  <a href={`/new/members/${m.id}`} aria-label={t('go_profile_aria', { username: m.kadi || t('member_fallback') })}>
                    <img className="avatar" src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                  </a>
                  <div>
                    <b>{m.isim} {m.soyisim}</b>{m.verified ? <span className="badge">✓</span> : null}
                    <div className="meta">@{m.kadi}</div>
                    <div className="meta role">{m.role}</div>
                    {canManageRoles && m.id !== user?.id ? (
                      <select className="input role-select" value={m.role} onChange={(e) => updateRole(m.id, e.target.value)}>
                        <option value="member">{t('role_member')}</option>
                        <option value="moderator">{t('role_moderator')}</option>
                        <option value="owner">{t('role_owner')}</option>
                      </select>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {canReviewRequests ? (
            <div className="panel">
              <h3>{t('group_join_requests_title')}</h3>
              <div className="panel-body">
                {!joinRequests.length ? <div className="muted">{t('group_join_requests_empty')}</div> : null}
                {joinRequests.map((r) => (
                  <div key={r.id} className="notif">
                    <a href={`/new/members/${r.user_id}`} aria-label={t('go_profile_aria', { username: r.kadi || t('member_fallback') })}>
                      <img className="avatar" src={r.resim ? `/api/media/vesikalik/${r.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                    </a>
                    <div>
                      <b>{r.isim} {r.soyisim}</b>{r.verified ? <span className="badge">✓</span> : null}
                      <div className="meta">@{r.kadi}</div>
                      <div className="composer-actions">
                        <button className="btn" onClick={() => reviewJoinRequest(r.id, 'approve')}>{t('approve')}</button>
                        <button className="btn ghost" onClick={() => reviewJoinRequest(r.id, 'reject')}>{t('reject')}</button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
          {canReviewRequests ? (
            <div className="panel">
              <h3>{t('group_bulk_invite_title')}</h3>
              <div className="panel-body stack">
                <input className="input" placeholder={t('member_search_placeholder_short')} value={inviteQuery} onChange={(e) => setInviteQuery(e.target.value)} />
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
                      <span className="chip">{selectedInviteIds.includes(Number(u.id)) ? t('selected') : t('select_action')}</span>
                    </button>
                  ))}
                  {!inviteResults.length && inviteQuery.trim() ? <div className="muted">{t('no_results')}</div> : null}
                </div>
                <button className="btn" onClick={sendInvites} disabled={!selectedInviteIds.length}>{t('group_send_invites_selected')}</button>
              </div>
            </div>
          ) : null}
          {canReviewRequests ? (
            <div className="panel">
              <h3>{t('group_pending_invites_title')}</h3>
              <div className="panel-body">
                {!pendingInvites.length ? <div className="muted">{t('group_pending_invites_empty')}</div> : null}
                {pendingInvites.map((inv) => (
                  <div key={inv.id} className="notif">
                    <a href={`/new/members/${inv.invited_user_id}`} aria-label={t('go_profile_aria', { username: inv.kadi || t('member_fallback') })}>
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
