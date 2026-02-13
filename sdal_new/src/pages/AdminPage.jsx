import React from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function AdminPage() {
  const { user } = useAuth();
  return (
    <Layout title="Yönetim">
      {user?.admin === 1 ? (
        <div className="panel">
          <div className="panel-body">
            <p>Yönetim paneli klasik arayüzde çalışır.</p>
            <a className="btn primary" href="/admin">Klasik Yönetim Panelini Aç</a>
          </div>
        </div>
      ) : (
        <div className="panel">
          <div className="panel-body">Bu sayfaya erişiminiz yok.</div>
        </div>
      )}
    </Layout>
  );
}
