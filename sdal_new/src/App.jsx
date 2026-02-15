import React from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './utils/auth.jsx';
import FeedPage from './pages/FeedPage.jsx';
import ExplorePage from './pages/ExplorePage.jsx';
import GroupsPage from './pages/GroupsPage.jsx';
import GroupDetailPage from './pages/GroupDetailPage.jsx';
import MessagesPage from './pages/MessagesPage.jsx';
import MemberDetailPage from './pages/MemberDetailPage.jsx';
import AlbumsPage from './pages/AlbumsPage.jsx';
import AlbumCategoryPage from './pages/AlbumCategoryPage.jsx';
import AlbumPhotoPage from './pages/AlbumPhotoPage.jsx';
import AlbumUploadPage from './pages/AlbumUploadPage.jsx';
import EventsPage from './pages/EventsPage.jsx';
import AnnouncementsPage from './pages/AnnouncementsPage.jsx';
import ProfilePage from './pages/ProfilePage.jsx';
import ProfilePhotoPage from './pages/ProfilePhotoPage.jsx';
import AdminPage from './pages/AdminPage.jsx';
import LoginPage from './pages/LoginPage.jsx';
import RegisterPage from './pages/RegisterPage.jsx';
import ActivationPage from './pages/ActivationPage.jsx';
import ActivationResendPage from './pages/ActivationResendPage.jsx';
import PasswordResetPage from './pages/PasswordResetPage.jsx';
import MessageComposePage from './pages/MessageComposePage.jsx';
import MessageDetailPage from './pages/MessageDetailPage.jsx';
import FollowingPage from './pages/FollowingPage.jsx';
import HelpPage from './pages/HelpPage.jsx';
import GamesPage from './pages/GamesPage.jsx';
import GlobalActionFeedback from './components/GlobalActionFeedback.jsx';

function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  if (loading) return children;
  if (!user) return <Navigate to="/new/login" replace />;
  return children;
}

export default function App() {
  return (
    <AuthProvider>
      <GlobalActionFeedback />
      <Routes>
        <Route path="/new/login" element={<LoginPage />} />
        <Route path="/new/register" element={<RegisterPage />} />
        <Route path="/new/activate" element={<ActivationPage />} />
        <Route path="/new/activation/resend" element={<ActivationResendPage />} />
        <Route path="/new/password-reset" element={<PasswordResetPage />} />
        <Route path="/new" element={<RequireAuth><FeedPage /></RequireAuth>} />
        <Route path="/new/explore" element={<RequireAuth><ExplorePage /></RequireAuth>} />
        <Route path="/new/following" element={<RequireAuth><FollowingPage /></RequireAuth>} />
        <Route path="/new/members/:id" element={<RequireAuth><MemberDetailPage /></RequireAuth>} />
        <Route path="/new/groups" element={<RequireAuth><GroupsPage /></RequireAuth>} />
        <Route path="/new/groups/:id" element={<RequireAuth><GroupDetailPage /></RequireAuth>} />
        <Route path="/new/messages" element={<RequireAuth><MessagesPage /></RequireAuth>} />
        <Route path="/new/messages/compose" element={<RequireAuth><MessageComposePage /></RequireAuth>} />
        <Route path="/new/messages/:id" element={<RequireAuth><MessageDetailPage /></RequireAuth>} />
        <Route path="/new/albums" element={<RequireAuth><AlbumsPage /></RequireAuth>} />
        <Route path="/new/albums/upload" element={<RequireAuth><AlbumUploadPage /></RequireAuth>} />
        <Route path="/new/albums/photo/:id" element={<RequireAuth><AlbumPhotoPage /></RequireAuth>} />
        <Route path="/new/albums/:id" element={<RequireAuth><AlbumCategoryPage /></RequireAuth>} />
        <Route path="/new/events" element={<RequireAuth><EventsPage /></RequireAuth>} />
        <Route path="/new/announcements" element={<RequireAuth><AnnouncementsPage /></RequireAuth>} />
        <Route path="/new/games" element={<RequireAuth><GamesPage /></RequireAuth>} />
        <Route path="/new/games/:game" element={<RequireAuth><GamesPage /></RequireAuth>} />
        <Route path="/new/profile" element={<RequireAuth><ProfilePage /></RequireAuth>} />
        <Route path="/new/profile/photo" element={<RequireAuth><ProfilePhotoPage /></RequireAuth>} />
        <Route path="/new/help" element={<RequireAuth><HelpPage /></RequireAuth>} />
        <Route path="/new/admin" element={<RequireAuth><AdminPage /></RequireAuth>} />
        <Route path="/new/*" element={<Navigate to="/new" replace />} />
      </Routes>
    </AuthProvider>
  );
}
