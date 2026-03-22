import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { readApiPayload } from '../utils/api.js';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';
import { NETWORKING_MESSAGES } from '../utils/networkingRegistry.js';
import { NETWORKING_TELEMETRY_EVENTS, sendNetworkingTelemetry } from '../utils/networkingTelemetry.js';
import { useI18n } from '../utils/i18n.jsx';

function relationshipLabel(value, relationshipTypes) {
  return relationshipTypes.find((item) => item.value === value)?.label || value;
}

function teacherOptionLabel(teacher) {
  const fullName = [teacher?.isim, teacher?.soyisim].filter(Boolean).join(' ').trim();
  return fullName ? `@${teacher.kadi} · ${fullName}` : `@${teacher.kadi || 'ogretmen'}`;
}

function reviewStatusLabel(t, value) {
  const status = String(value || '').trim().toLowerCase();
  if (status === 'confirmed') return t('teacher_review_confirmed');
  if (status === 'flagged') return t('teacher_review_flagged');
  if (status === 'rejected') return t('teacher_review_rejected');
  if (status === 'merged') return t('teacher_review_merged');
  return t('teacher_review_pending');
}

function reviewOutcomeMessage(t, value) {
  const status = String(value || '').trim().toLowerCase();
  if (status === 'confirmed') return t('teacher_message_confirmed');
  if (status === 'flagged') return t('teacher_message_flagged');
  if (status === 'rejected') return t('teacher_message_rejected');
  if (status === 'merged') return t('teacher_message_merged');
  return t('teacher_message_pending');
}

function confidenceLabel(t, value) {
  const score = Number(value || 0);
  if (!Number.isFinite(score) || score <= 0) return t('teacher_confidence_unknown');
  return t('teacher_confidence_label', { score: (score * 100).toFixed(0) });
}

