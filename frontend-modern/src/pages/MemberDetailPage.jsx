import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import StoryBar from '../components/StoryBar.jsx';
import { readApiPayload } from '../utils/api.js';
import { useI18n } from '../utils/i18n.jsx';

function canLinkToTeacherNetwork(member) {
  const role = String(member?.role || '').trim().toLowerCase();
  const cohort = String(member?.mezuniyetyili || '').trim().toLowerCase();
  return role === 'teacher' || role === 'admin' || role === 'root' || cohort === 'teacher' || cohort === 'ogretmen';
}

export default function MemberDetailPage() {
  const { t } = useI18n();
  const { id } = useParams();
  const { user } = useAuth();
  const [member, setMember] = useState(null);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [loadingAction, setLoadingAction] = useState(false);
  const [incomingConnectionId, setIncomingConnectionId] = useState(0);
  const [outgoingRequestId, setOutgoingRequestId] = useState(0);

  useEffect(() => {
    fetch(`/api/members/${id}`, { credentials: 'include' })
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        return res.json();
      })
      .then((p) => setMember(p.row || null))
      .catch((err) => setError(err.message));
  }, [id]);

  useEffect(() => {
    if (!id || String(user?.id || '') === String(id)) return;
    let cancelled = false;
    async function loadConnectionState() {
      const [incomingRes, outgoingRes] = await Promise.all([
        fetch('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', { credentials: 'include' }),
        fetch('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { credentials: 'include' })
      ]);
      if (!incomingRes.ok || !outgoingRes.ok || cancelled) return;
      const [{ data: incomingPayload }, { data: outgoingPayload }] = await Promise.all([
        readApiPayload(incomingRes, ''),
        readApiPayload(outgoingRes, '')
      ]);
      const targetId = Number(id || 0);
      const incoming = (incomingPayload.items || []).find((item) => Number(item.sender_id) === targetId);
      const outgoing = (outgoingPayload.items || []).find((item) => Number(item.receiver_id) === targetId);
      if (cancelled) return;
      setIncomingConnectionId(Number(incoming?.id || 0));
      setOutgoingRequestId(Number(outgoing?.id || 0));
    }
    loadConnectionState();
    return () => {
      cancelled = true;
    };
  }, [id, user?.id]);

  if (!member) return <Layout title={t('member_title')}>{error ? <div className="error">{error}</div> : t('loading')}</Layout>;

  return (
    <Layout title={`${member.isim} ${member.soyisim}`}>
      <div className="panel">
        <div className="panel-body">
          <img className="profile-avatar-xl" src={member.resim ? `/api/media/vesikalik/${member.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
          <div className="name">@{member.kadi}</div>
          <div className="meta">{member.mezuniyetyili || ''}</div>
          <div className="meta">{member.sehir || ''}</div>
          <div className="meta">{member.meslek || ''}</div>
          {member.unvan || member.sirket ? <div className="meta">{[member.unvan, member.sirket].filter(Boolean).join(' @ ')}</div> : null}
          {member.uzmanlik ? <div className="meta">{member.uzmanlik}</div> : null}
          {Number(member.mentor_opt_in || 0) === 1 ? <div className="meta">{t('profile_mentor_opt_in')}</div> : null}
          <div className="meta">{member.universite || ''}</div>
          {member.universite_bolum ? <div className="meta">{member.universite_bolum}</div> : null}
          <div className="meta">{member.websitesi || ''}</div>
          {member.linkedin_url ? (
            <div className="meta">
              <a href={member.linkedin_url} target="_blank" rel="noreferrer">{t('profile_linkedin')}</a>
            </div>
          ) : null}
          <div>{member.imza}</div>
          <div className="composer-actions">
            <a className="btn primary" href={`/new/messages/compose?to=${member.id}`}>{t('member_send_message')}</a>
            {String(user?.id || '') !== String(member.id || '') ? (
              <button className="btn ghost" onClick={async () => {
                setError('');
                setStatus('');
                const res = await fetch('/api/quick-access/add', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  credentials: 'include',
                  body: JSON.stringify({ id: member.id })
                });
                if (!res.ok) {
                  setError(await res.text());
                  return;
                }
                setStatus(t('member_quick_access_added'));
              }}
              >
                {t('member_quick_access_add')}
              </button>
            ) : null}
            {String(user?.id || '') !== String(member.id || '') && member.verified ? (
              <button
                className="btn ghost"
                disabled={loadingAction}
                onClick={async () => {
                  setError('');
                  setStatus('');
                  setLoadingAction(true);
                  try {
                    const endpoint = incomingConnectionId
                      ? `/api/new/connections/accept/${incomingConnectionId}`
                      : outgoingRequestId
                        ? `/api/new/connections/cancel/${outgoingRequestId}`
                        : `/api/new/connections/request/${member.id}`;
                    const res = await fetch(endpoint, { method: 'POST', credentials: 'include' });
                    if (!res.ok) {
                      const { message } = await readApiPayload(res, 'Bağlantı işlemi başarısız.');
                      if (res.status === 409 && message.toLowerCase().includes('zaten bekleyen bir bağlantı isteği')) {
                        const [incomingRes, outgoingRes] = await Promise.all([
                          fetch('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', { credentials: 'include' }),
                          fetch('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { credentials: 'include' })
                        ]);
                        if (incomingRes.ok && outgoingRes.ok) {
                          const [{ data: incomingPayload }, { data: outgoingPayload }] = await Promise.all([
                            readApiPayload(incomingRes, ''),
                            readApiPayload(outgoingRes, '')
                          ]);
                          const targetId = Number(member.id || 0);
                          const incoming = (incomingPayload.items || []).find((item) => Number(item.sender_id) === targetId);
                          const outgoing = (outgoingPayload.items || []).find((item) => Number(item.receiver_id) === targetId);
                          setIncomingConnectionId(Number(incoming?.id || 0));
                          setOutgoingRequestId(Number(outgoing?.id || 0));
                        }
                      }
                      setError(message);
                      return;
                    }
                    setIncomingConnectionId(0);
                    if (outgoingRequestId) {
                      setOutgoingRequestId(0);
                    } else if (!incomingConnectionId) {
                      const outgoingRes = await fetch('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { credentials: 'include' });
                      if (outgoingRes.ok) {
                        const { data: outgoingPayload } = await readApiPayload(outgoingRes, '');
                        const outgoing = (outgoingPayload.items || []).find((item) => Number(item.receiver_id) === Number(member.id || 0));
                        setOutgoingRequestId(Number(outgoing?.id || 0));
                      }
                    }
                    const statusKey = incomingConnectionId
                      ? 'connection_status_accepted'
                      : outgoingRequestId
                        ? 'connection_withdraw'
                        : 'connection_status_pending';
                    setStatus(t(statusKey));
                  } finally {
                    setLoadingAction(false);
                  }
                }}
              >
                {incomingConnectionId ? t('connection_accept') : outgoingRequestId ? t('connection_withdraw') : t('connection_request')}
              </button>
            ) : null}
            {String(user?.id || '') !== String(member.id || '') && canLinkToTeacherNetwork(member) ? (
              <a className="btn ghost" href={`/new/network/teachers?teacherId=${member.id}`}>
                Öğretmen Ağına Ekle
              </a>
            ) : null}
            {String(user?.id || '') !== String(member.id || '') && Number(member.mentor_opt_in || 0) === 1 ? (
              <button
                className="btn ghost"
                disabled={loadingAction}
                onClick={async () => {
                  setError('');
                  setStatus('');
                  setLoadingAction(true);
                  try {
                    const res = await fetch(`/api/new/mentorship/request/${member.id}`, {
                      method: 'POST',
                      credentials: 'include',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({})
                    });
                    if (!res.ok) {
                      const { message } = await readApiPayload(res, 'Mentorluk isteği gönderilemedi.');
                      setError(message);
                      return;
                    }
                    const { message } = await readApiPayload(res, t('mentorship_status_requested'));
                    setStatus(message || t('mentorship_status_requested'));
                  } finally {
                    setLoadingAction(false);
                  }
                }}
              >
                {t('mentorship_request')}
              </button>
            ) : null}
          </div>
          {status ? <div className="ok">{status}</div> : null}
        </div>
      </div>
      <div className="panel">
        <div className="panel-body">
          <StoryBar endpoint={`/api/new/stories/user/${id}`} showUpload={false} title={t('member_stories_title')} />
        </div>
      </div>
    </Layout>
  );
}
