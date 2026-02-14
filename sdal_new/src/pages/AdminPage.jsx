import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const msg = await res.text();
    throw new Error(msg || `Request failed: ${res.status}`);
  }
  return res.json();
}

const tabs = [
  { key: 'dashboard', label: 'Dashboard', section: 'Genel', hint: 'Canlı metrikler ve operasyon özeti' },
  { key: 'users', label: 'Üyeler', section: 'Topluluk', hint: 'Üye yönetimi ve yetkiler' },
  { key: 'verification', label: 'Doğrulama', section: 'Topluluk', hint: 'Rozet/kimlik doğrulama talepleri' },
  { key: 'groups', label: 'Gruplar', section: 'Topluluk', hint: 'Grup moderasyonu ve temizlik' },
  { key: 'stories', label: 'Hikayeler', section: 'Topluluk', hint: 'Story denetimi' },
  { key: 'chat', label: 'Canlı Sohbet', section: 'Topluluk', hint: 'Sohbet moderasyonu' },
  { key: 'messages', label: 'Mesajlar', section: 'Topluluk', hint: 'Sistem içi mesaj denetimi' },
  { key: 'pages', label: 'Sayfalar', section: 'İçerik', hint: 'Legacy sayfa yönetimi' },
  { key: 'events', label: 'Etkinlikler', section: 'İçerik', hint: 'Etkinlik içerikleri ve onaylar' },
  { key: 'announcements', label: 'Duyurular', section: 'İçerik', hint: 'Duyuru yayın yönetimi' },
  { key: 'album', label: 'Albüm Kategorileri', section: 'Medya', hint: 'Albüm kategori yönetimi' },
  { key: 'photos', label: 'Fotoğraf Moderasyon', section: 'Medya', hint: 'Fotoğraf onay/silme işlemleri' },
  { key: 'email', label: 'E-Posta', section: 'İletişim', hint: 'Tekil ve toplu gönderimler' },
  { key: 'tournament', label: 'Turnuva', section: 'İçerik', hint: 'Turnuva kayıt yönetimi' },
  { key: 'logs', label: 'Loglar', section: 'Sistem', hint: 'Hata/sayfa/üye log dosyaları' },
  { key: 'database', label: 'Veritabanı', section: 'Sistem', hint: 'Tablo ve kayıt gözlemleme' }
];

