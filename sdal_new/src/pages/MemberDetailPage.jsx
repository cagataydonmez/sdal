import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';

export default function MemberDetailPage() {
  const { id } = useParams();
  const [member, setMember] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(`/api/members/${id}`, { credentials: 'include' })
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        return res.json();
      })
      .then((p) => setMember(p.row || null))
      .catch((err) => setError(err.message));
  }, [id]);

  if (!member) return <Layout title="Üye">{error ? <div className="error">{error}</div> : 'Yükleniyor...'}</Layout>;

  return (
    <Layout title={`${member.isim} ${member.soyisim}`}>
      <div className="panel">
        <div className="panel-body">
          <img className="avatar" src={member.resim ? `/api/media/vesikalik/${member.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
          <div className="name">@{member.kadi}</div>
          <div className="meta">{member.mezuniyetyili || ''}</div>
          <div className="meta">{member.sehir || ''}</div>
          <div className="meta">{member.meslek || ''}</div>
          <div className="meta">{member.universite || ''}</div>
          <div className="meta">{member.websitesi || ''}</div>
          <div>{member.imza}</div>
        </div>
      </div>
    </Layout>
  );
}
