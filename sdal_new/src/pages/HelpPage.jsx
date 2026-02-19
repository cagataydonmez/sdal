import React from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function HelpPage() {
  const { t } = useI18n();
  return (
    <Layout title={t('help_center_title')}>
      <div className="panel">
        <h3>{t('help_quick_start_title')}</h3>
        <div className="panel-body stack">
          <div><b>{t('help_quick_1_title')}</b> {t('help_quick_1_body')}</div>
          <div><b>{t('help_quick_2_title')}</b> {t('help_quick_2_body')}</div>
          <div><b>{t('help_quick_3_title')}</b> {t('help_quick_3_body')}</div>
          <div><b>{t('help_quick_4_title')}</b> {t('help_quick_4_body')}</div>
          <div><b>{t('help_quick_5_title')}</b> {t('help_quick_5_body')}</div>
        </div>
      </div>

      <div className="panel">
        <h3>{t('help_feed_stories_title')}</h3>
        <div className="panel-body stack">
          <div><b>{t('help_feed_filters_title')}</b> {t('help_feed_filters_body')}</div>
          <div><b>{t('help_story_nav_title')}</b> {t('help_story_nav_body')}</div>
          <div><b>{t('help_image_upload_title')}</b> {t('help_image_upload_body')}</div>
        </div>
      </div>

      <div className="panel">
        <h3>{t('help_text_formatting_title')}</h3>
        <div className="panel-body stack">
          <div>{t('help_formatting_1')}</div>
          <div>{t('help_formatting_2')}</div>
          <div>{t('help_formatting_examples')}</div>
          <code>{t('help_formatting_code_1')}</code>
          <code>{t('help_formatting_code_2')}</code>
          <code>{t('help_formatting_code_3')}</code>
          <code>{t('help_formatting_code_4')}</code>
        </div>
      </div>

      <div className="panel" id="engagement-score">
        <h3>{t('help_engagement_title')}</h3>
        <div className="panel-body stack">
          <div><b>{t('help_engagement_1_title')}</b> {t('help_engagement_1_body')}</div>
          <div><b>{t('help_engagement_2_title')}</b> {t('help_engagement_2_body')}</div>
          <div><b>{t('help_engagement_3_title')}</b> {t('help_engagement_3_body')}</div>
          <div><b>{t('help_engagement_4_title')}</b> {t('help_engagement_4_body')}</div>
          <div><b>{t('help_engagement_5_title')}</b> {t('help_engagement_5_body')}</div>
        </div>
      </div>

      <div className="panel">
        <h3>{t('help_faq_title')}</h3>
        <div className="panel-body stack">
          <div><b>{t('help_faq_1_q')}</b> {t('help_faq_1_a')}</div>
          <div><b>{t('help_faq_2_q')}</b> {t('help_faq_2_a')}</div>
          <div><b>{t('help_faq_3_q')}</b> {t('help_faq_3_a')}</div>
        </div>
      </div>
    </Layout>
  );
}
