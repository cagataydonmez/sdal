import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { formatDateTime } from '../utils/date.js';

const BOARD_SIZE = 16;
const SNAKE_TICK_MS = 140;

const TETRIS_W = 10;
const TETRIS_H = 18;
const TETRIS_TICK_MS = 420;
const PIECES = [
  [[1, 1, 1, 1]],
  [[1, 1], [1, 1]],
  [[0, 1, 0], [1, 1, 1]],
  [[1, 0, 0], [1, 1, 1]],
  [[0, 0, 1], [1, 1, 1]],
  [[1, 1, 0], [0, 1, 1]],
  [[0, 1, 1], [1, 1, 0]]
];

const GAME_META = {
  snake: { title: 'Yilan (Klasik)', scoreLabel: 'Skor' },
  tetris: { title: 'Tetris (Klasik)', scoreLabel: 'Puan' },
  'tap-rush': { title: 'Tap Rush', scoreLabel: 'Skor' },
  'memory-pairs': { title: 'Memory Pairs', scoreLabel: 'Puan' },
  'puzzle-2048': { title: '2048', scoreLabel: 'Puan' }
};

function randomInt(max) {
  return Math.floor(Math.random() * max);
}

function rotate(mat) {
  const h = mat.length;
  const w = mat[0].length;
  const out = Array.from({ length: w }, () => Array(h).fill(0));
  for (let r = 0; r < h; r += 1) {
    for (let c = 0; c < w; c += 1) out[c][h - 1 - r] = mat[r][c];
  }
  return out;
}

function hasCollision(grid, piece, x, y) {
  for (let r = 0; r < piece.length; r += 1) {
    for (let c = 0; c < piece[r].length; c += 1) {
      if (!piece[r][c]) continue;
      const gx = x + c;
      const gy = y + r;
      if (gx < 0 || gx >= TETRIS_W || gy >= TETRIS_H) return true;
      if (gy >= 0 && grid[gy][gx]) return true;
    }
  }
  return false;
}

function mergePiece(grid, piece, x, y) {
  const next = grid.map((row) => [...row]);
  for (let r = 0; r < piece.length; r += 1) {
    for (let c = 0; c < piece[r].length; c += 1) {
      if (!piece[r][c]) continue;
      const gx = x + c;
      const gy = y + r;
      if (gy >= 0 && gy < TETRIS_H && gx >= 0 && gx < TETRIS_W) next[gy][gx] = 1;
    }
  }
  return next;
}

function clearLines(grid) {
  const kept = grid.filter((row) => row.some((cell) => !cell));
  const removed = TETRIS_H - kept.length;
  while (kept.length < TETRIS_H) kept.unshift(Array(TETRIS_W).fill(0));
  return { grid: kept, removed };
}

