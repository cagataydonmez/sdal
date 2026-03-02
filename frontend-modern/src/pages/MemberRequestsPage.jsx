import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

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

  async function createRequest() {
    setStatus('');
    setError('');
    try {
      const payload = { note };
      if (categoryKey === 'graduation_year_change') payload.requestedGraduationYear = requestedGraduationYear;
      await apiJson('/api/new/requests', {
        method: 'POST',
        body: JSON.stringify({ category_key: categoryKey, payload })
      });
      setStatus(t('member_requests_created'));
      setNote('');
      setRequestedGraduationYear('');
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
              <input className="input" value={requestedGraduationYear} onChange={(e) => setRequestedGraduationYear(e.target.value)} placeholder="2012" />
            </div>
          ) : null}
          <div className="form-row">
            <label>{t('description')}</label>
            <textarea className="input" value={note} onChange={(e) => setNote(e.target.value)} />
          </div>
          <button className="btn primary" onClick={createRequest}>{t('member_requests_submit')}</button>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="panel">
        <div className="panel-body">
          <h3>{t('member_requests_my')}</h3>
          {!items.length ? <div className="muted">{t('no_results')}</div> : null}
          {items.map((item) => (
            <div key={item.id} className="list-item" style={{ alignItems: 'flex-start' }}>
              <div>
                <strong>{item.category_label || item.category_key}</strong>
                <div className="muted">#{item.id} • {item.status} • {new Date(item.created_at).toLocaleString()}</div>
                {item.payload_json ? <pre className="muted" style={{ whiteSpace: 'pre-wrap' }}>{item.payload_json}</pre> : null}
              </div>
            </div>
          ))}
        </div>
      </div>
    </Layout>
  );
}
