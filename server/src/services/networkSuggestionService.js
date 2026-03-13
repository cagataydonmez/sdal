function safeLower(value) {
  return String(value || '').trim().toLowerCase();
}

export const networkSuggestionDefaultParams = Object.freeze({
  secondDegreeWeight: 18,
  maxSecondDegreeBonus: 54,
  sameGradBonus: 22,
  sameCityBonus: 8,
  sameUniversityBonus: 8,
  sameProfessionBonus: 5,
  followsViewerBonus: 10,
  sharedGroupWeight: 9,
  maxSharedGroupBonus: 18,
  directMentorshipBonus: 14,
  mentorshipOverlapWeight: 12,
  maxMentorshipOverlapBonus: 24,
  directTeacherBonus: 13,
  teacherOverlapWeight: 11,
  maxTeacherOverlapBonus: 22,
  engagementWeight: 0.2,
  maxEngagementBonus: 20,
  verifiedBonus: 2,
  onlineBonus: 1
});

export const networkSuggestionDefaultVariants = Object.freeze({
  A: {
    name: 'Baseline',
    description: 'Graph, trust ve engagement sinyallerini dengeli kullanan temel agirlik seti',
    trafficPct: 50,
    enabled: 1,
    params: { ...networkSuggestionDefaultParams }
  },
  B: {
    name: 'Trust Graph',
    description: 'Ogretmen ve mentorluk yakinligini one cikarip engagement etkisini azaltan deney seti',
    trafficPct: 50,
    enabled: 1,
    params: {
      ...networkSuggestionDefaultParams,
      sameGradBonus: 18,
      followsViewerBonus: 7,
      directMentorshipBonus: 18,
      mentorshipOverlapWeight: 15,
      maxMentorshipOverlapBonus: 28,
      directTeacherBonus: 18,
      teacherOverlapWeight: 15,
      maxTeacherOverlapBonus: 28,
      engagementWeight: 0.1,
      maxEngagementBonus: 12,
      verifiedBonus: 3
    }
  }
});

const networkSuggestionParamBounds = Object.freeze({
  secondDegreeWeight: [5, 30],
  maxSecondDegreeBonus: [10, 80],
  sameGradBonus: [0, 40],
  sameCityBonus: [0, 20],
  sameUniversityBonus: [0, 20],
  sameProfessionBonus: [0, 20],
  followsViewerBonus: [0, 20],
  sharedGroupWeight: [0, 20],
  maxSharedGroupBonus: [0, 40],
  directMentorshipBonus: [0, 30],
  mentorshipOverlapWeight: [0, 25],
  maxMentorshipOverlapBonus: [0, 40],
  directTeacherBonus: [0, 30],
  teacherOverlapWeight: [0, 25],
  maxTeacherOverlapBonus: [0, 40],
  engagementWeight: [0, 1],
  maxEngagementBonus: [0, 30],
  verifiedBonus: [0, 10],
  onlineBonus: [0, 10]
});

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function normalizeNetworkSuggestionParams(raw, fallback = networkSuggestionDefaultParams) {
  const source = raw && typeof raw === 'object' ? raw : {};
  const out = {};
  for (const [key, fallbackValue] of Object.entries(fallback)) {
    const nextValue = Number(source[key]);
    const range = networkSuggestionParamBounds[key];
    if (!range) {
      out[key] = Number.isFinite(nextValue) ? nextValue : fallbackValue;
      continue;
    }
    out[key] = Number.isFinite(nextValue) ? clamp(nextValue, range[0], range[1]) : fallbackValue;
  }
  return out;
}

function normalizedTextEquals(left, right) {
  const a = safeLower(left);
  const b = safeLower(right);
  return Boolean(a) && a === b;
}

export function buildMemberTrustBadges(member, options = {}) {
  const trustBadges = [];
  const isTeacherNetworkMember = options.isTeacherNetworkMember === true
    || Number(member?.teacher_network_member || 0) === 1
    || safeLower(member?.role) === 'teacher';

  if (Number(member?.verified || 0) === 1) trustBadges.push('verified_alumni');
  if (Number(member?.mentor_opt_in || 0) === 1) trustBadges.push('mentor');
  if (isTeacherNetworkMember) trustBadges.push('teacher_network');
  return trustBadges;
}

export function createPeerMap(rows, leftKey, rightKey) {
  const map = new Map();

  function addEdge(sourceId, targetId) {
    const source = Number(sourceId || 0);
    const target = Number(targetId || 0);
    if (!source || !target || source === target) return;
    if (!map.has(source)) map.set(source, new Set());
    map.get(source).add(target);
  }

  for (const row of rows || []) {
    addEdge(row?.[leftKey], row?.[rightKey]);
    addEdge(row?.[rightKey], row?.[leftKey]);
  }

  return map;
}

export function getPeerOverlapCount(map, sourceId, targetId) {
  const sourcePeers = map.get(Number(sourceId || 0));
  const targetPeers = map.get(Number(targetId || 0));
  if (!sourcePeers || !targetPeers || !sourcePeers.size || !targetPeers.size) return 0;

  let count = 0;
  for (const peer of sourcePeers) {
    if (targetPeers.has(peer)) count += 1;
  }
  return count;
}

