import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';
import SnakeGame from '../components/games/SnakeGame.jsx';
import { tarihduz } from '../utils/date.js';

export default function GameSnakePage() {
  const [scores, setScores] = useState([]);

  useEffect(() => {
    fetch('/api/games/snake/leaderboard')
      .then((r) => r.json())
      .then((p) => setScores(p.rows || []))
      .catch(() => {});
  }, []);

  return (
    <LegacyLayout pageTitle="Yılan Oyunu">
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffcc' }}>
              <b>Yılan</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }}>
              <SnakeGame />
              <hr className="sdal-hr" />
              <b>En Yüksek Puanlar</b>
              <div>
                {scores.map((s, idx) => (
                  <div key={`${s.isim}-${idx}`}>
                    <b>{idx + 1}. </b>{s.isim} - {s.skor} ({tarihduz(s.tarih)})
                  </div>
                ))}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
