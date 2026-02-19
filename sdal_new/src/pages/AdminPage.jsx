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
  { key: 'follows', label: 'Takip İlişkileri', section: 'Topluluk', hint: 'Takip eden/edilen ilişki analizi' },
  { key: 'engagement', label: 'Etkileşim Skorları', section: 'Topluluk', hint: 'Gizli görünürlük puanları' },
  { key: 'verification', label: 'Doğrulama', section: 'Topluluk', hint: 'Rozet/kimlik doğrulama talepleri' },
  { key: 'groups', label: 'Gruplar', section: 'Topluluk', hint: 'Grup moderasyonu ve temizlik' },
  { key: 'posts', label: 'Postlar', section: 'Topluluk', hint: 'Post moderasyonu ve silme' },
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

const commonLogActivities = [
  'http_error',
  'member_activity',
  'page_view',
  'admin_login_denied',
  'admin_login_success',
  'admin_logout',
  'story_delete',
  'post_delete',
  'chat_message_delete',
  'inbox_message_delete',
  'uncaught_route_error',
  'uncaught_exception',
  'unhandled_rejection',
  'server_started',
  'http_request'
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
  const [userSearchPhotoOnly, setUserSearchPhotoOnly] = useState(false);
  const [userVerifiedOnly, setUserVerifiedOnly] = useState(false);
  const [userOnlineOnly, setUserOnlineOnly] = useState(false);
  const [userMinScore, setUserMinScore] = useState('');
  const [userSort, setUserSort] = useState('engagement_desc');
  const [usersLoading, setUsersLoading] = useState(false);
  const [userMode, setUserMode] = useState('filter');
  const [userDetail, setUserDetail] = useState(null);
  const [userForm, setUserForm] = useState(null);
  const [usersMeta, setUsersMeta] = useState({ total: 0, returned: 0 });

  const [engagementRows, setEngagementRows] = useState([]);
  const [engagementLoading, setEngagementLoading] = useState(false);
  const [engagementFilters, setEngagementFilters] = useState({
    q: '',
    status: 'all',
    variant: '',
    minScore: '',
    maxScore: '',
    sort: 'score_desc',
    page: 1,
    limit: 40
  });
  const [engagementMeta, setEngagementMeta] = useState({ total: 0, page: 1, pages: 1, limit: 40 });
  const [engagementSummary, setEngagementSummary] = useState({ avgScore: 0, maxScore: 0, minScore: 0 });
  const [engagementLastCalculatedAt, setEngagementLastCalculatedAt] = useState('');
  const [engagementAbConfigs, setEngagementAbConfigs] = useState([]);
  const [engagementAbForms, setEngagementAbForms] = useState({});
  const [engagementAbPerformance, setEngagementAbPerformance] = useState([]);
  const [engagementAbAssignments, setEngagementAbAssignments] = useState([]);
  const [engagementAbRecommendations, setEngagementAbRecommendations] = useState([]);
  const [engagementAbLoading, setEngagementAbLoading] = useState(false);

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
  const [logFilters, setLogFilters] = useState({
    q: '',
    activity: '',
    userId: '',
    from: '',
    to: '',
    limit: 500,
    offset: 0
  });
  const [logMeta, setLogMeta] = useState({
    total: 0,
    matched: 0,
    returned: 0,
    offset: 0,
    limit: 500
  });

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
  const [posts, setPosts] = useState([]);
  const [stories, setStories] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);
  const [adminMessages, setAdminMessages] = useState([]);
  const [dbTables, setDbTables] = useState([]);
  const [dbTableName, setDbTableName] = useState('');
  const [dbColumns, setDbColumns] = useState([]);
  const [dbRows, setDbRows] = useState([]);
  const [dbMeta, setDbMeta] = useState({ total: 0, page: 1, pages: 1, limit: 50 });
  const [dbSearch, setDbSearch] = useState('');
  const [dbBackups, setDbBackups] = useState([]);
  const [dbRuntimePath, setDbRuntimePath] = useState('');
  const [dbBackupBusy, setDbBackupBusy] = useState(false);
  const [dbRestoreFile, setDbRestoreFile] = useState(null);
  const [dbRestoreInputKey, setDbRestoreInputKey] = useState(0);
  const [live, setLive] = useState({ counts: {}, activity: [], now: '' });
  const [dashboardAutoRefresh, setDashboardAutoRefresh] = useState(true);
  const [previewModal, setPreviewModal] = useState(null);
  const [followTargetUserId, setFollowTargetUserId] = useState('');
  const [followInsights, setFollowInsights] = useState({ user: null, items: [], hasMore: false });
  const [followInsightsLoading, setFollowInsightsLoading] = useState(false);

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
    if (tab === 'album') loadCategories();
    if (tab === 'photos') loadPhotos();
    if (tab === 'follows') setFollowInsights({ user: null, items: [], hasMore: false });
    if (tab === 'pages') loadPages();
    if (tab === 'logs') loadLogs();
    if (tab === 'email') loadEmailMeta();
    if (tab === 'tournament') loadTeams();
    if (tab === 'verification') loadVerification();
    if (tab === 'engagement') {
      loadEngagementScores();
      loadEngagementAb();
    }
    if (tab === 'events') loadEvents();
    if (tab === 'announcements') loadAnnouncements();
    if (tab === 'groups') loadGroups();
    if (tab === 'posts') loadPosts();
    if (tab === 'stories') loadStories();
    if (tab === 'chat') loadChat();
    if (tab === 'messages') loadAdminMessages();
    if (tab === 'database') {
      loadDbTables();
      loadDbBackups();
    }
  }, [tab, user, adminOk, refreshDashboard]);

  useEffect(() => {
    if (tab !== 'users' || user?.admin !== 1 || !adminOk) return;
    loadUsers(userFilter).catch((err) => setStatus(err.message || 'Üyeler yüklenemedi.'));
  }, [tab, user, adminOk, userFilter, userSort, userVerifiedOnly, userOnlineOnly, userSearchPhotoOnly, userMinScore]);

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

  async function loadUsers(filterValue = userFilter, overrides = {}) {
    setUsersLoading(true);
    try {
      const effectiveSort = overrides.sort ?? userSort;
      const effectiveQuery = String(overrides.query ?? userQuery).trim();
      const effectivePhotoOnly = overrides.photoOnly ?? userSearchPhotoOnly;
      const effectiveVerifiedOnly = overrides.verifiedOnly ?? userVerifiedOnly;
      const effectiveOnlineOnly = overrides.onlineOnly ?? userOnlineOnly;
      const effectiveMinScore = String(overrides.minScore ?? userMinScore ?? '').trim();
      const params = new URLSearchParams({
        filter: filterValue,
        sort: effectiveSort,
        limit: '800'
      });
      if (effectiveQuery) params.set('q', effectiveQuery);
      if (effectivePhotoOnly) params.set('photo', '1');
      if (effectiveVerifiedOnly) params.set('verified', '1');
      if (effectiveOnlineOnly) params.set('online', '1');
      if (effectiveMinScore) params.set('minScore', effectiveMinScore);
      const data = await apiJson(`/api/admin/users/lists?${params.toString()}`);
      setUsers(data.users || []);
      setUsersMeta({ total: Number(data.meta?.total || 0), returned: Number(data.meta?.returned || 0) });
      setUserMode(effectiveQuery || effectivePhotoOnly ? 'search' : 'filter');
    } finally {
      setUsersLoading(false);
    }
  }

  async function searchUsers() {
    await loadUsers(userFilter);
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

  async function loadEngagementScores(pageValue = engagementFilters.page) {
    setEngagementLoading(true);
    try {
      const params = new URLSearchParams({
        page: String(pageValue),
        limit: String(engagementFilters.limit || 40),
        sort: engagementFilters.sort || 'score_desc',
        status: engagementFilters.status || 'all'
      });
      if (engagementFilters.q.trim()) params.set('q', engagementFilters.q.trim());
      if (engagementFilters.variant) params.set('variant', engagementFilters.variant);
      if (String(engagementFilters.minScore || '').trim()) params.set('minScore', String(engagementFilters.minScore).trim());
      if (String(engagementFilters.maxScore || '').trim()) params.set('maxScore', String(engagementFilters.maxScore).trim());
      const data = await apiJson(`/api/new/admin/engagement-scores?${params.toString()}`);
      setEngagementRows(data.items || []);
      setEngagementMeta({
        total: Number(data.total || 0),
        page: Number(data.page || pageValue || 1),
        pages: Number(data.pages || 1),
        limit: Number(data.limit || engagementFilters.limit || 40)
      });
      setEngagementSummary(data.summary || { avgScore: 0, maxScore: 0, minScore: 0 });
      setEngagementLastCalculatedAt(data.lastCalculatedAt || '');
      setEngagementFilters((prev) => ({ ...prev, page: Number(data.page || pageValue || 1) }));
    } finally {
      setEngagementLoading(false);
    }
  }

  async function recalculateEngagementScores() {
    await apiJson('/api/new/admin/engagement-scores/recalculate', { method: 'POST' });
    setStatus('Etkileşim skorları yeniden hesaplandı.');
    await Promise.all([
      loadEngagementScores(1),
      loadEngagementAb(),
      loadUsers(userFilter)
    ]);
  }

  async function loadEngagementAb() {
    setEngagementAbLoading(true);
    try {
      const data = await apiJson('/api/new/admin/engagement-ab');
      const configs = data.configs || [];
      setEngagementAbConfigs(configs);
      setEngagementAbPerformance(data.performance || []);
      setEngagementAbAssignments(data.assignmentCounts || []);
      setEngagementAbRecommendations(data.recommendations || []);
      if (data.lastCalculatedAt) setEngagementLastCalculatedAt(data.lastCalculatedAt);
      const nextForms = {};
      for (const cfg of configs) {
        nextForms[cfg.variant] = {
          name: cfg.name || '',
          description: cfg.description || '',
          trafficPct: String(cfg.trafficPct ?? 50),
          enabled: Number(cfg.enabled || 0) === 1,
          paramsText: JSON.stringify(cfg.params || {}, null, 2)
        };
      }
      setEngagementAbForms(nextForms);
    } finally {
      setEngagementAbLoading(false);
    }
  }

  function updateEngagementAbForm(variant, field, value) {
    setEngagementAbForms((prev) => ({
      ...prev,
      [variant]: {
        ...(prev[variant] || {}),
        [field]: value
      }
    }));
  }

  async function saveEngagementAbVariant(variant) {
    const form = engagementAbForms[variant];
    if (!form) return;
    let params;
    try {
      params = JSON.parse(form.paramsText || '{}');
    } catch {
      setStatus(`Variant ${variant} parametre JSON formatı geçersiz.`);
      return;
    }
    await apiJson(`/api/new/admin/engagement-ab/${encodeURIComponent(variant)}`, {
      method: 'PUT',
      body: JSON.stringify({
        name: form.name,
        description: form.description,
        trafficPct: Number(form.trafficPct || 0),
        enabled: form.enabled ? 1 : 0,
        params
      })
    });
    setStatus(`Variant ${variant} kaydedildi.`);
    await Promise.all([
      loadEngagementAb(),
      loadEngagementScores(1)
    ]);
  }

  async function rebalanceEngagementAb() {
    await apiJson('/api/new/admin/engagement-ab/rebalance', { method: 'POST', body: JSON.stringify({ keepAssignments: 0 }) });
    setStatus('A/B üyelik dağılımı yeniden oluşturuldu ve skorlar hesaplandı.');
    await Promise.all([
      loadEngagementAb(),
      loadEngagementScores(1),
      loadUsers(userFilter)
    ]);
  }

  function applyAbRecommendation(recommendation) {
    const variant = recommendation?.variant;
    if (!variant) return;
    if (recommendation.patch && typeof recommendation.patch === 'object') {
      setEngagementAbForms((prev) => {
        const current = prev[variant];
        if (!current) return prev;
        let currentParams = {};
        try {
          currentParams = JSON.parse(current.paramsText || '{}');
        } catch {
          currentParams = {};
        }
        const merged = { ...currentParams, ...recommendation.patch };
        return {
          ...prev,
          [variant]: {
            ...current,
            paramsText: JSON.stringify(merged, null, 2)
          }
        };
      });
      setStatus(`Variant ${variant} için öneri forma uygulandı. Kaydetmek için "Variant ${variant} Kaydet" tuşuna bas.`);
    }
    if (recommendation.trafficPatch && typeof recommendation.trafficPatch === 'object') {
      setEngagementAbForms((prev) => {
        const next = { ...prev };
        for (const [v, value] of Object.entries(recommendation.trafficPatch)) {
          if (!next[v]) continue;
          next[v] = { ...next[v], trafficPct: String(value) };
        }
        return next;
      });
      setStatus('Traffic önerisi forma uygulandı. İlgili variantları kaydet.');
    }
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
      const params = new URLSearchParams({
        type: logType,
        ...(logFilters.from ? { from: logFilters.from } : {}),
        ...(logFilters.to ? { to: logFilters.to } : {})
      });
      const data = await apiJson(`/api/admin/logs?${params.toString()}`);
      setLogs(data.files || []);
      setLogFile('');
      setLogContent('');
      setLogMeta({ total: 0, matched: 0, returned: 0, offset: 0, limit: Number(logFilters.limit) || 500 });
    } catch (err) {
      setStatus(err.message || 'Loglar alınamadı.');
      setLogs([]);
    }
  }

  async function openLog(file, opts = {}) {
    const fileName = typeof file === 'string' ? file : file?.name;
    if (!fileName) return;
    const merged = {
      ...logFilters,
      ...opts
    };
    const params = new URLSearchParams({
      type: logType,
      file: fileName,
      ...(merged.q ? { q: merged.q } : {}),
      ...(merged.activity ? { activity: merged.activity } : {}),
      ...(merged.userId ? { userId: merged.userId } : {}),
      ...(merged.from ? { from: merged.from } : {}),
      ...(merged.to ? { to: merged.to } : {}),
      limit: String(merged.limit || 500),
      offset: String(merged.offset || 0)
    });
    const data = await apiJson(`/api/admin/logs?${params.toString()}`);
    setLogFile(fileName);
    setLogContent(data.content || '');
    setLogMeta({
      total: Number(data.total || 0),
      matched: Number(data.matched || 0),
      returned: Number(data.returned || 0),
      offset: Number(data.offset || 0),
      limit: Number(data.limit || merged.limit || 500)
    });
  }

  async function applyLogFilters() {
    if (!logFile) return;
    await openLog(logFile, { offset: 0 });
  }

  async function paginateLog(direction) {
    if (!logFile) return;
    const step = Number(logMeta.limit || logFilters.limit || 500);
    const currentOffset = Number(logMeta.offset || 0);
    const nextOffset = direction === 'next'
      ? currentOffset + step
      : Math.max(currentOffset - step, 0);
    await openLog(logFile, { offset: nextOffset });
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

  async function loadPosts() {
    const data = await apiJson('/api/new/admin/posts?limit=250');
    setPosts(data.items || []);
  }

  async function deletePost(id) {
    await apiJson(`/api/new/admin/posts/${id}`, { method: 'DELETE' });
    loadPosts();
    if (tab === 'dashboard') refreshDashboard();
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

  async function loadFollowInsights() {
    const uid = Number(followTargetUserId || 0);
    if (!uid) {
      setStatus('Lütfen geçerli bir üye ID girin.');
      return;
    }
    setFollowInsightsLoading(true);
    try {
      const data = await apiJson(`/api/new/admin/follows/${uid}?limit=80&offset=0`);
      setFollowInsights({
        user: data.user || null,
        items: data.items || [],
        hasMore: Boolean(data.hasMore)
      });
    } finally {
      setFollowInsightsLoading(false);
    }
  }

  async function loadDbTables() {
    const data = await apiJson('/api/new/admin/db/tables');
    const items = data.items || [];
    setDbTables(items);
    if (!dbTableName && items.length) {
      loadDbTable(items[0].name, 1);
    }
  }

  async function loadDbBackups() {
    const data = await apiJson('/api/new/admin/db/backups');
    setDbBackups(data.items || []);
    setDbRuntimePath(String(data.dbPath || ''));
  }

  async function createDbBackup() {
    setDbBackupBusy(true);
    try {
      const data = await apiJson('/api/new/admin/db/backups', {
        method: 'POST',
        body: JSON.stringify({ label: 'admin' })
      });
      setStatus(`Yedek oluşturuldu: ${data.backup?.name || '-'}`);
      await loadDbBackups();
    } finally {
      setDbBackupBusy(false);
    }
  }

  function downloadDbBackup(name) {
    if (!name) return;
    window.open(`/api/new/admin/db/backups/${encodeURIComponent(name)}/download`, '_blank', 'noopener,noreferrer');
  }

  async function restoreDbBackup() {
    if (!dbRestoreFile) {
      setStatus('Geri yüklemek için bir yedek dosyası seçin.');
      return;
    }
    setDbBackupBusy(true);
    try {
      const form = new FormData();
      form.append('backup', dbRestoreFile);
      const res = await fetch('/api/new/admin/db/restore', {
        method: 'POST',
        credentials: 'include',
        body: form
      });
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || 'Geri yükleme başarısız.');
      }
      const data = await res.json();
      setStatus(`Veritabanı geri yüklendi. Güvenlik yedeği: ${data.restored?.preRestoreName || '-'}`);
      setDbRestoreFile(null);
      setDbRestoreInputKey((v) => v + 1);
      await Promise.all([loadDbTables(), loadDbBackups()]);
      if (dbTableName) await loadDbTable(dbTableName, 1);
    } finally {
      setDbBackupBusy(false);
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
  const userSummary = useMemo(() => {
    const total = users.length;
    const active = users.filter((u) => Number(u.aktiv || 0) === 1 && Number(u.yasak || 0) === 0).length;
    const pending = users.filter((u) => Number(u.aktiv || 0) === 0 && Number(u.yasak || 0) === 0).length;
    const banned = users.filter((u) => Number(u.yasak || 0) === 1).length;
    const online = users.filter((u) => Number(u.online || 0) === 1).length;
    return { total, active, pending, banned, online };
  }, [users]);

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
              <div className="composer-actions">
                <select className="input" value={tab} onChange={(e) => setTab(e.target.value)}>
                  {tabs.map((item) => (
                    <option key={`tab-select-${item.key}`} value={item.key}>{item.section} / {item.label}</option>
                  ))}
                </select>
              </div>
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
                <button className="admin-kpi-card admin-kpi-link" onClick={() => { setTab('users'); setUserFilter('all'); }}>
                  <div className="muted">Toplam Üye</div><b>{stats.counts.users}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => { setTab('users'); setUserFilter('active'); }}>
                  <div className="muted">Aktif Üye</div><b>{stats.counts.activeUsers}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => { setTab('users'); setUserFilter('online'); }}>
                  <div className="muted">Online Üye</div><b>{live.counts.onlineUsers || 0}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => { setTab('photos'); setPhotoFilter((prev) => ({ ...prev, krt: 'onaybekleyen' })); }}>
                  <div className="muted">Bekleyen Fotoğraf</div><b>{live.counts.pendingPhotos || 0}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => setTab('events')}>
                  <div className="muted">Bekleyen Etkinlik</div><b>{live.counts.pendingEvents || 0}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => setTab('announcements')}>
                  <div className="muted">Bekleyen Duyuru</div><b>{live.counts.pendingAnnouncements || 0}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => setTab('verification')}>
                  <div className="muted">Bekleyen Doğrulama</div><b>{live.counts.pendingVerifications || 0}</b>
                </button>
                <button className="admin-kpi-card admin-kpi-link" onClick={() => setTab('messages')}>
                  <div className="muted">Toplam Mesaj</div><b>{stats.counts.messages}</b>
                </button>
                <div className="admin-kpi-card">
                  <div className="muted">Toplam Yüklenen Fotoğraf</div><b>{stats.storage?.uploadedPhotoCount || 0}</b>
                </div>
                <div className="admin-kpi-card">
                  <div className="muted">Yüklenen Medya Alanı (MB)</div><b>{Number(stats.storage?.uploadedPhotoSizeMb || 0).toFixed(2)}</b>
                </div>
                <div className="admin-kpi-card">
                  <div className="muted">Veritabanı Boyutu (MB)</div><b>{Number(stats.storage?.databaseSizeMb || 0).toFixed(2)}</b>
                </div>
                <div className="admin-kpi-card">
                  <div className="muted">Disk Kullanımı</div>
                  {stats.storage?.diskSupported ? (
                    <>
                      <b>{Number(stats.storage?.diskUsedPct).toFixed(1)}%</b>
                      <div className="meta">
                        Toplam {Number(stats.storage?.diskTotalMb).toFixed(0)} MB • Boş {Number(stats.storage?.diskFreeMb).toFixed(0)} MB
                      </div>
                      {stats.storage?.diskSource ? <div className="meta">Kaynak: {stats.storage.diskSource}</div> : null}
                    </>
                  ) : (
                    <div className="meta">Bu sunucuda desteklenmiyor.</div>
                  )}
                </div>
                <div className="admin-kpi-card">
                  <div className="muted">Anlık CPU</div>
                  {stats.storage?.cpuSupported ? <b>{Number(stats.storage?.cpuUsagePct).toFixed(1)}%</b> : <div className="meta">Bu sunucuda desteklenmiyor.</div>}
                </div>
              </div>
            </div>
          </div>
          <div className="grid">
            <div className="col-main">
              <div className="panel">
                <h3>Canlı Aktivite</h3>
                <div className="panel-body">
                  <div className="composer-actions">
                    <button className="btn ghost" onClick={() => setPreviewModal({ type: 'activity-all', data: live.activity || [] })}>Tümünü Gör</button>
                  </div>
                  <div className="list">
                    {(live.activity || []).slice(0, 5).map((a) => (
                      <button key={a.id} className="list-item" onClick={() => setPreviewModal({ type: 'activity', data: a })}>
                        <div>
                          <div className="name">{a.message}</div>
                          <div className="meta">{a.type} • {a.at ? new Date(a.at).toLocaleString('tr-TR') : '-'}</div>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
            <div className="col-side">
              <div className="panel">
                <h3>Yeni Üyeler</h3>
                <div className="panel-body">
                  <div className="composer-actions">
                    <button className="btn ghost" onClick={() => { setTab('users'); setUserFilter('recent'); }}>Tümünü Gör</button>
                  </div>
                  {stats.recentUsers.slice(0, 5).map((u) => (
                    <button key={u.id} className="list-item" onClick={() => setPreviewModal({ type: 'user', data: u })}>@{u.kadi}</button>
                  ))}
                </div>
              </div>
              <div className="panel">
                <h3>Son Paylaşımlar</h3>
                <div className="panel-body">
                  <div className="composer-actions">
                    <button className="btn ghost" onClick={() => setPreviewModal({ type: 'post-all', data: stats.recentPosts || [] })}>Tümünü Gör</button>
                  </div>
                  {stats.recentPosts.slice(0, 5).map((p) => (
                    <button key={p.id} className="list-item" onClick={() => setPreviewModal({ type: 'post', data: p })}>{(p.content || '').slice(0, 80) || '(metin yok)'}</button>
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
                <label>Liste Filtresi</label>
                <select className="input" value={userFilter} onChange={(e) => setUserFilter(e.target.value)}>
                  <option value="active">Aktif</option>
                  <option value="pending">Bekleyen</option>
                  <option value="banned">Yasaklı</option>
                  <option value="online">Online</option>
                  <option value="recent">Son giriş</option>
                  <option value="all">Tümü</option>
                </select>
                <select className="input" value={userSort} onChange={(e) => setUserSort(e.target.value)}>
                  <option value="engagement_desc">Skor: Yüksekten Düşüğe</option>
                  <option value="engagement_asc">Skor: Düşükten Yükseğe</option>
                  <option value="online">Online Önce</option>
                  <option value="recent">Son Giriş</option>
                  <option value="name">Ada Göre</option>
                </select>
                <input
                  className="input"
                  type="number"
                  min="0"
                  max="100"
                  placeholder="Min skor"
                  value={userMinScore}
                  onChange={(e) => setUserMinScore(e.target.value)}
                />
                <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={userVerifiedOnly}
                    onChange={(e) => setUserVerifiedOnly(e.target.checked)}
                  />
                  Verified
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={userOnlineOnly}
                    onChange={(e) => setUserOnlineOnly(e.target.checked)}
                  />
                  Sadece online
                </label>
                <button className="btn ghost" onClick={() => loadUsers(userFilter)}>Yenile</button>
              </div>
              <div className="form-row">
                <label>Arama</label>
                <input className="input" value={userQuery} onChange={(e) => setUserQuery(e.target.value)} />
                <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={userSearchPhotoOnly}
                    onChange={(e) => setUserSearchPhotoOnly(e.target.checked)}
                  />
                  Sadece fotoğrafı olanlar
                </label>
                <button className="btn" onClick={searchUsers}>Ara</button>
                <button
                  className="btn ghost"
                  onClick={() => {
                    setUserQuery('');
                    setUserSearchPhotoOnly(false);
                    setUserVerifiedOnly(false);
                    setUserOnlineOnly(false);
                    setUserMinScore('');
                    setUserSort('engagement_desc');
                    loadUsers(userFilter, {
                      query: '',
                      photoOnly: false,
                      verifiedOnly: false,
                      onlineOnly: false,
                      minScore: '',
                      sort: 'engagement_desc'
                    });
                  }}
                >
                  Temizle
                </button>
              </div>
              <div className="composer-actions">
                <span className="chip">Mod: {userMode === 'search' ? 'Arama Sonucu' : 'Filtre Listesi'}</span>
                <span className="chip">Toplam: {userSummary.total}</span>
                <span className="chip">Sunucuda Eşleşen: {usersMeta.total}</span>
                <span className="chip">Aktif: {userSummary.active}</span>
                <span className="chip">Bekleyen: {userSummary.pending}</span>
                <span className="chip">Yasaklı: {userSummary.banned}</span>
                <span className="chip">Online: {userSummary.online}</span>
              </div>
            </div>
            {usersLoading ? <div className="muted">Üyeler yükleniyor...</div> : null}
            <div className="list">
              {users.map((u) => (
                <button key={u.id} className="list-item" onClick={() => loadUserDetail(u.id)}>
                  <div>
                    <div className="name">@{u.kadi} ({u.isim} {u.soyisim})</div>
                    <div className="meta">
                      Skor: {Number(u.engagement_score || 0).toFixed(1)} / 100
                      {Number(u.online || 0) === 1 ? ' • Online' : ''}
                      {Number(u.verified || 0) === 1 ? ' • Verified' : ''}
                    </div>
                  </div>
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
                  <label>Etkileşim Skoru</label>
                  <input className="input" value={`${Number(userForm.engagement_score || 0).toFixed(1)} / 100`} readOnly />
                  <div className="muted">
                    Güncellendi: {userForm.engagement_updated_at ? new Date(userForm.engagement_updated_at).toLocaleString('tr-TR') : '-'}
                  </div>
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

      {tab === 'follows' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Takiplerini incelemek istediğin üye ID</label>
              <input className="input" value={followTargetUserId} onChange={(e) => setFollowTargetUserId(e.target.value)} placeholder="Örn: 123" />
              <button className="btn" onClick={loadFollowInsights} disabled={followInsightsLoading}>
                {followInsightsLoading ? 'Yükleniyor...' : 'Analizi Getir'}
              </button>
            </div>
            {followInsights.user ? (
              <div className="panel">
                <div className="panel-body">
                  <div className="name">{followInsights.user.isim} {followInsights.user.soyisim} (@{followInsights.user.kadi})</div>
                  <div className="meta">Takip sayısı: {followInsights.items.length}</div>
                </div>
              </div>
            ) : null}
            <div className="list">
              {followInsights.items.map((item) => (
                <button key={`follow-insight-${item.id}`} className="list-item" onClick={() => setPreviewModal({ type: 'follow', data: item })}>
                  <div>
                    <div className="name">@{item.kadi} • {item.isim} {item.soyisim}</div>
                    <div className="meta">
                      Takip tarihi: {item.followed_at ? new Date(item.followed_at).toLocaleString('tr-TR') : '-'}
                      {' '}• Gönderilen mesaj: {item.messageCount || 0}
                      {' '}• Alıntılama: {item.quoteCount || 0}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'engagement' ? (
        <div className="panel">
          <div className="panel-body">
            <h3>A/B Parametre Setleri</h3>
            <div className="composer-actions">
              <button className="btn ghost" onClick={loadEngagementAb}>A/B Verisini Yenile</button>
              <button className="btn ghost" onClick={rebalanceEngagementAb}>A/B Dağılımını Yeniden Oluştur</button>
              {engagementAbLoading ? <span className="muted">Yükleniyor...</span> : null}
            </div>
            <div className="composer-actions">
              {engagementAbAssignments.map((a) => (
                <span key={`assign-${a.variant}`} className="chip">
                  Atama {a.variant}: {a.cnt}
                </span>
              ))}
            </div>
            {engagementAbRecommendations.length ? (
              <div className="panel" style={{ marginBottom: 10 }}>
                <h3>Otomatik Öneriler</h3>
                <div className="panel-body">
                  {engagementAbRecommendations.map((rec, idx) => (
                    <div key={`rec-${rec.variant}-${idx}`} className="list-item">
                      <div>
                        <div className="name">Variant {rec.variant} • Güven: {Math.round(Number(rec.confidence || 0) * 100)}%</div>
                        <div className="meta">{Array.isArray(rec.reasons) ? rec.reasons.join(' | ') : ''}</div>
                        {rec.patch ? (
                          <div className="meta">
                            Parametre yaması: {Object.entries(rec.patch).slice(0, 6).map(([k, v]) => `${k}=${v}`).join(', ')}
                          </div>
                        ) : null}
                        {rec.trafficPatch ? (
                          <div className="meta">
                            Traffic yaması: {Object.entries(rec.trafficPatch).map(([k, v]) => `${k}:${v}%`).join(' • ')}
                          </div>
                        ) : null}
                      </div>
                      <button className="btn ghost" onClick={() => applyAbRecommendation(rec)}>Öneriyi Uygula</button>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            <div className="list">
              {engagementAbConfigs.map((cfg) => {
                const form = engagementAbForms[cfg.variant] || {};
                const perf = engagementAbPerformance.find((p) => String(p.variant) === String(cfg.variant));
                return (
                  <div key={cfg.variant} className="list-item" style={{ display: 'block' }}>
                    <div className="name">Variant {cfg.variant}</div>
                    <div className="meta">{cfg.description}</div>
                    <div className="meta">
                      Üye: {perf?.users || 0} • Ort. Skor: {Number(perf?.avg_score || 0).toFixed(1)} •
                      Etkileşim Oranı: {Number(perf?.engagementRate || 0).toFixed(2)}
                    </div>
                    <div className="form-row">
                      <label>Ad</label>
                      <input
                        className="input"
                        value={form.name || ''}
                        onChange={(e) => updateEngagementAbForm(cfg.variant, 'name', e.target.value)}
                      />
                      <label>Açıklama</label>
                      <input
                        className="input"
                        value={form.description || ''}
                        onChange={(e) => updateEngagementAbForm(cfg.variant, 'description', e.target.value)}
                      />
                      <label>Traffic %</label>
                      <input
                        className="input"
                        type="number"
                        min="0"
                        max="100"
                        value={form.trafficPct || '0'}
                        onChange={(e) => updateEngagementAbForm(cfg.variant, 'trafficPct', e.target.value)}
                      />
                      <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <input
                          type="checkbox"
                          checked={!!form.enabled}
                          onChange={(e) => updateEngagementAbForm(cfg.variant, 'enabled', e.target.checked)}
                        />
                        Aktif
                      </label>
                    </div>
                    <textarea
                      className="input"
                      rows={10}
                      value={form.paramsText || '{}'}
                      onChange={(e) => updateEngagementAbForm(cfg.variant, 'paramsText', e.target.value)}
                    />
                    <div className="composer-actions">
                      <button className="btn" onClick={() => saveEngagementAbVariant(cfg.variant)}>
                        Variant {cfg.variant} Kaydet
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>

            <h3>Skor Kayıtları</h3>
            <div className="form-row">
              <label>Filtre</label>
              <input
                className="input"
                placeholder="Kullanıcı ara"
                value={engagementFilters.q}
                onChange={(e) => setEngagementFilters((prev) => ({ ...prev, q: e.target.value }))}
              />
              <select
                className="input"
                value={engagementFilters.variant}
                onChange={(e) => setEngagementFilters((prev) => ({ ...prev, variant: e.target.value, page: 1 }))}
              >
                <option value="">Tüm variantlar</option>
                {engagementAbConfigs.map((cfg) => (
                  <option key={`variant-${cfg.variant}`} value={cfg.variant}>
                    Variant {cfg.variant}
                  </option>
                ))}
              </select>
              <select
                className="input"
                value={engagementFilters.status}
                onChange={(e) => setEngagementFilters((prev) => ({ ...prev, status: e.target.value, page: 1 }))}
              >
                <option value="all">Tüm üyeler</option>
                <option value="active">Aktif</option>
                <option value="pending">Bekleyen</option>
                <option value="banned">Yasaklı</option>
              </select>
              <input
                className="input"
                type="number"
                min="0"
                max="100"
                placeholder="Min skor"
                value={engagementFilters.minScore}
                onChange={(e) => setEngagementFilters((prev) => ({ ...prev, minScore: e.target.value, page: 1 }))}
              />
              <input
                className="input"
                type="number"
                min="0"
                max="100"
                placeholder="Maks skor"
                value={engagementFilters.maxScore}
                onChange={(e) => setEngagementFilters((prev) => ({ ...prev, maxScore: e.target.value, page: 1 }))}
              />
              <select
                className="input"
                value={engagementFilters.sort}
                onChange={(e) => setEngagementFilters((prev) => ({ ...prev, sort: e.target.value }))}
              >
                <option value="score_desc">Skor: Yüksekten Düşüğe</option>
                <option value="score_asc">Skor: Düşükten Yükseğe</option>
                <option value="recent_update">Son Güncellenen</option>
                <option value="name">Ada Göre</option>
              </select>
              <button className="btn" onClick={() => loadEngagementScores(1)}>Uygula</button>
              <button className="btn ghost" onClick={recalculateEngagementScores}>Skorları Yeniden Hesapla</button>
              <a className="btn ghost" href="/new/help#engagement-score">Yardım</a>
            </div>
            <div className="composer-actions">
              <span className="chip">Toplam: {engagementMeta.total}</span>
              <span className="chip">Ortalama: {Number(engagementSummary.avgScore || 0).toFixed(1)}</span>
              <span className="chip">Maks: {Number(engagementSummary.maxScore || 0).toFixed(1)}</span>
              <span className="chip">Min: {Number(engagementSummary.minScore || 0).toFixed(1)}</span>
              <span className="chip">
                Son hesaplama: {engagementLastCalculatedAt ? new Date(engagementLastCalculatedAt).toLocaleString('tr-TR') : '-'}
              </span>
            </div>
            {engagementLoading ? <div className="muted">Skorlar yükleniyor...</div> : null}
            <div className="list">
              {engagementRows.map((u) => (
                <div key={u.id} className="list-item">
                  <div>
                    <div className="name">@{u.kadi} ({u.isim} {u.soyisim})</div>
                    <div className="meta">
                      Variant: {u.ab_variant || 'A'} • Skor: {Number(u.score || 0).toFixed(1)} / 100 • Ham: {Number(u.raw_score || 0).toFixed(1)} • Son aktivite:{' '}
                      {u.last_activity_at ? new Date(u.last_activity_at).toLocaleString('tr-TR') : '-'}
                    </div>
                    <div className="meta">
                      İçerik: {Number(u.creator_score || 0).toFixed(1)} • Etkileşim: {Number(u.engagement_received_score || 0).toFixed(1)} •
                      Topluluk: {Number(u.community_score || 0).toFixed(1)} • Ağ: {Number(u.network_score || 0).toFixed(1)} •
                      Kalite: {Number(u.quality_score || 0).toFixed(1)} • Ceza: {Number(u.penalty_score || 0).toFixed(1)}
                    </div>
                    <div className="meta">
                      30g post: {u.posts_30d || 0} • Beğeni: {u.likes_received_30d || 0} • Yorum: {u.comments_received_30d || 0} •
                      Takipçi: {u.followers_count || 0} • Takip: {u.following_count || 0}
                    </div>
                  </div>
                </div>
              ))}
            </div>
            <div className="composer-actions">
              <button
                className="btn ghost"
                disabled={engagementMeta.page <= 1}
                onClick={() => loadEngagementScores(Math.max(1, engagementMeta.page - 1))}
              >
                Önceki
              </button>
              <span className="chip">Sayfa {engagementMeta.page} / {engagementMeta.pages}</span>
              <button
                className="btn ghost"
                disabled={engagementMeta.page >= engagementMeta.pages}
                onClick={() => loadEngagementScores(engagementMeta.page + 1)}
              >
                Sonraki
              </button>
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
              <input
                className="input"
                type="date"
                value={logFilters.from}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, from: e.target.value }))}
              />
              <input
                className="input"
                type="date"
                value={logFilters.to}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, to: e.target.value }))}
              />
              <button className="btn" onClick={loadLogs}>Yükle</button>
            </div>
            <div className="form-row">
              <label>İçerik Filtreleri</label>
              <input
                className="input"
                placeholder="Metin ara (q)"
                value={logFilters.q}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, q: e.target.value }))}
              />
              <select
                className="input"
                value={logFilters.activity}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, activity: e.target.value }))}
              >
                <option value="">Hızlı activity seç</option>
                {commonLogActivities.map((a) => (
                  <option key={a} value={a}>{a}</option>
                ))}
              </select>
              <input
                className="input"
                placeholder="activity (ör. http_error)"
                value={logFilters.activity}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, activity: e.target.value }))}
              />
              <input
                className="input"
                placeholder="userId"
                value={logFilters.userId}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, userId: e.target.value }))}
              />
              <input
                className="input"
                type="number"
                min="1"
                max="10000"
                placeholder="limit"
                value={logFilters.limit}
                onChange={(e) => setLogFilters((prev) => ({ ...prev, limit: Number(e.target.value || 500) }))}
              />
              <button className="btn ghost" onClick={applyLogFilters} disabled={!logFile}>Filtreyi Uygula</button>
            </div>
            <div className="list">
              {logs.map((f) => (
                <button key={f.name} className="list-item" onClick={() => openLog(f, { offset: 0 })}>
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
                <div className="composer-actions">
                  <div className="muted">
                    Toplam: {logMeta.total} • Eşleşen: {logMeta.matched} • Gösterilen: {logMeta.returned}
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      className="btn ghost"
                      onClick={() => paginateLog('prev')}
                      disabled={Number(logMeta.offset || 0) <= 0}
                    >
                      Önceki
                    </button>
                    <button
                      className="btn ghost"
                      onClick={() => paginateLog('next')}
                      disabled={Number(logMeta.offset || 0) + Number(logMeta.limit || 0) >= Number(logMeta.matched || 0)}
                    >
                      Sonraki
                    </button>
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
                  <button className="btn ghost" onClick={() => setPreviewModal({ type: 'event', data: e })}>Önizle</button>
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
                  <button className="btn ghost" onClick={() => setPreviewModal({ type: 'announcement', data: a })}>Önizle</button>
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

      {tab === 'posts' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="composer-actions">
              <button className="btn ghost" onClick={loadPosts}>Yenile</button>
            </div>
            <div className="list">
              {posts.map((p) => (
                <div key={p.id} className="list-item">
                  <div>
                    <div className="name">#{p.id} @{p.kadi || 'üye'}</div>
                    <div className="meta">{p.created_at ? new Date(p.created_at).toLocaleString('tr-TR') : '-'}</div>
                    <div className="meta">{(p.content || '').replace(/<[^>]+>/g, ' ').trim().slice(0, 220) || '(metin yok)'}</div>
                    {p.image ? <a className="meta" href={p.image} target="_blank" rel="noreferrer">Görseli Aç</a> : null}
                  </div>
                  <div className="composer-actions">
                    <button className="btn ghost" onClick={() => setPreviewModal({ type: 'post', data: p })}>Önizle</button>
                    <button className="btn ghost" onClick={() => deletePost(p.id)}>Sil</button>
                  </div>
                </div>
              ))}
            </div>
            {!posts.length ? <div className="muted">Gösterilecek post yok.</div> : null}
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
          <div className="panel">
            <h3>Yedekleme</h3>
            <div className="panel-body">
              <div className="db-toolbar">
                <button className="btn" onClick={createDbBackup} disabled={dbBackupBusy}>
                  {dbBackupBusy ? 'Çalışıyor...' : 'Yeni Yedek Oluştur'}
                </button>
                <button className="btn ghost" onClick={loadDbBackups} disabled={dbBackupBusy}>Listeyi Yenile</button>
              </div>
              <div className="muted">Yedek dosyasını indirip başka sunucuda geri yükleyebilirsiniz.</div>
              {dbRuntimePath ? (
                <div className="muted">Aktif DB yolu: <code>{dbRuntimePath}</code></div>
              ) : null}
              <input
                key={dbRestoreInputKey}
                className="input"
                type="file"
                accept=".sqlite,.db,.backup,.bak"
                onChange={(e) => setDbRestoreFile(e.target.files?.[0] || null)}
              />
              <button className="btn ghost" onClick={restoreDbBackup} disabled={dbBackupBusy || !dbRestoreFile}>
                Seçili Dosyadan Geri Yükle
              </button>
              <div className="list">
                {dbBackups.map((b) => (
                  <div key={b.name} className="list-item">
                    <div>
                      <div className="name">{b.name}</div>
                      <div className="meta">{Math.round((b.size || 0) / 1024)} KB • {b.mtime ? new Date(b.mtime).toLocaleString('tr-TR') : '-'}</div>
                    </div>
                    <button className="btn ghost" onClick={() => downloadDbBackup(b.name)}>İndir</button>
                  </div>
                ))}
              </div>
              {!dbBackups.length ? <div className="muted">Henüz yedek yok.</div> : null}
            </div>
          </div>
        </div>
      ) : null}

      {previewModal ? (
        <div className="story-modal" onClick={() => setPreviewModal(null)}>
          <div className="story-frame admin-preview" onClick={(e) => e.stopPropagation()}>
            <div className="composer-actions">
              <h3>Önizleme</h3>
              <button className="btn ghost" onClick={() => setPreviewModal(null)}>Kapat</button>
            </div>
            {previewModal.type === 'activity' ? (
              <div className="stack">
                <div className="name">{previewModal.data?.message}</div>
                <div className="meta">{previewModal.data?.type}</div>
                <div className="meta">{previewModal.data?.at ? new Date(previewModal.data.at).toLocaleString('tr-TR') : '-'}</div>
              </div>
            ) : null}
            {previewModal.type === 'activity-all' ? (
              <div className="list">
                {(previewModal.data || []).map((row) => (
                  <div key={`a-all-${row.id}`} className="list-item">
                    <div>
                      <div className="name">{row.message}</div>
                      <div className="meta">{row.type} • {row.at ? new Date(row.at).toLocaleString('tr-TR') : '-'}</div>
                    </div>
                  </div>
                ))}
              </div>
            ) : null}
            {previewModal.type === 'user' ? (
              <div className="stack">
                <div className="name">@{previewModal.data?.kadi}</div>
                <div className="meta">{previewModal.data?.isim} {previewModal.data?.soyisim}</div>
                <div className="meta">Kayıt: {previewModal.data?.ilktarih ? new Date(previewModal.data.ilktarih).toLocaleString('tr-TR') : '-'}</div>
              </div>
            ) : null}
            {previewModal.type === 'post' ? (
              <div className="stack">
                <div className="meta">Paylaşım ID: {previewModal.data?.id}</div>
                <div className="meta">Tarih: {previewModal.data?.created_at ? new Date(previewModal.data.created_at).toLocaleString('tr-TR') : '-'}</div>
                <div>{previewModal.data?.content || '(metin yok)'}</div>
                {previewModal.data?.image ? <img className="post-image" src={previewModal.data.image} alt="" /> : null}
              </div>
            ) : null}
            {previewModal.type === 'post-all' ? (
              <div className="list">
                {(previewModal.data || []).map((p) => (
                  <button key={`p-all-${p.id}`} className="list-item" onClick={() => setPreviewModal({ type: 'post', data: p })}>
                    <div>{(p.content || '').slice(0, 120) || '(metin yok)'}</div>
                  </button>
                ))}
              </div>
            ) : null}
            {previewModal.type === 'follow' ? (
              <div className="stack">
                <div className="name">@{previewModal.data?.kadi}</div>
                <div className="meta">Takip tarihi: {previewModal.data?.followed_at ? new Date(previewModal.data.followed_at).toLocaleString('tr-TR') : '-'}</div>
                <div className="meta">Mesaj sayısı: {previewModal.data?.messageCount || 0}</div>
                <div className="meta">Alıntılama sayısı: {previewModal.data?.quoteCount || 0}</div>
                <div>
                  <b>Son Mesajlar</b>
                  <div className="list">
                    {(previewModal.data?.recentMessages || []).map((m) => (
                      <div key={`fm-${m.id}`} className="list-item">
                        <div>
                          <div className="name">{m.konu || '(konu yok)'}</div>
                          <div className="meta">{m.tarih ? new Date(m.tarih).toLocaleString('tr-TR') : '-'}</div>
                          <div>{m.mesaj || ''}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
                <div>
                  <b>Son Alıntılar</b>
                  <div className="list">
                    {(previewModal.data?.recentQuotes || []).map((q) => (
                      <div key={`fq-${q.id}`} className="list-item">
                        <div>
                          <div className="meta">{q.created_at ? new Date(q.created_at).toLocaleString('tr-TR') : '-'}</div>
                          <div>{q.content || ''}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            ) : null}
            {previewModal.type === 'event' ? (
              <div className="stack">
                <div className="name">{previewModal.data?.title}</div>
                <div className="meta">{previewModal.data?.starts_at ? new Date(previewModal.data.starts_at).toLocaleString('tr-TR') : '-'}</div>
                <div className="meta">{previewModal.data?.location || '-'}</div>
                <div dangerouslySetInnerHTML={{ __html: previewModal.data?.description || previewModal.data?.body || '' }} />
                {previewModal.data?.image ? <img className="post-image" src={previewModal.data.image} alt="" /> : null}
              </div>
            ) : null}
            {previewModal.type === 'announcement' ? (
              <div className="stack">
                <div className="name">{previewModal.data?.title}</div>
                <div className="meta">{previewModal.data?.created_at ? new Date(previewModal.data.created_at).toLocaleString('tr-TR') : '-'}</div>
                <div dangerouslySetInnerHTML={{ __html: previewModal.data?.body || previewModal.data?.description || '' }} />
                {previewModal.data?.image ? <img className="post-image" src={previewModal.data.image} alt="" /> : null}
              </div>
            ) : null}
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
