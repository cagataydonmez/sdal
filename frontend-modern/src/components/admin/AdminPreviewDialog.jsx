import React from 'react';
import { createPortal } from 'react-dom';

export default function AdminPreviewDialog({
  title,
  onClose,
  children,
  compact = false,
  titleActions = null,
  footer = null,
  closeLabel = 'Kapat'
}) {
  return createPortal(
    <div className="content-preview-backdrop" onClick={onClose}>
      <div
        className={`content-preview-modal admin-preview-dialog ${compact ? 'is-compact' : ''}`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="content-preview-header admin-preview-header">
          <h4>{title}</h4>
          <div className="admin-preview-header-actions">
            {titleActions}
            <button className="btn ghost" onClick={onClose}>{closeLabel}</button>
          </div>
        </div>
        <div className="content-preview-body admin-preview-body">{children}</div>
        {footer ? <div className="admin-preview-footer">{footer}</div> : null}
      </div>
    </div>,
    document.body
  );
}
