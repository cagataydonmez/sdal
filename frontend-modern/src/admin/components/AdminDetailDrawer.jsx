import React from 'react';
import { createPortal } from 'react-dom';
import { useI18n } from '../../utils/i18n.jsx';

export default function AdminDetailDrawer({ title, open, onClose, children, width = 440 }) {
  const { t } = useI18n();
  if (!open) return null;
  return createPortal(
    <div className="ops-drawer-overlay" onClick={onClose}>
      <aside className="ops-drawer" style={{ width }} onClick={(e) => e.stopPropagation()}>
        <div className="ops-drawer-head">
          <h3>{title}</h3>
          <button className="btn ghost" onClick={onClose}>{t('close')}</button>
        </div>
        <div className="ops-drawer-body">{children}</div>
      </aside>
    </div>
  , document.body);
}
