import React from 'react';

export default function AdminDetailDrawer({ title, open, onClose, children, width = 440 }) {
  if (!open) return null;
  return (
    <div className="ops-drawer-overlay" onClick={onClose}>
      <aside className="ops-drawer" style={{ width }} onClick={(e) => e.stopPropagation()}>
        <div className="ops-drawer-head">
          <h3>{title}</h3>
          <button className="btn ghost" onClick={onClose}>Close</button>
        </div>
        <div className="ops-drawer-body">{children}</div>
      </aside>
    </div>
  );
}
