#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { performance } from 'perf_hooks';

const argv = process.argv.slice(2);

function argValue(name, fallback = '') {
  const idx = argv.findIndex((item) => item === `--${name}`);
  if (idx >= 0 && idx + 1 < argv.length) return argv[idx + 1];
  return fallback;
}

function argFlag(name) {
  return argv.includes(`--${name}`);
}

const BASE_URL = String(argValue('base', process.env.BASE_URL || 'http://127.0.0.1:8787')).replace(/\/+$/, '');
const E2E_TOKEN = String(argValue('e2e-token', process.env.E2E_TOKEN || ''));
const RUN_TAG = String(argValue('tag', `e2e${Date.now()}`)).replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 24) || `e2e${Date.now()}`;
const DEFAULT_PASSWORD = String(argValue('password', process.env.E2E_PASSWORD || 'Passw0rd123'));
const ADMIN_PANEL_PASSWORD = String(argValue('admin-password', process.env.SDAL_ADMIN_PASSWORD || ''));
const PERF_LOOPS = Math.max(1, Number.parseInt(argValue('loops', process.env.E2E_PERF_LOOPS || '5'), 10) || 5);
const TIMEOUT_MS = Math.max(1000, Number.parseInt(argValue('timeout-ms', process.env.E2E_TIMEOUT_MS || '20000'), 10) || 20000);
const REGISTER_TIMEOUT_MS = Math.max(
  TIMEOUT_MS,
  Number.parseInt(argValue('register-timeout-ms', process.env.E2E_REGISTER_TIMEOUT_MS || '60000'), 10) || 60000
);
const REGISTER_RETRIES = Math.max(1, Number.parseInt(argValue('register-retries', process.env.E2E_REGISTER_RETRIES || '3'), 10) || 3);
const LOGIN_RETRIES = Math.max(1, Number.parseInt(argValue('login-retries', process.env.E2E_LOGIN_RETRIES || '3'), 10) || 3);
const ARTIFACT_DIR = path.resolve(argValue('out', process.env.E2E_OUT_DIR || '/tmp'));
const APP_FILE = path.resolve(argValue('app-file', path.join(process.cwd(), 'server/app.js')));
const DRY_RUN = argFlag('dry-run');

const TINY_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8Xw8AAoMBgB7R6YQAAAAASUVORK5CYII=',
  'base64'
);
const TINY_PDF = Buffer.from('%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n', 'utf8');

const ROLE_USERS = [
  { key: 'admin', role: 'admin', mezuniyetyili: 2010 },
  { key: 'mod', role: 'mod', mezuniyetyili: 2011 },
  { key: 'user1', role: 'user', mezuniyetyili: 2012 },
  { key: 'user2', role: 'user', mezuniyetyili: 2013 },
  { key: 'user3', role: 'user', mezuniyetyili: 2014 }
];

const MOD_PERMISSIONS_ALL = [
  'requests.view',
  'requests.moderate',
  'posts.view',
  'posts.delete',
  'stories.view',
  'stories.delete',
  'chat.view',
  'chat.delete',
  'messages.view',
  'messages.delete',
  'groups.view',
  'groups.delete'
];

const records = [];
const routeCoverage = new Set();
const issuedUsernames = new Set();
const state = {
  users: {},
  ids: {
    postId: null,
    uploadedPostId: null,
    messageId: null,
    threadId: null,
    threadMessageId: null,
    chatMessageId: null,
    storyId: null,
    groupId: null,
    groupJoinRequestId: null,
    groupInviteId: null,
    eventId: null,
    announcementId: null,
    jobId: null,
    requestId: null,
    verificationRequestId: null,
    albumCategoryId: null,
    albumPhotoId: null,
    anyTableName: null
  }
};

class CookieJar {
  constructor() {
    this.store = new Map();
  }

  setFromHeaders(headers) {
    const setCookies = typeof headers.getSetCookie === 'function'
      ? headers.getSetCookie()
      : splitSetCookieHeader(headers.get('set-cookie'));
    for (const row of setCookies) {
      const first = String(row || '').split(';')[0];
      const eq = first.indexOf('=');
      if (eq <= 0) continue;
      const key = first.slice(0, eq).trim();
      const val = first.slice(eq + 1).trim();
      if (!key) continue;
      this.store.set(key, val);
    }
  }

  header() {
    return Array.from(this.store.entries()).map(([k, v]) => `${k}=${v}`).join('; ');
  }
}

function splitSetCookieHeader(value) {
  if (!value) return [];
  return String(value).split(/,(?=\s*[A-Za-z0-9_.-]+=)/g);
}

