import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

const AuthContext = createContext(null);

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    apiJson('/api/session')
      .then((data) => {
        if (alive) setUser(data?.user || null);
      })
      .catch(() => {
        if (alive) setUser(null);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, []);

  const value = useMemo(() => ({
    user,
    loading,
    async login(payload) {
      const data = await apiJson('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify(payload)
      });
      setUser(data.user);
      return data;
    },
    async logout() {
      await apiJson('/api/auth/logout', { method: 'POST' });
      setUser(null);
    },
    async refresh() {
      const data = await apiJson('/api/session');
      setUser(data?.user || null);
    }
  }), [user, loading]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
