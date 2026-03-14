import fs from 'fs';
import path from 'path';

function argValue(argv, name, fallback = '') {
  const idx = argv.findIndex((item) => item === `--${name}`);
  if (idx >= 0 && idx + 1 < argv.length) return argv[idx + 1];
  return fallback;
}

function argFlag(argv, name) {
  return argv.includes(`--${name}`);
}

export function buildBenchContext({ argv, env = process.env, cwd = process.cwd() }) {
  const runTag = `e2e${Date.now()}`;
  const BASE_URL = String(argValue(argv, 'base', env.BASE_URL || 'http://127.0.0.1:8787')).replace(/\/+$/, '');
  const E2E_TOKEN = String(argValue(argv, 'e2e-token', env.E2E_TOKEN || ''));
  const RUN_TAG = String(argValue(argv, 'tag', runTag)).replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 24) || runTag;
  const DEFAULT_PASSWORD = String(argValue(argv, 'password', env.E2E_PASSWORD || 'Passw0rd123'));
  const ADMIN_PANEL_PASSWORD = String(argValue(argv, 'admin-password', env.SDAL_ADMIN_PASSWORD || ''));
  const PERF_LOOPS = Math.max(1, Number.parseInt(argValue(argv, 'loops', env.E2E_PERF_LOOPS || '5'), 10) || 5);
  const TIMEOUT_MS = Math.max(1000, Number.parseInt(argValue(argv, 'timeout-ms', env.E2E_TIMEOUT_MS || '20000'), 10) || 20000);
  const REGISTER_TIMEOUT_MS = Math.max(
    TIMEOUT_MS,
    Number.parseInt(argValue(argv, 'register-timeout-ms', env.E2E_REGISTER_TIMEOUT_MS || '60000'), 10) || 60000
  );
  const REGISTER_RETRIES = Math.max(1, Number.parseInt(argValue(argv, 'register-retries', env.E2E_REGISTER_RETRIES || '3'), 10) || 3);
  const LOGIN_RETRIES = Math.max(1, Number.parseInt(argValue(argv, 'login-retries', env.E2E_LOGIN_RETRIES || '3'), 10) || 3);
  const ARTIFACT_DIR = path.resolve(argValue(argv, 'out', env.E2E_OUT_DIR || '/tmp'));
  const APP_FILE = path.resolve(argValue(argv, 'app-file', path.join(cwd, 'server/app.js')));
  const DRY_RUN = argFlag(argv, 'dry-run');
  const ALLOW_DESTRUCTIVE = argFlag(argv, 'allow-destructive');
  const PROBE_ONLY = argFlag(argv, 'probe-only') || String(env.E2E_PROBE_ONLY || '').trim().toLowerCase() === 'true';
  const ADVANCED_MODE = argFlag(argv, 'advanced') || String(env.E2E_ADVANCED || '').trim().toLowerCase() === 'true';
  const ADVANCED_CONCURRENCY = Math.max(2, Number.parseInt(argValue(argv, 'concurrency', env.E2E_CONCURRENCY || '6'), 10) || 6);
  const ADVANCED_RETRY_ATTEMPTS = Math.max(2, Number.parseInt(argValue(argv, 'retry-attempts', env.E2E_RETRY_ATTEMPTS || '3'), 10) || 3);
  const ADVANCED_SOAK_SECONDS = Math.max(
    0,
    Number.parseInt(
      argValue(argv, 'soak-seconds', env.E2E_SOAK_SECONDS || (ADVANCED_MODE ? '120' : '0')),
      10
    ) || 0
  );
  const ADVANCED_NEAR_LIMIT_MB = Math.max(1, Number.parseInt(argValue(argv, 'near-limit-mb', env.E2E_NEAR_LIMIT_MB || '8'), 10) || 8);
  const ADVANCED_OVER_LIMIT_MB = Math.max(2, Number.parseInt(argValue(argv, 'over-limit-mb', env.E2E_OVER_LIMIT_MB || '22'), 10) || 22);
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
  const destructiveRoutes = new Set([
    '/api/new/admin/db/driver/switch',
    '/api/new/admin/db/restore',
    '/api/new/admin/db/backups',
    '/api/new/admin/db/backups/:name/download',
    '/api/new/admin/members/:id',
    '/api/new/admin/posts/:id',
    '/api/new/admin/messages/:id',
    '/api/new/admin/stories/:id',
    '/api/new/admin/groups/:id'
  ]);

  return {
    BASE_URL,
    E2E_TOKEN,
    RUN_TAG,
    DEFAULT_PASSWORD,
    ADMIN_PANEL_PASSWORD,
    PERF_LOOPS,
    TIMEOUT_MS,
    REGISTER_TIMEOUT_MS,
    REGISTER_RETRIES,
    LOGIN_RETRIES,
    ARTIFACT_DIR,
    APP_FILE,
    DRY_RUN,
    ALLOW_DESTRUCTIVE,
    PROBE_ONLY,
    ADVANCED_MODE,
    ADVANCED_CONCURRENCY,
    ADVANCED_RETRY_ATTEMPTS,
    ADVANCED_SOAK_SECONDS,
    ADVANCED_NEAR_LIMIT_MB,
    ADVANCED_OVER_LIMIT_MB,
    TINY_PNG,
    TINY_PDF,
    ROLE_USERS,
    MOD_PERMISSIONS_ALL,
    destructiveRoutes
  };
}