class ApiClient {
  constructor(name) {
    this.name = name;
    this.jar = new CookieJar();
  }
}

function buildUsername(key, index) {
  const keyPart = String(key || 'user').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 4) || 'user';
  const tagPart = String(RUN_TAG || 'run').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 8) || 'run';
  let candidate = `${keyPart}${tagPart}${String(index + 1)}`.slice(0, 15);
  if (!candidate) candidate = `user${String(index + 1)}`;
  let guard = 2;
  while (issuedUsernames.has(candidate)) {
    candidate = `${keyPart}${tagPart}${String(guard)}`.slice(0, 15);
    guard += 1;
  }
  issuedUsernames.add(candidate);
  return candidate;
}

function withParams(template, params = {}) {
  let out = template;
  for (const [key, val] of Object.entries(params)) {
    out = out.replace(new RegExp(`:${key}(?=\\/|$)`, 'g'), encodeURIComponent(String(val)));
  }
  return out;
}

function inferJson(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.max(0, Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath, { recursive: true });
}

async function request(client, method, routeTemplate, {
  params = {},
  query = {},
  json = undefined,
  form = null,
  headers = {},
  allow = [],
  note = '',
  timeoutMs = TIMEOUT_MS
} = {}) {
  const pathname = withParams(routeTemplate, params);
  const url = new URL(pathname, `${BASE_URL}/`);
  for (const [k, v] of Object.entries(query || {})) {
    if (v === undefined || v === null || v === '') continue;
    url.searchParams.set(k, String(v));
  }

  const reqHeaders = {
    Accept: 'application/json, text/plain;q=0.9, */*;q=0.8',
    'User-Agent': 'sdal-e2e-full-api-bench/1.0',
    ...headers
  };
  const cookieHeader = client.jar.header();
  if (cookieHeader) reqHeaders.Cookie = cookieHeader;

  const init = { method, headers: reqHeaders };
  if (form) {
    init.body = form;
  } else if (json !== undefined) {
    init.body = JSON.stringify(json);
    init.headers['Content-Type'] = 'application/json';
  }

  const started = performance.now();
  let status = 0;
  let bodyText = '';
  let error = null;
  try {
    if (DRY_RUN) {
      status = 200;
      bodyText = '{"ok":true}';
    } else {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), Math.max(500, Number(timeoutMs) || TIMEOUT_MS));
      let resp;
      try {
        resp = await fetch(url, { ...init, signal: ctrl.signal });
      } finally {
        clearTimeout(timer);
      }
      status = resp.status;
      client.jar.setFromHeaders(resp.headers);
      bodyText = await resp.text();
    }
  } catch (err) {
    error = err?.message || String(err);
  }
  const elapsed = Number((performance.now() - started).toFixed(3));

  const okByStatus = status >= 200 && status < 300;
  const allowed = new Set(allow);
  const ok = error ? false : (okByStatus || allowed.has(status));
  const parsed = inferJson(bodyText);
  routeCoverage.add(`${String(method || 'GET').toUpperCase()} ${routeTemplate}`);

  records.push({
    ts: new Date().toISOString(),
    actor: client.name,
    method,
    routeTemplate,
    path: url.pathname,
    status,
    ok,
    elapsedMs: elapsed,
    note,
    error,
    bodyPreview: String(bodyText || '').slice(0, 300)
  });

  const marker = ok ? 'OK' : 'FAIL';
  const failPreview = !ok && bodyText ? ` body=${String(bodyText).replace(/\s+/g, ' ').slice(0, 180)}` : '';
  console.log(`${marker} ${client.name.padEnd(6)} ${method.padEnd(6)} ${url.pathname} status=${status} ms=${elapsed}${note ? ` note=${note}` : ''}${error ? ` err=${error}` : ''}${failPreview}`);

  return { ok, status, text: bodyText, json: parsed, elapsedMs: elapsed, error };
}

function must(result, message) {
  if (!result.ok) {
    throw new Error(message);
  }
}

function containsAny(haystack, needles) {
  const src = String(haystack || '').toLowerCase();
  return needles.some((item) => src.includes(String(item || '').toLowerCase()));
}

function isAbortError(result) {
  return result?.status === 0 && containsAny(result?.error || '', ['aborted', 'abort']);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, Math.max(0, Number(ms) || 0)));
}

