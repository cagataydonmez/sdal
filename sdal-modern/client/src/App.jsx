import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './utils/auth.jsx';
import HomePage from './pages/HomePage.jsx';
import LoginPage from './pages/LoginPage.jsx';
import MembersPage from './pages/MembersPage.jsx';
import MemberDetailPage from './pages/MemberDetailPage.jsx';
import MessagesPage from './pages/MessagesPage.jsx';
import MessageDetailPage from './pages/MessageDetailPage.jsx';
import MessageComposePage from './pages/MessageComposePage.jsx';
import AlbumsPage from './pages/AlbumsPage.jsx';
import AlbumDetailPage from './pages/AlbumDetailPage.jsx';
import AlbumPhotoPage from './pages/AlbumPhotoPage.jsx';
import AlbumUploadPage from './pages/AlbumUploadPage.jsx';
import ForumPage from './pages/ForumPage.jsx';
import PanolarPage from './pages/PanolarPage.jsx';
import QuickAccessPage from './pages/QuickAccessPage.jsx';
import QuickAccessAddPage from './pages/QuickAccessAddPage.jsx';
import QuickAccessRemovePage from './pages/QuickAccessRemovePage.jsx';
import NewPhotosPage from './pages/NewPhotosPage.jsx';
import NewMembersPage from './pages/NewMembersPage.jsx';
import TournamentPage from './pages/TournamentPage.jsx';
import TournamentRegisterPage from './pages/TournamentRegisterPage.jsx';
import GamesPage from './pages/GamesPage.jsx';
import GameSnakePage from './pages/GameSnakePage.jsx';
import GameTetrisPage from './pages/GameTetrisPage.jsx';
import LogoutPage from './pages/LogoutPage.jsx';
import NotFoundPage from './pages/NotFoundPage.jsx';
import ProfilePage from './pages/ProfilePage.jsx';
import AdminPage from './pages/AdminPage.jsx';
import RegisterPage from './pages/RegisterPage.jsx';
import PasswordResetPage from './pages/PasswordResetPage.jsx';
import ActivatePage from './pages/ActivatePage.jsx';
import ActivationResendPage from './pages/ActivationResendPage.jsx';
import BakimPage from './pages/BakimPage.jsx';
import Http500Page from './pages/Http500Page.jsx';
import KarikaturPage from './pages/KarikaturPage.jsx';
import StoriesPage from './pages/StoriesPage.jsx';

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/logout" element={<LogoutPage />} />

        <Route path="/uyeler" element={<RequireAuth><MembersPage /></RequireAuth>} />
        <Route path="/uyeler/:id" element={<RequireAuth><MemberDetailPage /></RequireAuth>} />
        <Route path="/mesajlar" element={<RequireAuth><MessagesPage /></RequireAuth>} />
        <Route path="/mesajlar/:id" element={<RequireAuth><MessageDetailPage /></RequireAuth>} />
        <Route path="/mesajlar/yeni" element={<RequireAuth><MessageComposePage /></RequireAuth>} />
        <Route path="/album" element={<RequireAuth><AlbumsPage /></RequireAuth>} />
        <Route path="/album/:id" element={<RequireAuth><AlbumDetailPage /></RequireAuth>} />
        <Route path="/album/foto/:id" element={<RequireAuth><AlbumPhotoPage /></RequireAuth>} />
        <Route path="/album/yeni" element={<RequireAuth><AlbumUploadPage /></RequireAuth>} />
        <Route path="/forum" element={<RequireAuth><ForumPage /></RequireAuth>} />
        <Route path="/panolar" element={<RequireAuth><PanolarPage /></RequireAuth>} />
        <Route path="/herisim" element={<RequireAuth><QuickAccessPage /></RequireAuth>} />
        <Route path="/hizli-erisim/ekle/:id" element={<RequireAuth><QuickAccessAddPage /></RequireAuth>} />
        <Route path="/hizli-erisim/ekle" element={<RequireAuth><QuickAccessAddPage /></RequireAuth>} />
        <Route path="/hizli-erisim/cikart/:id" element={<RequireAuth><QuickAccessRemovePage /></RequireAuth>} />
        <Route path="/hizli-erisim/cikart" element={<RequireAuth><QuickAccessRemovePage /></RequireAuth>} />
        <Route path="/enyeni-fotolar" element={<RequireAuth><NewPhotosPage /></RequireAuth>} />
        <Route path="/enyeni-uyeler" element={<RequireAuth><NewMembersPage /></RequireAuth>} />
        <Route path="/turnuva" element={<RequireAuth><TournamentPage /></RequireAuth>} />
        <Route path="/turnuva/kayit" element={<RequireAuth><TournamentRegisterPage /></RequireAuth>} />
        <Route path="/oyunlar" element={<RequireAuth><GamesPage /></RequireAuth>} />
        <Route path="/oyunlar/yilan" element={<RequireAuth><GameSnakePage /></RequireAuth>} />
        <Route path="/oyunlar/tetris" element={<RequireAuth><GameTetrisPage /></RequireAuth>} />
        <Route path="/profil" element={<RequireAuth><ProfilePage /></RequireAuth>} />
        <Route path="/profil/fotograf" element={<RequireAuth><ProfilePage /></RequireAuth>} />
        <Route path="/admin" element={<RequireAuth><AdminPage /></RequireAuth>} />
        <Route path="/yonetim" element={<RequireAuth><AdminPage /></RequireAuth>} />
        <Route path="/bakim" element={<BakimPage />} />
        <Route path="/http500" element={<Http500Page />} />
        <Route path="/karikatur1" element={<RequireAuth><KarikaturPage /></RequireAuth>} />
        <Route path="/hikayeler" element={<RequireAuth><StoriesPage /></RequireAuth>} />
        <Route path="/stories" element={<RequireAuth><StoriesPage /></RequireAuth>} />

        <Route path="/uye-kayit" element={<RegisterPage />} />
        <Route path="/sifre-hatirla" element={<PasswordResetPage />} />
        <Route path="/aktivet" element={<ActivatePage />} />
        <Route path="/aktivasyon-gonder" element={<ActivationResendPage />} />
        <Route path="/uyeara" element={<Navigate to="/uyeler" replace />} />

        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </AuthProvider>
  );
}

function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  if (loading) return children;
  if (!user) return <Navigate to="/login" replace />;
  return children;
}
