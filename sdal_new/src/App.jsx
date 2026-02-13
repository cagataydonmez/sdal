import React from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './utils/auth.jsx';
import FeedPage from './pages/FeedPage.jsx';
import ExplorePage from './pages/ExplorePage.jsx';
import GroupsPage from './pages/GroupsPage.jsx';
import GroupDetailPage from './pages/GroupDetailPage.jsx';
import MessagesPage from './pages/MessagesPage.jsx';
import AlbumsPage from './pages/AlbumsPage.jsx';
import EventsPage from './pages/EventsPage.jsx';
import AnnouncementsPage from './pages/AnnouncementsPage.jsx';
import ProfilePage from './pages/ProfilePage.jsx';
import AdminPage from './pages/AdminPage.jsx';
import LoginPage from './pages/LoginPage.jsx';

function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  if (loading) return children;
  if (!user) return <Navigate to="/new/login" replace />;
  return children;
}

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/new/login" element={<LoginPage />} />
        <Route path="/new" element={<RequireAuth><FeedPage /></RequireAuth>} />
        <Route path="/new/explore" element={<RequireAuth><ExplorePage /></RequireAuth>} />
        <Route path="/new/groups" element={<RequireAuth><GroupsPage /></RequireAuth>} />
        <Route path="/new/groups/:id" element={<RequireAuth><GroupDetailPage /></RequireAuth>} />
        <Route path="/new/messages" element={<RequireAuth><MessagesPage /></RequireAuth>} />
        <Route path="/new/albums" element={<RequireAuth><AlbumsPage /></RequireAuth>} />
        <Route path="/new/events" element={<RequireAuth><EventsPage /></RequireAuth>} />
        <Route path="/new/announcements" element={<RequireAuth><AnnouncementsPage /></RequireAuth>} />
        <Route path="/new/profile" element={<RequireAuth><ProfilePage /></RequireAuth>} />
        <Route path="/new/admin" element={<RequireAuth><AdminPage /></RequireAuth>} />
        <Route path="/new/*" element={<Navigate to="/new" replace />} />
      </Routes>
    </AuthProvider>
  );
}
