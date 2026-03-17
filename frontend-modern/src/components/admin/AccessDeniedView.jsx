import React from 'react';
import { useI18n } from '../../utils/i18n.jsx';

export default function AccessDeniedView() {
  const { t } = useI18n();
  return (
    <div className="panel">
      <div className="panel-body">{t('Bu sayfaya erişiminiz yok.')}</div>
    </div>
  );
}
