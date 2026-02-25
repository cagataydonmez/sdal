import React, { useEffect, useRef, useState } from 'react';

const COLS = 10;
const ROWS = 20;
const BLOCK = 14;

const SHAPES = [
  { color: '#663300', matrix: [[1, 1, 1, 1]] },
  { color: '#660000', matrix: [[1, 1], [1, 1]] },
  { color: '#003366', matrix: [[0, 1, 0], [1, 1, 1]] },
  { color: '#336600', matrix: [[1, 0, 0], [1, 1, 1]] },
  { color: '#663300', matrix: [[0, 0, 1], [1, 1, 1]] },
  { color: '#990000', matrix: [[1, 1, 0], [0, 1, 1]] },
  { color: '#003300', matrix: [[0, 1, 1], [1, 1, 0]] }
];

function emptyBoard() {
  return Array.from({ length: ROWS }, () => Array(COLS).fill(null));
}

function rotate(matrix) {
  return matrix[0].map((_, i) => matrix.map((row) => row[i]).reverse());
}

function randomPiece() {
  const shape = SHAPES[Math.floor(Math.random() * SHAPES.length)];
  return { ...shape, x: Math.floor((COLS - shape.matrix[0].length) / 2), y: 0 };
}

function collides(board, piece, dx = 0, dy = 0, rotated = null) {
  const matrix = rotated || piece.matrix;
  for (let y = 0; y < matrix.length; y++) {
    for (let x = 0; x < matrix[y].length; x++) {
      if (!matrix[y][x]) continue;
      const nx = piece.x + x + dx;
      const ny = piece.y + y + dy;
      if (nx < 0 || nx >= COLS || ny >= ROWS) return true;
      if (ny >= 0 && board[ny][nx]) return true;
    }
  }
  return false;
}

export default function TetrisGame() {
  const [board, setBoard] = useState(emptyBoard());
  const [piece, setPiece] = useState(randomPiece());
  const [score, setScore] = useState(0);
  const [running, setRunning] = useState(false);
  const intervalRef = useRef(null);

  useEffect(() => {
    function onKey(e) {
      if (!running) return;
      if (e.key === 'ArrowLeft' && !collides(board, piece, -1, 0)) {
        setPiece((p) => ({ ...p, x: p.x - 1 }));
      }
      if (e.key === 'ArrowRight' && !collides(board, piece, 1, 0)) {
        setPiece((p) => ({ ...p, x: p.x + 1 }));
      }
      if (e.key === 'ArrowDown' && !collides(board, piece, 0, 1)) {
        setPiece((p) => ({ ...p, y: p.y + 1 }));
      }
      if (e.key === 'ArrowUp') {
        const rotated = rotate(piece.matrix);
        if (!collides(board, piece, 0, 0, rotated)) {
          setPiece((p) => ({ ...p, matrix: rotated }));
        }
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [board, piece, running]);

  useEffect(() => {
    if (!running) return;
    intervalRef.current = setInterval(() => {
      drop();
    }, 400);
    return () => clearInterval(intervalRef.current);
  });

  function mergePiece(b, p) {
    const next = b.map((row) => row.slice());
    p.matrix.forEach((row, y) => {
      row.forEach((value, x) => {
        if (value) {
          const nx = p.x + x;
          const ny = p.y + y;
          if (ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS) {
            next[ny][nx] = p.color;
          }
        }
      });
    });
    return next;
  }

  function clearLines(b) {
    let cleared = 0;
    const next = b.filter((row) => row.some((cell) => !cell));
    cleared = ROWS - next.length;
    while (next.length < ROWS) next.unshift(Array(COLS).fill(null));
    if (cleared > 0) setScore((s) => s + cleared * 100);
    return next;
  }

  function drop() {
    if (collides(board, piece, 0, 1)) {
      const merged = mergePiece(board, piece);
      const cleaned = clearLines(merged);
      const nextPiece = randomPiece();
      if (collides(cleaned, nextPiece, 0, 0)) {
        setRunning(false);
        submitScore(score);
        return;
      }
      setBoard(cleaned);
      setPiece(nextPiece);
    } else {
      setPiece((p) => ({ ...p, y: p.y + 1 }));
    }
  }

  function reset() {
    setBoard(emptyBoard());
    setPiece(randomPiece());
    setScore(0);
    setRunning(true);
  }

  async function submitScore(finalScore) {
    if (!finalScore) return;
    await fetch('/api/games/tetris/score', {
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
        <svg width={COLS * BLOCK} height={ROWS * BLOCK}>
          <rect width={COLS * BLOCK} height={ROWS * BLOCK} fill="#fff" />
          {board.map((row, y) => row.map((cell, x) => cell ? (
            <rect key={`${x}-${y}`} x={x * BLOCK} y={y * BLOCK} width={BLOCK} height={BLOCK} fill={cell} />
          ) : null))}
          {piece.matrix.map((row, y) => row.map((cell, x) => cell ? (
            <rect key={`p-${x}-${y}`} x={(piece.x + x) * BLOCK} y={(piece.y + y) * BLOCK} width={BLOCK} height={BLOCK} fill={piece.color} />
          ) : null))}
        </svg>
      </div>
    </div>
  );
}