export class CookieJar {
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

export function splitSetCookieHeader(value) {
  if (!value) return [];
  return String(value).split(/,(?=\s*[A-Za-z0-9_.-]+=)/g);
}

export class ApiClient {
  constructor(name) {
    this.name = name;
    this.jar = new CookieJar();
  }
}

export function buildUsername(key, index, runTag, issuedUsernames) {
  const keyPart = String(key || 'user').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 4) || 'user';
  const tagPart = String(runTag || 'run').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 8) || 'run';
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

export function withParams(template, params = {}) {
  let out = template;
  for (const [key, val] of Object.entries(params)) {
    out = out.replace(new RegExp(`:${key}(?=\\/|$)`, 'g'), encodeURIComponent(String(val)));
  }
  return out;
}

export function inferJson(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.max(0, Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

export function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath, { recursive: true });
}

export function must(result, message) {
  if (!result.ok) {
    throw new Error(message);
  }
}

export function containsAny(haystack, needles) {
  const src = String(haystack || '').toLowerCase();
  return needles.some((item) => src.includes(String(item || '').toLowerCase()));
}

export function isAbortError(result) {
  return result?.status === 0 && containsAny(result?.error || '', ['aborted', 'abort']);
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, Math.max(0, Number(ms) || 0)));
}

export function pngForm(tinyPng, fieldName = 'file', fileName = 'tiny.png') {
  const form = new FormData();
  form.append(fieldName, new Blob([tinyPng], { type: 'image/png' }), fileName);
  return form;
}

export function pdfForm(tinyPdf, fieldName = 'file', fileName = 'tiny.pdf') {
  const form = new FormData();
  form.append(fieldName, new Blob([tinyPdf], { type: 'application/pdf' }), fileName);
  return form;
}

export function pngFormSized(tinyPng, fieldName = 'file', fileName = 'sized.png', sizeBytes = 1024 * 1024) {
  const targetSize = Math.max(128, Number(sizeBytes) || 1024);
  const pad = Math.max(0, targetSize - tinyPng.length);
  const body = Buffer.concat([tinyPng, Buffer.alloc(pad, 0)]);
  const form = new FormData();
  form.append(fieldName, new Blob([body], { type: 'image/png' }), fileName);
  return form;
}

