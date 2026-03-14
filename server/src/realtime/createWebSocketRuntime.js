import { WebSocketServer } from 'ws';

export function createWebSocketRuntime({
  sessionParser,
  normalizeUserId,
  allowLegacyWsQueryAuth,
  writeAppLog,
  sqlGet,
  formatUserText,
  isFormattedContentEmpty,
  sqlRun,
  scheduleEngagementRecalculation,
  broadcastChatMessage,
  setChatWss,
  setMessengerWss
}) {
  function parseWsUserIdFromQuery(req) {
    try {
      const url = new URL(req.url || '', 'http://localhost');
      const userId = Number(url.searchParams.get('userId') || 0);
      return userId > 0 ? userId : 0;
    } catch {
      return 0;
    }
  }

  function attachSessionToUpgradeRequest(req) {
    return new Promise((resolve) => {
      const fakeRes = {
        getHeader() { return undefined; },
        setHeader() {},
        writeHead() {},
        end() {}
      };
      try {
        sessionParser(req, fakeRes, () => resolve(req.session || null));
      } catch {
        resolve(null);
      }
    });
  }

  async function resolveWsUser(req) {
    const session = await attachSessionToUpgradeRequest(req);
    const sessionUserId = Number(normalizeUserId(session?.userId) || 0);
    const queryUserId = parseWsUserIdFromQuery(req);

    if (sessionUserId > 0) {
      if (queryUserId > 0 && queryUserId !== sessionUserId) {
        return { userId: 0, reason: 'session_query_mismatch' };
      }
      return { userId: sessionUserId, source: 'session' };
    }

    if (allowLegacyWsQueryAuth && queryUserId > 0) {
      writeAppLog('warn', 'ws_legacy_query_auth_used', { path: req.url || '', userId: queryUserId });
      return { userId: queryUserId, source: 'legacy_query' };
    }

    return { userId: 0, reason: 'missing_session' };
  }

  function attachWebSocketServers(server) {
    const chatWss = new WebSocketServer({ server, path: '/ws/chat' });
    setChatWss(chatWss);
    chatWss.on('connection', async (ws, req) => {
      const auth = await resolveWsUser(req);
      if (!auth.userId) {
        ws.close(1008, 'Unauthorized');
        return;
      }
      ws.sdalUserId = auth.userId;

      ws.on('message', (data) => {
        try {
          const payload = JSON.parse(String(data || '{}'));
          const userId = Number(ws.sdalUserId || 0);
          const rawMessage = String(payload?.message || '').slice(0, 5000);
          if (!userId || !rawMessage) return;
          const user = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [userId]) || null;
          if (!user?.id) return;
          const message = formatUserText(rawMessage || '');
          if (isFormattedContentEmpty(message)) return;
          const now = new Date().toISOString();
          const result = sqlRun('INSERT INTO chat_messages (user_id, message, created_at) VALUES (?, ?, ?)', [
            userId,
            message,
            now
          ]);
          scheduleEngagementRecalculation('chat_message_created');
          broadcastChatMessage({
            id: result?.lastInsertRowid,
            user_id: user.id,
            message,
            created_at: now,
            user: {
              id: user.id,
              kadi: user.kadi,
              isim: user.isim,
              soyisim: user.soyisim,
              resim: user.resim,
              verified: user.verified
            }
          });
        } catch {
          // ignore
        }
      });
    });

    const messengerWss = new WebSocketServer({ server, path: '/ws/messenger' });
    setMessengerWss(messengerWss);
    messengerWss.on('connection', async (ws, req) => {
      const auth = await resolveWsUser(req);
      if (!auth.userId) {
        ws.close(1008, 'Unauthorized');
        return;
      }
      ws.sdalUserId = auth.userId;
      try {
        ws.send(JSON.stringify({ type: 'messenger:hello', userId: auth.userId }));
      } catch {
        // ignore
      }
    });
  }

  return {
    attachWebSocketServers
  };
}
