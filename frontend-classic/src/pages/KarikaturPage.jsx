import React from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

const MAX_ID = 607;

export default function KarikaturPage() {
  const [params, setParams] = useSearchParams();
  const id = Math.max(1, Math.min(parseInt(params.get('id') || '1', 10), MAX_ID));

  function go(nextId) {
    setParams({ id: String(nextId) });
  }

  return (
    <LegacyLayout pageTitle="Yücel Özgür Karikatürleri">
      <b>Yücel Özgür Karikatürleri</b>
      <hr color="#660000" size="1" />
      <div>
        <button className="sub" onClick={() => go(Math.min(id + 1, MAX_ID))}>Sonraki</button>
        <button className="sub" onClick={() => go(Math.max(id - 1, 1))}>Önceki</button>
      </div>
      <div style={{ marginTop: 10 }}>
        <img src={`/legacy/karikatur1/${id}.jpg`} border="1" alt={`Karikatür ${id}`} onError={(e) => { e.currentTarget.style.display = 'none'; }} />
        <div>Karikatür #{id}</div>
      </div>
      <hr color="#660000" size="1" />
      <div>
        Karikatür arşivi için ID girin:
        <input
          type="number"
          min="1"
          max={MAX_ID}
          value={id}
          onChange={(e) => go(Math.max(1, Math.min(parseInt(e.target.value || '1', 10), MAX_ID)))}
          className="inptxt"
          style={{ width: 80, marginLeft: 8 }}
        />
      </div>
    </LegacyLayout>
  );
}
