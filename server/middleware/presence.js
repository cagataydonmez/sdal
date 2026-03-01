export const ONLINE_HEARTBEAT_MS = 20 * 1000;

export function toLocalDateParts(now = new Date()) {
  const pad = (v) => String(v).padStart(2, '0');
  const y = now.getFullYear();
  const m = pad(now.getMonth() + 1);
  const d = pad(now.getDate());
  const hh = pad(now.getHours());
  const mm = pad(now.getMinutes());
  const ss = pad(now.getSeconds());
  return {
    date: `${y}-${m}-${d}`,
    time: `${hh}:${mm}:${ss}`
  };
}

export function presenceMiddleware({ sqlRun, onlineHeartbeatMs = ONLINE_HEARTBEAT_MS }) {
  return (req, _res, next) => {
    if (!req.session?.userId) return next();
    const nowMs = Date.now();
    const prev = Number(req.session._presenceUpdatedAt || 0);
    if (prev && nowMs - prev < onlineHeartbeatMs) return next();
    req.session._presenceUpdatedAt = nowMs;
    try {
      const now = new Date(nowMs);
      const localParts = toLocalDateParts(now);
      sqlRun('UPDATE uyeler SET sonislemtarih = ?, sonislemsaat = ?, sonip = ?, online = 1 WHERE id = ?', [
        localParts.date,
        localParts.time,
        req.ip,
        req.session.userId
      ]);
    } catch {
      // presence update is best effort
    }
    return next();
  };
}

