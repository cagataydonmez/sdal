import crypto from 'crypto';
import { ensureRedisConnection, getRedisClient, isRedisConfigured } from './redisClient.js';

const CHAT_CHANNEL = 'sdal:realtime:chat';
const MESSENGER_CHANNEL = 'sdal:realtime:messenger';

function createInstanceId() {
  return `${process.pid}-${crypto.randomBytes(6).toString('hex')}`;
}

export function createRealtimeBus({
  onChatEvent,
  onMessengerEvent,
  logger = console,
  instanceId = createInstanceId()
} = {}) {
  let publisher = null;
  let subscriber = null;
  let started = false;

  async function start() {
    if (started) return;
    started = true;

    if (!isRedisConfigured()) return;

    try {
      publisher = getRedisClient();
      if (!publisher) return;
      await ensureRedisConnection();

      subscriber = publisher.duplicate();
      await subscriber.connect();

      await subscriber.subscribe(CHAT_CHANNEL, (raw) => {
        handleIncoming(raw, 'chat');
      });

      await subscriber.subscribe(MESSENGER_CHANNEL, (raw) => {
        handleIncoming(raw, 'messenger');
      });
    } catch (err) {
      logger.warn?.('[realtime] redis pub/sub start failed, continuing local-only', err?.message || err);
      await stop();
    }
  }

  async function stop() {
    started = false;
    if (!subscriber) return;
    try {
      if (subscriber.isOpen) {
        await subscriber.unsubscribe(CHAT_CHANNEL);
        await subscriber.unsubscribe(MESSENGER_CHANNEL);
        await subscriber.quit();
      }
    } catch {
      // no-op
    } finally {
      subscriber = null;
    }
  }

  function handleIncoming(raw, type) {
    try {
      const envelope = JSON.parse(String(raw || '{}'));
      if (!envelope || envelope.instanceId === instanceId) return;

      if (type === 'chat' && typeof onChatEvent === 'function' && envelope.payload) {
        onChatEvent(envelope.payload);
        return;
      }

      if (type === 'messenger' && typeof onMessengerEvent === 'function' && envelope.payload) {
        onMessengerEvent(Array.isArray(envelope.userIds) ? envelope.userIds : [], envelope.payload);
      }
    } catch {
      // ignore malformed pub/sub payloads
    }
  }

  async function publish(channel, payload) {
    if (!payload || !publisher || !publisher.isReady) return false;
    try {
      await publisher.publish(channel, JSON.stringify(payload));
      return true;
    } catch {
      return false;
    }
  }

  async function publishChat(payload) {
    return publish(CHAT_CHANNEL, {
      instanceId,
      at: new Date().toISOString(),
      payload
    });
  }

  async function publishMessenger(userIds, payload) {
    return publish(MESSENGER_CHANNEL, {
      instanceId,
      at: new Date().toISOString(),
      userIds: (userIds || []).map((id) => Number(id || 0)).filter((id) => id > 0),
      payload
    });
  }

  function getState() {
    return {
      enabled: isRedisConfigured(),
      started,
      redisReady: Boolean(publisher?.isReady),
      subscriberReady: Boolean(subscriber?.isReady),
      instanceId
    };
  }

  return {
    start,
    stop,
    publishChat,
    publishMessenger,
    getState,
    instanceId
  };
}
