import { startTransition, useCallback, useEffect, useReducer, useRef } from 'react';
import { emitAppChange } from '../utils/live.js';
import { unwrapApiData } from '../utils/api.js';
import { NETWORKING_TELEMETRY_EVENTS, sendNetworkingTelemetry } from '../utils/networkingTelemetry.js';
import {
  getConnectionActionEvent,
  getConnectionActionSuccessMessage,
  NETWORKING_EVENTS,
  NETWORKING_MESSAGES
} from '../utils/networkingRegistry.js';

function readConnectionUserField(item, key) {
  return Number(item?.[key] || 0);
}

function readResponsePayload(res) {
  return res.clone().json().catch(() => null);
}

async function readResponseMessage(res, fallbackMessage) {
  const payload = await readResponsePayload(res);
  const message = payload?.message || payload?.error;
  if (message) return String(message);
  try {
    const text = await res.text();
    if (text) return text;
  } catch {
    // no-op
  }
  return fallbackMessage;
}

async function fetchJson(url, fallback, options = {}) {
  try {
    const res = await fetch(url, { credentials: 'include', ...options });
    if (!res.ok) {
      return {
        ok: false,
        data: fallback,
        message: await readResponseMessage(res, 'Beklenmeyen bir hata oluştu.')
      };
    }
    const payload = await res.json();
    return {
      ok: true,
      data: unwrapApiData(payload) || fallback,
      message: payload?.message || ''
    };
  } catch {
    return { ok: false, data: fallback, message: 'İstek tamamlanamadı.' };
  }
}

function emptyMetrics() {
  return {
    connections: { requested: 0, accepted: 0, pending_incoming: 0, pending_outgoing: 0 },
    mentorship: { requested: 0, accepted: 0 },
    teacherLinks: { created: 0 },
    time_to_first_network_success_days: null
  };
}

function initialState() {
  return {
    bootstrapping: true,
    hubRefreshing: false,
    discoveryLoading: true,
    metricsWindow: '30d',
    metrics: emptyMetrics(),
    loadError: '',
    loadNotice: '',
    feedback: { type: '', message: '' },
    incoming: [],
    outgoing: [],
    incomingMentorship: [],
    outgoingMentorship: [],
    teacherEvents: [],
    teacherUnreadCount: 0,
    suggestions: [],
    followingIds: new Set(),
    incomingConnectionMap: {},
    outgoingConnectionMap: {},
    pendingAction: {}
  };
}

function removeKey(map, key) {
  if (!key || !Object.prototype.hasOwnProperty.call(map, key)) return map;
  const next = { ...map };
  delete next[key];
  return next;
}

function incrementMetric(metrics, path, delta) {
  const next = {
    ...metrics,
    connections: { ...(metrics.connections || {}) },
    mentorship: { ...(metrics.mentorship || {}) },
    teacherLinks: { ...(metrics.teacherLinks || {}) }
  };
  if (path === 'connections.accepted') next.connections.accepted = Math.max(0, Number(next.connections.accepted || 0) + delta);
  if (path === 'connections.pending_incoming') next.connections.pending_incoming = Math.max(0, Number(next.connections.pending_incoming || 0) + delta);
  if (path === 'connections.pending_outgoing') next.connections.pending_outgoing = Math.max(0, Number(next.connections.pending_outgoing || 0) + delta);
  if (path === 'mentorship.accepted') next.mentorship.accepted = Math.max(0, Number(next.mentorship.accepted || 0) + delta);
  if (path === 'teacherLinks.created') next.teacherLinks.created = Math.max(0, Number(next.teacherLinks.created || 0) + delta);
  return next;
}

