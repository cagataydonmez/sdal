import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';

export function useMenu() {
  const [menu, setMenu] = useState([]);
  const location = useLocation();

  useEffect(() => {
    let alive = true;
    fetch('/api/menu', { credentials: 'include' })
      .then((res) => (res.ok ? res.json() : { items: [] }))
      .then((data) => {
        if (!alive) return;
        const items = (data.items || []).map((item) => ({
          ...item,
          active: location.pathname === item.url
        }));
        const hasStories = items.some((item) => item.url === '/hikayeler');
        if (!hasStories) {
          items.push({
            label: 'Hikayeler',
            url: '/hikayeler',
            active: location.pathname === '/hikayeler' || location.pathname === '/stories'
          });
        }
        setMenu(items);
      })
      .catch(() => {
        if (alive) setMenu([]);
      });
    return () => {
      alive = false;
    };
  }, [location.pathname]);

  return { menu };
}
