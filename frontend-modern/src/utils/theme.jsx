import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

const ThemeContext = createContext({
  mode: 'auto',
  theme: 'light',
  cycleMode: () => {}
});

const THEME_MODE_KEY = 'sdal_new_theme_mode';

function resolveAutoTheme(now = new Date()) {
  const hour = now.getHours();
  return hour >= 19 || hour < 7 ? 'dark' : 'light';
}

function readStoredMode() {
  if (typeof window === 'undefined') return 'auto';
  const value = String(window.localStorage.getItem(THEME_MODE_KEY) || '').toLowerCase();
  if (value === 'dark' || value === 'light' || value === 'auto') return value;
  return 'auto';
}

export function ThemeProvider({ children }) {
  const [mode, setMode] = useState(() => readStoredMode());
  const [tick, setTick] = useState(() => Date.now());

  const theme = useMemo(
    () => (mode === 'auto' ? resolveAutoTheme(new Date(tick)) : mode),
    [mode, tick]
  );

  useEffect(() => {
    if (mode !== 'auto') return undefined;
    const id = setInterval(() => setTick(Date.now()), 60 * 1000);
    return () => clearInterval(id);
  }, [mode]);

  useEffect(() => {
    if (typeof document === 'undefined') return;
    const root = document.documentElement;
    root.setAttribute('data-theme', theme);
    root.style.colorScheme = theme;
  }, [theme]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(THEME_MODE_KEY, mode);
  }, [mode]);

  function cycleMode() {
    setMode((current) => {
      if (current === 'auto') return 'dark';
      if (current === 'dark') return 'light';
      return 'auto';
    });
  }

  const value = useMemo(() => ({ mode, theme, cycleMode }), [mode, theme]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  return useContext(ThemeContext);
}
