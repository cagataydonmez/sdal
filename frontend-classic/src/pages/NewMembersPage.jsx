import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function NewMembersPage() {
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    fetch('/api/members/latest?limit=100', { credentials: 'include' })
      .then((res) => res.json())
      .then((data) => {
        if (!alive) return;
        setItems(data.items || []);
      })
      .catch(() => {
        if (alive) setError('Veri alınamadı.');
      });
    return () => { alive = false; };
  }, []);

  return (
    <LegacyLayout pageTitle="En Yeni Üyeler">
      <hr color="#662233" size="1" />
      <table border="0" cellPadding="2" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td style={{ background: '#660000', color: 'white' }}>
              <b>En Yeni 100 Üyemiz</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }}>
              {error ? <div className="hatamsg1">{error}</div> : null}
              <table border="0" cellPadding="2" cellSpacing="0" width="100%">
                <tbody>
                  {items.map((u, idx) => (
                    <tr key={u.id}>
                      <td width="30"><b>{idx + 1}</b></td>
                      <td width="60">
                        <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(u.resim || 'nophoto.jpg')}`} border="1" alt="" />
                      </td>
                      <td>
                        <a href={`/uyeler/${u.id}`}>{u.kadi} - {u.isim} {u.soyisim}</a>
                        {' '}({u.mezuniyetyili})
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
