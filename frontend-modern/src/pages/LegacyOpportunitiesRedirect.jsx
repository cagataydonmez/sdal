import React from 'react';
import { Navigate, useLocation } from '../router.jsx';

export default function LegacyOpportunitiesRedirect() {
  const location = useLocation();
  const search = location.search || '';
  return <Navigate replace to={`/new/explore${search}`} />;
}
