import React, { useMemo, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { Link, useLocation } from '../router.jsx';
import { MODULE_CONTROL_ITEMS } from '../utils/moduleNavigation.js';

const MODULE_LABELS = Object.fromEntries(MODULE_CONTROL_ITEMS.map((item) => [item.key, item.defaultLabel]));

export default function ModuleInactivePage({ moduleKey = '', message = '' }) {
  const location = useLocation();
  const [note, setNote] = useState('');
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const moduleLabel = useMemo(() => MODULE_LABELS[moduleKey] || 'Bu modül', [moduleKey]);

  async function submitReopenRequest() {
    setSubmitting(true);
    setStatus('');
    setError('');
    try {
      const payload = {
        note: note.trim(),
        moduleKey,
        moduleLabel,
        requestedPath: location.pathname
      };
      const response = await fetch('/api/module-access-requests', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          payload
        })
      });
      if (!response.ok) throw new Error(await response.text());
      setStatus('Talebiniz yönetime iletildi.');
      setNote('');
    } catch (err) {
      setError(err.message || 'Talebiniz iletilemedi.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Layout title={`${moduleLabel} şu anda pasif`}>
      <section className="panel">
        <div className="panel-body">
          <h3>{moduleLabel} şu anda pasif</h3>
          <p className="muted">
            {message || 'Bu modül yönetim tarafından geçici olarak kapatıldığı için şu anda erişime açık değil.'}
          </p>
          <p className="muted">
            Modül tekrar açıldığında menüde yeniden görünür ve ilgili ekranlara erişebilirsiniz.
          </p>
          <div className="ops-inline-actions">
            <Link className="btn ghost" to="/new">Ana sayfaya dön</Link>
            <Link className="btn ghost" to="/new/requests">Taleplerim</Link>
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panel-body">
          <h3>Yönetime yeniden açma talebi gönder</h3>
          <p className="muted">
            İsterseniz bu modülün tekrar erişime açılması için kısa bir not iletebilirsiniz.
          </p>
          <textarea
            className="input"
            rows={4}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Bu modüle neden ihtiyaç duyduğunuzu yazabilirsiniz."
          />
          <div className="ops-inline-actions">
            <button className="btn primary" disabled={submitting} onClick={submitReopenRequest} type="button">
              {submitting ? 'Gönderiliyor...' : 'Talep gönder'}
            </button>
          </div>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </section>
    </Layout>
  );
}
