import React from 'react';
import { useI18n } from '../../utils/i18n.jsx';

function getRowId(row, rowKey) {
  if (typeof rowKey === 'function') return rowKey(row);
  return row?.[rowKey || 'id'];
}

export default function AdminDataTable({
  columns,
  rows,
  rowKey = 'id',
  loading,
  emptyText = 'No records.',
  selectable = false,
  selectedIds = new Set(),
  onToggleRow,
  onToggleAll,
  pagination,
  onPageChange,
  onRowClick
}) {
  const { t } = useI18n();
  const hasRows = Array.isArray(rows) && rows.length > 0;
  const allSelected = hasRows && rows.every((row) => selectedIds.has(getRowId(row, rowKey)));

  return (
    <div className="ops-table-wrap">
      <table className="ops-table">
        <thead>
          <tr>
            {selectable ? (
              <th>
                <input type="checkbox" checked={allSelected} onChange={(e) => onToggleAll?.(e.target.checked)} />
              </th>
            ) : null}
            {columns.map((column) => <th key={column.key}>{column.label}</th>)}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr>
              <td colSpan={columns.length + (selectable ? 1 : 0)} className="muted">{t('loading')}</td>
            </tr>
          ) : null}
          {!loading && !hasRows ? (
            <tr>
              <td colSpan={columns.length + (selectable ? 1 : 0)} className="muted">{emptyText}</td>
            </tr>
          ) : null}
          {!loading && hasRows ? rows.map((row) => {
            const id = getRowId(row, rowKey);
            return (
              <tr key={id} className={onRowClick ? 'clickable' : ''} onClick={() => onRowClick?.(row)}>
                {selectable ? (
                  <td onClick={(e) => e.stopPropagation()}>
                    <input
                      type="checkbox"
                      checked={selectedIds.has(id)}
                      onChange={(e) => onToggleRow?.(row, e.target.checked)}
                    />
                  </td>
                ) : null}
                {columns.map((column) => (
                  <td key={`${id}-${column.key}`} data-label={typeof column.label === 'string' ? column.label : ''}>
                    {column.render ? column.render(row) : String(row?.[column.key] ?? '-')}
                  </td>
                ))}
              </tr>
            );
          }) : null}
        </tbody>
      </table>
      <div className="ops-card-list">
        {loading ? <div className="muted ops-card-item">{t('loading')}</div> : null}
        {!loading && !hasRows ? <div className="muted ops-card-item">{emptyText}</div> : null}
        {!loading && hasRows ? rows.map((row) => {
          const id = getRowId(row, rowKey);
          return (
            <article key={`card-${id}`} className={`ops-card-item${onRowClick ? ' clickable' : ''}`} onClick={() => onRowClick?.(row)}>
              {selectable ? (
                <label className="ops-card-check" onClick={(e) => e.stopPropagation()}>
                  <input
                    type="checkbox"
                    checked={selectedIds.has(id)}
                    onChange={(e) => onToggleRow?.(row, e.target.checked)}
                  />
                  <span>{t('selected')}</span>
                </label>
              ) : null}
              <div className="ops-card-fields">
                {columns.map((column) => (
                  <div key={`${id}-card-${column.key}`} className="ops-card-field">
                    <span className="ops-card-label">{column.label}</span>
                    <div className="ops-card-value">{column.render ? column.render(row) : String(row?.[column.key] ?? '-')}</div>
                  </div>
                ))}
              </div>
            </article>
          );
        }) : null}
      </div>
      {pagination ? (
        <div className="ops-table-pagination">
          <button className="btn ghost" disabled={pagination.page <= 1} onClick={() => onPageChange?.(pagination.page - 1)}>{t('Önceki')}</button>
          <span className="chip">{t('Sayfa')} {pagination.page} / {pagination.pages || 1}</span>
          <span className="chip">{t('Toplam')} {pagination.total || 0}</span>
          <button className="btn ghost" disabled={(pagination.page || 1) >= (pagination.pages || 1)} onClick={() => onPageChange?.(pagination.page + 1)}>{t('Sonraki')}</button>
        </div>
      ) : null}
    </div>
  );
}
