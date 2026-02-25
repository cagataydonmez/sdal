import React, { useEffect, useState } from 'react';
import { useSearchParams, Link } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function ActivatePage() {
  const [params] = useSearchParams();
  const [message, setMessage] = useState('Aktivasyon yapılıyor...');
  const id = params.get('id');
  const akt = params.get('akt');

  useEffect(() => {
    if (!id || !akt) {
      setMessage('Aktivasyon kodu eksik.');
      return;
    }
    fetch(`/api/activate?id=${encodeURIComponent(id)}&akt=${encodeURIComponent(akt)}`)
      .then(async (res) => {
        if (!res.ok) {
          setMessage(await res.text());
          return;
        }
        const data = await res.json();
        setMessage(`Tebrikler ${data.kadi}! Aktivasyon başarıyla tamamlandı.`);
      })
      .catch(() => setMessage('Aktivasyon sırasında hata oluştu.'));
  }, [id, akt]);

  return (
    <LegacyLayout pageTitle="Aktivasyon Tamamlama" showLeftColumn={false}>
      <div style={{ padding: 12 }}>
        {message}
        <br /><br />
        <Link to="/">Anasayfaya dön</Link>
      </div>
    </LegacyLayout>
  );
}
