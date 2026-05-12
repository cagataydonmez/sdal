export const PUBLICATION_STATUS = Object.freeze({
  DRAFT: 'draft',
  PENDING: 'pending_publication',
  PUBLISHED: 'published',
  UNPUBLISHED: 'unpublished'
});

export const APPROVAL_STATUS = Object.freeze({
  NOT_REQUIRED: 'not_required',
  PENDING: 'pending',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  CHANGES_REQUESTED: 'changes_requested'
});

export const APPROVAL_ENTITY_TYPES = new Set([
  'event',
  'announcement',
  'job',
  'group_event',
  'group_announcement',
  'group_post'
]);

export function isTruthy(value) {
  if (value === true) return true;
  if (value === false || value == null) return false;
  const raw = String(value).trim().toLowerCase();
  return ['1', 'true', 'evet', 'yes', 'on'].includes(raw);
}

export function isFalseyInput(value) {
  if (value === false) return true;
  if (value === true || value == null) return false;
  const raw = String(value).trim().toLowerCase();
  return ['0', 'false', 'hayir', 'hayır', 'no', 'off'].includes(raw);
}

export function wantsPublish(body = {}) {
  if (Object.prototype.hasOwnProperty.call(body, 'publish')) return isTruthy(body.publish);
  if (Object.prototype.hasOwnProperty.call(body, 'published')) return isTruthy(body.published);
  if (Object.prototype.hasOwnProperty.call(body, 'approved')) return isTruthy(body.approved);
  if (Object.prototype.hasOwnProperty.call(body, 'show_in_feed')) return !isFalseyInput(body.show_in_feed);
  return true;
}

export function wantsShowInFeed(body = {}) {
  if (Object.prototype.hasOwnProperty.call(body, 'show_in_feed')) return !isFalseyInput(body.show_in_feed);
  if (Object.prototype.hasOwnProperty.call(body, 'showInFeed')) return !isFalseyInput(body.showInFeed);
  return true;
}

export function normalizePublicationStatus(value, fallback = PUBLICATION_STATUS.PUBLISHED) {
  const raw = String(value || '').trim().toLowerCase();
  return Object.values(PUBLICATION_STATUS).includes(raw) ? raw : fallback;
}

export function normalizeApprovalStatus(value, fallback = APPROVAL_STATUS.NOT_REQUIRED) {
  const raw = String(value || '').trim().toLowerCase();
  return Object.values(APPROVAL_STATUS).includes(raw) ? raw : fallback;
}

export async function isApprovalRequired({ sqlGetAsync, entityType, groupId = null }) {
  if (!APPROVAL_ENTITY_TYPES.has(entityType)) return false;
  try {
    const row = await sqlGetAsync(
      `SELECT approval_required
       FROM content_approval_settings
       WHERE entity_type = ? AND COALESCE(group_id, 0) = COALESCE(?, 0)
       ORDER BY updated_at DESC, id DESC
       LIMIT 1`,
      [entityType, groupId]
    );
    return isTruthy(row?.approval_required);
  } catch {
    return false;
  }
}

export async function buildInitialContentState({
  sqlGetAsync,
  entityType,
  groupId = null,
  body = {},
  actorIsTrusted = false
}) {
  const publish = wantsPublish(body);
  const showInFeed = wantsShowInFeed(body);
  if (!publish) {
    return {
      publicationStatus: PUBLICATION_STATUS.DRAFT,
      approvalStatus: APPROVAL_STATUS.NOT_REQUIRED,
      showInFeed
    };
  }
  const approvalRequired = !actorIsTrusted && await isApprovalRequired({ sqlGetAsync, entityType, groupId });
  return {
    publicationStatus: approvalRequired ? PUBLICATION_STATUS.PENDING : PUBLICATION_STATUS.PUBLISHED,
    approvalStatus: approvalRequired ? APPROVAL_STATUS.PENDING : APPROVAL_STATUS.NOT_REQUIRED,
    showInFeed
  };
}

export function canSeeContent(row, { actorId, isAdmin = false, isManager = false } = {}) {
  const publicationStatus = normalizePublicationStatus(row?.publication_status, row?.approved === 0 || row?.approved === false ? PUBLICATION_STATUS.PENDING : PUBLICATION_STATUS.PUBLISHED);
  const approvalStatus = normalizeApprovalStatus(row?.approval_status, APPROVAL_STATUS.NOT_REQUIRED);
  if (publicationStatus === PUBLICATION_STATUS.PUBLISHED
    && approvalStatus !== APPROVAL_STATUS.PENDING
    && approvalStatus !== APPROVAL_STATUS.REJECTED
    && approvalStatus !== APPROVAL_STATUS.CHANGES_REQUESTED) return true;
  if (isAdmin || isManager) return true;
  return Number(row?.created_by || row?.poster_id || 0) === Number(actorId || 0);
}

export function isFeedVisible(row) {
  const publicationStatus = normalizePublicationStatus(row?.publication_status, row?.approved === 0 || row?.approved === false ? PUBLICATION_STATUS.PENDING : PUBLICATION_STATUS.PUBLISHED);
  const approvalStatus = normalizeApprovalStatus(row?.approval_status, APPROVAL_STATUS.NOT_REQUIRED);
  return publicationStatus === PUBLICATION_STATUS.PUBLISHED
    && approvalStatus !== APPROVAL_STATUS.PENDING
    && approvalStatus !== APPROVAL_STATUS.REJECTED
    && approvalStatus !== APPROVAL_STATUS.CHANGES_REQUESTED
    && Number(row?.show_in_feed ?? 1) !== 0;
}

export function publicQuery(alias = '', hasApprovedColumn = true) {
  const p = alias ? `${alias}.` : '';
  const approvedFallback = hasApprovedColumn
    ? `CASE WHEN LOWER(COALESCE(CAST(${p}approved AS TEXT), 'true')) IN ('1','true','evet','yes') THEN 'published' ELSE 'pending_publication' END`
    : "'published'";
  return `COALESCE(${p}publication_status, ${approvedFallback}) = 'published'
    AND COALESCE(${p}approval_status, 'not_required') NOT IN ('pending', 'rejected', 'changes_requested')`;
}
