import React from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';
import StoriesManager from '../components/StoriesManager.jsx';

export default function StoriesPage() {
  return (
    <LegacyLayout pageTitle="Hikayeler">
      <StoriesManager />
    </LegacyLayout>
  );
}
