import { startTransition, useCallback, useEffect, useRef, useState } from 'react';
import { readApiPayload } from '../utils/api.js';

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

export function useOpportunityInboxState(tab = 'all') {
  const [state, setState] = useState(initialState);
  const requestIdRef = useRef(0);

  const load = useCallback(async ({ append = false, cursor = '' } = {}) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    setState((prev) => ({
      ...prev,
      loading: append ? prev.loading : true,
      loadingMore: append,
      error: append ? prev.error : ''
    }));

    try {
      const params = new URLSearchParams({
        limit: '20',
        tab: String(tab || 'all')
      });
      if (cursor) params.set('cursor', String(cursor));
      const res = await fetch(`/api/new/opportunities?${params.toString()}`, {
        credentials: 'include',
        cache: 'no-store'
      });
      const { data, message } = await readApiPayload(res, 'Fırsat merkezi yüklenemedi.');
      if (!res.ok) throw new Error(message);
      const payload = data?.opportunities || {};
      if (requestId !== requestIdRef.current) return;
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
    void load({ append: false, cursor: '' });
  }, [load, tab]);

  const loadMore = useCallback(async () => {
    if (!state.hasMore || state.loadingMore || !state.nextCursor) return;
    await load({ append: true, cursor: state.nextCursor });
  }, [load, state.hasMore, state.loadingMore, state.nextCursor]);

  return { state, actions: { reload: () => load({ append: false, cursor: '' }), loadMore } };
}
