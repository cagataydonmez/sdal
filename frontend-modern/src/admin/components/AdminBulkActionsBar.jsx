import React from 'react';

export default function AdminBulkActionsBar({ selectedCount, children, onClear }) {
  if (!selectedCount) return null;
  return (
    <div className="ops-bulk-bar">
      <div>{selectedCount} selected</div>
      <div className="ops-bulk-actions">{children}</div>
      <button className="btn ghost" onClick={onClear}>Clear</button>
    </div>
  );
}