export default function AdminPage() {
  const { user } = useAuth();
  const [tab, setTab] = useState('dashboard');
  const [status, setStatus] = useState('');
  const [adminOk, setAdminOk] = useState(false);
  const [adminPassword, setAdminPassword] = useState('');

  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [userFilter, setUserFilter] = useState('active');
  const [userQuery, setUserQuery] = useState('');
  const [userDetail, setUserDetail] = useState(null);
  const [userForm, setUserForm] = useState(null);

  const [categories, setCategories] = useState([]);
  const [categoryForm, setCategoryForm] = useState({ kategori: '', aciklama: '', aktif: 1 });

  const [photos, setPhotos] = useState([]);
  const [photoFilter, setPhotoFilter] = useState({ krt: 'onaybekleyen', kid: '', diz: '' });
  const [photoEdit, setPhotoEdit] = useState(null);

  const [pages, setPages] = useState([]);
  const [pageForm, setPageForm] = useState({ sayfaismi: '', sayfaurl: '', babaid: '0', menugorun: 1, yonlendir: 0, mozellik: 0, resim: 'yok' });

  const [logs, setLogs] = useState([]);
  const [logFile, setLogFile] = useState('');
  const [logContent, setLogContent] = useState('');
  const [logType, setLogType] = useState('app');

  const [emailCats, setEmailCats] = useState([]);
  const [emailTemplates, setEmailTemplates] = useState([]);
  const [emailSend, setEmailSend] = useState({ to: '', from: '', subject: '', html: '' });
  const [emailBulk, setEmailBulk] = useState({ categoryId: '', from: '', subject: '', html: '' });
  const [emailCatForm, setEmailCatForm] = useState({ ad: '', tur: 'all', deger: '', aciklama: '' });
  const [emailTplForm, setEmailTplForm] = useState({ ad: '', konu: '', icerik: '' });

  const [teams, setTeams] = useState([]);

  const [verifRequests, setVerifRequests] = useState([]);
  const [verifyUpdate, setVerifyUpdate] = useState({ userId: '', verified: '1' });

  const [events, setEvents] = useState([]);
  const [eventForm, setEventForm] = useState({ title: '', body: '', date: '' });

  const [announcements, setAnnouncements] = useState([]);
  const [announcementForm, setAnnouncementForm] = useState({ title: '', body: '' });

  const [groups, setGroups] = useState([]);
  const [stories, setStories] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);
  const [adminMessages, setAdminMessages] = useState([]);
  const [dbTables, setDbTables] = useState([]);
  const [dbTableName, setDbTableName] = useState('');
  const [dbColumns, setDbColumns] = useState([]);
  const [dbRows, setDbRows] = useState([]);
  const [dbMeta, setDbMeta] = useState({ total: 0, page: 1, pages: 1, limit: 50 });
  const [dbSearch, setDbSearch] = useState('');
  const [live, setLive] = useState({ counts: {}, activity: [], now: '' });
  const [dashboardAutoRefresh, setDashboardAutoRefresh] = useState(true);

  useEffect(() => {
    if (!user) return;
    fetch('/api/admin/session', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setAdminOk(!!p.adminOk))
      .catch(() => {});
  }, [user]);

  const refreshDashboard = useCallback(async () => {
    if (user?.admin !== 1 || !adminOk) return;
    const [statsData, liveData] = await Promise.all([
      apiJson('/api/new/admin/stats'),
      apiJson('/api/new/admin/live')
    ]);
    setStats(statsData);
    setLive(liveData || { counts: {}, activity: [], now: '' });
  }, [user, adminOk]);

  useEffect(() => {
    if (user?.admin !== 1 || !adminOk) return;
    if (tab === 'dashboard') refreshDashboard();
    if (tab === 'users') loadUsers();
    if (tab === 'album') loadCategories();
    if (tab === 'photos') loadPhotos();
    if (tab === 'pages') loadPages();
    if (tab === 'logs') loadLogs();
    if (tab === 'email') loadEmailMeta();
    if (tab === 'tournament') loadTeams();
    if (tab === 'verification') loadVerification();
    if (tab === 'events') loadEvents();
    if (tab === 'announcements') loadAnnouncements();
    if (tab === 'groups') loadGroups();
    if (tab === 'stories') loadStories();
    if (tab === 'chat') loadChat();
    if (tab === 'messages') loadAdminMessages();
    if (tab === 'database') loadDbTables();
  }, [tab, user, adminOk, refreshDashboard]);

  useEffect(() => {
    if (tab !== 'dashboard' || !dashboardAutoRefresh || user?.admin !== 1 || !adminOk) return undefined;
    const timer = setInterval(() => {
      refreshDashboard().catch(() => {});
    }, 7000);
    return () => clearInterval(timer);
  }, [tab, dashboardAutoRefresh, user, adminOk, refreshDashboard]);

  useEffect(() => {
    if (tab !== 'logs' || user?.admin !== 1 || !adminOk) return;
    loadLogs().catch(() => {});
  }, [logType, tab, user, adminOk]);

  async function adminLogin(e) {
    e.preventDefault();
    setStatus('');
    const res = await fetch('/api/admin/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ password: adminPassword })
    });
    if (!res.ok) {
      setStatus(await res.text());
      return;
    }
    setAdminOk(true);
    setAdminPassword('');
    setStatus('Admin girişi başarılı.');
  }

  async function loadStats() {
    const data = await apiJson('/api/new/admin/stats');
    setStats(data);
  }

  async function loadUsers() {
    const data = await apiJson(`/api/admin/users/lists?filter=${userFilter}`);
    setUsers(data.users || []);
  }

  async function searchUsers() {
    if (!userQuery.trim()) return;
    const data = await apiJson(`/api/admin/users/search?q=${encodeURIComponent(userQuery)}`);
    setUsers(data.users || []);
  }

  async function loadUserDetail(id) {
    const data = await apiJson(`/api/admin/users/${id}`);
    setUserDetail(data.user);
    setUserForm(data.user);
  }

  async function saveUser() {
    if (!userForm?.id) return;
    await apiJson(`/api/admin/users/${userForm.id}`, { method: 'PUT', body: JSON.stringify(userForm) });
    setStatus('Üye güncellendi.');
    loadUsers();
  }

  async function updateVerify() {
    await apiJson('/api/new/admin/verify', { method: 'POST', body: JSON.stringify(verifyUpdate) });
    setStatus('Doğrulama güncellendi.');
  }

  async function loadCategories() {
    const data = await apiJson('/api/admin/album/categories');
    setCategories(data.categories || []);
  }

  async function addCategory() {
    await apiJson('/api/admin/album/categories', { method: 'POST', body: JSON.stringify(categoryForm) });
    setCategoryForm({ kategori: '', aciklama: '', aktif: 1 });
    loadCategories();
  }

  async function saveCategory(cat) {
    await apiJson(`/api/admin/album/categories/${cat.id}`, { method: 'PUT', body: JSON.stringify(cat) });
    loadCategories();
  }

  async function deleteCategory(id) {
    await apiJson(`/api/admin/album/categories/${id}`, { method: 'DELETE' });
    loadCategories();
  }

  async function loadPhotos() {
    const qs = new URLSearchParams(photoFilter).toString();
    const data = await apiJson(`/api/admin/album/photos?${qs}`);
    setPhotos(data.photos || []);
  }

  async function updatePhoto() {
    if (!photoEdit) return;
    await apiJson(`/api/admin/album/photos/${photoEdit.id}`, { method: 'PUT', body: JSON.stringify(photoEdit) });
    setPhotoEdit(null);
    loadPhotos();
  }

  async function deletePhoto(id) {
    await apiJson(`/api/admin/album/photos/${id}`, { method: 'DELETE' });
    loadPhotos();
  }

  async function bulkPhoto(action) {
    const ids = photos.filter((p) => p.selected).map((p) => p.id);
    if (!ids.length) return;
    const finalAction = action === 'pasif' ? 'deaktiv' : action;
    await apiJson('/api/admin/album/photos/bulk', { method: 'POST', body: JSON.stringify({ ids, action: finalAction }) });
    loadPhotos();
  }

  async function loadPages() {
    const data = await apiJson('/api/admin/pages');
    setPages(data.pages || []);
  }

  async function savePage() {
    await apiJson('/api/admin/pages', { method: 'POST', body: JSON.stringify(pageForm) });
    setPageForm({ sayfaismi: '', sayfaurl: '', babaid: '0', menugorun: 1, yonlendir: 0, mozellik: 0, resim: 'yok' });
    loadPages();
  }

  async function updatePage(p) {
    await apiJson(`/api/admin/pages/${p.id}`, { method: 'PUT', body: JSON.stringify(p) });
    loadPages();
  }

  async function deletePage(id) {
    await apiJson(`/api/admin/pages/${id}`, { method: 'DELETE' });
    loadPages();
  }

  async function loadLogs() {
    try {
      const data = await apiJson(`/api/admin/logs?type=${encodeURIComponent(logType)}`);
      setLogs(data.files || []);
      setLogFile('');
      setLogContent('');
    } catch (err) {
      setStatus(err.message || 'Loglar alınamadı.');
      setLogs([]);
    }
  }

  async function openLog(file) {
    const fileName = typeof file === 'string' ? file : file?.name;
    if (!fileName) return;
    const data = await apiJson(`/api/admin/logs?type=${encodeURIComponent(logType)}&file=${encodeURIComponent(fileName)}`);
    setLogFile(fileName);
    setLogContent(data.content || '');
  }

  async function copyCurrentLog() {
    if (!logContent) return;
    try {
      await navigator.clipboard.writeText(logContent);
      setStatus('Log içeriği panoya kopyalandı.');
    } catch {
      setStatus('Kopyalama başarısız. Tarayıcı izinlerini kontrol edin.');
    }
  }

  function downloadCurrentLog() {
    if (!logContent) return;
    const fileName = (logFile || `${logType}.log`).replace(/[^\w.-]/g, '_');
    const blob = new Blob([logContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName.endsWith('.log') ? fileName : `${fileName}.log`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  async function loadEmailMeta() {
    const cats = await apiJson('/api/admin/email/categories');
    const tpls = await apiJson('/api/admin/email/templates');
    setEmailCats(cats.categories || []);
    setEmailTemplates(tpls.templates || []);
  }

  async function sendEmail() {
    await apiJson('/api/admin/email/send', { method: 'POST', body: JSON.stringify(emailSend) });
    setStatus('E-posta gönderildi.');
  }

  async function sendBulk() {
    await apiJson('/api/admin/email/bulk', { method: 'POST', body: JSON.stringify(emailBulk) });
    setStatus('Toplu e-posta gönderildi.');
  }

  async function addEmailCategory() {
    await apiJson('/api/admin/email/categories', { method: 'POST', body: JSON.stringify(emailCatForm) });
    setEmailCatForm({ ad: '', tur: 'all', deger: '', aciklama: '' });
    loadEmailMeta();
  }

  async function addEmailTemplate() {
    await apiJson('/api/admin/email/templates', { method: 'POST', body: JSON.stringify(emailTplForm) });
    setEmailTplForm({ ad: '', konu: '', icerik: '' });
    loadEmailMeta();
  }

  async function updateEmailCategory(cat) {
    await apiJson(`/api/admin/email/categories/${cat.id}`, { method: 'PUT', body: JSON.stringify(cat) });
    loadEmailMeta();
  }

  async function deleteEmailCategory(id) {
    await apiJson(`/api/admin/email/categories/${id}`, { method: 'DELETE' });
    loadEmailMeta();
  }

  async function updateEmailTemplate(tpl) {
    await apiJson(`/api/admin/email/templates/${tpl.id}`, { method: 'PUT', body: JSON.stringify(tpl) });
    loadEmailMeta();
  }

  async function deleteEmailTemplate(id) {
    await apiJson(`/api/admin/email/templates/${id}`, { method: 'DELETE' });
    loadEmailMeta();
  }

  async function loadTeams() {
    const data = await apiJson('/api/admin/tournament');
    setTeams(data.teams || []);
  }

  async function deleteTeam(id) {
    await apiJson(`/api/admin/tournament/${id}`, { method: 'DELETE' });
    loadTeams();
  }

  async function loadVerification() {
    const data = await apiJson('/api/new/admin/verification-requests');
    setVerifRequests(data.items || []);
  }

  async function reviewRequest(id, statusValue) {
    await apiJson(`/api/new/admin/verification-requests/${id}`, { method: 'POST', body: JSON.stringify({ status: statusValue }) });
    loadVerification();
  }

  async function loadEvents() {
    const data = await apiJson('/api/new/events');
    setEvents(data.items || []);
  }

  async function addEvent() {
    await apiJson('/api/new/events', { method: 'POST', body: JSON.stringify(eventForm) });
    setEventForm({ title: '', body: '', date: '' });
    loadEvents();
  }

  async function deleteEvent(id) {
    await apiJson(`/api/new/events/${id}`, { method: 'DELETE' });
    loadEvents();
  }

  async function loadAnnouncements() {
    const data = await apiJson('/api/new/announcements');
    setAnnouncements(data.items || []);
  }

  async function addAnnouncement() {
    await apiJson('/api/new/announcements', { method: 'POST', body: JSON.stringify(announcementForm) });
    setAnnouncementForm({ title: '', body: '' });
    loadAnnouncements();
  }

  async function deleteAnnouncement(id) {
    await apiJson(`/api/new/announcements/${id}`, { method: 'DELETE' });
    loadAnnouncements();
  }

  async function loadGroups() {
    const data = await apiJson('/api/new/admin/groups');
    setGroups(data.items || []);
  }

  async function deleteGroup(id) {
    await apiJson(`/api/new/admin/groups/${id}`, { method: 'DELETE' });
    loadGroups();
  }

  async function loadStories() {
    try {
      const data = await apiJson('/api/new/admin/stories');
      setStories(data.items || []);
    } catch (err) {
      setStatus(err.message || 'Hikayeler alınamadı.');
      setStories([]);
    }
  }

  async function deleteStory(id) {
    await apiJson(`/api/new/admin/stories/${id}`, { method: 'DELETE' });
    loadStories();
  }

  async function loadChat() {
    try {
      const data = await apiJson('/api/new/admin/chat/messages');
      setChatMessages(data.items || []);
    } catch (err) {
      setStatus(err.message || 'Sohbet mesajları alınamadı.');
      setChatMessages([]);
    }
  }

  async function deleteChat(id) {
    await apiJson(`/api/new/admin/chat/messages/${id}`, { method: 'DELETE' });
    loadChat();
  }

  async function loadAdminMessages() {
    const data = await apiJson('/api/new/admin/messages');
    setAdminMessages(data.items || []);
  }

  async function deleteAdminMessage(id) {
    await apiJson(`/api/new/admin/messages/${id}`, { method: 'DELETE' });
    loadAdminMessages();
  }

  async function loadDbTables() {
    const data = await apiJson('/api/new/admin/db/tables');
    const items = data.items || [];
    setDbTables(items);
    if (!dbTableName && items.length) {
      loadDbTable(items[0].name, 1);
    }
  }

  async function loadDbTable(name, page = 1) {
    if (!name) return;
    const data = await apiJson(`/api/new/admin/db/table/${encodeURIComponent(name)}?page=${page}&limit=${dbMeta.limit}`);
    setDbTableName(data.table || name);
    setDbColumns(data.columns || []);
    setDbRows(data.rows || []);
    setDbMeta({ total: data.total || 0, page: data.page || 1, pages: data.pages || 1, limit: data.limit || dbMeta.limit });
  }

  const filteredDbRows = useMemo(() => {
    const needle = dbSearch.trim().toLowerCase();
    if (!needle) return dbRows;
    return dbRows.filter((row) =>
      Object.values(row || {}).some((value) => String(value ?? '').toLowerCase().includes(needle))
    );
  }, [dbRows, dbSearch]);

  const groupedTabs = useMemo(() => {
    return tabs.reduce((acc, t) => {
      if (!acc[t.section]) acc[t.section] = [];
      acc[t.section].push(t);
      return acc;
    }, {});
  }, []);

  const currentTab = useMemo(() => tabs.find((t) => t.key === tab) || tabs[0], [tab]);

  if (user?.admin !== 1) {
    return (
      <Layout title="Yönetim">
        <div className="panel">
          <div className="panel-body">Bu sayfaya erişiminiz yok.</div>
        </div>
      </Layout>
    );
  }

  if (!adminOk) {
    return (
      <Layout title="Yönetim">
        <div className="panel">
          <div className="panel-body">
            <form className="stack" onSubmit={adminLogin}>
              <input className="input" type="password" placeholder="Admin şifresi" value={adminPassword} onChange={(e) => setAdminPassword(e.target.value)} />
              <button className="btn primary" type="submit">Admin Giriş</button>
              {status ? <div className="muted">{status}</div> : null}
            </form>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout title="Yönetim">
      <div className="admin-shell">
        <aside className="panel admin-nav">
          <h3>Admin Menü</h3>
          <div className="panel-body">
            {Object.entries(groupedTabs).map(([section, sectionTabs]) => (
              <div key={section} className="admin-nav-group">
                <div className="admin-nav-title">{section}</div>
                {sectionTabs.map((t) => (
                  <button
                    key={t.key}
                    className={`admin-nav-item ${tab === t.key ? 'active' : ''}`}
                    onClick={() => setTab(t.key)}
                  >
                    <div className="name">{t.label}</div>
                    <div className="meta">{t.hint}</div>
                  </button>
                ))}
              </div>
            ))}
          </div>
        </aside>

        <div className="admin-content">
          <div className="panel admin-page-header">
            <div className="panel-body">
              <h3>{currentTab.label}</h3>
              <div className="muted">{currentTab.hint}</div>
            </div>
          </div>

          <div className="admin-page-wrap">
      {tab === 'dashboard' && stats ? (
        <div className="stack">
          <div className="panel">
            <h3>Yönetim Dashboard</h3>
            <div className="panel-body">
              <div className="admin-live-header">
                <div className="muted">
                  Son canlı güncelleme: {live.now ? new Date(live.now).toLocaleString('tr-TR') : '-'}
                </div>
                <div className="admin-live-actions">
                  <label className="admin-switch">
                    <input
                      type="checkbox"
                      checked={dashboardAutoRefresh}
                      onChange={(e) => setDashboardAutoRefresh(e.target.checked)}
                    />
                    <span>Canlı İzleme</span>
                  </label>
                  <button className="btn ghost" onClick={() => refreshDashboard().catch(() => {})}>Şimdi Yenile</button>
                </div>
              </div>
              <div className="admin-kpi-grid">
                <div className="admin-kpi-card"><div className="muted">Toplam Üye</div><b>{stats.counts.users}</b></div>
                <div className="admin-kpi-card"><div className="muted">Aktif Üye</div><b>{stats.counts.activeUsers}</b></div>
                <div className="admin-kpi-card"><div className="muted">Online Üye</div><b>{live.counts.onlineUsers || 0}</b></div>
                <div className="admin-kpi-card"><div className="muted">Bekleyen Fotoğraf</div><b>{live.counts.pendingPhotos || 0}</b></div>
                <div className="admin-kpi-card"><div className="muted">Bekleyen Etkinlik</div><b>{live.counts.pendingEvents || 0}</b></div>
                <div className="admin-kpi-card"><div className="muted">Bekleyen Duyuru</div><b>{live.counts.pendingAnnouncements || 0}</b></div>
                <div className="admin-kpi-card"><div className="muted">Bekleyen Doğrulama</div><b>{live.counts.pendingVerifications || 0}</b></div>
                <div className="admin-kpi-card"><div className="muted">Toplam Mesaj</div><b>{stats.counts.messages}</b></div>
              </div>
            </div>
          </div>
          <div className="grid">
            <div className="col-main">
              <div className="panel">
                <h3>Canlı Aktivite</h3>
                <div className="panel-body">
                  <div className="list">
                    {(live.activity || []).map((a) => (
                      <div key={a.id} className="list-item">
                        <div>
                          <div className="name">{a.message}</div>
                          <div className="meta">{a.type} • {a.at ? new Date(a.at).toLocaleString('tr-TR') : '-'}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
            <div className="col-side">
              <div className="panel">
                <h3>Yeni Üyeler</h3>
                <div className="panel-body">
                  {stats.recentUsers.map((u) => (
                    <div key={u.id} className="list-item">@{u.kadi}</div>
                  ))}
                </div>
              </div>
              <div className="panel">
                <h3>Son Paylaşımlar</h3>
                <div className="panel-body">
                  {stats.recentPosts.map((p) => (
                    <div key={p.id} className="list-item">{(p.content || '').slice(0, 80) || '(metin yok)'}</div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'users' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="stack">
              <div className="form-row">
                <label>Filtre</label>
                <select className="input" value={userFilter} onChange={(e) => setUserFilter(e.target.value)}>
                  <option value="active">Aktif</option>
                  <option value="pending">Bekleyen</option>
                  <option value="banned">Yasaklı</option>
                  <option value="online">Online</option>
                  <option value="recent">Son giriş</option>
                  <option value="all">Tümü</option>
                </select>
                <button className="btn" onClick={loadUsers}>Listele</button>
              </div>
              <div className="form-row">
                <label>Arama</label>
                <input className="input" value={userQuery} onChange={(e) => setUserQuery(e.target.value)} />
                <button className="btn" onClick={searchUsers}>Ara</button>
              </div>
            </div>
            <div className="list">
              {users.map((u) => (
                <button key={u.id} className="list-item" onClick={() => loadUserDetail(u.id)}>
                  {u.kadi} ({u.isim} {u.soyisim})
                </button>
              ))}
            </div>
            {userForm ? (
              <div className="panel-body">
                <h3>Üye Düzenle</h3>
                <div className="form-row">
                  <label>İsim</label>
                  <input className="input" value={userForm.isim || ''} onChange={(e) => setUserForm({ ...userForm, isim: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Soyisim</label>
                  <input className="input" value={userForm.soyisim || ''} onChange={(e) => setUserForm({ ...userForm, soyisim: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Email</label>
                  <input className="input" value={userForm.email || ''} onChange={(e) => setUserForm({ ...userForm, email: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Şifre (yalnızca gerekiyorsa)</label>
                  <input className="input" type="password" value={userForm.sifre || ''} onChange={(e) => setUserForm({ ...userForm, sifre: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Aktivasyon</label>
                  <input className="input" value={userForm.aktivasyon || ''} onChange={(e) => setUserForm({ ...userForm, aktivasyon: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Aktif</label>
                  <select className="input" value={userForm.aktiv ?? 1} onChange={(e) => setUserForm({ ...userForm, aktiv: Number(e.target.value) })}>
                    <option value={1}>Aktif</option>
                    <option value={0}>Pasif</option>
                  </select>
                </div>
                <div className="form-row">
                  <label>Yasak</label>
                  <select className="input" value={userForm.yasak ?? 0} onChange={(e) => setUserForm({ ...userForm, yasak: Number(e.target.value) })}>
                    <option value={0}>Hayır</option>
                    <option value={1}>Evet</option>
                  </select>
                </div>
                <div className="form-row">
                  <label>Admin</label>
                  <select className="input" value={userForm.admin ?? 0} onChange={(e) => setUserForm({ ...userForm, admin: Number(e.target.value) })}>
                    <option value={0}>Hayır</option>
                    <option value={1}>Evet</option>
                  </select>
                </div>
                <button className="btn primary" onClick={saveUser}>Kaydet</button>
              </div>
            ) : null}
            <div className="form-row">
              <label>Doğrulama Rozeti</label>
              <input className="input" placeholder="Üye ID" value={verifyUpdate.userId} onChange={(e) => setVerifyUpdate({ ...verifyUpdate, userId: e.target.value })} />
              <select className="input" value={verifyUpdate.verified} onChange={(e) => setVerifyUpdate({ ...verifyUpdate, verified: e.target.value })}>
                <option value="1">Doğrula</option>
                <option value="0">Kaldır</option>
              </select>
              <button className="btn" onClick={updateVerify}>Güncelle</button>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'album' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Yeni Kategori</label>
              <input className="input" placeholder="Kategori" value={categoryForm.kategori} onChange={(e) => setCategoryForm({ ...categoryForm, kategori: e.target.value })} />
              <input className="input" placeholder="Açıklama" value={categoryForm.aciklama} onChange={(e) => setCategoryForm({ ...categoryForm, aciklama: e.target.value })} />
              <select className="input" value={categoryForm.aktif} onChange={(e) => setCategoryForm({ ...categoryForm, aktif: Number(e.target.value) })}>
                <option value={1}>Aktif</option>
                <option value={0}>Pasif</option>
              </select>
              <button className="btn primary" onClick={addCategory}>Ekle</button>
            </div>
            <div className="list">
              {categories.map((c) => (
                <div key={c.id} className="list-item">
                  <input className="input" value={c.kategori || ''} onChange={(e) => setCategories((prev) => prev.map((x) => x.id === c.id ? { ...x, kategori: e.target.value } : x))} />
                  <input className="input" value={c.aciklama || ''} onChange={(e) => setCategories((prev) => prev.map((x) => x.id === c.id ? { ...x, aciklama: e.target.value } : x))} />
                  <select className="input" value={c.aktif ?? 1} onChange={(e) => setCategories((prev) => prev.map((x) => x.id === c.id ? { ...x, aktif: Number(e.target.value) } : x))}>
                    <option value={1}>Aktif</option>
                    <option value={0}>Pasif</option>
                  </select>
                  <button className="btn" onClick={() => saveCategory(c)}>Kaydet</button>
                  <button className="btn ghost" onClick={() => deleteCategory(c.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'photos' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Filtre</label>
              <select className="input" value={photoFilter.krt} onChange={(e) => setPhotoFilter({ ...photoFilter, krt: e.target.value })}>
                <option value="onaybekleyen">Onay Bekleyen</option>
                <option value="aktif">Aktif</option>
                <option value="pasif">Pasif</option>
              </select>
              <input className="input" placeholder="Kategori ID" value={photoFilter.kid} onChange={(e) => setPhotoFilter({ ...photoFilter, kid: e.target.value })} />
              <input className="input" placeholder="Sıralama" value={photoFilter.diz} onChange={(e) => setPhotoFilter({ ...photoFilter, diz: e.target.value })} />
              <button className="btn" onClick={loadPhotos}>Getir</button>
            </div>
            <div className="panel-body">
              <button className="btn" onClick={() => bulkPhoto('aktif')}>Toplu Aktif</button>
              <button className="btn ghost" onClick={() => bulkPhoto('pasif')}>Toplu Pasif</button>
              <button className="btn ghost" onClick={() => bulkPhoto('sil')}>Toplu Sil</button>
            </div>
            <div className="list">
              {photos.map((p) => (
                <div key={p.id} className="list-item">
                  <input type="checkbox" checked={!!p.selected} onChange={(e) => setPhotos((prev) => prev.map((x) => x.id === p.id ? { ...x, selected: e.target.checked } : x))} />
                  <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(p.dosyaadi || 'nophoto.jpg')}`} alt="" />
                  <span>{p.baslik}</span>
                  <button className="btn ghost" onClick={() => setPhotoEdit(p)}>Düzenle</button>
                  <button className="btn ghost" onClick={() => deletePhoto(p.id)}>Sil</button>
                </div>
              ))}
            </div>
            {photoEdit ? (
              <div className="panel-body">
                <h3>Fotoğraf Düzenle</h3>
                <input className="input" value={photoEdit.baslik || ''} onChange={(e) => setPhotoEdit({ ...photoEdit, baslik: e.target.value })} />
                <input className="input" value={photoEdit.aciklama || ''} onChange={(e) => setPhotoEdit({ ...photoEdit, aciklama: e.target.value })} />
                <input className="input" value={photoEdit.aktif ?? ''} onChange={(e) => setPhotoEdit({ ...photoEdit, aktif: e.target.value })} />
                <input className="input" value={photoEdit.katid ?? ''} onChange={(e) => setPhotoEdit({ ...photoEdit, katid: e.target.value })} />
                <button className="btn primary" onClick={updatePhoto}>Kaydet</button>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {tab === 'messages' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {adminMessages.map((m) => (
                <div key={m.id} className="list-item">
                  <div>
                    <div className="name">{m.konu}</div>
                    <div className="meta">{m.kimden_kadi} → {m.kime_kadi} • {m.tarih ? new Date(m.tarih).toLocaleString('tr-TR') : '-'}</div>
                    <div className="meta" style={{ marginTop: 6, whiteSpace: 'pre-wrap' }}>{m.mesaj || '(mesaj içeriği boş)'}</div>
                  </div>
                  <button className="btn ghost" onClick={() => deleteAdminMessage(m.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'pages' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Yeni Sayfa</label>
              <input className="input" placeholder="Başlık" value={pageForm.sayfaismi} onChange={(e) => setPageForm({ ...pageForm, sayfaismi: e.target.value })} />
              <input className="input" placeholder="URL" value={pageForm.sayfaurl} onChange={(e) => setPageForm({ ...pageForm, sayfaurl: e.target.value })} />
              <input className="input" placeholder="Baba ID" value={pageForm.babaid} onChange={(e) => setPageForm({ ...pageForm, babaid: e.target.value })} />
              <select className="input" value={pageForm.menugorun} onChange={(e) => setPageForm({ ...pageForm, menugorun: Number(e.target.value) })}>
                <option value={1}>Menüde Göster</option>
                <option value={0}>Menüde Gizle</option>
              </select>
              <select className="input" value={pageForm.yonlendir} onChange={(e) => setPageForm({ ...pageForm, yonlendir: Number(e.target.value) })}>
                <option value={0}>Yönlendirme Yok</option>
                <option value={1}>Yönlendir</option>
              </select>
              <select className="input" value={pageForm.mozellik} onChange={(e) => setPageForm({ ...pageForm, mozellik: Number(e.target.value) })}>
                <option value={0}>Normal</option>
                <option value={1}>Özel</option>
              </select>
              <input className="input" placeholder="Resim (yok)" value={pageForm.resim} onChange={(e) => setPageForm({ ...pageForm, resim: e.target.value || 'yok' })} />
              <button className="btn primary" onClick={savePage}>Kaydet</button>
            </div>
            <div className="list">
              {pages.map((p) => (
                <div key={p.id} className="list-item">
                  <input className="input" value={p.sayfaismi || ''} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, sayfaismi: e.target.value } : x))} />
                  <input className="input" value={p.sayfaurl || ''} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, sayfaurl: e.target.value } : x))} />
                  <input className="input" value={p.babaid ?? 0} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, babaid: e.target.value } : x))} />
                  <select className="input" value={p.menugorun ?? 1} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, menugorun: Number(e.target.value) } : x))}>
                    <option value={1}>Menüde</option>
                    <option value={0}>Gizli</option>
                  </select>
                  <input className="input" value={p.resim || 'yok'} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, resim: e.target.value || 'yok' } : x))} />
                  <button className="btn" onClick={() => updatePage(p)}>Güncelle</button>
                  <button className="btn ghost" onClick={() => deletePage(p.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'email' ? (
        <div className="grid">
          <div className="col-main">
            <div className="panel">
              <h3>Tekil E-posta</h3>
              <div className="panel-body">
                <input className="input" placeholder="To" value={emailSend.to} onChange={(e) => setEmailSend({ ...emailSend, to: e.target.value })} />
                <input className="input" placeholder="From" value={emailSend.from} onChange={(e) => setEmailSend({ ...emailSend, from: e.target.value })} />
                <input className="input" placeholder="Subject" value={emailSend.subject} onChange={(e) => setEmailSend({ ...emailSend, subject: e.target.value })} />
                <textarea className="input" placeholder="HTML" value={emailSend.html} onChange={(e) => setEmailSend({ ...emailSend, html: e.target.value })} />
                <button className="btn primary" onClick={sendEmail}>Gönder</button>
              </div>
            </div>
            <div className="panel">
              <h3>Toplu E-posta</h3>
              <div className="panel-body">
                <select className="input" value={emailBulk.categoryId} onChange={(e) => setEmailBulk({ ...emailBulk, categoryId: e.target.value })}>
                  <option value="">Kategori</option>
                  {emailCats.map((c) => <option key={c.id} value={c.id}>{c.ad}</option>)}
                </select>
                <input className="input" placeholder="From" value={emailBulk.from} onChange={(e) => setEmailBulk({ ...emailBulk, from: e.target.value })} />
                <input className="input" placeholder="Subject" value={emailBulk.subject} onChange={(e) => setEmailBulk({ ...emailBulk, subject: e.target.value })} />
                <textarea className="input" placeholder="HTML" value={emailBulk.html} onChange={(e) => setEmailBulk({ ...emailBulk, html: e.target.value })} />
                <button className="btn primary" onClick={sendBulk}>Gönder</button>
              </div>
            </div>
          </div>
          <div className="col-side">
            <div className="panel">
              <h3>Kategoriler</h3>
              <div className="panel-body">
                <input className="input" placeholder="Ad" value={emailCatForm.ad} onChange={(e) => setEmailCatForm({ ...emailCatForm, ad: e.target.value })} />
                <select className="input" value={emailCatForm.tur} onChange={(e) => setEmailCatForm({ ...emailCatForm, tur: e.target.value })}>
                  <option value="all">Tümü</option>
                  <option value="active">Aktif</option>
                  <option value="pending">Bekleyen</option>
                  <option value="banned">Yasaklı</option>
                  <option value="year">Mezuniyet</option>
                  <option value="custom">Özel</option>
                </select>
                <input className="input" placeholder="Değer" value={emailCatForm.deger} onChange={(e) => setEmailCatForm({ ...emailCatForm, deger: e.target.value })} />
                <input className="input" placeholder="Açıklama" value={emailCatForm.aciklama} onChange={(e) => setEmailCatForm({ ...emailCatForm, aciklama: e.target.value })} />
                <button className="btn" onClick={addEmailCategory}>Ekle</button>
                {emailCats.map((c) => (
                  <div key={c.id} className="list-item">
                    <input className="input" value={c.ad || ''} onChange={(e) => setEmailCats((prev) => prev.map((x) => x.id === c.id ? { ...x, ad: e.target.value } : x))} />
                    <button className="btn" onClick={() => updateEmailCategory(c)}>Kaydet</button>
                    <button className="btn ghost" onClick={() => deleteEmailCategory(c.id)}>Sil</button>
                  </div>
                ))}
              </div>
            </div>
            <div className="panel">
              <h3>Şablonlar</h3>
              <div className="panel-body">
                <input className="input" placeholder="Ad" value={emailTplForm.ad} onChange={(e) => setEmailTplForm({ ...emailTplForm, ad: e.target.value })} />
                <input className="input" placeholder="Konu" value={emailTplForm.konu} onChange={(e) => setEmailTplForm({ ...emailTplForm, konu: e.target.value })} />
                <textarea className="input" placeholder="İçerik" value={emailTplForm.icerik} onChange={(e) => setEmailTplForm({ ...emailTplForm, icerik: e.target.value })} />
                <button className="btn" onClick={addEmailTemplate}>Ekle</button>
                {emailTemplates.map((t) => (
                  <div key={t.id} className="list-item">
                    <input className="input" value={t.ad || ''} onChange={(e) => setEmailTemplates((prev) => prev.map((x) => x.id === t.id ? { ...x, ad: e.target.value } : x))} />
                    <button className="btn" onClick={() => updateEmailTemplate(t)}>Kaydet</button>
                    <button className="btn ghost" onClick={() => deleteEmailTemplate(t.id)}>Sil</button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'logs' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Log Türü</label>
              <select className="input" value={logType} onChange={(e) => setLogType(e.target.value)}>
                <option value="app">Uygulama Logları</option>
                <option value="error">Hata Logları</option>
                <option value="page">Sayfa Logları</option>
                <option value="member">Üye Logları</option>
              </select>
              <button className="btn" onClick={loadLogs}>Yükle</button>
            </div>
            <div className="list">
              {logs.map((f) => (
                <button key={f.name} className="list-item" onClick={() => openLog(f)}>
                  <span>{f.name}</span>
                  <span className="meta">{Math.round((f.size || 0) / 1024)} KB</span>
                </button>
              ))}
            </div>
            {!logs.length ? <div className="muted">Bu log türünde henüz dosya yok.</div> : null}
            {logFile ? (
              <div className="panel-body">
                <div className="composer-actions">
                  <h3>{logFile}</h3>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="btn ghost" onClick={copyCurrentLog}>Kopyala</button>
                    <button className="btn ghost" onClick={downloadCurrentLog}>İndir</button>
                  </div>
                </div>
                <textarea className="input" rows={12} value={logContent} readOnly />
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {tab === 'tournament' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {teams.map((t) => (
                <div key={t.id} className="list-item">
                  <div>{t.tisim || t.takimadi || t.isim || `Takım #${t.id}`}</div>
                  <button className="btn ghost" onClick={() => deleteTeam(t.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'verification' ? (
        <div className="panel">
          <div className="panel-body">
            {verifRequests.map((r) => (
              <div key={r.id} className="list-item">
                <div>@{r.kadi} • {r.status}</div>
                <button className="btn" onClick={() => reviewRequest(r.id, 'approved')}>Onayla</button>
                <button className="btn ghost" onClick={() => reviewRequest(r.id, 'rejected')}>Reddet</button>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {tab === 'events' ? (
        <div className="panel">
          <div className="panel-body">
            <input className="input" placeholder="Başlık" value={eventForm.title} onChange={(e) => setEventForm({ ...eventForm, title: e.target.value })} />
            <input className="input" placeholder="Tarih" value={eventForm.date} onChange={(e) => setEventForm({ ...eventForm, date: e.target.value })} />
            <textarea className="input" placeholder="İçerik" value={eventForm.body} onChange={(e) => setEventForm({ ...eventForm, body: e.target.value })} />
            <button className="btn primary" onClick={addEvent}>Ekle</button>
            <div className="list">
              {events.map((e) => (
                <div key={e.id} className="list-item">
                  <div>{e.title}</div>
                  <button className="btn ghost" onClick={() => deleteEvent(e.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'announcements' ? (
        <div className="panel">
          <div className="panel-body">
            <input className="input" placeholder="Başlık" value={announcementForm.title} onChange={(e) => setAnnouncementForm({ ...announcementForm, title: e.target.value })} />
            <textarea className="input" placeholder="İçerik" value={announcementForm.body} onChange={(e) => setAnnouncementForm({ ...announcementForm, body: e.target.value })} />
            <button className="btn primary" onClick={addAnnouncement}>Ekle</button>
            <div className="list">
              {announcements.map((a) => (
                <div key={a.id} className="list-item">
                  <div>{a.title}</div>
                  <button className="btn ghost" onClick={() => deleteAnnouncement(a.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'groups' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {groups.map((g) => (
                <div key={g.id} className="list-item">
                  <div>{g.name}</div>
                  <button className="btn ghost" onClick={() => deleteGroup(g.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'stories' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {stories.map((s) => (
                <div key={s.id} className="list-item">
                  <div>
                    <div className="name">@{s.kadi || 'üye'}</div>
                    <div className="meta">{s.created_at ? new Date(s.created_at).toLocaleString('tr-TR') : '-'}</div>
                    <div className="meta">{s.caption || '(açıklama yok)'}</div>
                    {s.image ? <a className="meta" href={s.image} target="_blank" rel="noreferrer">Görseli Aç</a> : null}
                  </div>
                  <button className="btn ghost" onClick={() => deleteStory(s.id)}>Sil</button>
                </div>
              ))}
            </div>
            {!stories.length ? <div className="muted">Gösterilecek hikaye yok.</div> : null}
          </div>
        </div>
      ) : null}

      {tab === 'chat' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {chatMessages.map((c) => (
                <div key={c.id} className="list-item">
                  <div>
                    <div className="name">@{c.kadi || 'üye'}</div>
                    <div className="meta">{c.created_at ? new Date(c.created_at).toLocaleString('tr-TR') : '-'}</div>
                    <div>{c.message}</div>
                  </div>
                  <button className="btn ghost" onClick={() => deleteChat(c.id)}>Sil</button>
                </div>
              ))}
            </div>
            {!chatMessages.length ? <div className="muted">Gösterilecek sohbet mesajı yok.</div> : null}
          </div>
        </div>
      ) : null}

      {tab === 'database' ? (
        <div className="db-grid">
          <div className="panel">
            <h3>Tablolar</h3>
            <div className="panel-body">
              <button className="btn" onClick={loadDbTables}>Yenile</button>
              <div className="list">
                {dbTables.map((t) => (
                  <button
                    key={t.name}
                    className={`list-item db-table-item ${dbTableName === t.name ? 'active' : ''}`}
                    onClick={() => loadDbTable(t.name, 1)}
                  >
                    <span>{t.name}</span>
                    <span className="meta">{t.rowCount}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
          <div className="panel">
            <h3>İçerik: {dbTableName || '-'}</h3>
            <div className="panel-body">
              <div className="db-toolbar">
                <input
                  className="input"
                  placeholder="Bu sayfada ara..."
                  value={dbSearch}
                  onChange={(e) => setDbSearch(e.target.value)}
                />
                <span className="chip">Toplam: {dbMeta.total}</span>
                <span className="chip">Sayfa: {dbMeta.page}/{dbMeta.pages}</span>
                <button
                  className="btn ghost"
                  disabled={dbMeta.page <= 1}
                  onClick={() => loadDbTable(dbTableName, dbMeta.page - 1)}
                >
                  Önceki
                </button>
                <button
                  className="btn ghost"
                  disabled={dbMeta.page >= dbMeta.pages}
                  onClick={() => loadDbTable(dbTableName, dbMeta.page + 1)}
                >
                  Sonraki
                </button>
              </div>
              {dbColumns.length ? (
                <div className="db-table-wrap">
                  <table className="db-table">
                    <thead>
                      <tr>
                        {dbColumns.map((c) => (
                          <th key={c.name}>
                            <div>{c.name}</div>
                            <div className="meta">{c.type || 'TEXT'}{c.pk ? ' • PK' : ''}</div>
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {filteredDbRows.map((row, idx) => (
                        <tr key={idx}>
                          {dbColumns.map((c) => (
                            <td key={`${idx}-${c.name}`}>{String(row?.[c.name] ?? '')}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div className="muted">Tablo seçin.</div>
              )}
            </div>
          </div>
        </div>
      ) : null}

      {status ? <div className="muted">{status}</div> : null}
          </div>
        </div>
      </div>
    </Layout>
  );
}
