import React, { useCallback, useEffect, useState } from 'react';
import { adminClient } from '../../../admin/api/adminClient.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';

function StatusChip({ active }) {
  return (
    <span className="chip" style={{ background: active ? 'var(--color-success, #22c55e)' : 'var(--color-danger, #ef4444)', color: '#fff' }}>
      {active ? 'Aktif' : 'Pasif'}
    </span>
  );
}

export default function SecuritySection() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const result = await adminClient.get('/api/new/admin/security/status');
      setData(result);
    } catch (err) {
      setError(err.message || 'Güvenlik durumu yüklenemedi.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const helmet = data?.helmet || {};
  const validation = data?.validation || {};
  const schemas = Array.isArray(validation.schemas) ? validation.schemas : [];
  const rejections = Array.isArray(validation.rejections) ? validation.rejections : [];
  const headers = Array.isArray(helmet.headers) ? helmet.headers : [];

  const rejectionColumns = [
    { key: 'at', label: 'Zaman', render: (row) => row.at ? new Date(row.at).toLocaleString('tr-TR') : '-' },
    { key: 'method', label: 'Method' },
    { key: 'url', label: 'URL' },
    { key: 'messages', label: 'Hata', render: (row) => Array.isArray(row.messages) ? row.messages.join(', ') : '-' },
  ];

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Güvenlik ve Doğrulama</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>Yenile</button>
      </div>

      {error ? <div className="muted">{error}</div> : null}

      {/* Helmet Security Headers */}
      <div className="panel">
        <div className="panel-body stack">
          <div className="ops-head-row">
            <h3>HTTP Güvenlik Başlıkları (Helmet)</h3>
            <StatusChip active={helmet.active} />
          </div>
          {helmet.cspDisabled ? (
            <div className="muted">Content-Security-Policy: devre dışı (uygulama ihtiyacına göre etkinleştirilebilir)</div>
          ) : null}
          <div className="list">
            {headers.map((h) => (
              <div key={h.name} className="list-item">
                <div className="name">{h.name}</div>
                <StatusChip active={h.active} />
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Zod Schema Coverage */}
      <div className="panel">
        <div className="panel-body stack">
          <h3>Zod Şema Kapsamı</h3>
          <div className="list">
            {schemas.map((s) => (
              <div key={s.route} className="list-item">
                <div>
                  <div className="name">{s.route}</div>
                  <div className="meta">{s.schema} · Alan: {(s.fields || []).join(', ')}</div>
                </div>
                <StatusChip active />
              </div>
            ))}
            {!schemas.length ? <div className="muted">Şema bulunamadı.</div> : null}
          </div>
        </div>
      </div>

      {/* Validation Rejections Log */}
      <div className="panel">
        <div className="panel-body stack">
          <div className="ops-head-row">
            <h3>Son Doğrulama Hataları</h3>
            <span className="chip">{validation.totalRejections || 0} kayıt</span>
          </div>
          <AdminDataTable
            columns={rejectionColumns}
            rows={rejections}
            loading={loading}
            emptyText="Henüz doğrulama hatası kaydedilmedi."
          />
        </div>
      </div>
    </section>
  );
}
