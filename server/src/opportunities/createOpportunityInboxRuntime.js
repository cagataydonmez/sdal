function clamp(value, min, max) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return min;
  return Math.max(min, Math.min(max, numeric));
}

function toIsoOrNull(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : null;
}

function ageBonus(value, ceiling = 180) {
  const iso = toIsoOrNull(value);
  if (!iso) return 0;
  const diffMs = Date.now() - new Date(iso).getTime();
  const days = Math.max(0, Math.floor(diffMs / (24 * 60 * 60 * 1000)));
  return Math.max(0, ceiling - (days * 12));
}

function personName(row) {
  const full = `${String(row?.isim || '').trim()} ${String(row?.soyisim || '').trim()}`.trim();
  if (full) return full;
  const handle = String(row?.kadi || '').trim();
  return handle ? `@${handle}` : 'Bir üye';
}

function normalizeOpportunityInboxTab(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === 'now' || raw === 'networking' || raw === 'jobs' || raw === 'updates') return raw;
  return 'all';
}

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function selectOptionalColumnSql(hasColumn, table, alias, column, fallbackSql = 'NULL') {
  return hasColumn(table, column) ? `${alias}.${column}` : fallbackSql;
}

export function createOpportunityInboxRuntime({
  sqlGetAsync,
  sqlAllAsync,
  hasTable,
  hasColumn,
  buildNetworkInboxPayload,
  buildExploreSuggestionsPayload
}) {
  function createEmptyOpportunityInboxPayload(tab = 'all') {
    return {
      tab,
      items: [],
      hasMore: false,
      next_cursor: '',
      summary: {
        all: 0,
        now: 0,
        networking: 0,
        jobs: 0,
        updates: 0
      }
    };
  }

  function buildSummary(items) {
    return {
      all: items.length,
      now: items.filter((item) => item.priority_bucket === 'now').length,
      networking: items.filter((item) => item.category === 'networking').length,
      jobs: items.filter((item) => item.category === 'jobs').length,
      updates: items.filter((item) => item.category === 'updates').length
    };
  }

  function makeOpportunityItem(item) {
    return {
      id: String(item.id),
      kind: item.kind,
      source: item.source,
      category: item.category,
      score: Number(item.score || 0),
      priority_bucket: item.priority_bucket,
      title: item.title,
      summary: item.summary,
      why_now: item.why_now,
      reasons: safeArray(item.reasons),
      target: item.target || null,
      primary_action: item.primary_action || null,
      entity_type: item.entity_type || '',
      entity_id: item.entity_id == null ? null : Number(item.entity_id || 0),
      created_at: toIsoOrNull(item.created_at),
      read_at: toIsoOrNull(item.read_at)
    };
  }

  async function buildPendingJobReviewItems(userId) {
    if (!hasTable('jobs') || !hasTable('job_applications') || !hasColumn('job_applications', 'status')) return [];
    const reviewedAtSql = selectOptionalColumnSql(hasColumn, 'job_applications', 'ja', 'reviewed_at', 'NULL');
    const rows = await sqlAllAsync(
      `SELECT ja.id AS application_id,
              ja.job_id,
              ja.created_at AS application_created_at,
              ${reviewedAtSql} AS reviewed_at,
              j.title,
              j.company,
              j.poster_id,
              u.id AS applicant_id,
              u.kadi,
              u.isim,
              u.soyisim
       FROM job_applications ja
       JOIN jobs j ON j.id = ja.job_id
       LEFT JOIN uyeler u ON u.id = ja.applicant_id
       WHERE j.poster_id = ?
         AND LOWER(TRIM(COALESCE(ja.status, ''))) = 'pending'
       ORDER BY ja.id DESC
       LIMIT 12`,
      [userId]
    );

    return rows.map((row) => makeOpportunityItem({
      id: `job-review:${row.application_id}`,
      kind: 'job_application_review',
      source: 'jobs',
      category: 'jobs',
      score: 4200 + ageBonus(row.application_created_at),
      priority_bucket: 'now',
      title: `${personName(row)} başvurunu bekliyor`,
      summary: `"${String(row.title || 'İş ilanı')}" ilanına gelen başvuruyu değerlendir.`,
      why_now: 'İlan sahibinin cevap hızı başvuru dönüşümünü doğrudan etkiler.',
      reasons: [
        'Bekleyen iş başvurusu',
        String(row.company || '').trim() ? `${String(row.company).trim()} ilanı` : 'İş ilanı kuyruğu'
      ],
      target: {
        href: `/new/jobs?job=${Number(row.job_id || 0)}&tab=applications`,
        label: 'Başvuruları aç'
      },
      primary_action: {
        kind: 'open',
        label: 'Başvuruları aç'
      },
      entity_type: 'job_application',
      entity_id: row.application_id,
      created_at: row.application_created_at
    }));
  }

  async function buildJobDecisionUpdateItems(userId) {
    if (!hasTable('jobs') || !hasTable('job_applications') || !hasColumn('job_applications', 'status')) return [];
    const reviewedAtSql = selectOptionalColumnSql(hasColumn, 'job_applications', 'ja', 'reviewed_at', 'ja.created_at');
    const decisionNoteSql = selectOptionalColumnSql(hasColumn, 'job_applications', 'ja', 'decision_note', "''");
    const rows = await sqlAllAsync(
      `SELECT ja.id AS application_id,
              ja.job_id,
              ja.status,
              ${reviewedAtSql} AS reviewed_at,
              ${decisionNoteSql} AS decision_note,
              j.title,
              j.company
       FROM job_applications ja
       JOIN jobs j ON j.id = ja.job_id
       WHERE ja.applicant_id = ?
         AND LOWER(TRIM(COALESCE(ja.status, ''))) IN ('reviewed', 'accepted', 'rejected')
       ORDER BY ${reviewedAtSql} DESC, ja.id DESC
       LIMIT 12`,
      [userId]
    );

    return rows.map((row) => {
      const status = String(row.status || '').trim().toLowerCase();
      const statusLabel = status === 'accepted' ? 'kabul edildi' : status === 'rejected' ? 'reddedildi' : 'güncellendi';
      return makeOpportunityItem({
        id: `job-update:${row.application_id}`,
        kind: 'job_application_update',
        source: 'jobs',
        category: 'jobs',
        score: 3900 + ageBonus(row.reviewed_at),
        priority_bucket: 'now',
        title: `İş başvurun ${statusLabel}`,
        summary: `"${String(row.title || 'İş ilanı')}" için güncel karar notunu gör.`,
        why_now: status === 'accepted'
          ? 'Sıcak dönüşleri hızlı takip etmek fırsat penceresini büyütür.'
          : 'Başvuru durumundaki değişiklikler bir sonraki adımı netleştirir.',
        reasons: safeArray([
          status === 'accepted' ? 'Olumlu dönüş' : status === 'rejected' ? 'Karar bildirimi' : 'Başvuru güncellemesi',
          String(row.company || '').trim() ? `${String(row.company).trim()} ilanı` : ''
        ]).filter(Boolean),
        target: {
          href: `/new/jobs?job=${Number(row.job_id || 0)}&focus=my-application&application=${Number(row.application_id || 0)}`,
          label: 'Başvuru durumunu aç'
        },
        primary_action: {
          kind: 'open',
          label: 'Başvuru durumunu aç'
        },
        entity_type: 'job_application',
        entity_id: row.application_id,
        created_at: row.reviewed_at
      });
    });
  }

  async function buildFreshJobRecommendationItems(userId) {
    if (!hasTable('jobs')) return [];
    const rows = await sqlAllAsync(
      `SELECT j.id,
              j.title,
              j.company,
              j.location,
              j.job_type,
              j.created_at
       FROM jobs j
       WHERE j.poster_id != ?
         ${hasTable('job_applications') ? `AND NOT EXISTS (
           SELECT 1
           FROM job_applications ja
           WHERE ja.job_id = j.id
             AND ja.applicant_id = ?
         )` : ''}
       ORDER BY j.id DESC
       LIMIT 8`,
      hasTable('job_applications') ? [userId, userId] : [userId]
    );

    return rows.map((row) => {
      const reasonBits = [];
      if (String(row.location || '').trim()) reasonBits.push(String(row.location).trim());
      if (String(row.job_type || '').trim()) reasonBits.push(String(row.job_type).trim());
      return makeOpportunityItem({
        id: `job-rec:${row.id}`,
        kind: 'job_recommendation',
        source: 'jobs',
        category: 'jobs',
        score: 1500 + ageBonus(row.created_at, 120),
        priority_bucket: 'later',
        title: `"${String(row.title || 'İş ilanı')}" senin için açık`,
        summary: String(row.company || '').trim()
          ? `${String(row.company).trim()} ilanını kaçırmadan gözden geçir.`
          : 'Yeni açılan iş ilanını değerlendir.',
        why_now: 'Yeni ilanlar ilk günlerinde daha yüksek cevap alma şansına sahiptir.',
        reasons: reasonBits,
        target: {
          href: `/new/jobs?job=${Number(row.id || 0)}`,
          label: 'İlanı aç'
        },
        primary_action: {
          kind: 'open',
          label: 'İlanı aç'
        },
        entity_type: 'job',
        entity_id: row.id,
        created_at: row.created_at
      });
    });
  }

  async function buildOpportunityInboxPayload(userId, { limit = 20, cursor = '', tab = 'all' } = {}) {
    const safeUserId = Number(userId || 0);
    const safeLimit = clamp(limit, 1, 40);
    const normalizedTab = normalizeOpportunityInboxTab(tab);
    const offset = Math.max(parseInt(String(cursor || '0'), 10) || 0, 0);
    if (!safeUserId) return createEmptyOpportunityInboxPayload(normalizedTab);

    const [inbox, discovery, jobReviews, jobUpdates, jobRecommendations] = await Promise.all([
      buildNetworkInboxPayload(safeUserId, { limit: 12, teacherLinkLimit: 12 }),
      buildExploreSuggestionsPayload(safeUserId, { limit: 8, offset: 0 }),
      buildPendingJobReviewItems(safeUserId),
      buildJobDecisionUpdateItems(safeUserId),
      buildFreshJobRecommendationItems(safeUserId)
    ]);

    const items = [];

    for (const item of safeArray(inbox?.mentorship?.incoming)) {
      items.push(makeOpportunityItem({
        id: `mentorship:${item.id}`,
        kind: 'mentorship_request',
        source: 'networking',
        category: 'networking',
        score: 5000 + ageBonus(item.updated_at || item.created_at),
        priority_bucket: 'now',
        title: `${personName(item)} senden mentorluk bekliyor`,
        summary: String(item.focus_area || '').trim()
          ? `${String(item.focus_area).trim()} odağındaki talebi değerlendir.`
          : 'Bekleyen mentorluk talebini değerlendir.',
        why_now: 'Mentorluk talepleri sıcak kaldığında kabul ve devam oranı yükselir.',
        reasons: safeArray([
          'Bekleyen mentorluk talebi',
          String(item.message || '').trim() ? 'Kişisel mesaj eklendi' : ''
        ]).filter(Boolean),
        target: {
          href: `/new/network/hub?section=incoming-mentorship&request=${Number(item.id || 0)}`,
          label: 'Talebi incele'
        },
        primary_action: {
          kind: 'open',
          label: 'Talebi incele'
        },
        entity_type: 'mentorship_request',
        entity_id: item.id,
        created_at: item.updated_at || item.created_at
      }));
    }

    for (const item of safeArray(inbox?.connections?.incoming)) {
      items.push(makeOpportunityItem({
        id: `connection:${item.id}`,
        kind: 'connection_request',
        source: 'networking',
        category: 'networking',
        score: 4400 + ageBonus(item.updated_at || item.created_at),
        priority_bucket: 'now',
        title: `${personName(item)} bağlantı bekliyor`,
        summary: 'Bekleyen bağlantı isteğini netleştir ve networking kuyruğunu temizle.',
        why_now: 'Bağlantı kuyruğu büyüdükçe yeni mesaj ve keşif akışı dağılır.',
        reasons: ['Bekleyen bağlantı isteği'],
        target: {
          href: `/new/network/hub?section=incoming-connections&request=${Number(item.id || 0)}`,
          label: 'İsteği aç'
        },
        primary_action: {
          kind: 'open',
          label: 'İsteği aç'
        },
        entity_type: 'connection_request',
        entity_id: item.id,
        created_at: item.updated_at || item.created_at
      }));
    }

    for (const item of safeArray(inbox?.teacherLinks?.events).filter((event) => !event?.read_at)) {
      items.push(makeOpportunityItem({
        id: `teacher-link:${item.id}`,
        kind: 'teacher_link_update',
        source: 'teacher_network',
        category: 'updates',
        score: 3500 + ageBonus(item.created_at),
        priority_bucket: 'now',
        title: 'Öğretmen ağına yeni bir sinyal eklendi',
        summary: String(item.message || '').trim() || 'Teacher Network tarafında yeni bir kayıt oluştu.',
        why_now: 'Yeni güven sinyalleri üyelik graph’ını görünür biçimde güçlendirir.',
        reasons: ['Okunmamış öğretmen ağı bildirimi'],
        target: {
          href: `/new/network/hub?section=teacher-notifications&notification=${Number(item.id || 0)}`,
          label: 'Teacher Network aç'
        },
        primary_action: {
          kind: 'open',
          label: 'Teacher Network aç'
        },
        entity_type: 'notification',
        entity_id: item.id,
        created_at: item.created_at,
        read_at: item.read_at
      }));
    }

    for (const item of safeArray(discovery?.items).slice(0, 6)) {
      const reasons = safeArray(item.reasons);
      const badges = safeArray(item.trust_badges);
      items.push(makeOpportunityItem({
        id: `member-suggestion:${item.id}`,
        kind: 'member_suggestion',
        source: 'networking_discovery',
        category: 'networking',
        score: 1800 + (reasons.length * 40) + (badges.length * 15) + (Number(item.verified || 0) === 1 ? 20 : 0),
        priority_bucket: 'later',
        title: `${personName(item)} ile sıcak bir bağ kurabilirsin`,
        summary: String(item.mezuniyetyili || '').trim()
          ? `${String(item.mezuniyetyili).trim()} mezun grubundan güçlü bir aday.`
          : 'Mevcut graph sinyallerine göre sıcak bir networking adayı.',
        why_now: 'Mevcut graph sinyalleri bu kişiyi soğuk keşif yerine sıcak tanışma fırsatına çeviriyor.',
        reasons: [...reasons.slice(0, 3), ...badges.slice(0, 1)],
        target: {
          href: `/new/members/${Number(item.id || 0)}`,
          label: 'Profili aç'
        },
        primary_action: {
          kind: 'open',
          label: 'Profili aç'
        },
        entity_type: 'user',
        entity_id: item.id,
        created_at: new Date().toISOString()
      }));
    }

    items.push(...jobReviews, ...jobUpdates, ...jobRecommendations);

    const sorted = items.sort((left, right) => {
      if (right.score !== left.score) return right.score - left.score;
      const leftAt = Date.parse(String(left.created_at || '')) || 0;
      const rightAt = Date.parse(String(right.created_at || '')) || 0;
      if (rightAt !== leftAt) return rightAt - leftAt;
      return String(left.id).localeCompare(String(right.id));
    });

    const filtered = sorted.filter((item) => {
      if (normalizedTab === 'all') return true;
      if (normalizedTab === 'now') return item.priority_bucket === 'now';
      if (normalizedTab === 'networking') return item.category === 'networking';
      if (normalizedTab === 'jobs') return item.category === 'jobs';
      if (normalizedTab === 'updates') return item.category === 'updates';
      return true;
    });

    const pageItems = filtered.slice(offset, offset + safeLimit);
    const nextCursor = offset + pageItems.length < filtered.length ? String(offset + pageItems.length) : '';

    return {
      tab: normalizedTab,
      items: pageItems,
      hasMore: Boolean(nextCursor),
      next_cursor: nextCursor,
      summary: buildSummary(sorted)
    };
  }

  return {
    normalizeOpportunityInboxTab,
    buildOpportunityInboxPayload
  };
}