function useLeaderboard(gameKey, endpointType = 'classic') {
  const [rows, setRows] = useState([]);
  const endpoint = endpointType === 'classic'
    ? `/api/games/${gameKey}/leaderboard`
    : `/api/games/arcade/${gameKey}/leaderboard`;

  const load = useCallback(async () => {
    const res = await fetch(endpoint, { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setRows(payload.rows || []);
  }, [endpoint]);

  useEffect(() => { load(); }, [load]);

  return { rows, reload: load };
}

function Leaderboard({ title, rows, scoreLabel }) {
  return (
    <div className="panel game-leaderboard">
      <h3>{title} - Yüksek Skor</h3>
      <div className="panel-body">
        {rows.length === 0 ? <div className="muted">Henüz skor yok.</div> : null}
        {rows.map((r, idx) => (
          <div className="list-item game-score-row" key={`${r.isim}-${r.skor}-${idx}`}>
            <div><b>{idx + 1}. @{r.isim}</b></div>
            <div className="meta">{scoreLabel}: {r.skor ?? r.puan} · {formatDateTime(r.tarih)}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SnakeGame({ onScore }) {
  const [snake, setSnake] = useState([{ x: 7, y: 7 }]);
  const [dir, setDir] = useState({ x: 1, y: 0 });
  const [food, setFood] = useState({ x: 12, y: 10 });
  const [running, setRunning] = useState(false);
  const [score, setScore] = useState(0);

  useEffect(() => {
    if (!running) return undefined;
    const timer = setInterval(() => {
      setSnake((prev) => {
        const head = prev[0];
        const next = { x: head.x + dir.x, y: head.y + dir.y };
        if (
          next.x < 0 || next.x >= BOARD_SIZE || next.y < 0 || next.y >= BOARD_SIZE
          || prev.some((p) => p.x === next.x && p.y === next.y)
        ) {
          setRunning(false);
          onScore(score);
          return prev;
        }
        const grew = next.x === food.x && next.y === food.y;
        const arr = [next, ...prev];
        if (!grew) arr.pop();
        if (grew) {
          setScore((s) => s + 10);
          let nf = { x: randomInt(BOARD_SIZE), y: randomInt(BOARD_SIZE) };
          while (arr.some((p) => p.x === nf.x && p.y === nf.y)) nf = { x: randomInt(BOARD_SIZE), y: randomInt(BOARD_SIZE) };
          setFood(nf);
        }
        return arr;
      });
    }, SNAKE_TICK_MS);
    return () => clearInterval(timer);
  }, [running, dir, food, score, onScore]);

  useEffect(() => {
    function onKey(e) {
      const map = { ArrowUp: [0, -1], ArrowDown: [0, 1], ArrowLeft: [-1, 0], ArrowRight: [1, 0] };
      if (!map[e.key]) return;
      const [x, y] = map[e.key];
      setDir((d) => (d.x + x === 0 && d.y + y === 0 ? d : { x, y }));
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const cells = useMemo(() => {
    const set = new Set(snake.map((p) => `${p.x}:${p.y}`));
    return Array.from({ length: BOARD_SIZE * BOARD_SIZE }, (_, i) => {
      const x = i % BOARD_SIZE;
      const y = Math.floor(i / BOARD_SIZE);
      if (food.x === x && food.y === y) return 'food';
      if (set.has(`${x}:${y}`)) return 'snake';
      return '';
    });
  }, [snake, food]);

  return (
    <div className="panel game-panel">
      <h3>Yilan (Klasik)</h3>
      <div className="game-toolbar">
        <span className="chip">Skor: {score}</span>
        <button className="btn" onClick={() => setRunning((v) => !v)}>{running ? 'Duraklat' : 'Baslat'}</button>
        <button className="btn ghost" onClick={() => {
          setSnake([{ x: 7, y: 7 }]); setDir({ x: 1, y: 0 }); setFood({ x: 12, y: 10 }); setScore(0); setRunning(false);
        }}>Sifirla</button>
      </div>
      <div className="snake-grid" style={{ gridTemplateColumns: `repeat(${BOARD_SIZE}, 1fr)` }}>
        {cells.map((v, idx) => <div key={idx} className={`snake-cell ${v}`} />)}
      </div>
      <div className="mobile-controls">
        <button className="btn" onClick={() => setDir((d) => (d.y === 1 ? d : { x: 0, y: -1 }))}>Yukari</button>
        <div>
          <button className="btn" onClick={() => setDir((d) => (d.x === 1 ? d : { x: -1, y: 0 }))}>Sol</button>
          <button className="btn" onClick={() => setDir((d) => (d.x === -1 ? d : { x: 1, y: 0 }))}>Sag</button>
        </div>
        <button className="btn" onClick={() => setDir((d) => (d.y === -1 ? d : { x: 0, y: 1 }))}>Asagi</button>
      </div>
    </div>
  );
}

function TetrisGame({ onScore }) {
  const [grid, setGrid] = useState(() => Array.from({ length: TETRIS_H }, () => Array(TETRIS_W).fill(0)));
  const [piece, setPiece] = useState(PIECES[randomInt(PIECES.length)]);
  const [x, setX] = useState(3);
  const [y, setY] = useState(-1);
  const [running, setRunning] = useState(false);
  const [score, setScore] = useState(0);

  const spawn = useCallback((baseGrid) => {
    const np = PIECES[randomInt(PIECES.length)];
    const nx = Math.floor((TETRIS_W - np[0].length) / 2);
    const ny = -1;
    if (hasCollision(baseGrid, np, nx, ny)) {
      setRunning(false);
      onScore(score);
      return;
    }
    setPiece(np);
    setX(nx);
    setY(ny);
  }, [onScore, score]);

  const tick = useCallback(() => {
    if (hasCollision(grid, piece, x, y + 1)) {
      const merged = mergePiece(grid, piece, x, y);
      const cleared = clearLines(merged);
      if (cleared.removed > 0) setScore((s) => s + cleared.removed * 100);
      setGrid(cleared.grid);
      spawn(cleared.grid);
      return;
    }
    setY((v) => v + 1);
  }, [grid, piece, x, y, spawn]);

  useEffect(() => {
    if (!running) return undefined;
    const timer = setInterval(tick, TETRIS_TICK_MS);
    return () => clearInterval(timer);
  }, [running, tick]);

  function move(dx) {
    if (!hasCollision(grid, piece, x + dx, y)) setX((v) => v + dx);
  }

  function drop() {
    if (!hasCollision(grid, piece, x, y + 1)) setY((v) => v + 1);
    else tick();
  }

  function spin() {
    const rotated = rotate(piece);
    if (!hasCollision(grid, rotated, x, y)) setPiece(rotated);
  }

  useEffect(() => {
    function onKey(e) {
      if (e.key === 'ArrowLeft') move(-1);
      if (e.key === 'ArrowRight') move(1);
      if (e.key === 'ArrowDown') drop();
      if (e.key === 'ArrowUp') spin();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const cells = useMemo(() => {
    const temp = grid.map((r) => [...r]);
    for (let r = 0; r < piece.length; r += 1) {
      for (let c = 0; c < piece[r].length; c += 1) {
        if (!piece[r][c]) continue;
        const gx = x + c;
        const gy = y + r;
        if (gy >= 0 && gx >= 0 && gx < TETRIS_W && gy < TETRIS_H) temp[gy][gx] = 2;
      }
    }
    return temp.flat();
  }, [grid, piece, x, y]);

  return (
    <div className="panel game-panel">
      <h3>Tetris (Klasik)</h3>
      <div className="game-toolbar">
        <span className="chip">Puan: {score}</span>
        <button className="btn" onClick={() => setRunning((v) => !v)}>{running ? 'Duraklat' : 'Baslat'}</button>
        <button className="btn ghost" onClick={() => {
          setGrid(Array.from({ length: TETRIS_H }, () => Array(TETRIS_W).fill(0)));
          setPiece(PIECES[randomInt(PIECES.length)]);
          setX(3);
          setY(-1);
          setScore(0);
          setRunning(false);
        }}>Sifirla</button>
      </div>
      <div className="tetris-grid" style={{ gridTemplateColumns: `repeat(${TETRIS_W}, 1fr)` }}>
        {cells.map((v, i) => <div key={i} className={`tetris-cell ${v ? 'on' : ''} ${v === 2 ? 'active' : ''}`} />)}
      </div>
      <div className="mobile-controls">
        <button className="btn" onClick={spin}>Cevir</button>
        <div>
          <button className="btn" onClick={() => move(-1)}>Sol</button>
          <button className="btn" onClick={() => move(1)}>Sag</button>
        </div>
        <button className="btn" onClick={drop}>Asagi</button>
      </div>
    </div>
  );
}

function TapRush({ onScore }) {
  const [running, setRunning] = useState(false);
  const [time, setTime] = useState(20);
  const [score, setScore] = useState(0);
  const [dot, setDot] = useState({ x: 50, y: 50 });

  useEffect(() => {
    if (!running) return undefined;
    const timer = setInterval(() => {
      setTime((t) => {
        if (t <= 1) {
          setRunning(false);
          onScore(score);
          return 0;
        }
        return t - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [running, score, onScore]);

  function hit() {
    if (!running) return;
    setScore((s) => s + 1);
    setDot({ x: 8 + randomInt(84), y: 8 + randomInt(84) });
  }

  function start() {
    setScore(0);
    setTime(20);
    setDot({ x: 8 + randomInt(84), y: 8 + randomInt(84) });
    setRunning(true);
  }

  return (
    <div className="panel game-panel">
      <h3>Tap Rush</h3>
      <div className="game-toolbar">
        <span className="chip">Skor: {score}</span>
        <span className="chip">Sure: {time}s</span>
        <button className="btn" onClick={start}>{running ? 'Yeniden Baslat' : 'Baslat'}</button>
      </div>
      <div className="tap-area">
        <button className="tap-dot" style={{ left: `${dot.x}%`, top: `${dot.y}%` }} onClick={hit} disabled={!running} />
      </div>
    </div>
  );
}

function MemoryPairs({ onScore }) {
  const [cards, setCards] = useState([]);
  const [open, setOpen] = useState([]);
  const [matched, setMatched] = useState(new Set());
  const [moves, setMoves] = useState(0);
  const [finished, setFinished] = useState(false);

  function reset() {
    const vals = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    const deck = [...vals, ...vals].sort(() => Math.random() - 0.5).map((v, i) => ({ id: i, value: v }));
    setCards(deck);
    setOpen([]);
    setMatched(new Set());
    setMoves(0);
    setFinished(false);
  }

  useEffect(() => { reset(); }, []);

  useEffect(() => {
    if (open.length !== 2) return;
    const [a, b] = open;
    setMoves((m) => m + 1);
    if (cards[a]?.value === cards[b]?.value) {
      setMatched((prev) => {
        const next = new Set(prev);
        next.add(a);
        next.add(b);
        if (next.size === 16) {
          setFinished(true);
          const sc = Math.max(100, 1200 - (moves + 1) * 20);
          onScore(sc);
        }
        return next;
      });
      setOpen([]);
      return;
    }
    const timer = setTimeout(() => setOpen([]), 550);
    return () => clearTimeout(timer);
  }, [open, cards, moves, onScore]);

  function flip(idx) {
    if (finished || open.includes(idx) || matched.has(idx) || open.length === 2) return;
    setOpen((prev) => [...prev, idx]);
  }

  const points = Math.max(100, 1200 - moves * 20);

  return (
    <div className="panel game-panel">
      <h3>Memory Pairs</h3>
      <div className="game-toolbar">
        <span className="chip">Hamle: {moves}</span>
        <span className="chip">Puan: {points}</span>
        <button className="btn" onClick={reset}>Yenile</button>
      </div>
      <div className="memory-grid">
        {cards.map((c, idx) => {
          const visible = open.includes(idx) || matched.has(idx);
          return (
            <button key={c.id} className={`memory-card ${visible ? 'open' : ''}`} onClick={() => flip(idx)}>
              {visible ? c.value : '?'}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function slideLine(line) {
  const compact = line.filter((n) => n !== 0);
  const out = [];
  let score = 0;
  for (let i = 0; i < compact.length; i += 1) {
    if (compact[i] && compact[i] === compact[i + 1]) {
      const merged = compact[i] * 2;
      out.push(merged);
      score += merged;
      i += 1;
    } else {
      out.push(compact[i]);
    }
  }
  while (out.length < 4) out.push(0);
  return { line: out, score };
}

function Puzzle2048({ onScore }) {
  const [grid, setGrid] = useState(() => Array.from({ length: 4 }, () => Array(4).fill(0)));
  const [score, setScore] = useState(0);

  function spawn(board) {
    const empties = [];
    for (let r = 0; r < 4; r += 1) for (let c = 0; c < 4; c += 1) if (!board[r][c]) empties.push([r, c]);
    if (!empties.length) return board;
    const [r, c] = empties[randomInt(empties.length)];
    const next = board.map((row) => [...row]);
    next[r][c] = Math.random() < 0.9 ? 2 : 4;
    return next;
  }

  function reset() {
    const empty = Array.from({ length: 4 }, () => Array(4).fill(0));
    setGrid(spawn(spawn(empty)));
    setScore(0);
  }

  useEffect(() => { reset(); }, []);

  const applyMove = useCallback((dir) => {
    setGrid((prev) => {
      let moved = false;
      let gained = 0;
      let next = prev.map((row) => [...row]);

      function setRow(r, row) {
        for (let c = 0; c < 4; c += 1) {
          if (next[r][c] !== row[c]) moved = true;
          next[r][c] = row[c];
        }
      }

      function setCol(c, col) {
        for (let r = 0; r < 4; r += 1) {
          if (next[r][c] !== col[r]) moved = true;
          next[r][c] = col[r];
        }
      }

      if (dir === 'left' || dir === 'right') {
        for (let r = 0; r < 4; r += 1) {
          const base = dir === 'left' ? next[r] : [...next[r]].reverse();
          const slid = slideLine(base);
          gained += slid.score;
          setRow(r, dir === 'left' ? slid.line : [...slid.line].reverse());
        }
      } else {
        for (let c = 0; c < 4; c += 1) {
          const col = [next[0][c], next[1][c], next[2][c], next[3][c]];
          const base = dir === 'up' ? col : [...col].reverse();
          const slid = slideLine(base);
          gained += slid.score;
          setCol(c, dir === 'up' ? slid.line : [...slid.line].reverse());
        }
      }

      if (!moved) return prev;
      if (gained) setScore((s) => s + gained);
      const spawned = spawn(next);
      const maxTile = Math.max(...spawned.flat());
      if (maxTile >= 2048) onScore(score + gained + maxTile);
      return spawned;
    });
  }, [onScore, score]);

  useEffect(() => {
    function onKey(e) {
      const map = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' };
      if (map[e.key]) applyMove(map[e.key]);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [applyMove]);

  return (
    <div className="panel game-panel">
      <h3>2048</h3>
      <div className="game-toolbar">
        <span className="chip">Puan: {score}</span>
        <button className="btn" onClick={reset}>Yenile</button>
      </div>
      <div className="g2048-grid">
        {grid.flat().map((n, i) => <div className={`g2048-cell v${n}`} key={i}>{n || ''}</div>)}
      </div>
      <div className="mobile-controls">
        <button className="btn" onClick={() => applyMove('up')}>Yukari</button>
        <div>
          <button className="btn" onClick={() => applyMove('left')}>Sol</button>
          <button className="btn" onClick={() => applyMove('right')}>Sag</button>
        </div>
        <button className="btn" onClick={() => applyMove('down')}>Asagi</button>
      </div>
    </div>
  );
}

export default function GamesPage() {
  const [status, setStatus] = useState('');
  const snakeBoard = useLeaderboard('snake', 'classic');
  const tetrisBoard = useLeaderboard('tetris', 'classic');
  const tapBoard = useLeaderboard('tap-rush', 'arcade');
  const memoryBoard = useLeaderboard('memory-pairs', 'arcade');
  const g2048Board = useLeaderboard('puzzle-2048', 'arcade');

  const saveScore = useCallback(async (game, score, type = 'arcade') => {
    if (!score || score < 1) return;
    const endpoint = type === 'classic' ? `/api/games/${game}/score` : `/api/games/arcade/${game}/score`;
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ score })
    });
    if (!res.ok) return;
    setStatus(`${GAME_META[game].title} skoru kaydedildi: ${score}`);
    if (game === 'snake') snakeBoard.reload();
    if (game === 'tetris') tetrisBoard.reload();
    if (game === 'tap-rush') tapBoard.reload();
    if (game === 'memory-pairs') memoryBoard.reload();
    if (game === 'puzzle-2048') g2048Board.reload();
  }, [snakeBoard, tetrisBoard, tapBoard, memoryBoard, g2048Board]);

  return (
    <Layout title="Oyunlar">
      {status ? <div className="ok">{status}</div> : null}
      <div className="games-layout">
        <SnakeGame onScore={(s) => saveScore('snake', s, 'classic')} />
        <Leaderboard title={GAME_META.snake.title} rows={snakeBoard.rows} scoreLabel={GAME_META.snake.scoreLabel} />

        <TetrisGame onScore={(s) => saveScore('tetris', s, 'classic')} />
        <Leaderboard title={GAME_META.tetris.title} rows={tetrisBoard.rows} scoreLabel={GAME_META.tetris.scoreLabel} />

        <TapRush onScore={(s) => saveScore('tap-rush', s)} />
        <Leaderboard title={GAME_META['tap-rush'].title} rows={tapBoard.rows} scoreLabel={GAME_META['tap-rush'].scoreLabel} />

        <MemoryPairs onScore={(s) => saveScore('memory-pairs', s)} />
        <Leaderboard title={GAME_META['memory-pairs'].title} rows={memoryBoard.rows} scoreLabel={GAME_META['memory-pairs'].scoreLabel} />

        <Puzzle2048 onScore={(s) => saveScore('puzzle-2048', s)} />
        <Leaderboard title={GAME_META['puzzle-2048'].title} rows={g2048Board.rows} scoreLabel={GAME_META['puzzle-2048'].scoreLabel} />
      </div>
    </Layout>
  );
}
