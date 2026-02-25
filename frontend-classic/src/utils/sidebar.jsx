import { useEffect, useState } from 'react';

export function useSidebar() {
  const [data, setData] = useState({
    onlineUsers: [],
    newMembers: [],
    newPhotos: [],
    topSnake: [],
    topTetris: [],
    newMessagesCount: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    fetch('/api/sidebar', { credentials: 'include' })
      .then((res) => (res.ok ? res.json() : null))
      .then((payload) => {
        if (!alive || !payload) return;
        setData(payload);
      })
      .catch(() => {
        if (alive) setData((prev) => ({ ...prev }));
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, []);

  return { data, loading };
}
