import React from 'react';
import Layout from '../components/Layout.jsx';
import LiveChatPanel from '../components/LiveChatPanel.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function WhatsappChatPage() {
  const { t } = useI18n();

  return (
    <Layout title={t('nav_whatsapp')}>
      <div className="wa-page-head panel">
        <h3>{t('whatsapp_title')}</h3>
        <p className="muted">{t('whatsapp_subtitle')}</p>
      </div>
      <div className="wa-page-chat">
        <LiveChatPanel />
      </div>
    </Layout>
  );
}
