import React from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function BakimPage() {
  return (
    <LegacyLayout pageTitle="Bakım Çalışması" showLeftColumn={false}>
      <div style={{ textAlign: 'center' }}>
        <img src="/legacy/bakim.jpg" alt="Bakım" />
      </div>
    </LegacyLayout>
  );
}
