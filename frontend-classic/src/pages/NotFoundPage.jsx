import React from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function NotFoundPage() {
  return (
    <LegacyLayout pageTitle="Sayfa Bulunamadı">
      <div style={{ padding: 12 }}>
        Aradığınız sayfa bulunamadı.
      </div>
    </LegacyLayout>
  );
}
