import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';

export default function ActivationPage() {
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState('Aktivasyon kontrol ediliyor...');
  const [error, setError] = useState('');

  useEffect(() => {
    const id = searchParams.get('id');
    const akt = searchParams.get('akt');
    if (!id || !akt) {
      setStatus('');
      setError('Aktivasyon kodu eksik.');
      return;
    }
    fetch(`/api/activate?id=${encodeURIComponent(id)}&akt=${encodeURIComponent(akt)}`)
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        return res.json();
      })
      .then((data) => {
        setStatus(`Aktivasyon tamamlandı. Hoş geldin ${data.kadi}.`);
      })
      .catch((err) => {
        setStatus('');
        setError(err.message || 'Aktivasyon başarısız.');
      });
  }, [searchParams]);

  return (
    <Layout title="Aktivasyon">
      <div className="panel">
        <div className="panel-body">
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
          <a className="btn ghost" href="/new/login">Giriş Yap</a>
        </div>
      </div>
    </Layout>
  );
}
