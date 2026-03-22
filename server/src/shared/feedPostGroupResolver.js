import { HttpError } from './httpError.js';

function normalizePositiveId(value) {
  const parsed = Number.parseInt(String(value ?? '').trim(), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

export async function resolveFeedPostGroupId({
  requestedGroupId = null,
  feedType = '',
  authorId,
  findGraduationYearById,
  findGroupByName
}) {
  const explicitGroupId = normalizePositiveId(requestedGroupId);
  if (explicitGroupId) return explicitGroupId;

  if (String(feedType || '').trim().toLowerCase() !== 'community') {
    return null;
  }

  if (typeof findGraduationYearById !== 'function' || typeof findGroupByName !== 'function') {
    throw new Error('Community feed group resolution requires lookup functions.');
  }

  const graduationYear = Number(await findGraduationYearById(authorId));
  if (!Number.isFinite(graduationYear) || graduationYear <= 1900) {
    throw new HttpError(400, 'Topluluk akışı için mezuniyet yılı bulunamadı.');
  }

  const cohortGroup = await findGroupByName(`${graduationYear} Mezunları`);
  const cohortGroupId = normalizePositiveId(cohortGroup?.id);
  if (!cohortGroupId) {
    throw new HttpError(400, 'Topluluk akışı için uygun topluluk grubu bulunamadı.');
  }

  return cohortGroupId;
}
