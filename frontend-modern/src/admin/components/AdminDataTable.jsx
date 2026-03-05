import React from 'react';

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
              <td colSpan={columns.length + (selectable ? 1 : 0)} className="muted">Loading...</td>
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
                  <td key={`${id}-${column.key}`}>{column.render ? column.render(row) : String(row?.[column.key] ?? '-')}</td>
                ))}
              </tr>
            );
          }) : null}
        </tbody>
      </table>
      {pagination ? (
        <div className="ops-table-pagination">
          <button className="btn ghost" disabled={pagination.page <= 1} onClick={() => onPageChange?.(pagination.page - 1)}>Previous</button>
          <span className="chip">Page {pagination.page} / {pagination.pages || 1}</span>
          <span className="chip">Total {pagination.total || 0}</span>
          <button className="btn ghost" disabled={(pagination.page || 1) >= (pagination.pages || 1)} onClick={() => onPageChange?.(pagination.page + 1)}>Next</button>
        </div>
      ) : null}
    </div>
  );
}