function parseOptionList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export default function TeachersNetworkPage() {
  const { t } = useI18n();
  const [searchParams] = useSearchParams();
  const deepLinkedTeacherId = Math.max(parseInt(searchParams.get('teacherId') || '0', 10), 0);
  const highlightedLinkId = Math.max(parseInt(searchParams.get('link') || '0', 10), 0);
  const notificationId = Math.max(parseInt(searchParams.get('notification') || '0', 10), 0);
  const reviewParam = String(searchParams.get('review') || '').trim().toLowerCase();
  const [direction, setDirection] = useState('my_teachers');
  const [relationshipType, setRelationshipType] = useState('');
  const [classYear, setClassYear] = useState('');
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [offset, setOffset] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [teacherOptions, setTeacherOptions] = useState([]);
  const [teacherSearch, setTeacherSearch] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [similarWarning, setSimilarWarning] = useState(null);
  const historyCardRefs = useRef(new Map());

  const RELATIONSHIP_TYPES = useMemo(() => [
    { value: 'taught_in_class', label: t('teacher_relationship_class') },
    { value: 'mentor', label: t('teacher_relationship_mentor') },
    { value: 'advisor', label: t('teacher_relationship_advisor') }
  ], [t]);

  const RELATIONSHIP_HELPERS = useMemo(() => ({
    taught_in_class: t('teacher_helper_class'),
    mentor: t('teacher_helper_mentor'),
    advisor: t('teacher_helper_advisor')
  }), [t]);

  const [form, setForm] = useState({
    teacherId: deepLinkedTeacherId > 0 ? String(deepLinkedTeacherId) : '',
    relationship_type: 'taught_in_class',
    class_year: '',
    notes: ''
  });

  const years = useMemo(() => {
    const now = new Date().getFullYear();
    const all = [];
    for (let y = now; y >= 1999; y -= 1) all.push(String(y));
    return all;
  }, []);

  const selectedTeacher = teacherOptions.find((teacher) => String(teacher.id) === String(form.teacherId));
  const selectedTeacherExistingTypes = parseOptionList(selectedTeacher?.existing_relationship_types);
  const selectedTeacherExistingYears = parseOptionList(selectedTeacher?.existing_class_years);
  const activeHistoryTitle = direction === 'my_teachers' ? t('teacher_history_my_teachers_title') : t('teacher_history_my_students_title');
  const activeHistorySubtitle = direction === 'my_teachers'
    ? t('teacher_history_my_teachers_desc')
    : t('teacher_history_my_students_desc');
  const relationshipHelper = RELATIONSHIP_HELPERS[form.relationship_type] || RELATIONSHIP_HELPERS.taught_in_class;
  const notificationLandingResolved = !notificationId || (
    highlightedLinkId > 0
      ? Boolean(reviewParam) || items.some((item) => Number(item.id || 0) === highlightedLinkId)
      : true
  );

  useNotificationNavigationTracking(notificationId, {
    surface: 'teachers_network_page',
    resolved: notificationLandingResolved
  });

  const loadTeacherOptions = useCallback(async (term = '') => {
    try {
      const params = new URLSearchParams();
      params.set('limit', '30');
      if (term) params.set('term', term);
      if (deepLinkedTeacherId > 0) params.set('include_id', String(deepLinkedTeacherId));
      const res = await fetch(`/api/new/teachers/options?${params.toString()}`, { credentials: 'include' });
      const { data, message } = await readApiPayload(res, NETWORKING_MESSAGES.errors.teacherOptionsLoadFailed);
      if (!res.ok) throw new Error(message);
      const nextItems = data?.items || [];
      setTeacherOptions(nextItems);
      if (deepLinkedTeacherId > 0) {
        const hasDeepLinkedTeacher = nextItems.some((teacher) => Number(teacher.id) === deepLinkedTeacherId);
        if (hasDeepLinkedTeacher) {
          setForm((prev) => (prev.teacherId ? prev : { ...prev, teacherId: String(deepLinkedTeacherId) }));
        }
      }
    } catch {
      setTeacherOptions([]);
    }
  }, [deepLinkedTeacherId]);

  const load = useCallback(async (nextOffset = 0, append = false) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      params.set('direction', direction);
      params.set('limit', '20');
      params.set('offset', String(nextOffset));
      if (relationshipType) params.set('relationship_type', relationshipType);
      if (classYear) params.set('class_year', classYear);
      const res = await fetch(`/api/new/teachers/network?${params.toString()}`, { credentials: 'include' });
      const { message, data } = await readApiPayload(res, NETWORKING_MESSAGES.errors.teacherNetworkLoadFailed);
      if (!res.ok) throw new Error(message);
      const nextItems = data?.items || [];
      setItems((prev) => (append ? [...prev, ...nextItems] : nextItems));
      setOffset(nextOffset + nextItems.length);
      setHasMore(Boolean(data?.hasMore));
    } catch (err) {
      setError(err.message || NETWORKING_MESSAGES.errors.teacherNetworkLoadFailed);
    } finally {
      setLoading(false);
    }
  }, [classYear, direction, relationshipType]);

  useEffect(() => {
    void sendNetworkingTelemetry({
      eventName: NETWORKING_TELEMETRY_EVENTS.teacherNetworkViewed,
      sourceSurface: 'teachers_network_page',
      targetUserId: deepLinkedTeacherId || null,
      entityType: deepLinkedTeacherId > 0 ? 'user' : '',
      entityId: deepLinkedTeacherId || null
    });
  }, [deepLinkedTeacherId]);

  useEffect(() => {
    loadTeacherOptions('');
  }, [loadTeacherOptions]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadTeacherOptions(teacherSearch);
    }, 250);
    return () => clearTimeout(timer);
  }, [teacherSearch, loadTeacherOptions]);

  useEffect(() => {
    load(0, false);
  }, [load]);

  useEffect(() => {
    if (!highlightedLinkId || !items.length) return;
    const timer = window.setTimeout(() => {
      const node = historyCardRefs.current.get(highlightedLinkId);
      node?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [highlightedLinkId, items]);

  useEffect(() => {
    setSimilarWarning(null);
  }, [form.teacherId, form.relationship_type, form.class_year]);

  async function submitLink(e, { confirmSimilar = false } = {}) {
    e.preventDefault();
    setError('');
    setStatus('');
    const teacherId = Number(form.teacherId || 0);
    if (!teacherId) {
      setError(t('teacher_error_select'));
      return;
    }
    const body = {
      relationship_type: form.relationship_type,
      notes: String(form.notes || '').trim(),
      created_via: 'manual_alumni_link',
      source_surface: deepLinkedTeacherId > 0 ? 'member_detail_page' : 'teachers_network_page'
    };
    if (confirmSimilar) body.confirm_similar = true;
    const selectedClassYear = Number(form.class_year || 0);
    if (selectedClassYear >= 1950 && selectedClassYear <= 2100) body.class_year = selectedClassYear;

    setSubmitting(true);
    try {
      const res = await fetch(`/api/new/teachers/network/link/${teacherId}`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      const { message, payload, data } = await readApiPayload(res, NETWORKING_MESSAGES.errors.teacherLinkCreateFailed);
      if (!res.ok) {
        if (payload?.code === 'SIMILAR_RELATIONSHIP_EXISTS') {
          setSimilarWarning({
            message,
            links: data?.similar_links || payload?.similar_links || [],
            requiresConfirmation: Boolean(data?.requires_confirmation || payload?.requires_confirmation)
          });
          return;
        }
        setError(message);
        return;
      }
      setSimilarWarning(null);
      setStatus(message || NETWORKING_MESSAGES.success.teacherLinkCreated);
      setForm((prev) => ({
        ...prev,
        teacherId: '',
        relationship_type: 'taught_in_class',
        class_year: '',
        notes: ''
      }));
      await Promise.all([load(0, false), loadTeacherOptions(teacherSearch)]);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Layout title={t('teacher_page_title')}>
      <section className="network-hero network-hero-teachers">
        <div className="network-hero-copy">
          <span className="network-eyebrow">Teacher network graph</span>
          <h2>{t('teacher_section_manage_title')}</h2>
          <p>{t('teacher_section_manage_description')}</p>
        </div>
        <div className="network-hero-actions">
          <Link className="btn primary" to="/new/network/hub">{t('teacher_action_back_hub')}</Link>
          <Link className="btn ghost" to="/new/explore">{t('teacher_action_discover')}</Link>
        </div>
      </section>

      <div className="network-dashboard network-dashboard-tight">
        <div className="panel network-panel-emphasis">
          <div className="network-section-head">
            <div>
              <span className="network-section-kicker">{t('teacher_form_section_kicker')}</span>
              <h3>{t('teacher_form_section_title')}</h3>
              <p>{t('teacher_form_section_description')}</p>
            </div>
            {deepLinkedTeacherId > 0 ? <span className="chip">{t('teacher_form_prefilled_chip')}</span> : null}
          </div>
          <div className="panel-body">
            {highlightedLinkId > 0 && reviewParam ? (
              <div className="network-soft-alert">
                <strong>{reviewStatusLabel(t, reviewParam)}</strong>
                <div>{reviewOutcomeMessage(t, reviewParam)}</div>
              </div>
            ) : null}
            <form className="network-form-grid" onSubmit={submitLink}>
              <div className="form-row">
                <label>{t('teacher_form_label_search')}</label>
                <input
                  className="input"
                  placeholder={t('teacher_form_search_placeholder')}
                  value={teacherSearch}
                  onChange={(e) => setTeacherSearch(e.target.value)}
                />
              </div>
              <div className="form-row">
                <label>{t('teacher_form_label_select')}</label>
                <select
                  className="input"
                  value={form.teacherId}
                  onChange={(e) => setForm((prev) => ({ ...prev, teacherId: e.target.value }))}
                  required
                >
                  <option value="">{t('teacher_form_select_placeholder')}</option>
                  {teacherOptions.map((teacher) => (
                    <option key={teacher.id} value={teacher.id}>
                      {teacherOptionLabel(teacher)}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>{t('teacher_form_label_relationship')}</label>
                <select
                  className="input"
                  value={form.relationship_type}
                  onChange={(e) => setForm((prev) => ({ ...prev, relationship_type: e.target.value }))}
                >
                  {RELATIONSHIP_TYPES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
                </select>
                <span className="network-field-hint">{relationshipHelper}</span>
              </div>
              <div className="form-row">
                <label>{t('teacher_form_label_year')}</label>
                <select
                  className="input"
                  value={form.class_year}
                  onChange={(e) => setForm((prev) => ({ ...prev, class_year: e.target.value }))}
                >
                  <option value="">{t('teacher_form_year_placeholder')}</option>
                  {years.map((y) => <option key={y} value={y}>{y}</option>)}
                </select>
              </div>
              <div className="form-row network-form-wide">
                <label>{t('teacher_form_label_notes')}</label>
                <textarea
                  className="input"
                  value={form.notes}
                  onChange={(e) => setForm((prev) => ({ ...prev, notes: e.target.value }))}
                  maxLength={500}
                  placeholder={t('teacher_form_notes_placeholder')}
                />
              </div>
              <div className="network-form-footer">
                <button className="btn primary" type="submit" disabled={submitting}>
                  {submitting ? t('teacher_form_saving') : t('teacher_form_submit')}
                </button>
                <span className="muted">{t('teacher_form_hint')}</span>
              </div>
            </form>
            {similarWarning?.links?.length ? (
              <div className="network-soft-alert">
                <strong>{t('teacher_warning_similar_title')}</strong>
                <div>{similarWarning.message}</div>
                <div className="network-guidance-list">
                  {similarWarning.links.map((item) => (
                    <div key={item.id} className="network-guidance-item">
                      <strong>{relationshipLabel(item.relationship_type, RELATIONSHIP_TYPES)} {item.class_year ? `· ${item.class_year}` : ''}</strong>
                      <span>{reviewStatusLabel(t, item.review_status)} · {confidenceLabel(t, item.confidence_score)}</span>
                    </div>
                  ))}
                </div>
                {similarWarning.requiresConfirmation ? (
                  <div className="composer-actions">
                    <button className="btn ghost" type="button" onClick={() => setSimilarWarning(null)}>
                      {t('teacher_action_cancel')}
                    </button>
                    <button className="btn primary" type="button" disabled={submitting} onClick={(event) => submitLink(event, { confirmSimilar: true })}>
                      {t('teacher_action_confirm_similar')}
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error">{error}</div> : null}
          </div>
        </div>

        <div className="network-column">
          <div className="panel">
            <div className="network-section-head">
              <div>
                <span className="network-section-kicker">{t('teacher_value_panel_kicker')}</span>
                <h3>{t('teacher_value_panel_title')}</h3>
                <p>{t('teacher_value_panel_description')}</p>
              </div>
            </div>
            <div className="panel-body stack">
              <div className="network-value-list">
                <div className="network-value-card">
                  <strong>{t('teacher_value_1_title')}</strong>
                  <span>{t('teacher_value_1_description')}</span>
                </div>
                <div className="network-value-card">
                  <strong>{t('teacher_value_2_title')}</strong>
                  <span>{t('teacher_value_2_description')}</span>
                </div>
                <div className="network-value-card">
                  <strong>{t('teacher_value_3_title')}</strong>
                  <span>{t('teacher_value_3_description')}</span>
                </div>
                <div className="network-value-card">
                  <strong>{t('teacher_value_4_title')}</strong>
                  <span>{t('teacher_value_4_description')}</span>
                </div>
              </div>
              <div className="network-guidance-list">
                <div className="network-guidance-item">
                  <strong>{t('teacher_guidance_when_title')}</strong>
                  <span>{t('teacher_guidance_when_description')}</span>
                </div>
                <div className="network-guidance-item">
                  <strong>{t('teacher_guidance_for_title')}</strong>
                  <span>{t('teacher_guidance_for_description')}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="panel">
            <div className="network-section-head">
              <div>
                <span className="network-section-kicker">{t('teacher_preview_section_title')}</span>
                <h3>{t('teacher_preview_title')}</h3>
                <p>{t('teacher_preview_description')}</p>
              </div>
            </div>
            <div className="panel-body stack">
              {selectedTeacher ? (
                <div className="network-highlight-card">
                  <div className="network-highlight-title">{teacherOptionLabel(selectedTeacher)}</div>
                  <div className="network-highlight-meta">
                    <span className="chip">{t('teacher_preview_student_count', { count: selectedTeacher.student_count || 0 })}</span>
                    {selectedTeacher.mezuniyetyili ? <span className="chip">{t('teacher_preview_cohort', { year: selectedTeacher.mezuniyetyili })}</span> : null}
                    {Number(selectedTeacher.existing_link_count || 0) > 0 ? <span className="chip">{t('teacher_preview_existing_link', { count: selectedTeacher.existing_link_count })}</span> : null}
                  </div>
                  <p className="muted">{t('teacher_preview_notification')}</p>
                  {Number(selectedTeacher.existing_link_count || 0) > 0 ? (
                    <div className="network-guidance-list">
                      {selectedTeacherExistingTypes.length ? (
                        <div className="network-guidance-item">
                          <strong>{t('teacher_preview_existing_types')}</strong>
                          <span>{selectedTeacherExistingTypes.join(', ')}</span>
                        </div>
                      ) : null}
                      {selectedTeacherExistingYears.length ? (
                        <div className="network-guidance-item">
                          <strong>{t('teacher_preview_existing_years')}</strong>
                          <span>{selectedTeacherExistingYears.join(', ')}</span>
                        </div>
                      ) : null}
                    </div>
                  ) : null}
                </div>
              ) : (
                <div className="network-empty-state">
                  <strong>{t('teacher_preview_empty_title')}</strong>
                  <span>{t('teacher_preview_empty_description')}</span>
                </div>
              )}
              <div className="network-guidance-list">
                <div className="network-guidance-item">
                  <strong>{t('teacher_guidance_deep_link_title')}</strong>
                  <span>{t('teacher_guidance_deep_link_description')}</span>
                </div>
                <div className="network-guidance-item">
                  <strong>{t('teacher_guidance_safe_select_title')}</strong>
                  <span>{t('teacher_guidance_safe_select_description')}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">{t('teacher_history_kicker')}</span>
            <h3>{activeHistoryTitle}</h3>
            <p>{activeHistorySubtitle}</p>
          </div>
          <span className="chip">{t('teacher_record_count', { count: items.length })}</span>
        </div>
        <div className="panel-body">
          <div className="network-filter-bar">
            <select className="input" value={direction} onChange={(e) => setDirection(e.target.value)}>
              <option value="my_teachers">{t('teacher_filter_my_teachers')}</option>
              <option value="my_students">{t('teacher_filter_my_students')}</option>
            </select>
            <select className="input" value={relationshipType} onChange={(e) => setRelationshipType(e.target.value)}>
              <option value="">{t('teacher_filter_all_types')}</option>
              {RELATIONSHIP_TYPES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
            <select className="input" value={classYear} onChange={(e) => setClassYear(e.target.value)}>
              <option value="">{t('teacher_filter_all_years')}</option>
              {years.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
            <button className="btn ghost" type="button" onClick={() => load(0, false)} disabled={loading}>
              {loading ? t('teacher_action_refreshing') : t('teacher_action_apply_filter')}
            </button>
          </div>

          {!items.length && !loading ? (
            <div className="network-empty-state network-empty-state-wide">
              <strong>{t('teacher_empty_title')}</strong>
              <span>{t('teacher_empty_description')}</span>
            </div>
          ) : null}

          <div className="network-history-list">
            {items.map((item) => (
              <article
                key={item.id}
                className={`network-history-card${highlightedLinkId === Number(item.id || 0) ? ' notification-focus-card' : ''}`}
                ref={(node) => {
                  if (node) historyCardRefs.current.set(Number(item.id || 0), node);
                  else historyCardRefs.current.delete(Number(item.id || 0));
                }}
              >
                <div className="network-history-main">
                  <div className="network-history-title">
                    <strong>@{item.kadi || 'uye'}</strong>
                    <span>{item.isim || ''} {item.soyisim || ''}</span>
                  </div>
                  <div className="network-history-meta">
                    <span className="chip">{relationshipLabel(item.relationship_type, RELATIONSHIP_TYPES)}</span>
                    {item.class_year ? <span className="chip">{t('teacher_history_year_label')}{item.class_year}</span> : null}
                    {item.verified ? <span className="chip">{t('teacher_history_verified_chip')}</span> : null}
                    <span className="chip">{reviewStatusLabel(t, item.review_status)}</span>
                    <span className="chip">{confidenceLabel(t, item.confidence_score)}</span>
                  </div>
                </div>
                {item.notes ? <p className="muted">{item.notes}</p> : <p className="muted">{t('teacher_history_no_notes')}</p>}
              </article>
            ))}
          </div>

          {hasMore ? (
            <button className="btn ghost" type="button" onClick={() => load(offset, true)} disabled={loading}>
              {loading ? t('loading') : t('teacher_action_load_more')}
            </button>
          ) : null}
        </div>
      </div>
    </Layout>
  );
}
