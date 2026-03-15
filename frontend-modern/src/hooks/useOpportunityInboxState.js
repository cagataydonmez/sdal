import { startTransition, useCallback, useEffect, useRef, useState } from 'react';
import { readApiPayload } from '../utils/api.js';
import { getCached, setCache } from '../utils/swrCache.js';

function initialState() {
  return {
    loading: true,
    loadingMore: false,
    error: '',
    items: [],
    summary: { all: 0, now: 0, networking: 0, jobs: 0, updates: 0 },
    hasMore: false,
    nextCursor: '',
    tab: 'all'
  };
}

function cacheKey(tab) {
  return `opportunities:${tab || 'all'}`;
}

export function useOpportunityInboxState(tab = 'all') {
  const [state, setState] = useState(() => {
    const cached = getCached(cacheKey(tab));
    if (cached) {
      return {
        ...initialState(),
        loading: cached.stale,
        items: cached.data.items || [],
        summary: cached.data.summary || initialState().summary,
        hasMore: Boolean(cached.data.hasMore),
        nextCursor: String(cached.data.next_cursor || ''),
        tab: String(cached.data.tab || tab || 'all')
      };
    }
    return initialState();
  });
  const requestIdRef = useRef(0);

  const load = useCallback(async ({ append = false, cursor = '' } = {}) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!append) {
      const cached = getCached(cacheKey(tab));
      if (cached) {
        startTransition(() => {
          setState((prev) => ({
            ...prev,
            loading: cached.stale,
            error: '',
            items: cached.data.items || [],
            summary: cached.data.summary || prev.summary,
            hasMore: Boolean(cached.data.hasMore),
            nextCursor: String(cached.data.next_cursor || ''),
            tab: String(cached.data.tab || tab || 'all')
          }));
        });
        if (!cached.stale) return;
      } else {
        setState((prev) => ({
          ...prev,
          loading: true,
          error: ''
        }));
      }
    } else {
      setState((prev) => ({
        ...prev,
        loadingMore: true
      }));
    }

    try {
      const params = new URLSearchParams({
        limit: '20',
        tab: String(tab || 'all')
      });
      if (cursor) params.set('cursor', String(cursor));
      const res = await fetch(`/api/new/opportunities?${params.toString()}`, {
        credentials: 'include'
      });
      const { data, message } = await readApiPayload(res, 'Fırsat merkezi yüklenemedi.');
      if (!res.ok) throw new Error(message);
      const payload = data?.opportunities || {};
      if (requestId !== requestIdRef.current) return;

      if (!append) {
        setCache(cacheKey(tab), payload, 30_000);
      }

      startTransition(() => {
        setState((prev) => ({
          ...prev,
          loading: false,
          loadingMore: false,
          error: '',
          items: append ? [...prev.items, ...(Array.isArray(payload.items) ? payload.items : [])] : (Array.isArray(payload.items) ? payload.items : []),
          summary: payload.summary || prev.summary,
          hasMore: Boolean(payload.hasMore),
          nextCursor: String(payload.next_cursor || ''),
          tab: String(payload.tab || tab || 'all')
        }));
      });
    } catch (err) {
      if (requestId !== requestIdRef.current) return;
      setState((prev) => ({
        ...prev,
        loading: false,
        loadingMore: false,
        error: err.message || 'Fırsat merkezi yüklenemedi.'
      }));
    }
  }, [tab]);

  useEffect(() => {
    const cached = getCached(cacheKey(tab));
    if (cached) {
      setState((prev) => ({
        ...prev,
        loading: cached.stale,
        loadingMore: false,
        error: '',
        items: cached.data.items || [],
        summary: cached.data.summary || prev.summary,
        hasMore: Boolean(cached.data.hasMore),
        nextCursor: String(cached.data.next_cursor || ''),
        tab: String(tab || 'all')
      }));
      if (!cached.stale) return;
    } else {
      setState((prev) => ({
        ...prev,
        loading: true,
        loadingMore: false,
        error: '',
        items: [],
        hasMore: false,
        nextCursor: '',
        tab: String(tab || 'all')
      }));
    }
    void load({ append: false, cursor: '' });
  }, [load, tab]);

  const loadMore = useCallback(async () => {
    if (!state.hasMore || state.loadingMore || !state.nextCursor) return;
    await load({ append: true, cursor: state.nextCursor });
  }, [load, state.hasMore, state.loadingMore, state.nextCursor]);

  return { state, actions: { reload: () => load({ append: false, cursor: '' }), loadMore } };
}
