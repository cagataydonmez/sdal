import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';
import TetrisGame from '../components/games/TetrisGame.jsx';
import { tarihduz } from '../utils/date.js';

export default function GameTetrisPage() {
  const [scores, setScores] = useState([]);

  useEffect(() => {
    fetch('/api/games/tetris/leaderboard')
      .then((r) => r.json())
      .then((p) => setScores(p.rows || []))
      .catch(() => {});
  }, []);

  return (
    <LegacyLayout pageTitle="Tetris Oyunu">
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffcc' }}>
              <b>Tetris</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }}>
              <TetrisGame />
              <hr className="sdal-hr" />
              <b>En Yüksek Puanlar</b>
              <div>
                {scores.map((s, idx) => (
                  <div key={`${s.isim}-${idx}`}>
                    <b>{idx + 1}. </b>{s.isim} - {s.puan} ({tarihduz(s.tarih)})
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
