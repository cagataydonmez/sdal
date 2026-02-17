import React from 'react';
import { Link } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { useAuth } from '../utils/auth.jsx';
import LoginPage from './LoginPage.jsx';

export default function HomePage() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <LegacyLayout pageTitle="Anasayfa">
        <div>Yükleniyor...</div>
      </LegacyLayout>
    );
  }

  if (!user) {
    return <LoginPage />;
  }

  return (
    <LegacyLayout pageTitle="Anasayfa">
      <div style={{ padding: 12 }}>
        <h3>Hoşgeldiniz, {user.kadi}</h3>
        <p>SDAL mezunlar sitesi modernleştiriliyor. Menüden devam edebilirsiniz.</p>
        <p>
          Hikaye yönetimi için <Link to="/hikayeler">Hikayeler sayfasına</Link> gidebilirsin.
        </p>
      </div>
    </LegacyLayout>
  );
}
