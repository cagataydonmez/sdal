import React from 'react';
import { formatDateTime } from '../utils/date.js';
import { buildNotificationViewModel, getNotificationCategoryLabel } from '../utils/notificationRegistry.js';

function avatarUrl(photo) {
  return photo ? `/api/media/vesikalik/${photo}` : '/legacy/vesikalik/nophoto.jpg';
}

export default function NotificationCard({
  notification,
  compact = false,
  busy = false,
  onOpen,
  onRead,
  onAction
}) {
  const view = buildNotificationViewModel(notification);
  const extraActions = (view.actions || []).filter((action) => action.kind !== 'open').slice(0, compact ? 2 : 3);

  return (
    <article className={`notification-card${view.read_at ? '' : ' unread'}${compact ? ' compact' : ''}${view.isActionable ? ' actionable' : ''}`}>
      <a className="notification-card-avatar" href={view.href || '/new'} onClick={() => onOpen?.(view)}>
        <img className="avatar" src={avatarUrl(view.resim)} loading="lazy" decoding="async" alt="" />
      </a>
      <div className="notification-card-body">
        <div className="notification-card-head">
          <div className="notification-card-chips">
            <span className="chip">{getNotificationCategoryLabel(view.category)}</span>
            {view.isActionable ? <span className="chip">Aksiyon Gerekli</span> : null}
            {!view.read_at ? <span className="chip">Yeni</span> : null}
          </div>
          <div className="meta">{formatDateTime(view.created_at)}</div>
        </div>
        <a className="notification-card-link" href={view.href || '/new'} onClick={() => onOpen?.(view)}>
          <b>@{view.kadi}</b> {view.verified ? <span className="badge">✓</span> : null} {view.message}
        </a>
        {!compact ? (
          <div className="notification-card-meta">
            <span className="meta">Tip: {view.type}</span>
          </div>
        ) : null}
        <div className="notification-card-actions">
          {extraActions.map((action) => (
            <button
              key={`${view.id}-${action.kind}`}
              className={`btn ${action.kind.startsWith('accept') ? 'primary' : 'ghost'}`}
              disabled={busy}
              onClick={() => onAction?.(view, action)}
            >
              {action.label}
            </button>
          ))}
          {!view.read_at ? (
            <button className="btn ghost" disabled={busy} onClick={() => onRead?.(view)}>
              Okundu yap
            </button>
          ) : null}
        </div>
      </div>
    </article>
  );
}
