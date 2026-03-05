import crypto from 'crypto';
import { ensureRedisConnection, getRedisClient, isRedisConfigured } from './redisClient.js';

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function nowMs() {
  return Date.now();
}

function parseBlPopResult(result) {
  if (!result) return null;
  if (Array.isArray(result) && result.length >= 2) return String(result[1]);
  if (typeof result === 'object' && result.element) return String(result.element);
  return null;
}

export function createJobQueue({
  namespace = 'sdal:jobs:main',
  logger = console,
  defaultMaxAttempts = 4,
  defaultBackoffMs = 2_000
} = {}) {
  const queueKey = `${namespace}:queue`;
  const delayedKey = `${namespace}:delayed`;

  let producer = null;
  let consumer = null;
  let started = false;
  let workerPromise = null;
  const memoryQueue = [];
  const memoryDelayed = [];

  async function ensureProducer() {
    if (!isRedisConfigured()) return null;
    try {
      producer = producer || getRedisClient();
      if (!producer) return null;
      await ensureRedisConnection();
      if (!producer.isReady) return null;
      return producer;
    } catch {
      return null;
    }
  }

  function buildJob(type, payload, options = {}) {
    return {
      id: `${Date.now()}-${crypto.randomBytes(6).toString('hex')}`,
      type: String(type || '').trim(),
      payload: payload ?? {},
      attempts: Number(options.attempts || 0),
      maxAttempts: toPositiveInt(options.maxAttempts, defaultMaxAttempts),
      backoffMs: toPositiveInt(options.backoffMs, defaultBackoffMs),
      createdAt: options.createdAt || new Date().toISOString()
    };
  }

  function memoryEnqueue(job, delayMs = 0) {
    if (delayMs > 0) {
      memoryDelayed.push({ dueAt: nowMs() + delayMs, raw: JSON.stringify(job) });
      return;
    }
    memoryQueue.push(JSON.stringify(job));
  }

  async function redisEnqueue(client, job, delayMs = 0) {
    const raw = JSON.stringify(job);
    if (delayMs > 0) {
      await client.zAdd(delayedKey, [{ score: nowMs() + delayMs, value: raw }]);
      return;
    }
    await client.rPush(queueKey, raw);
  }

  async function enqueue(type, payload, options = {}) {
    const job = buildJob(type, payload, options);
    const delayMs = Math.max(Number(options.delayMs || 0), 0);
    const client = await ensureProducer();

    if (client) {
      try {
        await redisEnqueue(client, job, delayMs);
        return { ok: true, backend: 'redis', jobId: job.id };
      } catch {
        // fall through to memory
      }
    }

    memoryEnqueue(job, delayMs);
    return { ok: true, backend: 'memory', jobId: job.id };
  }

  async function releaseDueDelayedJobs(redisClient) {
    if (redisClient?.isReady) {
      const due = await redisClient.zRangeByScore(delayedKey, 0, nowMs(), {
        LIMIT: { offset: 0, count: 100 }
      });
      if (due.length) {
        const tx = redisClient.multi();
        for (const raw of due) {
          tx.zRem(delayedKey, raw);
          tx.rPush(queueKey, raw);
        }
        await tx.exec();
      }
      return;
    }

    if (!memoryDelayed.length) return;
    const now = nowMs();
    const keep = [];
    for (const entry of memoryDelayed) {
      if (!entry || typeof entry.raw !== 'string') continue;
      if (Number(entry.dueAt || 0) <= now) {
        memoryQueue.push(entry.raw);
      } else {
        keep.push(entry);
      }
    }
    memoryDelayed.length = 0;
    memoryDelayed.push(...keep);
  }

  async function dequeue(redisClient, timeoutSeconds = 2) {
    if (redisClient?.isReady) {
      const item = await redisClient.blPop(queueKey, timeoutSeconds);
      return parseBlPopResult(item);
    }

    if (memoryQueue.length) return memoryQueue.shift();
    await wait(200);
    return null;
  }

  async function scheduleRetry(job, err) {
    const nextAttempt = Number(job.attempts || 0) + 1;
    if (nextAttempt >= Number(job.maxAttempts || defaultMaxAttempts)) {
      logger.error?.('[jobs] permanent failure', {
        jobType: job.type,
        jobId: job.id,
        attempts: nextAttempt,
        message: err?.message || String(err || 'unknown_error')
      });
      return;
    }

    const delayMs = Math.min(Number(job.backoffMs || defaultBackoffMs) * (2 ** (nextAttempt - 1)), 60_000);
    const retryJob = {
      ...job,
      attempts: nextAttempt
    };

    const client = await ensureProducer();
    if (client) {
      try {
        await redisEnqueue(client, retryJob, delayMs);
        return;
      } catch {
        // fallback below
      }
    }
    memoryEnqueue(retryJob, delayMs);
  }

  async function processJob(raw, handlers) {
    let job;
    try {
      job = JSON.parse(String(raw || '{}'));
    } catch {
      return;
    }

    if (!job?.type) return;
    const handler = handlers[job.type];
    if (typeof handler !== 'function') return;

    try {
      await handler(job.payload || {}, { job });
    } catch (err) {
      await scheduleRetry(job, err);
    }
  }

  async function startWorker({ handlers = {}, pollTimeoutSeconds = 2 } = {}) {
    if (started) return;
    started = true;

    const timeoutSeconds = toPositiveInt(pollTimeoutSeconds, 2);
    let redisConsumer = null;

    const producerClient = await ensureProducer();
    if (producerClient?.isReady) {
      try {
        consumer = producerClient.duplicate();
        await consumer.connect();
        redisConsumer = consumer;
      } catch {
        redisConsumer = null;
      }
    }

    workerPromise = (async () => {
      while (started) {
        try {
          await releaseDueDelayedJobs(redisConsumer);
          const raw = await dequeue(redisConsumer, timeoutSeconds);
          if (!raw) continue;
          await processJob(raw, handlers);
        } catch (err) {
          logger.error?.('[jobs] worker loop error', err?.message || err);
          await wait(300);
        }
      }
    })();

    return workerPromise;
  }

  async function stopWorker() {
    started = false;
    if (consumer) {
      try {
        if (consumer.isOpen) await consumer.quit();
      } catch {
        // no-op
      } finally {
        consumer = null;
      }
    }

    if (workerPromise) {
      await Promise.race([workerPromise.catch(() => {}), wait(500)]);
      workerPromise = null;
    }
  }

  function getState() {
    return {
      queueKey,
      delayedKey,
      redisConfigured: isRedisConfigured(),
      producerReady: Boolean(producer?.isReady),
      consumerReady: Boolean(consumer?.isReady),
      started,
      memoryQueueDepth: memoryQueue.length,
      memoryDelayedDepth: memoryDelayed.length
    };
  }

  return {
    enqueue,
    startWorker,
    stopWorker,
    getState
  };
}