async function assertE2EHarnessActive() {
  if (DRY_RUN) return;
  const probe = new ApiClient('probe');
  const ts = Date.now();
  const probePayload = {
    kadi: `p${String(ts).slice(-8)}`,
    sifre: 'Passw0rd!123',
    sifre2: 'Passw0rd!123',
    email: `probe.${ts}@example.test`,
    isim: 'Probe',
    soyisim: 'Runner',
    mezuniyetyili: 2015,
    gkodu: 'abc-not-captcha',
    kvkk_consent: false,
    directory_consent: false,
    e2e_token: E2E_TOKEN
  };
  const res = await request(probe, 'POST', '/api/register/preview', {
    json: probePayload,
    headers: { 'x-e2e-token': E2E_TOKEN },
    allow: [400],
    note: 'e2e-probe'
  });
  if (res.status === 200) return;
  const msg = String(res.text || '');
  if (containsAny(msg, ['güvenlik kodu', 'kvkk', 'açık rıza', 'mezun rehberi'])) {
    throw new Error(`E2E harness disabled or token mismatch on server. Probe response: ${msg}`);
  }
  throw new Error(`E2E probe failed (HTTP ${res.status}): ${msg || 'empty response'}`);
}

async function registerAndLoginUsers() {
  for (let idx = 0; idx < ROLE_USERS.length; idx += 1) {
    const spec = ROLE_USERS[idx];
    const username = buildUsername(spec.key, idx);
    const email = `${RUN_TAG}.${spec.key}@example.test`;
    const registerClient = new ApiClient(`${spec.key}-reg`);
    const payload = {
      kadi: username,
      sifre: DEFAULT_PASSWORD,
      sifre2: DEFAULT_PASSWORD,
      email,
      isim: `E2E${spec.key}`,
      soyisim: 'Runner',
      mezuniyetyili: spec.mezuniyetyili,
      gkodu: '00000000',
      kvkk_consent: true,
      directory_consent: true,
      role: spec.role
    };
    if (spec.role === 'mod') {
      payload.moderationPermissionKeys = MOD_PERMISSIONS_ALL;
    }
    if (E2E_TOKEN) payload.e2e_token = E2E_TOKEN;

    let registered = false;
    for (let attempt = 1; attempt <= REGISTER_RETRIES; attempt += 1) {
      const reg = await request(registerClient, 'POST', '/api/register', {
        json: payload,
        headers: E2E_TOKEN ? { 'x-e2e-token': E2E_TOKEN } : {},
        allow: [200, 400],
        note: `register:${spec.key}:attempt${attempt}`,
        timeoutMs: REGISTER_TIMEOUT_MS
      });
      if (reg.status === 200) {
        registered = true;
        break;
      }
      if (reg.status === 400) {
        const msg = String(reg.text || '').trim();
        if (containsAny(msg, ['zaten kayıtlı'])) {
          registered = true;
          break;
        }
        if (containsAny(msg, ['güvenlik kodu', 'kvkk', 'açık rıza', 'mezun rehberi'])) {
          throw new Error(`register failed for ${spec.key}: E2E harness/token not active. Response: ${msg}`);
        }
        throw new Error(`register failed for ${spec.key}: ${msg || 'HTTP 400'}`);
      }
      if (isAbortError(reg) && attempt < REGISTER_RETRIES) {
        await sleep(1200 * attempt);
        continue;
      }
      throw new Error(`register failed for ${spec.key}: status=${reg.status} err=${reg.error || 'unknown'}`);
    }

    const client = new ApiClient(spec.key);
    let login = null;
    for (let attempt = 1; attempt <= LOGIN_RETRIES; attempt += 1) {
      const result = await request(client, 'POST', '/api/auth/login', {
        json: { kadi: username, sifre: DEFAULT_PASSWORD },
        allow: [400, 401],
        note: `login:${spec.key}:attempt${attempt}`,
        timeoutMs: Math.max(10000, TIMEOUT_MS)
      });
      if (result.status >= 200 && result.status < 300) {
        login = result;
        break;
      }
      if (attempt < LOGIN_RETRIES) {
        await sleep(900 * attempt);
      }
    }
    if (!login || !(login.status >= 200 && login.status < 300)) {
      const suffix = registered ? 'after register' : 'without register';
      throw new Error(`login failed for ${spec.key} (${suffix})`);
    }

    const session = await request(client, 'GET', '/api/session', { note: `session:${spec.key}` });
    must(session, `session failed for ${spec.key}`);
    const user = session.json?.user || login.json?.user;
    if (!user?.id && !DRY_RUN) {
      throw new Error(`session user missing for ${spec.key}`);
    }
    const userId = Number(user?.id || idx + 2);
    state.users[spec.key] = {
      ...spec,
      username,
      email,
      id: userId,
      client
    };
  }
}

