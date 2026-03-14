export function createTeacherLinkModerationRuntime({
  sqlGet,
  sqlAll,
  sqlRun,
  normalizeCohortValue,
  roleAtLeast,
  TEACHER_NETWORK_MIN_CLASS_YEAR,
  TEACHER_NETWORK_MAX_CLASS_YEAR,
  TEACHER_COHORT_VALUE,
  normalizeTeacherAlumniRelationshipType,
  normalizeTeacherLinkCreatedVia,
  normalizeTeacherLinkSourceSurface,
  normalizeTeacherLinkReviewStatus,
  normalizeTeacherLinkReviewNote,
  ensureTeacherAlumniLinksTable,
  ensureTeacherAlumniLinkModerationEventsTable
}) {
  function clampTeacherLinkConfidenceScore(value) {
    const numeric = Number(value || 0);
    if (!Number.isFinite(numeric)) return 0.05;
    return Math.max(0.05, Math.min(0.99, numeric));
  }

  function roundTeacherLinkConfidenceScore(value) {
    return Number(clampTeacherLinkConfidenceScore(value).toFixed(2));
  }

  function computeTeacherLinkConfidenceScore(row, duplicateProximityCount = 0) {
    let score = 0.52;
    const createdVia = normalizeTeacherLinkCreatedVia(row?.created_via);
    const sourceSurface = normalizeTeacherLinkSourceSurface(row?.source_surface);
    const reviewStatus = normalizeTeacherLinkReviewStatus(row?.review_status) || 'pending';
    const teacherRole = String(row?.teacher_role || '').trim().toLowerCase();
    const teacherCohort = normalizeCohortValue(row?.teacher_cohort);

    if (createdVia === 'manual_alumni_link') score += 0.08;
    if (createdVia === 'import') score += 0.03;
    if (sourceSurface === 'member_detail_page') score += 0.08;
    else if (sourceSurface === 'teachers_network_page') score += 0.04;
    else if (sourceSurface === 'network_hub') score += 0.03;
    if (Number(row?.teacher_verified || 0) === 1 || teacherRole === 'teacher' || teacherCohort === TEACHER_COHORT_VALUE || roleAtLeast(teacherRole, 'admin')) score += 0.16;
    if (Number(row?.alumni_verified || 0) === 1) score += 0.06;
    if (row?.class_year !== null && row?.class_year !== undefined && String(row.class_year).trim() !== '') score += 0.05;
    if (String(row?.notes || '').trim().length >= 12) score += 0.04;
    if (String(row?.relationship_type || '').trim().toLowerCase() === 'mentor') score += 0.05;
    if (reviewStatus === 'confirmed') score += 0.18;
    if (reviewStatus === 'flagged') score -= 0.28;

    const duplicatePenalty = Math.min(0.25, Math.max(0, Number(duplicateProximityCount || 0)) * 0.09);
    score -= duplicatePenalty;
    return roundTeacherLinkConfidenceScore(score);
  }

  function isTeacherLinkActiveStatus(value) {
    const status = normalizeTeacherLinkReviewStatus(value) || 'pending';
    return status !== 'rejected' && status !== 'merged';
  }

  function canTransitionTeacherLinkReviewStatus(currentStatus, nextStatus) {
    const current = normalizeTeacherLinkReviewStatus(currentStatus) || 'pending';
    const next = normalizeTeacherLinkReviewStatus(nextStatus);
    if (!next) return false;
    const allowedTransitions = {
      pending: ['confirmed', 'flagged', 'rejected', 'merged'],
      confirmed: ['pending', 'flagged', 'rejected', 'merged'],
      flagged: ['pending', 'confirmed', 'rejected', 'merged'],
      rejected: ['pending', 'confirmed', 'flagged'],
      merged: ['pending', 'confirmed', 'flagged']
    };
    return allowedTransitions[current]?.includes(next) || false;
  }

  function selectTeacherLinkMergeTarget(linkId, teacherUserId, alumniUserId, requestedTargetId = 0) {
    const safeLinkId = Number(linkId || 0);
    const safeTeacherUserId = Number(teacherUserId || 0);
    const safeAlumniUserId = Number(alumniUserId || 0);
    const safeRequestedTargetId = Number(requestedTargetId || 0);
    if (!safeLinkId || !safeTeacherUserId || !safeAlumniUserId) return null;

    if (safeRequestedTargetId > 0 && safeRequestedTargetId !== safeLinkId) {
      return sqlGet(
        `SELECT id, review_status
         FROM teacher_alumni_links
         WHERE id = ?
           AND teacher_user_id = ?
           AND alumni_user_id = ?
           AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
         LIMIT 1`,
        [safeRequestedTargetId, safeTeacherUserId, safeAlumniUserId]
      ) || null;
    }

    return sqlGet(
      `SELECT id, review_status
       FROM teacher_alumni_links
       WHERE teacher_user_id = ?
         AND alumni_user_id = ?
         AND id <> ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
       ORDER BY CASE WHEN COALESCE(review_status, 'pending') = 'confirmed' THEN 0 ELSE 1 END ASC,
                COALESCE(confidence_score, 0) DESC,
                COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') DESC,
                id DESC
       LIMIT 1`,
      [safeTeacherUserId, safeAlumniUserId, safeLinkId]
    ) || null;
  }

  function logTeacherLinkModerationEvent({ linkId, actorUserId = null, eventType, fromStatus = '', toStatus = '', note = '', mergeTargetId = null }) {
    const safeLinkId = Number(linkId || 0);
    const safeMergeTargetId = Number(mergeTargetId || 0) || null;
    const safeEventType = String(eventType || '').trim().slice(0, 64);
    if (!safeLinkId || !safeEventType) return;
    ensureTeacherAlumniLinkModerationEventsTable();
    sqlRun(
      `INSERT INTO teacher_alumni_link_moderation_events
         (link_id, actor_user_id, event_type, from_status, to_status, note, merge_target_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        safeLinkId,
        Number(actorUserId || 0) || null,
        safeEventType,
        normalizeTeacherLinkReviewStatus(fromStatus) || null,
        normalizeTeacherLinkReviewStatus(toStatus) || null,
        normalizeTeacherLinkReviewNote(note) || null,
        safeMergeTargetId,
        new Date().toISOString()
      ]
    );
  }

  function buildTeacherLinkModerationAssessment(row) {
    const reviewStatus = normalizeTeacherLinkReviewStatus(row?.review_status) || 'pending';
    const confidenceScore = Number(row?.confidence_score || 0);
    const noteLength = String(row?.notes || '').trim().length;
    const classYearPresent = row?.class_year !== null && row?.class_year !== undefined && String(row.class_year).trim() !== '';
    const duplicateActiveCount = Math.max(0, Number(row?.active_pair_link_count || 0) - 1);
    const teacherVerified = Number(row?.teacher_verified || 0) === 1;
    const alumniVerified = Number(row?.alumni_verified || 0) === 1;
    const createdVia = normalizeTeacherLinkCreatedVia(row?.created_via);
    const sourceSurface = normalizeTeacherLinkSourceSurface(row?.source_surface);

    const riskSignals = [];
    const positiveSignals = [];
    let riskScore = 0;

    if (confidenceScore < 0.45) {
      riskSignals.push({ code: 'low_confidence', label: 'Confidence score is low', severity: 'high' });
      riskScore += 3;
    } else if (confidenceScore < 0.65) {
      riskSignals.push({ code: 'medium_confidence', label: 'Confidence score needs review', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'healthy_confidence', label: 'Confidence score is strong' });
    }

    if (!classYearPresent) {
      riskSignals.push({ code: 'missing_class_year', label: 'Class year is missing', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'class_year_present', label: 'Class year is provided' });
    }

    if (noteLength === 0) {
      riskSignals.push({ code: 'missing_notes', label: 'No supporting note was added', severity: 'high' });
      riskScore += 2;
    } else if (noteLength < 12) {
      riskSignals.push({ code: 'short_notes', label: 'Supporting note is very short', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'detailed_notes', label: 'Supporting note adds context' });
    }

    if (duplicateActiveCount > 0) {
      riskSignals.push({ code: 'duplicate_active_pair', label: 'Another active link exists for the same teacher-alumni pair', severity: 'high' });
      riskScore += 3;
    } else {
      positiveSignals.push({ code: 'single_active_pair_record', label: 'No competing active duplicate exists' });
    }

    if (teacherVerified) positiveSignals.push({ code: 'teacher_verified', label: 'Teacher account is verified' });
    else {
      riskSignals.push({ code: 'teacher_unverified', label: 'Teacher account is not verified', severity: 'medium' });
      riskScore += 1;
    }

    if (alumniVerified) positiveSignals.push({ code: 'alumni_verified', label: 'Alumni account is verified' });
    else {
      riskSignals.push({ code: 'alumni_unverified', label: 'Alumni account is not verified', severity: 'medium' });
      riskScore += 1;
    }

    if (createdVia === 'import') {
      riskSignals.push({ code: 'imported_record', label: 'Record came from import flow', severity: 'medium' });
      riskScore += 1;
    } else {
      positiveSignals.push({ code: 'manual_submission', label: 'Record was submitted manually' });
    }

    if (sourceSurface === 'member_detail_page') {
      positiveSignals.push({ code: 'contextual_source_surface', label: 'Created from a contextual member detail flow' });
    }

    if (reviewStatus === 'flagged') {
      riskSignals.push({ code: 'previously_flagged', label: 'Record is already flagged', severity: 'high' });
      riskScore += 2;
    }

    const riskLevel = riskScore >= 6 ? 'high' : riskScore >= 3 ? 'medium' : 'low';
    let recommendedAction = 'keep_pending';
    let recommendationLabel = 'Keep pending';
    let decisionHint = 'Needs another moderation pass.';

    if (reviewStatus === 'merged') {
      recommendedAction = 'keep_merged';
      recommendationLabel = 'Keep merged';
      decisionHint = 'This record is already merged into another active link.';
    } else if (reviewStatus === 'rejected') {
      recommendedAction = 'keep_rejected';
      recommendationLabel = 'Keep rejected';
      decisionHint = 'This record is already removed from the active graph.';
    } else if (duplicateActiveCount > 0) {
      recommendedAction = 'merge';
      recommendationLabel = 'Merge';
      decisionHint = 'A duplicate active pair exists. Prefer merging instead of keeping two active claims.';
    } else if (confidenceScore >= 0.75 && teacherVerified && alumniVerified && (classYearPresent || noteLength >= 18)) {
      recommendedAction = 'confirm';
      recommendationLabel = 'Confirm';
      decisionHint = 'Signals are strong enough to confirm the teacher-alumni relationship.';
    } else if (riskLevel === 'high') {
      recommendedAction = 'flag';
      recommendationLabel = 'Flag';
      decisionHint = 'Too many risk signals are present for an auto-confirm decision.';
    }

    return {
      confidence_score: confidenceScore,
      risk_level: riskLevel,
      risk_signals: riskSignals,
      positive_signals: positiveSignals,
      recommended_action: recommendedAction,
      recommendation_label: recommendationLabel,
      decision_hint: decisionHint
    };
  }

  function refreshTeacherLinkConfidenceScore(linkId) {
    const safeLinkId = Number(linkId || 0);
    if (!safeLinkId) return null;
    ensureTeacherAlumniLinksTable();
    const row = sqlGet(
      `SELECT l.id, l.teacher_user_id, l.alumni_user_id, l.relationship_type, l.class_year, l.notes,
              l.created_via, l.source_surface, COALESCE(l.review_status, 'pending') AS review_status,
              teacher.verified AS teacher_verified, teacher.role AS teacher_role, teacher.mezuniyetyili AS teacher_cohort,
              alumni.verified AS alumni_verified,
              (SELECT COUNT(*) FROM teacher_alumni_links pair_link
                WHERE pair_link.teacher_user_id = l.teacher_user_id
                  AND pair_link.alumni_user_id = l.alumni_user_id
                  AND pair_link.id <> l.id
                  AND COALESCE(pair_link.review_status, 'pending') NOT IN ('rejected', 'merged')) AS duplicate_proximity_count
       FROM teacher_alumni_links l
       LEFT JOIN uyeler teacher ON teacher.id = l.teacher_user_id
       LEFT JOIN uyeler alumni ON alumni.id = l.alumni_user_id
       WHERE l.id = ?`,
      [safeLinkId]
    );
    if (!row) return null;
    const nextScore = computeTeacherLinkConfidenceScore(row, Number(row?.duplicate_proximity_count || 0));
    sqlRun('UPDATE teacher_alumni_links SET confidence_score = ? WHERE id = ?', [nextScore, safeLinkId]);
    return nextScore;
  }

  function listTeacherLinkPairDuplicates(alumniUserId, teacherUserId) {
    const safeAlumniUserId = Number(alumniUserId || 0);
    const safeTeacherUserId = Number(teacherUserId || 0);
    if (!safeAlumniUserId || !safeTeacherUserId) return [];
    return sqlAll(
      `SELECT id, relationship_type, class_year, notes, created_at,
              COALESCE(review_status, 'pending') AS review_status,
              confidence_score
       FROM teacher_alumni_links
       WHERE alumni_user_id = ?
         AND teacher_user_id = ?
         AND COALESCE(review_status, 'pending') NOT IN ('rejected', 'merged')
       ORDER BY COALESCE(CASE WHEN CAST(created_at AS TEXT) = '' THEN NULL ELSE created_at END, '1970-01-01T00:00:00.000Z') DESC, id DESC`,
      [safeAlumniUserId, safeTeacherUserId]
    ) || [];
  }

  return {
    isTeacherLinkActiveStatus,
    canTransitionTeacherLinkReviewStatus,
    selectTeacherLinkMergeTarget,
    logTeacherLinkModerationEvent,
    buildTeacherLinkModerationAssessment,
    refreshTeacherLinkConfidenceScore,
    listTeacherLinkPairDuplicates
  };
}
