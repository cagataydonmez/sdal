import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { formatDateTime } from '../utils/date.js';

const EMPTY_FORM = { company: '', title: '', description: '', location: '', job_type: '', link: '' };

export default function JobsPage() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [searchParams] = useSearchParams();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [query, setQuery] = useState({ search: '', location: '', job_type: '' });
  const [form, setForm] = useState(EMPTY_FORM);
  const [applicationsByJob, setApplicationsByJob] = useState({});
  const [applicationsError, setApplicationsError] = useState('');
  const [applicationsLoading, setApplicationsLoading] = useState(false);
  const cardRefs = useRef(new Map());
  const highlightedJobId = Number(searchParams.get('job') || 0);
  const highlightedTab = String(searchParams.get('tab') || '').trim().toLowerCase();
  const highlightedJob = useMemo(
    () => items.find((item) => Number(item.id || 0) === highlightedJobId) || null,
    [items, highlightedJobId]
  );

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

  useEffect(() => {
    if (!highlightedJobId) return;
    const timer = window.setTimeout(() => {
      const node = cardRefs.current.get(highlightedJobId);
      node?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [highlightedJobId, items.length]);

  useEffect(() => {
    if (!highlightedJob || highlightedTab !== 'applications') return;
    if (Number(highlightedJob.poster_id || 0) !== Number(user?.id || 0)) return;
    let cancelled = false;
    async function loadApplications() {
      setApplicationsLoading(true);
      setApplicationsError('');
      try {
        const res = await fetch(`/api/new/jobs/${highlightedJob.id}/applications`, { credentials: 'include' });
        if (!res.ok) throw new Error(await res.text());
        const payload = await res.json();
        if (cancelled) return;
        setApplicationsByJob((prev) => ({ ...prev, [highlightedJob.id]: payload.items || [] }));
      } catch (err) {
        if (cancelled) return;
        setApplicationsError(err.message || 'Başvurular yüklenemedi.');
      } finally {
        if (!cancelled) setApplicationsLoading(false);
      }
    }
    loadApplications();
    return () => {
      cancelled = true;
    };
  }, [highlightedJob, highlightedTab, user?.id]);

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
          <div
            className={`panel${highlightedJobId === Number(job.id || 0) ? ' notification-focus-card' : ''}`}
            key={job.id}
            ref={(node) => {
              if (node) cardRefs.current.set(Number(job.id || 0), node);
              else cardRefs.current.delete(Number(job.id || 0));
            }}
          >
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
              {highlightedJobId === Number(job.id || 0) && highlightedTab === 'applications' ? (
                <div className="panel notification-focus-inline-panel">
                  <div className="panel-body">
                    <strong>Başvuru görünümü</strong>
                    {Number(job.poster_id || 0) !== Number(user?.id || 0) ? (
                      <div className="muted">Bu ilanın başvuruları sadece ilan sahibi tarafından görüntülenebilir.</div>
                    ) : applicationsLoading ? (
                      <div className="muted">{t('loading')}</div>
                    ) : applicationsError ? (
                      <div className="muted">{applicationsError}</div>
                    ) : !(applicationsByJob[job.id] || []).length ? (
                      <div className="muted">Henüz başvuru yok.</div>
                    ) : (
                      <div className="stack">
                        {(applicationsByJob[job.id] || []).map((application) => (
                          <div className="request-payload-card" key={application.id}>
                            <div className="request-payload-row">
                              <span className="request-payload-key">Aday</span>
                              <span className="request-payload-value">@{application.kadi || '-'}</span>
                            </div>
                            <div className="request-payload-row">
                              <span className="request-payload-key">Tarih</span>
                              <span className="request-payload-value">{formatDateTime(application.created_at)}</span>
                            </div>
                            <div className="request-payload-row">
                              <span className="request-payload-key">Not</span>
                              <div className="request-payload-value" dangerouslySetInnerHTML={{ __html: application.cover_letter || '<span class="muted">Not bırakılmadı.</span>' }} />
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        ))}
      </div>
    </Layout>
  );
}
