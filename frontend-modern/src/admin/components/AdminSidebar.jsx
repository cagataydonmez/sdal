import React from 'react';

export default function AdminSidebar({ sections, activeKey, onChange }) {
  return (
    <aside className="ops-sidebar panel">
      <div className="panel-body">
        <div className="ops-sidebar-title">Operations Console</div>
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
