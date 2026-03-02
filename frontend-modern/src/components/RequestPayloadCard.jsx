import React, { useMemo } from 'react';

function normalizePayload(payloadJson) {
  if (!payloadJson) return {};
  if (typeof payloadJson === 'object') return payloadJson;
  try {
    return JSON.parse(String(payloadJson));
  } catch {
    return { note: String(payloadJson) };
  }
}

export default function RequestPayloadCard({ payloadJson }) {
  const payload = useMemo(() => normalizePayload(payloadJson), [payloadJson]);
  const keys = Object.keys(payload || {}).filter((k) => k !== 'attachments');
  const attachments = Array.isArray(payload?.attachments) ? payload.attachments : [];

  return (
    <div className="request-payload-card">
      {keys.map((key) => (
        <div key={key} className="request-payload-row">
          <span className="request-payload-key">{key}</span>
          <span className="request-payload-value">{String(payload[key] ?? '-')}</span>
        </div>
      ))}
      {attachments.length ? (
        <div className="request-payload-attachments">
          {attachments.map((file, idx) => (
            <a key={`${file?.url || idx}`} href={file?.url} target="_blank" rel="noreferrer" className="chip">
              📎 {file?.name || `Dosya ${idx + 1}`}
            </a>
          ))}
        </div>
      ) : null}
    </div>
  );
}
