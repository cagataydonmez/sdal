import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function LogoutPage() {
  const { logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    logout().finally(() => navigate('/'));
  }, [logout, navigate]);

  return (
    <LegacyLayout pageTitle="Çıkış">
      <div style={{ padding: 12 }}>Çıkış yapılıyor...</div>
    </LegacyLayout>
  );
}
