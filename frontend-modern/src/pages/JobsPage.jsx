import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { formatDateTime } from '../utils/date.js';

const EMPTY_FORM = { company: '', title: '', description: '', location: '', job_type: '', link: '' };

export default function JobsPage() {
  const { t } = useI18n();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [query, setQuery] = useState({ search: '', location: '', job_type: '' });
  const [form, setForm] = useState(EMPTY_FORM);

  async function load() {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      if (query.search.trim()) params.set('search', query.search.trim());
      if (query.location.trim()) params.set('location', query.location.trim());
      if (query.job_type.trim()) params.set('job_type', query.job_type.trim());
      const res = await fetch(`/api/new/jobs?${params.toString()}`, { credentials: 'include' });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      setItems(data.items || []);
    } catch (err) {
      setError(err.message || t('jobs_load_failed'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function submitJob(e) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const res = await fetch('/api/new/jobs', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      if (!res.ok) throw new Error(await res.text());
      setForm(EMPTY_FORM);
      await load();
    } catch (err) {
      setError(err.message || t('jobs_create_failed'));
    } finally {
      setSaving(false);
    }
  }

  async function deleteJob(id) {
    if (!window.confirm(t('jobs_delete_confirm'))) return;
    try {
      const res = await fetch(`/api/new/jobs/${id}`, { method: 'DELETE', credentials: 'include' });
      if (!res.ok) throw new Error(await res.text());
      await load();
    } catch (err) {
      setError(err.message || t('jobs_delete_failed'));
    }
  }

  return (
    <Layout title={t('jobs_title')}>
      <div className="panel">
        <h3>{t('jobs_new_post')}</h3>
        <form className="panel-body grid two" onSubmit={submitJob}>
          <label>{t('jobs_company')}<input className="input" required value={form.company} onChange={(e) => setForm({ ...form, company: e.target.value })} /></label>
          <label>{t('jobs_job_title')}<input className="input" required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
          <label>{t('location')}<input className="input" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} /></label>
          <label>{t('jobs_type')}<input className="input" value={form.job_type} onChange={(e) => setForm({ ...form, job_type: e.target.value })} placeholder={t('jobs_type_placeholder')} /></label>
          <label className="span-2">{t('jobs_link')}<input className="input" value={form.link} onChange={(e) => setForm({ ...form, link: e.target.value })} placeholder="https://..." /></label>
          <label className="span-2">{t('description')}<textarea className="input" rows={4} required value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
          <div className="span-2 composer-actions">
            <button className="btn" disabled={saving}>{saving ? t('saving') : t('jobs_publish')}</button>
          </div>
        </form>
      </div>

      <div className="panel">
        <div className="panel-body grid three">
          <input className="input" placeholder={t('search')} value={query.search} onChange={(e) => setQuery({ ...query, search: e.target.value })} />
          <input className="input" placeholder={t('location')} value={query.location} onChange={(e) => setQuery({ ...query, location: e.target.value })} />
          <input className="input" placeholder={t('jobs_type')} value={query.job_type} onChange={(e) => setQuery({ ...query, job_type: e.target.value })} />
        </div>
        <div className="panel-body"><button className="btn ghost" onClick={load}>{t('search')}</button></div>
      </div>

      {error ? <div className="panel error">{error}</div> : null}
      {loading ? <div className="muted">{t('loading')}</div> : null}
      {!loading && items.length === 0 ? <div className="muted">{t('jobs_empty')}</div> : null}

      <div className="stack">
        {items.map((job) => (
          <div className="panel" key={job.id}>
            <div className="panel-body">
              <div className="list-item">
                <div>
                  <b>{job.title}</b>
                  <div className="meta">{job.company} {job.location ? `· ${job.location}` : ''} {job.job_type ? `· ${job.job_type}` : ''}</div>
                  <div className="meta">@{job.poster_kadi || t('member_fallback')} · {formatDateTime(job.created_at)}</div>
                </div>
                <div className="composer-actions">
                  {job.link ? <a className="btn ghost" href={job.link} target="_blank" rel="noreferrer">{t('jobs_apply')}</a> : null}
                  <button className="btn ghost" onClick={() => deleteJob(job.id)}>{t('delete')}</button>
                </div>
              </div>
              <div dangerouslySetInnerHTML={{ __html: job.description || '' }} />
            </div>
          </div>
        ))}
      </div>
    </Layout>
  );
}