function pngForm(fieldName = 'file', fileName = 'tiny.png') {
  const form = new FormData();
  form.append(fieldName, new Blob([TINY_PNG], { type: 'image/png' }), fileName);
  return form;
}

function pdfForm(fieldName = 'file', fileName = 'tiny.pdf') {
  const form = new FormData();
  form.append(fieldName, new Blob([TINY_PDF], { type: 'application/pdf' }), fileName);
  return form;
}

async function runCoreScenario() {
  const admin = state.users.admin.client;
  const mod = state.users.mod.client;
  const user1 = state.users.user1.client;
  const user2 = state.users.user2.client;
  const user3 = state.users.user3.client;

  await request(admin, 'GET', '/api/health');
  await request(user1, 'GET', '/api/site-access', { query: { path: '/new' } });
  await request(user1, 'GET', '/api/auth/oauth/providers');
  await request(user1, 'GET', '/api/captcha');
  await request(user1, 'GET', '/api/profile');

  for (const key of Object.keys(state.users)) {
    const u = state.users[key];
    await request(u.client, 'PUT', '/api/profile', {
      json: {
        isim: `E2E${u.key}`,
        soyisim: 'Runner',
        mezuniyetyili: u.mezuniyetyili,
        sehir: 'Istanbul',
        meslek: 'QA',
        kvkk_consent: true,
        directory_consent: true
      },
      note: `profile-update:${u.key}`
    });

    const photo = pngForm('file', `${u.key}.png`);
    await request(u.client, 'POST', '/api/profile/photo', {
      form: photo,
      note: `profile-photo:${u.key}`
    });
  }

  await request(user1, 'GET', '/api/members', { query: { page: 1, pageSize: 10 } });
  await request(user1, 'GET', '/api/members/:id', { params: { id: state.users.user2.id } });

  await request(user1, 'POST', '/api/messages', {
    json: { kime: String(state.users.user2.id), konu: `msg-${RUN_TAG}`, mesaj: 'E2E direct message body' }
  });
  const inbox = await request(user2, 'GET', '/api/messages', { query: { box: 'inbox', page: 1, pageSize: 10 } });
  state.ids.messageId = Number(inbox.json?.rows?.[0]?.id || 0) || null;
  if (state.ids.messageId) {
    await request(user2, 'GET', '/api/messages/:id', { params: { id: state.ids.messageId } });
  }

  await request(user1, 'POST', '/api/new/posts', { json: { content: `E2E post ${RUN_TAG}` } });
  const postUploadForm = pngForm('image', 'post.png');
  postUploadForm.append('content', `E2E uploaded post ${RUN_TAG}`);
  await request(user1, 'POST', '/api/new/posts/upload', { form: postUploadForm });

  const feed = await request(user1, 'GET', '/api/new/feed', {
    query: { limit: 20, offset: 0, feedType: 'main', filter: 'latest' }
  });
  state.ids.postId = Number(feed.json?.items?.[0]?.id || 0) || null;
  if (state.ids.postId) {
    await request(user2, 'POST', '/api/new/posts/:id/like', { params: { id: state.ids.postId } });
    await request(user2, 'POST', '/api/new/posts/:id/comments', {
      params: { id: state.ids.postId },
      json: { comment: `E2E comment ${RUN_TAG}` }
    });
    await request(user1, 'GET', '/api/new/posts/:id/comments', { params: { id: state.ids.postId } });
    await request(user1, 'PATCH', '/api/new/posts/:id', {
      params: { id: state.ids.postId },
      json: { content: `E2E post edited ${RUN_TAG}` }
    });
  }

  const storyForm = pngForm('image', 'story.png');
  storyForm.append('caption', `E2E story ${RUN_TAG}`);
  await request(user1, 'POST', '/api/new/stories/upload', { form: storyForm });
  const storiesMine = await request(user1, 'GET', '/api/new/stories/mine');
  state.ids.storyId = Number(storiesMine.json?.items?.[0]?.id || 0) || null;
  await request(user1, 'GET', '/api/new/stories');
  if (state.ids.storyId) {
    await request(user2, 'POST', '/api/new/stories/:id/view', { params: { id: state.ids.storyId } });
  }

  const chatSend = await request(user3, 'POST', '/api/new/chat/send', { json: { message: `E2E chat ${RUN_TAG}` } });
  state.ids.chatMessageId = Number(chatSend.json?.id || 0) || null;
  await request(user1, 'GET', '/api/new/chat/messages', { query: { limit: 40 } });
  if (state.ids.chatMessageId) {
    await request(user3, 'PATCH', '/api/new/chat/messages/:id', {
      params: { id: state.ids.chatMessageId },
      json: { message: `E2E chat edited ${RUN_TAG}` }
    });
  }

  const thread = await request(user1, 'POST', '/api/sdal-messenger/threads', {
    json: { userId: state.users.user2.id }
  });
  state.ids.threadId = Number(thread.json?.thread?.id || thread.json?.id || 0) || null;
  if (state.ids.threadId) {
    const tmsg = await request(user1, 'POST', '/api/sdal-messenger/threads/:id/messages', {
      params: { id: state.ids.threadId },
      json: { body: `E2E thread message ${RUN_TAG}` }
    });
    state.ids.threadMessageId = Number(tmsg.json?.message?.id || tmsg.json?.id || 0) || null;
    await request(user2, 'GET', '/api/sdal-messenger/threads/:id/messages', {
      params: { id: state.ids.threadId }
    });
    await request(user2, 'POST', '/api/sdal-messenger/threads/:id/read', {
      params: { id: state.ids.threadId }
    });
  }

  const groupCreate = await request(user1, 'POST', '/api/new/groups', {
    json: { name: `E2E Group ${RUN_TAG}`, description: 'E2E group description', visibility: 'public' }
  });
  state.ids.groupId = Number(groupCreate.json?.id || 0) || null;
  if (state.ids.groupId) {
    await request(user2, 'POST', '/api/new/groups/:id/join', { params: { id: state.ids.groupId } });
    const reqs = await request(user1, 'GET', '/api/new/groups/:id/requests', { params: { id: state.ids.groupId } });
    state.ids.groupJoinRequestId = Number(reqs.json?.items?.[0]?.id || 0) || null;
    if (state.ids.groupJoinRequestId) {
      await request(user1, 'POST', '/api/new/groups/:id/requests/:requestId', {
        params: { id: state.ids.groupId, requestId: state.ids.groupJoinRequestId },
        json: { action: 'approve' }
      });
    }
    await request(user1, 'POST', '/api/new/groups/:id/invitations', {
      params: { id: state.ids.groupId },
      json: { userIds: [state.users.user3.id] }
    });
    await request(user3, 'POST', '/api/new/groups/:id/invitations/respond', {
      params: { id: state.ids.groupId },
      json: { action: 'accept' }
    });
    const coverForm = pngForm('image', 'cover.png');
    await request(user1, 'POST', '/api/new/groups/:id/cover', {
      params: { id: state.ids.groupId },
      form: coverForm
    });
    await request(user1, 'POST', '/api/new/groups/:id/posts', {
      params: { id: state.ids.groupId },
      json: { content: `E2E group post ${RUN_TAG}` }
    });
    await request(user1, 'GET', '/api/new/groups/:id', { params: { id: state.ids.groupId } });
  }

  const eventCreate = await request(user1, 'POST', '/api/new/events', {
    json: {
      title: `E2E Event ${RUN_TAG}`,
      description: 'E2E event description',
      starts_at: new Date(Date.now() + 3600_000).toISOString(),
      location: 'Istanbul'
    }
  });
  state.ids.eventId = Number(eventCreate.json?.id || 0) || null;
  if (state.ids.eventId) {
    await request(admin, 'POST', '/api/new/events/:id/approve', {
      params: { id: state.ids.eventId },
      json: { approved: 1 }
    });
    await request(user2, 'POST', '/api/new/events/:id/respond', {
      params: { id: state.ids.eventId },
      json: { response: 'going' }
    });
    await request(user2, 'POST', '/api/new/events/:id/comments', {
      params: { id: state.ids.eventId },
      json: { comment: `E2E event comment ${RUN_TAG}` }
    });
  }

  const annCreate = await request(user1, 'POST', '/api/new/announcements', {
    json: {
      title: `E2E Announcement ${RUN_TAG}`,
      body: 'E2E announcement body'
    }
  });
  state.ids.announcementId = Number(annCreate.json?.id || 0) || null;
  if (state.ids.announcementId) {
    await request(admin, 'POST', '/api/new/announcements/:id/approve', {
      params: { id: state.ids.announcementId },
      json: { approved: 1 }
    });
  }

  const jobCreate = await request(user1, 'POST', '/api/new/jobs', {
    json: {
      title: `E2E Job ${RUN_TAG}`,
      company: 'SDAL',
      location: 'Remote',
      description: 'E2E job description'
    }
  });
  state.ids.jobId = Number(jobCreate.json?.id || 0) || null;
  await request(user1, 'GET', '/api/new/jobs', { query: { limit: 20, offset: 0 } });

  await request(user2, 'GET', '/api/new/request-categories');
  const uploadRequestAttachment = pdfForm('file', 'request.pdf');
  await request(user2, 'POST', '/api/new/requests/upload', { form: uploadRequestAttachment });
  const categories = await request(user2, 'GET', '/api/new/request-categories');
  const categoryKey = categories.json?.items?.[0]?.category_key;
  if (categoryKey) {
    await request(user2, 'POST', '/api/new/requests', {
      json: { category_key: categoryKey, payload: { note: `E2E request ${RUN_TAG}` } }
    });
    const myReqs = await request(user2, 'GET', '/api/new/requests/my');
    state.ids.requestId = Number(myReqs.json?.items?.[0]?.id || 0) || null;
  }

  await request(user3, 'POST', '/api/new/verified/request', { json: { proof_path: '/uploads/mock-proof.png' }, allow: [400] });
  const proofForm = pngForm('proof', 'proof.png');
  await request(user3, 'POST', '/api/new/verified/proof', { form: proofForm, allow: [400] });
  const verList = await request(mod, 'GET', '/api/new/admin/verification-requests', { query: { page: 1, limit: 20 } });
  state.ids.verificationRequestId = Number(verList.json?.items?.[0]?.id || 0) || null;
  if (state.ids.verificationRequestId) {
    await request(mod, 'POST', '/api/new/admin/verification-requests/:id', {
      params: { id: state.ids.verificationRequestId },
      json: { status: 'approved' },
      allow: [403]
    });
  }

  await request(admin, 'GET', '/api/new/admin/stats');
  await request(admin, 'GET', '/api/new/admin/live');
  await request(admin, 'GET', '/api/new/admin/db/tables');
  const tables = await request(admin, 'GET', '/api/new/admin/db/tables');
  state.ids.anyTableName = String(tables.json?.items?.[0]?.name || '');
  if (state.ids.anyTableName) {
    await request(admin, 'GET', '/api/new/admin/db/table/:name', {
      params: { name: state.ids.anyTableName },
      query: { page: 1, limit: 20 }
    });
  }
  await request(admin, 'GET', '/api/new/admin/db/driver/status');
}