export function pdfFormSized(tinyPdf, fieldName = 'file', fileName = 'sized.pdf', sizeBytes = 1024 * 1024) {
  const targetSize = Math.max(256, Number(sizeBytes) || 1024);
  const pad = Math.max(0, targetSize - tinyPdf.length);
  const body = Buffer.concat([tinyPdf, Buffer.alloc(pad, 0)]);
  const form = new FormData();
  form.append(fieldName, new Blob([body], { type: 'application/pdf' }), fileName);
  return form;
}

export function discoverApiRoutes(appFile) {
  const source = fs.readFileSync(appFile, 'utf-8');
  const regex = /app\.(get|post|put|patch|delete)\(\s*(['"`])([^'"`]+)\2/g;
  const rows = [];
  let match;
  while ((match = regex.exec(source)) !== null) {
    const method = String(match[1] || '').toUpperCase();
    const route = String(match[3] || '').trim();
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

export function writeBenchReports({ artifactDir, runTag, baseUrl, records, routes }) {
  ensureDir(artifactDir);
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const rawPath = path.join(artifactDir, `sdal_e2e_raw_${runTag}_${stamp}.ndjson`);
  const summaryPath = path.join(artifactDir, `sdal_e2e_summary_${runTag}_${stamp}.tsv`);
  const slowPath = path.join(artifactDir, `sdal_e2e_slowest_${runTag}_${stamp}.tsv`);
  const coveragePath = path.join(artifactDir, `sdal_e2e_coverage_${runTag}_${stamp}.tsv`);

  fs.writeFileSync(rawPath, records.map((row) => JSON.stringify(row)).join('\n') + '\n', 'utf8');

  const groups = new Map();
  for (const row of records) {
    const key = `${row.method} ${row.routeTemplate}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(row);
  }

  const summaryRows = [];
  for (const [key, rows] of groups.entries()) {
    const timings = rows.map((row) => Number(row.elapsedMs || 0)).sort((a, b) => a - b);
    const okCount = rows.filter((row) => row.ok).length;
    const avg = timings.length ? timings.reduce((sum, value) => sum + value, 0) / timings.length : 0;
    const statuses = {};
    for (const row of rows) statuses[row.status] = (statuses[row.status] || 0) + 1;
    summaryRows.push({
      endpoint: key,
      calls: rows.length,
      ok: okCount,
      avgMs: Number(avg.toFixed(3)),
      p95Ms: Number(percentile(timings, 95).toFixed(3)),
      maxMs: Number((timings[timings.length - 1] || 0).toFixed(3)),
      statuses: Object.entries(statuses).map(([status, count]) => `${status}:${count}`).join(',')
    });
  }
  summaryRows.sort((a, b) => b.avgMs - a.avgMs);

  const summaryHeader = 'endpoint\tcalls\tok\tavg_ms\tp95_ms\tmax_ms\tstatus_mix\n';
  fs.writeFileSync(
    summaryPath,
    summaryHeader + summaryRows.map((row) => `${row.endpoint}\t${row.calls}\t${row.ok}\t${row.avgMs}\t${row.p95Ms}\t${row.maxMs}\t${row.statuses}`).join('\n') + '\n',
    'utf8'
  );
  fs.writeFileSync(
    slowPath,
    summaryHeader + summaryRows.slice(0, 60).map((row) => `${row.endpoint}\t${row.calls}\t${row.ok}\t${row.avgMs}\t${row.p95Ms}\t${row.maxMs}\t${row.statuses}`).join('\n') + '\n',
    'utf8'
  );

  const discovered = new Set(routes.map((row) => `${row.method} ${row.route}`));
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
  const failedCalls = records.filter((row) => !row.ok).length;
  const avgMsAll = totalCalls ? records.reduce((sum, row) => sum + Number(row.elapsedMs || 0), 0) / totalCalls : 0;

  return {
    rawPath,
    summaryPath,
    slowPath,
    coveragePath,
    discoveredCount: discovered.size,
    testedCount: tested.size,
    missingCount: missing.length,
    totalCalls,
    failedCalls,
    avgMsAll,
    baseUrl,
    runTag
  };
}
