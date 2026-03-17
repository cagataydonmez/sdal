import React from 'react';
import { useI18n } from '../../utils/i18n.jsx';

export default function AdminSidebar({ sections, activeKey, onChange }) {
  const { t } = useI18n();
  return (
    <aside className="ops-sidebar panel">
      <div className="panel-body">
        <div className="ops-sidebar-title">{t('Operasyon Konsolu')}</div>
        <nav className="ops-sidebar-nav">
          {sections.map((section) => (
            <button
              key={section.key}
              className={`ops-sidebar-item ${activeKey === section.key ? 'active' : ''}`}
              onClick={() => onChange(section.key)}
            >
              <div className="name">{section.label}</div>
              <div className="meta">{section.hint}</div>
            </button>
          ))}
        </nav>
      </div>
    </aside>
  );
}
