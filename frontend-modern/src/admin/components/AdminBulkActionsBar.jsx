import React from 'react';
import { useI18n } from '../../utils/i18n.jsx';

export default function AdminBulkActionsBar({ selectedCount, children, onClear }) {
  const { t } = useI18n();
  if (!selectedCount) return null;
  return (
    <div className="ops-bulk-bar">
      <div>{selectedCount} {t('seçildi')}</div>
      <div className="ops-bulk-actions">{children}</div>
      <button className="btn ghost" onClick={onClear}>{t('Temizle')}</button>
    </div>
  );
}
