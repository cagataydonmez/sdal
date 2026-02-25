import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function QuickAccessRemovePage() {
  const { id } = useParams();
  const [params] = useSearchParams();
  const targetId = id || params.get('uid') || '';
  const navigate = useNavigate();
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    fetch('/api/quick-access/remove', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ id: targetId })
    })
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        if (alive) navigate('/herisim?hlc=e', { replace: true });
      })
      .catch((err) => {
        if (alive) setError(err.message || 'Hata oluştu.');
      });
    return () => { alive = false; };
  }, [id, targetId, navigate]);

  return (
    <LegacyLayout pageTitle="Hızlı Erişim Listesinden Çıkart">
      {error ? <div className="hatamsg1">{error}</div> : <div>İşlem yapılıyor...</div>}
    </LegacyLayout>
  );
}
