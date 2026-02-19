import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function ActivationPage() {
  const { t } = useI18n();
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState(t('activation_checking'));
  const [error, setError] = useState('');

  useEffect(() => {
    const id = searchParams.get('id');
    const akt = searchParams.get('akt');
    if (!id || !akt) {
      setStatus('');
      setError(t('activation_error_missing_code'));
      return;
    }
    fetch(`/api/activate?id=${encodeURIComponent(id)}&akt=${encodeURIComponent(akt)}`)
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        return res.json();
      })
      .then((data) => {
        setStatus(t('activation_status_success', { username: data.kadi }));
      })
      .catch((err) => {
        setStatus('');
        setError(err.message || t('activation_error_failed'));
      });
  }, [searchParams]);

  return (
    <Layout title={t('activation_title')}>
      <div className="panel">
        <div className="panel-body">
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
          <a className="btn ghost" href="/new/login">{t('login_submit')}</a>
        </div>
      </div>
    </Layout>
  );
}
