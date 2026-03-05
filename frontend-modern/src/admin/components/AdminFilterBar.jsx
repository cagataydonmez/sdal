import React from 'react';

export default function AdminFilterBar({ searchValue, onSearchChange, searchPlaceholder = 'Search...', actions, children }) {
  return (
    <div className="ops-filter-bar">
      <input
        className="input"
        value={searchValue || ''}
        onChange={(e) => onSearchChange?.(e.target.value)}
        placeholder={searchPlaceholder}
      />
      <div className="ops-filter-extra">{children}</div>
      {actions ? <div className="ops-filter-actions">{actions}</div> : null}
    </div>
  );
}
