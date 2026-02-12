import React, { useEffect, useRef, useState } from 'react';

const GRID = 20;
const SIZE = 12;

function randomFood(snake) {
  while (true) {
    const x = Math.floor(Math.random() * GRID);
    const y = Math.floor(Math.random() * GRID);
    if (!snake.some((s) => s.x === x && s.y === y)) return { x, y };
  }
}

export default function SnakeGame() {
  const [snake, setSnake] = useState([{ x: 9, y: 9 }]);
  const [dir, setDir] = useState({ x: 1, y: 0 });
  const [food, setFood] = useState({ x: 5, y: 5 });
  const [score, setScore] = useState(0);
  const [running, setRunning] = useState(false);
  const intervalRef = useRef(null);

  useEffect(() => {
    function onKey(e) {
      if (e.key === 'ArrowUp' && dir.y !== 1) setDir({ x: 0, y: -1 });
      if (e.key === 'ArrowDown' && dir.y !== -1) setDir({ x: 0, y: 1 });
      if (e.key === 'ArrowLeft' && dir.x !== 1) setDir({ x: -1, y: 0 });
      if (e.key === 'ArrowRight' && dir.x !== -1) setDir({ x: 1, y: 0 });
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [dir]);

  useEffect(() => {
    if (!running) return;
    intervalRef.current = setInterval(() => {
      setSnake((prev) => {
        const head = { x: (prev[0].x + dir.x + GRID) % GRID, y: (prev[0].y + dir.y + GRID) % GRID };
        if (prev.some((p) => p.x === head.x && p.y === head.y)) {
          setRunning(false);
          submitScore(score);
          return prev;
        }
        const next = [head, ...prev];
        if (head.x === food.x && head.y === food.y) {
          setScore((s) => s + 10);
          setFood(randomFood(next));
          return next;
        }
        next.pop();
        return next;
      });
    }, 120);
    return () => clearInterval(intervalRef.current);
  }, [running, dir, food, score]);

  function reset() {
    setSnake([{ x: 9, y: 9 }]);
    setDir({ x: 1, y: 0 });
    setFood({ x: 5, y: 5 });
    setScore(0);
    setRunning(true);
  }

  async function submitScore(finalScore) {
    if (!finalScore) return;
    await fetch('/api/games/snake/score', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ score: finalScore })
    });
  }

  return (
    <div>
      <div style={{ marginBottom: 6 }}>
        <b>Skor:</b> {score}
        {' '}<button className="sub" onClick={() => (running ? setRunning(false) : setRunning(true))}>{running ? 'Duraklat' : 'Başlat'}</button>
        {' '}<button className="sub" onClick={reset}>Yeni Oyun</button>
      </div>
      <div style={{ background: '#fff', display: 'inline-block', border: '1px solid #663300' }}>
        <svg width={GRID * SIZE} height={GRID * SIZE}>
          <rect width={GRID * SIZE} height={GRID * SIZE} fill="#fff" />
          <rect x={food.x * SIZE} y={food.y * SIZE} width={SIZE} height={SIZE} fill="#660000" />
          {snake.map((s, i) => (
            <rect key={`${s.x}-${s.y}-${i}`} x={s.x * SIZE} y={s.y * SIZE} width={SIZE} height={SIZE} fill="#663300" />
          ))}
        </svg>
      </div>
    </div>
  );
}
