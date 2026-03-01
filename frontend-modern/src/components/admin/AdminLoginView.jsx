import React from 'react';

export default function AdminLoginView({ adminLogin, adminPassword, setAdminPassword, status }) {
  return (
    <div className="panel">
      <div className="panel-body">
        <form className="stack" onSubmit={adminLogin}>
          <input
            className="input"
            type="password"
            placeholder="Admin şifresi"
            value={adminPassword}
            onChange={(e) => setAdminPassword(e.target.value)}
          />
          <button className="btn primary" type="submit">Admin Giriş</button>
          {status ? <div className="muted">{status}</div> : null}
        </form>
      </div>
    </div>
  );
}