function discoverApiRoutes() {
  const source = fs.readFileSync(APP_FILE, 'utf-8');
  const regex = /app\.(get|post|put|patch|delete)\(\s*(['"`])([^'"`]+)\2/g;
  const rows = [];
  let m;
  while ((m = regex.exec(source)) !== null) {
    const method = String(m[1] || '').toUpperCase();
    const route = String(m[3] || '').trim();
    if (!route.startsWith('/api/')) continue;
    rows.push({ method, route });
  }
  const unique = new Map();
  for (const row of rows) {
    unique.set(`${row.method} ${row.route}`, row);
  }
  return Array.from(unique.values()).sort((a, b) => {
    if (a.route === b.route) return a.method.localeCompare(b.method);
    return a.route.localeCompare(b.route);
  });
}

function resolveParam(route, name) {
  const n = String(name || '').toLowerCase();
  if (n === 'name') return state.ids.anyTableName || 'uyeler';
  if (n === 'provider') return 'google';
  if (n === 'game') return 'tap-rush';
  if (n === 'file') return '2.webp';
  if (n === 'variant') return 'A';
  if (n === 'userid' || n === 'id') {
    if (route.includes('/messages/')) return state.ids.messageId || 1;
    if (route.includes('/posts/')) return state.ids.postId || 1;
    if (route.includes('/stories/')) return state.ids.storyId || 1;
    if (route.includes('/groups/')) return state.ids.groupId || 1;
    if (route.includes('/events/')) return state.ids.eventId || 1;
    if (route.includes('/announcements/')) return state.ids.announcementId || 1;
    if (route.includes('/jobs/')) return state.ids.jobId || 1;
    if (route.includes('/verification-requests/')) return state.ids.verificationRequestId || 1;
    if (route.includes('/requests/') && route.includes('/admin/')) return state.ids.requestId || 1;
    if (route.includes('/threads/')) return state.ids.threadId || 1;
    if (route.includes('/photos/')) return state.ids.albumPhotoId || 1;
    if (route.includes('/members/')) return state.users.user2?.id || 1;
    return state.users.user1?.id || 1;
  }
  if (n === 'requestid') return state.ids.groupJoinRequestId || state.ids.requestId || 1;
  if (n === 'eventid') return state.ids.eventId || 1;
  if (n === 'announcementid') return state.ids.announcementId || 1;
  if (n === 'commentid') return 1;
  return 1;
}

function buildRouteParams(route) {
  const params = {};
  const matches = route.match(/:([a-zA-Z0-9_]+)/g) || [];
  for (const raw of matches) {
    const name = raw.slice(1);
    const value = resolveParam(route, name);
    if (value === null || value === undefined || value === '') return null;
    params[name] = value;
  }
  return params;
}

async function runBestEffortRouteSweep(routes) {
  const payloads = {
    '/api/new/events/:id/respond': { response: 'going' },
    '/api/new/events/:id/response-visibility': { is_public: 1 },
    '/api/new/events/:id/comments': { comment: `E2E sweep comment ${RUN_TAG}` },
    '/api/new/groups/:id/requests/:requestId': { action: 'approve' },
    '/api/new/groups/:id/invitations/respond': { action: 'accept' },
    '/api/new/groups/:id/settings': { visibility: 'public', showContactHint: true },
    '/api/new/chat/send': { message: `E2E sweep chat ${RUN_TAG}` },
    '/api/new/posts': { content: `E2E sweep post ${RUN_TAG}` },
    '/api/new/announcements': { title: `E2E sweep ${RUN_TAG}`, body: 'sweep body' },
    '/api/new/jobs': { title: `E2E sweep ${RUN_TAG}`, company: 'SDAL', location: 'Remote', description: 'sweep job' },
    '/api/messages': { kime: String(state.users.user2?.id || 0), konu: 'Sweep', mesaj: 'Sweep message' },
    '/api/quick-access/add': { id: state.users.user2?.id || 0 },
    '/api/quick-access/remove': { id: state.users.user2?.id || 0 }
  };

  for (const row of routes) {
    const routeTemplate = row.route;
    if (routeCoverage.has(`${row.method} ${routeTemplate}`)) continue;
    const params = buildRouteParams(routeTemplate);
    if (params === null) {
      records.push({
        ts: new Date().toISOString(),
        actor: 'sweep',
        method: row.method,
        routeTemplate,
        path: routeTemplate,
        status: 0,
        ok: false,
        elapsedMs: 0,
        note: 'SKIPPED_MISSING_PARAMS',
        error: 'missing route params',
        bodyPreview: ''
      });
      continue;
    }

    const actor = routeTemplate.startsWith('/api/new/admin/') || routeTemplate.startsWith('/api/admin/')
      ? state.users.admin?.client
      : state.users.user1?.client;
    if (!actor) continue;

    const method = row.method;
    if (method === 'GET') {
      await request(actor, method, routeTemplate, { params, allow: [400, 401, 403, 404] });
      continue;
    }

    const body = payloads[routeTemplate];
    if (body) {
      await request(actor, method, routeTemplate, { params, json: body, allow: [400, 401, 403, 404] });
    } else {
      await request(actor, method, routeTemplate, { params, json: {}, allow: [400, 401, 403, 404, 405] });
    }
  }
}

function writeReports(routes) {
  ensureDir(ARTIFACT_DIR);
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const rawPath = path.join(ARTIFACT_DIR, `sdal_e2e_raw_${RUN_TAG}_${stamp}.ndjson`);
  const summaryPath = path.join(ARTIFACT_DIR, `sdal_e2e_summary_${RUN_TAG}_${stamp}.tsv`);
  const slowPath = path.join(ARTIFACT_DIR, `sdal_e2e_slowest_${RUN_TAG}_${stamp}.tsv`);
  const coveragePath = path.join(ARTIFACT_DIR, `sdal_e2e_coverage_${RUN_TAG}_${stamp}.tsv`);

  fs.writeFileSync(rawPath, records.map((row) => JSON.stringify(row)).join('\n') + '\n', 'utf8');

  const groups = new Map();
  for (const row of records) {
    const key = `${row.method} ${row.routeTemplate}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(row);
  }

  const summaryRows = [];
  for (const [key, rows] of groups.entries()) {
    const timings = rows.map((r) => Number(r.elapsedMs || 0)).sort((a, b) => a - b);
    const okCount = rows.filter((r) => r.ok).length;
    const avg = timings.length ? timings.reduce((s, v) => s + v, 0) / timings.length : 0;
    const statuses = {};
    for (const r of rows) statuses[r.status] = (statuses[r.status] || 0) + 1;
    summaryRows.push({
      endpoint: key,
      calls: rows.length,
      ok: okCount,
      avgMs: Number(avg.toFixed(3)),
      p95Ms: Number(percentile(timings, 95).toFixed(3)),
      maxMs: Number((timings[timings.length - 1] || 0).toFixed(3)),
      statuses: Object.entries(statuses).map(([s, c]) => `${s}:${c}`).join(',')
    });
  }
  summaryRows.sort((a, b) => b.avgMs - a.avgMs);

  const summaryHeader = 'endpoint\tcalls\tok\tavg_ms\tp95_ms\tmax_ms\tstatus_mix\n';
  fs.writeFileSync(
    summaryPath,
    summaryHeader + summaryRows.map((r) => `${r.endpoint}\t${r.calls}\t${r.ok}\t${r.avgMs}\t${r.p95Ms}\t${r.maxMs}\t${r.statuses}`).join('\n') + '\n',
    'utf8'
  );

  const slowRows = summaryRows.slice(0, 60);
  fs.writeFileSync(
    slowPath,
    summaryHeader + slowRows.map((r) => `${r.endpoint}\t${r.calls}\t${r.ok}\t${r.avgMs}\t${r.p95Ms}\t${r.maxMs}\t${r.statuses}`).join('\n') + '\n',
    'utf8'
  );

  const discovered = new Set(routes.map((r) => `${r.method} ${r.route}`));
  const tested = new Set(Array.from(groups.keys()));
  const missing = Array.from(discovered).filter((item) => !tested.has(item)).sort((a, b) => a.localeCompare(b));
  const coverageLines = [
    `discovered_routes\t${discovered.size}`,
    `tested_routes\t${tested.size}`,
    `untested_routes\t${missing.length}`,
    ''
  ];
  for (const item of missing) coverageLines.push(item);
  fs.writeFileSync(coveragePath, coverageLines.join('\n') + '\n', 'utf8');

  const totalCalls = records.length;
  const failedCalls = records.filter((r) => !r.ok).length;
  const avgMsAll = totalCalls ? records.reduce((s, r) => s + Number(r.elapsedMs || 0), 0) / totalCalls : 0;

  console.log('\n=== E2E API RESULT ===');
  console.log(`base=${BASE_URL}`);
  console.log(`run_tag=${RUN_TAG}`);
  console.log(`calls=${totalCalls} failed=${failedCalls} avg_ms=${avgMsAll.toFixed(3)}`);
  console.log(`routes_discovered=${discovered.size} routes_tested=${tested.size} routes_untested=${missing.length}`);
  console.log(`raw=${rawPath}`);
  console.log(`summary=${summaryPath}`);
  console.log(`slow=${slowPath}`);
  console.log(`coverage=${coveragePath}`);
}

async function runPerfLoops() {
  const user = state.users.user1?.client;
  if (!user) return;
  const endpoints = [
    '/api/new/feed?limit=20&offset=0&feedType=main&filter=latest',
    '/api/new/notifications?limit=3&offset=0',
    '/api/new/stories',
    '/api/new/messages/unread',
    '/api/new/online-members?limit=10&excludeSelf=1',
    '/api/quick-access',
    '/api/new/admin/stats',
    '/api/new/admin/live'
  ];
  for (const endpoint of endpoints) {
    for (let i = 0; i < PERF_LOOPS; i += 1) {
      const actor = endpoint.includes('/api/new/admin/') ? state.users.admin.client : user;
      await request(actor, 'GET', endpoint, { allow: [304] });
    }
  }
}

async function main() {
  console.log(`[e2e] base=${BASE_URL}`);
  console.log(`[e2e] app_file=${APP_FILE}`);
  console.log(`[e2e] token=${E2E_TOKEN ? 'provided' : 'missing'}`);
  if (typeof fetch !== 'function' || typeof FormData !== 'function' || typeof Blob !== 'function') {
    throw new Error('Node.js 18+ required (fetch/FormData/Blob unavailable)');
  }
  if (!fs.existsSync(APP_FILE)) throw new Error(`app.js not found: ${APP_FILE}`);
  if (!E2E_TOKEN && !DRY_RUN) {
    throw new Error('E2E token missing. Set --e2e-token or E2E_TOKEN.');
  }

  await assertE2EHarnessActive();
  await registerAndLoginUsers();
  await runCoreScenario();
  await runPerfLoops();

  if (ADMIN_PANEL_PASSWORD) {
    await request(state.users.admin.client, 'POST', '/api/admin/login', {
      json: { password: ADMIN_PANEL_PASSWORD },
      allow: [400]
    });
  }

  const routes = discoverApiRoutes();
  await runBestEffortRouteSweep(routes);
  writeReports(routes);
}

main().catch((err) => {
  console.error('[e2e] fatal:', err?.stack || err?.message || err);
  process.exitCode = 1;
});