function reducer(state, action) {
  switch (action.type) {
    case 'SET_METRICS_WINDOW':
      return { ...state, metricsWindow: action.value };
    case 'SET_PENDING_ACTION':
      return {
        ...state,
        pendingAction: {
          ...state.pendingAction,
          [action.key]: action.value
        }
      };
    case 'CLEAR_FEEDBACK':
      return { ...state, feedback: { type: '', message: '' } };
    case 'SET_FEEDBACK':
      return { ...state, feedback: action.value };
    case 'START_HUB_LOAD':
      if (action.silent) {
        return state;
      }
      return {
        ...state,
        bootstrapping: state.bootstrapping ? true : false,
        hubRefreshing: state.bootstrapping ? false : true,
        loadError: '',
        loadNotice: ''
      };
    case 'FINISH_HUB_LOAD':
      return {
        ...state,
        bootstrapping: false,
        hubRefreshing: false,
        incoming: action.payload.incoming,
        outgoing: action.payload.outgoing,
        incomingMentorship: action.payload.incomingMentorship,
        outgoingMentorship: action.payload.outgoingMentorship,
        teacherEvents: action.payload.teacherEvents,
        teacherUnreadCount: action.payload.teacherUnreadCount,
        metrics: action.payload.metrics,
        loadError: action.payload.loadError,
        loadNotice: action.payload.loadNotice
      };
    case 'START_DISCOVERY_LOAD':
      return action.silent ? state : { ...state, discoveryLoading: true };
    case 'FINISH_DISCOVERY_LOAD':
      return {
        ...state,
        discoveryLoading: false,
        suggestions: action.payload.suggestions,
        incomingConnectionMap: action.payload.incomingConnectionMap,
        outgoingConnectionMap: action.payload.outgoingConnectionMap,
        loadNotice: action.payload.loadNotice === undefined ? state.loadNotice : action.payload.loadNotice
      };
    case 'CONNECTION_ACCEPTED': {
      const { requestId, senderId } = action.payload;
      return {
        ...state,
        incoming: state.incoming.filter((item) => Number(item.id) !== Number(requestId)),
        suggestions: senderId > 0 ? state.suggestions.filter((item) => Number(item.id) !== senderId) : state.suggestions,
        incomingConnectionMap: senderId > 0 ? removeKey(state.incomingConnectionMap, senderId) : state.incomingConnectionMap,
        outgoingConnectionMap: senderId > 0 ? removeKey(state.outgoingConnectionMap, senderId) : state.outgoingConnectionMap,
        metrics: incrementMetric(incrementMetric(state.metrics, 'connections.pending_incoming', -1), 'connections.accepted', 1)
      };
    }
    case 'CONNECTION_IGNORED': {
      const { requestId, senderId } = action.payload;
      return {
        ...state,
        incoming: state.incoming.filter((item) => Number(item.id) !== Number(requestId)),
        incomingConnectionMap: senderId > 0 ? removeKey(state.incomingConnectionMap, senderId) : state.incomingConnectionMap,
        metrics: incrementMetric(state.metrics, 'connections.pending_incoming', -1)
      };
    }
    case 'CONNECTION_REQUEST_SENT':
      return {
        ...state,
        outgoingConnectionMap: action.payload.requestId > 0
          ? { ...state.outgoingConnectionMap, [action.payload.targetId]: action.payload.requestId }
          : state.outgoingConnectionMap,
        metrics: incrementMetric(state.metrics, 'connections.pending_outgoing', 1)
      };
    case 'CONNECTION_CANCELLED':
      return {
        ...state,
        outgoingConnectionMap: removeKey(state.outgoingConnectionMap, action.payload.targetId),
        metrics: incrementMetric(state.metrics, 'connections.pending_outgoing', -1)
      };
    case 'MENTORSHIP_ACCEPTED':
      return {
        ...state,
        incomingMentorship: state.incomingMentorship.filter((item) => Number(item.id) !== Number(action.id)),
        metrics: incrementMetric(state.metrics, 'mentorship.accepted', 1)
      };
    case 'MENTORSHIP_DECLINED':
      return {
        ...state,
        incomingMentorship: state.incomingMentorship.filter((item) => Number(item.id) !== Number(action.id))
      };
    case 'MARK_TEACHER_LINKS_READ':
      return {
        ...state,
        teacherUnreadCount: 0,
        teacherEvents: state.teacherEvents.map((item) => ({ ...item, read_at: item.read_at || action.readAt }))
      };
    case 'TOGGLE_FOLLOW': {
      const next = new Set(state.followingIds);
      if (next.has(action.userId)) next.delete(action.userId);
      else next.add(action.userId);
      return {
        ...state,
        followingIds: next,
        suggestions: state.suggestions.filter((item) => Number(item.id) !== Number(action.userId))
      };
    }
    default:
      return state;
  }
}

function inboxFallback() {
  return {
    inbox: {
      connections: { incoming: [], outgoing: [] },
      mentorship: { incoming: [], outgoing: [] },
      teacherLinks: { events: [], unread_count: 0 }
    }
  };
}

function metricsFallback() {
  return { metrics: emptyMetrics() };
}

function requestsFallback() {
  return { items: [] };
}

