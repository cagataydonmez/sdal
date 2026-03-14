import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useLocation } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';
import RequestPayloadCard from '../components/RequestPayloadCard.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export default function MemberRequestsPage() {
  const { t } = useI18n();
  const location = useLocation();
  const [items, setItems] = useState([]);
  const [categories, setCategories] = useState([]);
  const [categoryKey, setCategoryKey] = useState('graduation_year_change');
  const [requestedGraduationYear, setRequestedGraduationYear] = useState('');
  const [note, setNote] = useState('');
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [attachments, setAttachments] = useState([]);
  const requestCardRefs = useRef(new Map());
  const searchParams = useMemo(() => new URLSearchParams(location.search || ''), [location.search]);
  const highlightedRequestId = Number(searchParams.get('request') || 0);
  const notificationId = Number(searchParams.get('notification') || 0);
  const notificationStatus = String(searchParams.get('status') || '').trim().toLowerCase();
  const landingResolved = !notificationId || !highlightedRequestId || items.some((item) => Number(item.id || 0) === highlightedRequestId);

  useNotificationNavigationTracking(notificationId, {
    surface: 'member_requests_page',
    resolved: landingResolved
  });

  async function load() {
    const [myReq, cats] = await Promise.all([apiJson('/api/new/requests/my'), apiJson('/api/new/request-categories')]);
    setItems(myReq.items || []);
    setCategories(cats.items || []);
  }

  useEffect(() => {
    const params = new URLSearchParams(location.search || '');
    const category = String(params.get('category') || '').trim();
    if (category) setCategoryKey(category);
    load().catch(() => {});
  }, [location.search]);

  useEffect(() => {
    if (!highlightedRequestId || !items.length) return;
    const timer = window.setTimeout(() => {
      requestCardRefs.current.get(highlightedRequestId)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [highlightedRequestId, items]);

  async function uploadAttachment(file) {
    const form = new FormData();
    form.append('file', file);
    const res = await fetch('/api/new/requests/upload', { method: 'POST', body: form, credentials: 'include' });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    return data?.attachment;
  }

  async function createRequest() {
    setStatus('');
    setError('');
    try {
      const payload = { note, attachments };
      if (categoryKey === 'graduation_year_change') payload.requestedGraduationYear = requestedGraduationYear;
      await apiJson('/api/new/requests', {
        method: 'POST',
        body: JSON.stringify({ category_key: categoryKey, payload })
      });
      setStatus(t('member_requests_created'));
      setNote('');
      setRequestedGraduationYear('');
      setAttachments([]);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <Layout title={t('member_requests_title')}>
      <div className="panel">
        <div className="panel-body">
          <h3>{t('member_requests_create')}</h3>
          <div className="form-row">
            <label>{t('member_requests_category')}</label>
            <select className="input" value={categoryKey} onChange={(e) => setCategoryKey(e.target.value)}>
              {categories.map((c) => <option key={c.category_key} value={c.category_key}>{c.label}</option>)}
            </select>
          </div>
          {categoryKey === 'graduation_year_change' ? (
            <div className="form-row">
              <label>{t('profile_graduation')}</label>
              <select className="input" value={requestedGraduationYear} onChange={(e) => setRequestedGraduationYear(e.target.value)}>
                <option value="">Yıl seçiniz</option>
                <option value="teacher">Öğretmen</option>
                {Array.from({ length: new Date().getFullYear() - 1999 + 1 }, (_, i) => String(new Date().getFullYear() - i)).map((year) => <option key={year} value={year}>{year}</option>)}
              </select>
            </div>
          ) : null}
          <div className="form-row">
            <label>{t('description')}</label>
            <textarea className="input" value={note} onChange={(e) => setNote(e.target.value)} />
          </div>

          <div className="form-row">
            <label>Dosya / Fotoğraf Eki</label>
            <input
              className="input"
              type="file"
              accept=".jpg,.jpeg,.png,.pdf"
              onChange={async (e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                try {
                  const attachment = await uploadAttachment(file);
                  if (attachment) setAttachments((prev) => [...prev, attachment]);
                } catch (err) {
                  setError(err.message);
                }
                e.target.value = '';
              }}
            />
            {attachments.length ? <RequestPayloadCard payloadJson={{ attachments }} /> : null}
          </div>

          <button className="btn primary" onClick={createRequest}>{t('member_requests_submit')}</button>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="panel">
        <div className="panel-body">
          <h3>{t('member_requests_my')}</h3>
          {notificationId && notificationStatus ? (
            <div className="notification-focus-inline-panel">
              <strong>Talep sonucu güncellendi</strong>
              <div className="muted">
                {notificationStatus === 'approved'
                  ? 'Talebin onaylandı. İlgili kayıt aşağıda vurgulandı.'
                  : 'Talebin sonuçlandı. Ayrıntı için ilgili kayıt aşağıda vurgulandı.'}
              </div>
            </div>
          ) : null}
          {!items.length ? <div className="muted">{t('no_results')}</div> : null}
          {items.map((item) => (
            <div
              key={item.id}
              ref={(node) => {
                if (node) requestCardRefs.current.set(Number(item.id || 0), node);
                else requestCardRefs.current.delete(Number(item.id || 0));
              }}
              className={`list-item${Number(item.id || 0) === highlightedRequestId ? ' notification-focus-card' : ''}`}
              style={{ alignItems: 'flex-start' }}
            >
              <div>
                <strong>{item.category_label || item.category_key}</strong>
                <div className="muted">#{item.id} • {item.status} • {new Date(item.created_at).toLocaleString()}</div>
                {item.payload_json ? <RequestPayloadCard payloadJson={item.payload_json} /> : null}
              </div>
            </div>
          ))}
        </div>
      </div>
    </Layout>
  );
}