export function scoreNetworkSuggestion({
  viewer,
  candidate,
  secondDegree = 0,
  followsViewer = false,
  sharedGroups = 0,
  mentorshipOverlap = 0,
  hasDirectMentorshipLink = false,
  teacherOverlap = 0,
  hasDirectTeacherLink = false,
  params = networkSuggestionDefaultParams
} = {}) {
  const scoringParams = normalizeNetworkSuggestionParams(params);
  let score = 0;
  const reasons = [];

  if (secondDegree > 0) {
    score += Math.min(Number(secondDegree || 0) * scoringParams.secondDegreeWeight, scoringParams.maxSecondDegreeBonus);
    reasons.push(`${secondDegree} ortak baglanti`);
  }

  if (Number(candidate?.mezuniyetyili || 0) > 0 && String(candidate?.mezuniyetyili || '') === String(viewer?.mezuniyetyili || '')) {
    score += scoringParams.sameGradBonus;
    reasons.push('Ayni mezuniyet yili');
  }
  if (normalizedTextEquals(viewer?.sehir, candidate?.sehir)) {
    score += scoringParams.sameCityBonus;
    reasons.push('Ayni sehir');
  }
  if (normalizedTextEquals(viewer?.universite, candidate?.universite)) {
    score += scoringParams.sameUniversityBonus;
    reasons.push('Ayni universite');
  }
  if (normalizedTextEquals(viewer?.meslek, candidate?.meslek)) {
    score += scoringParams.sameProfessionBonus;
    reasons.push('Benzer meslek');
  }
  if (followsViewer) {
    score += scoringParams.followsViewerBonus;
    reasons.push('Seni takip ediyor');
  }

  if (sharedGroups > 0) {
    score += Math.min(Number(sharedGroups || 0) * scoringParams.sharedGroupWeight, scoringParams.maxSharedGroupBonus);
    reasons.push(sharedGroups > 1 ? `${sharedGroups} ortak grup` : 'Ortak grup uyeligi');
  }

  if (hasDirectMentorshipLink) {
    score += scoringParams.directMentorshipBonus;
    reasons.push('Dogrudan mentorluk baglantisi');
  }
  if (mentorshipOverlap > 0) {
    score += Math.min(Number(mentorshipOverlap || 0) * scoringParams.mentorshipOverlapWeight, scoringParams.maxMentorshipOverlapBonus);
    reasons.push('Mentorluk aginda yakinlik');
  }

  const isTeacherNetworkMember = Boolean(hasDirectTeacherLink || teacherOverlap > 0 || safeLower(candidate?.role) === 'teacher');
  if (hasDirectTeacherLink) {
    score += scoringParams.directTeacherBonus;
    reasons.push('Dogrudan ogretmen agi baglantisi');
  }
  if (teacherOverlap > 0) {
    score += Math.min(Number(teacherOverlap || 0) * scoringParams.teacherOverlapWeight, scoringParams.maxTeacherOverlapBonus);
    reasons.push('Ogretmen aginda yakinlik');
  }

  const engagementScore = Number(candidate?.engagement_score || 0);
  if (engagementScore > 0) {
    score += Math.min(scoringParams.maxEngagementBonus, engagementScore * scoringParams.engagementWeight);
    if (engagementScore >= 70) reasons.push('Toplulukta aktif');
  }
  if (Number(candidate?.verified || 0) === 1) score += scoringParams.verifiedBonus;
  if (Number(candidate?.online || 0) === 1) score += scoringParams.onlineBonus;

  return {
    score,
    reasons: reasons.slice(0, 3),
    trustBadges: buildMemberTrustBadges(candidate, { isTeacherNetworkMember }),
    isTeacherNetworkMember
  };
}

export function sortNetworkSuggestions(items = []) {
  return [...items].sort((a, b) => {
    if (Number(b?.score || 0) !== Number(a?.score || 0)) return Number(b?.score || 0) - Number(a?.score || 0);
    if (Number(b?.online || 0) !== Number(a?.online || 0)) return Number(b?.online || 0) - Number(a?.online || 0);
    if (Number(b?.verified || 0) !== Number(a?.verified || 0)) return Number(b?.verified || 0) - Number(a?.verified || 0);
    return Number(b?.id || 0) - Number(a?.id || 0);
  });
}

export function buildScoredNetworkSuggestion(candidate, scoring = {}) {
  const suggestion = scoreNetworkSuggestion({
    viewer: scoring.viewer,
    candidate,
    secondDegree: scoring.secondDegree,
    followsViewer: scoring.followsViewer,
    sharedGroups: scoring.sharedGroups,
    mentorshipOverlap: scoring.mentorshipOverlap,
    hasDirectMentorshipLink: scoring.hasDirectMentorshipLink,
    teacherOverlap: scoring.teacherOverlap,
    hasDirectTeacherLink: scoring.hasDirectTeacherLink,
    params: scoring.params
  });

  return {
    ...candidate,
    score: suggestion.score,
    reasons: suggestion.reasons,
    trustBadges: suggestion.trustBadges
  };
}

export function mapNetworkSuggestionForApi(item) {
  return {
    id: item?.id,
    kadi: item?.kadi,
    isim: item?.isim,
    soyisim: item?.soyisim,
    resim: item?.resim,
    verified: item?.verified,
    mezuniyetyili: item?.mezuniyetyili,
    online: item?.online,
    role: item?.role,
    mentor_opt_in: Number(item?.mentor_opt_in || 0),
    reasons: Array.isArray(item?.reasons) ? item.reasons : [],
    trust_badges: Array.isArray(item?.trustBadges) ? item.trustBadges : []
  };
}