function hubFallback() {
  return {
    ok: false,
    code: '',
    message: '',
    data: {
      hub: {
        window: '30d',
        since: null,
        inbox: inboxFallback().inbox,
        metrics: emptyMetrics(),
        discovery: {
          suggestions: [],
          hasMore: false,
          total: 0,
          connection_maps: { incoming: {}, outgoing: {} }
        },
        counts: { actionable: 0 }
      }
    }
  };
}

export function useNetworkingHubState(t) {
  const [state, dispatch] = useReducer(reducer, undefined, initialState);
  const hasMountedRef = useRef(false);
  const hubRequestRef = useRef(0);
  const discoveryRequestRef = useRef(0);
  const metricsWindowReadyRef = useRef(false);
  const silentRefreshTimerRef = useRef(null);
  const discoveryTelemetrySentRef = useRef(false);
  const stateRef = useRef(state);

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  const loadHubData = useCallback(async ({ silent = false, windowValue } = {}) => {
    const nextWindow = windowValue || stateRef.current.metricsWindow || '30d';
    const requestId = hubRequestRef.current + 1;
    hubRequestRef.current = requestId;
    dispatch({ type: 'START_HUB_LOAD', silent });
    dispatch({ type: 'START_DISCOVERY_LOAD', silent });

    const bootstrapRes = await fetchJson(
      `/api/new/network/hub?limit=12&teacher_limit=12&suggestion_limit=8&window=${encodeURIComponent(nextWindow)}`,
      hubFallback()
    );

    if (requestId !== hubRequestRef.current) return;

    const hub = bootstrapRes.data?.hub || hubFallback().data.hub;
    if (bootstrapRes.ok && !discoveryTelemetrySentRef.current) {
      discoveryTelemetrySentRef.current = true;
      void sendNetworkingTelemetry({
        eventName: NETWORKING_TELEMETRY_EVENTS.hubSuggestionsLoaded,
        sourceSurface: 'network_hub',
        entityType: 'suggestion_batch',
        metadata: {
          suggestion_count: Array.isArray(hub.discovery?.suggestions) ? hub.discovery.suggestions.length : 0,
          actionable_count: Number(hub.counts?.actionable || 0),
          experiment_variant: String(hub.discovery?.experiment_variant || 'A')
        }
      });
    }

    startTransition(() => {
      dispatch({
        type: 'FINISH_HUB_LOAD',
        payload: {
          incoming: hub.inbox?.connections?.incoming || [],
          outgoing: hub.inbox?.connections?.outgoing || [],
          incomingMentorship: hub.inbox?.mentorship?.incoming || [],
          outgoingMentorship: hub.inbox?.mentorship?.outgoing || [],
          teacherEvents: hub.inbox?.teacherLinks?.events || [],
          teacherUnreadCount: Number(hub.inbox?.teacherLinks?.unread_count || 0),
          metrics: hub.metrics || emptyMetrics(),
          loadError: bootstrapRes.ok ? '' : (bootstrapRes.message || t('network_hub_load_error')),
          loadNotice: bootstrapRes.ok ? '' : ''
        }
      });
      dispatch({
        type: 'FINISH_DISCOVERY_LOAD',
        payload: {
          suggestions: hub.discovery?.suggestions || [],
          incomingConnectionMap: hub.discovery?.connection_maps?.incoming || {},
          outgoingConnectionMap: hub.discovery?.connection_maps?.outgoing || {},
          loadNotice: silent ? undefined : ''
        }
      });
    });
  }, [t]);

  const loadDiscoveryData = useCallback(async ({ silent = false } = {}) => {
    const requestId = discoveryRequestRef.current + 1;
    discoveryRequestRef.current = requestId;
    dispatch({ type: 'START_DISCOVERY_LOAD', silent });

    const [suggestionRes, incomingRes, outgoingRes] = await Promise.all([
      fetchJson('/api/new/explore/suggestions?limit=8&offset=0', requestsFallback()),
      fetchJson('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', requestsFallback()),
      fetchJson('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', requestsFallback())
    ]);

    if (requestId !== discoveryRequestRef.current) return;

    const incomingConnectionMap = {};
    for (const item of (incomingRes.data?.items || [])) {
      const senderId = readConnectionUserField(item, 'sender_id');
      if (!senderId) continue;
      incomingConnectionMap[senderId] = readConnectionUserField(item, 'id');
    }

    const outgoingConnectionMap = {};
    for (const item of (outgoingRes.data?.items || [])) {
      const receiverId = readConnectionUserField(item, 'receiver_id');
      if (!receiverId) continue;
      outgoingConnectionMap[receiverId] = readConnectionUserField(item, 'id');
    }

    startTransition(() => {
      dispatch({
        type: 'FINISH_DISCOVERY_LOAD',
        payload: {
          suggestions: suggestionRes.data?.items || [],
          incomingConnectionMap,
          outgoingConnectionMap,
          loadNotice: silent
            ? undefined
            : ((!suggestionRes.ok || !incomingRes.ok || !outgoingRes.ok)
              ? 'Öneriler yavaş yanıt veriyor. Öncelikli istekler hazır, keşif kartları arka planda yenileniyor.'
              : '')
        }
      });
    });
  }, []);

  const queueSilentRefresh = useCallback(({ hub = true, discovery = true, delay = 180 } = {}) => {
    if (silentRefreshTimerRef.current) {
      window.clearTimeout(silentRefreshTimerRef.current);
    }
    silentRefreshTimerRef.current = window.setTimeout(() => {
      if (hub && discovery) {
        void loadHubData({ silent: true, windowValue: stateRef.current.metricsWindow });
        return;
      }
      if (hub) void loadHubData({ silent: true, windowValue: stateRef.current.metricsWindow });
      if (discovery) void loadDiscoveryData({ silent: true });
    }, delay);
  }, [loadDiscoveryData, loadHubData]);

  useEffect(() => {
    hasMountedRef.current = true;
    void loadHubData({ silent: false, windowValue: stateRef.current.metricsWindow });

    return () => {
      hasMountedRef.current = false;
      if (silentRefreshTimerRef.current) {
        window.clearTimeout(silentRefreshTimerRef.current);
      }
    };
  }, [loadHubData]);

  useEffect(() => {
    if (!hasMountedRef.current) return undefined;
    const refreshTimer = window.setInterval(() => {
      queueSilentRefresh({ hub: true, discovery: true, delay: 0 });
    }, 25000);
    return () => window.clearInterval(refreshTimer);
  }, [queueSilentRefresh]);

  useEffect(() => {
    if (!hasMountedRef.current) return;
    if (!metricsWindowReadyRef.current) {
      metricsWindowReadyRef.current = true;
      return;
    }
    void loadHubData({ silent: true, windowValue: state.metricsWindow });
  }, [loadHubData, state.metricsWindow]);

  const runAction = useCallback(async (key, action) => {
    if (stateRef.current.pendingAction[key]) return;
    dispatch({ type: 'SET_PENDING_ACTION', key, value: true });
    dispatch({ type: 'CLEAR_FEEDBACK' });
    try {
      await action();
    } finally {
      dispatch({ type: 'SET_PENDING_ACTION', key, value: false });
    }
  }, []);

  const actions = {
    setMetricsWindow(value) {
      dispatch({ type: 'SET_METRICS_WINDOW', value });
    },
    async acceptRequest(requestId) {
      await runAction(`accept-${requestId}`, async () => {
        const senderId = Number(stateRef.current.incoming.find((item) => Number(item.id) === Number(requestId))?.sender_id || 0);
        const res = await fetch(`/api/new/connections/accept/${requestId}`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.connectionAcceptFailed) } });
          return;
        }
        const payload = await readResponsePayload(res);
        dispatch({ type: 'CONNECTION_ACCEPTED', payload: { requestId, senderId } });
        emitAppChange(NETWORKING_EVENTS.connectionAccepted, { requestId });
        dispatch({ type: 'SET_FEEDBACK', value: { type: 'ok', message: payload?.message || NETWORKING_MESSAGES.success.connectionAccepted } });
        queueSilentRefresh({ hub: true, discovery: true });
      });
    },
    async ignoreRequest(requestId) {
      await runAction(`ignore-${requestId}`, async () => {
        const senderId = Number(stateRef.current.incoming.find((item) => Number(item.id) === Number(requestId))?.sender_id || 0);
        const res = await fetch(`/api/new/connections/ignore/${requestId}`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.connectionIgnoreFailed) } });
          return;
        }
        const payload = await readResponsePayload(res);
        dispatch({ type: 'CONNECTION_IGNORED', payload: { requestId, senderId } });
        emitAppChange(NETWORKING_EVENTS.connectionIgnored, { requestId });
        dispatch({ type: 'SET_FEEDBACK', value: { type: 'ok', message: payload?.message || NETWORKING_MESSAGES.success.connectionIgnored } });
        queueSilentRefresh({ hub: true, discovery: true });
      });
    },
    async connectUser(userId) {
      await runAction(`connect-${userId}`, async () => {
        const targetId = Number(userId || 0);
        if (!targetId) return;
        const incomingRequestId = Number(stateRef.current.incomingConnectionMap[targetId] || 0);
        const outgoingRequestId = Number(stateRef.current.outgoingConnectionMap[targetId] || 0);
        const endpoint = incomingRequestId
          ? `/api/new/connections/accept/${incomingRequestId}`
          : outgoingRequestId
            ? `/api/new/connections/cancel/${outgoingRequestId}`
            : `/api/new/connections/request/${targetId}`;
        const res = await fetch(endpoint, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.connectionActionFailed) } });
          queueSilentRefresh({ hub: true, discovery: true, delay: 0 });
          return;
        }

        const payload = await readResponsePayload(res);
        const responseData = unwrapApiData(payload) || payload || {};
        if (incomingRequestId) {
          dispatch({ type: 'CONNECTION_ACCEPTED', payload: { requestId: incomingRequestId, senderId: targetId } });
        } else if (outgoingRequestId) {
          dispatch({ type: 'CONNECTION_CANCELLED', payload: { targetId } });
        } else {
          dispatch({ type: 'CONNECTION_REQUEST_SENT', payload: { targetId, requestId: Number(responseData?.request_id || payload?.request_id || 0) } });
        }

        emitAppChange(getConnectionActionEvent({ incomingRequestId, outgoingRequestId }), {
          userId: targetId,
          requestId: incomingRequestId || outgoingRequestId || responseData?.request_id || payload?.request_id || 0
        });
        dispatch({
          type: 'SET_FEEDBACK',
          value: {
            type: 'ok',
            message: payload?.message || getConnectionActionSuccessMessage({ incomingRequestId, outgoingRequestId })
          }
        });
        queueSilentRefresh({ hub: true, discovery: true });
      });
    },
    async acceptMentorship(id) {
      await runAction(`mentorship-accept-${id}`, async () => {
        const res = await fetch(`/api/new/mentorship/accept/${id}`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.mentorshipAcceptFailed) } });
          return;
        }
        const payload = await readResponsePayload(res);
        dispatch({ type: 'MENTORSHIP_ACCEPTED', id });
        emitAppChange(NETWORKING_EVENTS.mentorshipAccepted, { id });
        dispatch({ type: 'SET_FEEDBACK', value: { type: 'ok', message: payload?.message || NETWORKING_MESSAGES.success.mentorshipAccepted } });
        queueSilentRefresh({ hub: true, discovery: true });
      });
    },
    async declineMentorship(id) {
      await runAction(`mentorship-decline-${id}`, async () => {
        const res = await fetch(`/api/new/mentorship/decline/${id}`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.mentorshipDeclineFailed) } });
          return;
        }
        const payload = await readResponsePayload(res);
        dispatch({ type: 'MENTORSHIP_DECLINED', id });
        dispatch({ type: 'SET_FEEDBACK', value: { type: 'ok', message: payload?.message || NETWORKING_MESSAGES.success.mentorshipDeclined } });
        queueSilentRefresh({ hub: true, discovery: true });
      });
    },
    async markTeacherLinksRead() {
      await runAction('teacher-links-read', async () => {
        const res = await fetch('/api/new/network/inbox/teacher-links/read', {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.teacherLinksReadFailed) } });
          return;
        }
        const payload = await readResponsePayload(res);
        emitAppChange(NETWORKING_EVENTS.teacherLinksRead);
        dispatch({ type: 'MARK_TEACHER_LINKS_READ', readAt: new Date().toISOString() });
        dispatch({ type: 'SET_FEEDBACK', value: { type: 'ok', message: payload?.message || NETWORKING_MESSAGES.success.teacherLinksRead } });
      });
    },
    async toggleFollow(userId) {
      await runAction(`follow-${userId}`, async () => {
        const res = await fetch(`/api/new/follow/${userId}`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ source_surface: 'network_hub' })
        });
        if (!res.ok) {
          dispatch({ type: 'SET_FEEDBACK', value: { type: 'error', message: await readResponseMessage(res, NETWORKING_MESSAGES.errors.followUpdateFailed) } });
          return;
        }
        dispatch({ type: 'TOGGLE_FOLLOW', userId: Number(userId) });
        emitAppChange(NETWORKING_EVENTS.followChanged, { userId });
        dispatch({ type: 'SET_FEEDBACK', value: { type: 'ok', message: NETWORKING_MESSAGES.success.followUpdated } });
        queueSilentRefresh({ hub: false, discovery: true });
      });
    }
  };

  return { state, actions };
}
