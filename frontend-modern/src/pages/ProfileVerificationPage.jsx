import React, { useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';

export default function ProfileVerificationPage() {
  const { t } = useI18n();
  const { refresh } = useAuth();
  const location = useLocation();
  const [verificationProofFile, setVerificationProofFile] = useState(null);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const searchParams = useMemo(() => new URLSearchParams(location.search || ''), [location.search]);
  const notificationId = Number(searchParams.get('notification') || 0);
  const notificationStatus = String(searchParams.get('status') || '').trim().toLowerCase();

  useNotificationNavigationTracking(notificationId, {
    surface: 'profile_verification_page',
    resolved: !notificationId || notificationStatus === 'approved' || notificationStatus === 'rejected'
  });

  async function uploadVerificationProof() {
    if (!verificationProofFile) {
      return { proof_path: '', proof_image_record_id: '' };
    }
    const form = new FormData();
    form.append('proof', verificationProofFile);
    const res = await fetch('/api/new/verified/proof', {
      method: 'POST',
      credentials: 'include',
      body: form
    });
    if (!res.ok) {
      throw new Error((await res.text()) || t('profile_verify_proof_upload_failed'));
    }
    const payload = await res.json();
    return {
      proof_path: String(payload.proof_path || '').trim(),
      proof_image_record_id: String(payload.proof_image_record_id || '').trim()
    };
  }

  async function submitVerification() {
    setStatus('');
    setError('');
    try {
      const proof = await uploadVerificationProof();
      const res = await fetch('/api/new/verified/request', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(proof)
      });
      if (!res.ok) {
        setStatus(await res.text());
        return;
      }
      setStatus(t('profile_verify_request_received'));
      setVerificationProofFile(null);
      await refresh();
    } catch (err) {
      setError(err?.message || t('profile_verify_request_failed'));
    }
  }

  return (
    <Layout title={t('profile_verification_title')}>
      <div className="panel">
        <div className="panel-body">
          {notificationId && notificationStatus ? (
            <div className="notification-focus-inline-panel">
              <strong>Doğrulama sonucu</strong>
              <div className="muted">
                {notificationStatus === 'approved'
                  ? 'Doğrulama talebin onaylandı. Profil verin yenilenirken bu sayfayı referans alabilirsin.'
                  : 'Doğrulama talebin reddedildi. Yeni belge yükleyip tekrar başvurabilirsin.'}
              </div>
            </div>
          ) : null}
          <p className="muted">{t('profile_verification_hint')}</p>
          <div className="form-row">
            <label>{t('profile_verification_proof_label')}</label>
            <input
              className="input"
              type="file"
              accept=".jpg,.jpeg,.png,.pdf"
              onChange={(e) => setVerificationProofFile(e.target.files?.[0] || null)}
            />
          </div>
          <div className="inline-actions">
            <button className="btn primary" onClick={submitVerification}>{t('profile_verify_request')}</button>
            <a className="btn ghost" href="/new/profile">{t('back')}</a>
          </div>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
