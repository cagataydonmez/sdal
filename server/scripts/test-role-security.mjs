import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdal-role-test-'));
process.env.SDAL_DB_PATH = path.join(tmpDir, 'test.sqlite');
process.env.ROOT_BOOTSTRAP_PASSWORD = 'RootPass!123';
process.env.SDAL_ADMIN_PASSWORD = 'AdminPanel!123';
process.env.SDAL_SESSION_SECRET = 'test-secret';

const { default: app, onServerStarted } = await import('../app.js');
const { sqlRun, sqlGet } = await import('../db.js');

await onServerStarted();

function seedUser({ kadi, sifre, admin = 0, role = 'user', mezuniyetyili = '2010' }) {
  const now = new Date().toISOString();
  sqlRun(
    `INSERT INTO uyeler (kadi, sifre, email, isim, soyisim, aktivasyon, aktiv, ilktarih, mezuniyetyili, ilkbd, admin, role, verified, verification_status)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 1, ?, ?, 1, 'approved')`,
    [kadi, sifre, `${kadi}@example.com`, kadi, 'Test', `${kadi}-act`, now, mezuniyetyili, admin, role]
  );
  return sqlGet('SELECT id FROM uyeler WHERE kadi = ?', [kadi]).id;
}

const adminId = seedUser({ kadi: 'admin1', sifre: 'adminpass', admin: 1, role: 'admin' });
const userId = seedUser({ kadi: 'user1', sifre: 'userpass', role: 'user', mezuniyetyili: '2011' });
const modId = seedUser({ kadi: 'mod1', sifre: 'modpass', role: 'mod', mezuniyetyili: '2012' });

const server = app.listen(0);
const base = `http://127.0.0.1:${server.address().port}`;

async function withSession(loginBody) {
  const loginRes = await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(loginBody)
  });
  const cookie = loginRes.headers.get('set-cookie');
  assert.equal(loginRes.status, 200);
  return cookie?.split(';')[0] || '';
}

async function req(method, url, cookie, body) {
  return fetch(`${base}${url}`, {
    method,
    headers: {
      cookie,
      'content-type': 'application/json'
    },
    body: body ? JSON.stringify(body) : undefined
  });
}

try {
  const adminCookie = await withSession({ kadi: 'admin1', sifre: 'adminpass' });
  const rootCookie = await withSession({ kadi: 'root', sifre: 'RootPass!123' });
  const modCookie = await withSession({ kadi: 'mod1', sifre: 'modpass' });

  const adminRoleChange = await req('POST', `/admin/users/${userId}/role`, adminCookie, { role: 'admin' });
  assert.equal(adminRoleChange.status, 403);

  const rootRoleChange = await req('POST', `/admin/users/${userId}/role`, rootCookie, { role: 'admin' });
  assert.equal(rootRoleChange.status, 200);

  const assignByAdmin = await req('POST', `/admin/moderators/${modId}/scopes`, adminCookie, { graduationYears: [2012, 2013] });
  assert.equal(assignByAdmin.status, 200);

  const assignByMod = await req('POST', `/admin/moderators/${userId}/scopes`, modCookie, { graduationYears: [2011] });
  assert.equal(assignByMod.status, 403);

  const modAllowed = await req('POST', '/admin/moderation/check/2012', modCookie);
  assert.equal(modAllowed.status, 200);
  const modDenied = await req('POST', '/admin/moderation/check/2011', modCookie);
  assert.equal(modDenied.status, 403);

  const rootCreatePost = await req('POST', '/api/new/posts', rootCookie, { body: 'root should fail' });
  assert.equal(rootCreatePost.status, 403);

  console.log('role-security smoke tests passed');
} finally {
  server.close();
}
