export function registerSystemRoutes(app, deps) {
  const {
    dbDriver,
    dbPath,
    sqlGet,
    checkPostgresHealth,
    checkRedisHealth,
    isPostgresConfigured,
    isRedisConfigured,
    getPostgresPoolState,
    getRedisState,
    getRealtimeBus,
    getBackgroundJobQueue,
    issueCaptcha,
    resolveModuleKeyByPath,
    getModuleControlMap,
    getSiteControl,
    getCurrentUser,
    isOAuthProfileIncomplete,
    getUserRole,
    roleAtLeast,
    getModeratorPermissionSummary
  } = deps;

  async function healthHandler(_req, res) {
    const startedAt = Date.now();

    let dbCheck = {
      configured: true,
      ready: false,
      detail: '',
      latencyMs: 0
    };

    if (dbDriver === 'postgres') {
      dbCheck = await checkPostgresHealth();
    } else {
      try {
        const dbStartedAt = Date.now();
        const row = sqlGet('SELECT 1 AS ok');
        dbCheck = {
          configured: true,
          ready: Number(row?.ok || 0) === 1,
          detail: 'ok',
          latencyMs: Date.now() - dbStartedAt
        };
      } catch (err) {
        dbCheck = {
          configured: true,
          ready: false,
          detail: err?.message || 'sqlite check failed',
          latencyMs: Date.now() - startedAt
        };
      }
    }

    const redisCheck = await checkRedisHealth();
    const redisRequired = isRedisConfigured();
    const realtimeBus = getRealtimeBus();
    const backgroundJobQueue = getBackgroundJobQueue();
    const overallOk = dbCheck.ready && (!redisRequired || redisCheck.ready);

    res.status(overallOk ? 200 : 503).json({
      ok: overallOk,
      dbPath,
      dbDriver,
      dbReady: dbCheck.ready,
      redisReady: redisCheck.ready,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '0.1.0',
      uptimeSec: Math.floor(process.uptime()),
      durationMs: Date.now() - startedAt,
      checks: {
        db: dbCheck,
        redis: redisCheck,
        realtime: realtimeBus?.getState?.() || { started: false, enabled: false },
        jobs: backgroundJobQueue?.getState?.() || { started: false }
      },
      runtime: {
        postgres: getPostgresPoolState(),
        redis: getRedisState(),
        realtime: realtimeBus?.getState?.() || { started: false, enabled: false },
        jobs: backgroundJobQueue?.getState?.() || { started: false },
        postgresConfigured: isPostgresConfigured(),
        redisConfigured: redisRequired
      }
    });
  }

  app.get('/health', healthHandler);
  app.get('/api/health', healthHandler);

  app.get('/api/captcha', (req, res) => {
    issueCaptcha(req, res);
  });

  app.get('/api/site-access', (req, res) => {
    const pathValue = String(req.query.path || req.path || '').trim();
    const moduleKey = resolveModuleKeyByPath(pathValue);
    const modules = getModuleControlMap();
    const site = getSiteControl();
    res.json({
      siteOpen: site.siteOpen,
      maintenanceMessage: site.maintenanceMessage,
      modules,
      moduleKey,
      moduleOpen: moduleKey ? !!modules[moduleKey] : true
    });
  });

  app.get('/api/session', (req, res) => {
    if (!req.session.userId) {
      return res.json({ user: null });
    }
    const current = getCurrentUser(req);
    const user = current
      ? {
        id: current.id,
        kadi: current.kadi,
        isim: current.isim,
        soyisim: current.soyisim,
        photo: current.resim,
        admin: current.admin,
        role: current.role,
        verified: current.verified,
        mezuniyetyili: current.mezuniyetyili,
        oauth_provider: current.oauth_provider,
        kvkk_consent_at: current.kvkk_consent_at,
        directory_consent_at: current.directory_consent_at
      }
      : null;
    if (!user) return res.json({ user: null });
    const state = isOAuthProfileIncomplete(user) ? 'incomplete' : 'active';
    const role = getUserRole(user);
    const moderationPermissionKeys = role === 'mod' ? getModeratorPermissionSummary(user.id).assignedKeys : [];
    res.json({ user: { ...user, role, admin: roleAtLeast(role, 'admin') ? 1 : 0, state, moderationPermissionKeys } });
  });
}
