import { useCallback, useMemo, useState } from 'react';

export default function useAdminQueryState(initialState) {
  const [query, setQuery] = useState(initialState);

  const patchQuery = useCallback((patch) => {
    setQuery((prev) => ({ ...prev, ...(patch || {}) }));
  }, []);

  const resetQuery = useCallback(() => {
    setQuery(initialState);
  }, [initialState]);

  const setPage = useCallback((page) => {
    setQuery((prev) => ({ ...prev, page: Math.max(Number(page) || 1, 1) }));
  }, []);

  const setSearch = useCallback((q) => {
    setQuery((prev) => ({ ...prev, q, page: 1 }));
  }, []);

  return useMemo(() => ({
    query,
    setQuery,
    patchQuery,
    resetQuery,
    setPage,
    setSearch
  }), [query, patchQuery, resetQuery, setPage, setSearch]);
}
