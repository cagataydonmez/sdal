import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import StoryBar from '../components/StoryBar.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function MemberDetailPage() {
  const { t } = useI18n();
  const { id } = useParams();
  const { user } = useAuth();
  const [member, setMember] = useState(null);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');

  useEffect(() => {
    fetch(`/api/members/${id}`, { credentials: 'include' })
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        return res.json();
      })
      .then((p) => setMember(p.row || null))
      .catch((err) => setError(err.message));
  }, [id]);

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
          <div className="meta">{member.universite || ''}</div>
          <div className="meta">{member.websitesi || ''}</div>
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
