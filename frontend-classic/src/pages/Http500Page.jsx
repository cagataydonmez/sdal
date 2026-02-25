import React from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function Http500Page() {
  return (
    <LegacyLayout pageTitle="Sunucu Hatası" showLeftColumn={false}>
      <div className="hatamsg1">
        Bir hata oluştu. Lütfen daha sonra tekrar deneyiniz.
      </div>
    </LegacyLayout>
  );
}
