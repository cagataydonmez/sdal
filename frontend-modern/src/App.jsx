import React from 'react';
import { Navigate, Outlet, Route, createRoutesFromElements, useLocation } from './router.jsx';
import { AuthProvider, useAuth } from './utils/auth.jsx';
import FeedPage from './pages/FeedPage.jsx';
import LoginPage from './pages/LoginPage.jsx';
import RootLoginPage from './pages/RootLoginPage.jsx';
import RegisterPage from './pages/RegisterPage.jsx';
import ActivationPage from './pages/ActivationPage.jsx';
import ActivationResendPage from './pages/ActivationResendPage.jsx';
import PasswordResetPage from './pages/PasswordResetPage.jsx';
import GlobalActionFeedback from './components/GlobalActionFeedback.jsx';
import { ThemeProvider } from './utils/theme.jsx';
import { I18nProvider } from './utils/i18n.jsx';

const ExplorePage = React.lazy(() => import('./pages/ExplorePage.jsx'));
const ExploreSuggestionsPage = React.lazy(() => import('./pages/ExploreSuggestionsPage.jsx'));
const GroupsPage = React.lazy(() => import('./pages/GroupsPage.jsx'));
const GroupDetailPage = React.lazy(() => import('./pages/GroupDetailPage.jsx'));
const MessagesPage = React.lazy(() => import('./pages/MessagesPage.jsx'));
const MessengerPage = React.lazy(() => import('./pages/MessengerPage.jsx'));
const MemberDetailPage = React.lazy(() => import('./pages/MemberDetailPage.jsx'));
const AlbumsPage = React.lazy(() => import('./pages/AlbumsPage.jsx'));
const AlbumCategoryPage = React.lazy(() => import('./pages/AlbumCategoryPage.jsx'));
const AlbumPhotoPage = React.lazy(() => import('./pages/AlbumPhotoPage.jsx'));
const AlbumUploadPage = React.lazy(() => import('./pages/AlbumUploadPage.jsx'));
const EventsPage = React.lazy(() => import('./pages/EventsPage.jsx'));
const AnnouncementsPage = React.lazy(() => import('./pages/AnnouncementsPage.jsx'));
const ProfilePage = React.lazy(() => import('./pages/ProfilePage.jsx'));
const ProfilePhotoPage = React.lazy(() => import('./pages/ProfilePhotoPage.jsx'));
const ProfileVerificationPage = React.lazy(() => import('./pages/ProfileVerificationPage.jsx'));
const ProfileEmailChangePage = React.lazy(() => import('./pages/ProfileEmailChangePage.jsx'));
const MemberRequestsPage = React.lazy(() => import('./pages/MemberRequestsPage.jsx'));
const AdminPage = React.lazy(() => import('./pages/AdminPage.jsx'));
const MessageComposePage = React.lazy(() => import('./pages/MessageComposePage.jsx'));
const MessageDetailPage = React.lazy(() => import('./pages/MessageDetailPage.jsx'));
const FollowingPage = React.lazy(() => import('./pages/FollowingPage.jsx'));
const HelpPage = React.lazy(() => import('./pages/HelpPage.jsx'));
const GamesPage = React.lazy(() => import('./pages/GamesPage.jsx'));
const NotificationsPage = React.lazy(() => import('./pages/NotificationsPage.jsx'));
const JobsPage = React.lazy(() => import('./pages/JobsPage.jsx'));
const TeachersNetworkPage = React.lazy(() => import('./pages/TeachersNetworkPage.jsx'));
const NetworkingHubPage = React.lazy(() => import('./pages/NetworkingHubPage.jsx'));
const OpportunityInboxPage = React.lazy(() => import('./pages/OpportunityInboxPage.jsx'));

function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  function isProfileCompletionRequired() {
    if (!user) return false;
    const state = String(user.state || '').toLowerCase();
    return state === 'incomplete';
  }

  function canAccessRouteDuringCompletion() {
    return location.pathname === '/new/profile' || location.pathname === '/new/profile/photo' || location.pathname === '/new/profile/verification' || location.pathname === '/new/profile/email-change' || location.pathname === '/new/requests';
  }

  if (loading) return children;
  if (!user) return <Navigate to="/new/login" replace />;
  if (location.pathname === '/new/profile/verification' && Number(user?.verified || 0) === 1) {
    return <Navigate to="/new/profile" replace />;
  }
  if (isProfileCompletionRequired() && !canAccessRouteDuringCompletion()) {
    return <Navigate to="/new/profile?complete=1" replace />;
  }
  return children;
}

function RouteFallback() {
  return <div className="muted" style={{ padding: 16 }}>Yukleniyor...</div>;
}

function AppProviders() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <AuthProvider>
          <GlobalActionFeedback />
          <React.Suspense fallback={<RouteFallback />}>
            <Outlet />
          </React.Suspense>
        </AuthProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}

export const appRoutes = createRoutesFromElements(
  <Route element={<AppProviders />}>
    <Route path="/new/login" element={<LoginPage />} />
    <Route path="/new/root-login" element={<RootLoginPage />} />
    <Route path="/new/register" element={<RegisterPage />} />
    <Route path="/new/activate" element={<ActivationPage />} />
    <Route path="/new/activation/resend" element={<ActivationResendPage />} />
    <Route path="/new/password-reset" element={<PasswordResetPage />} />
    <Route path="/new" element={<RequireAuth><FeedPage /></RequireAuth>} />
    <Route path="/new/explore" element={<RequireAuth><ExplorePage /></RequireAuth>} />
    <Route path="/new/explore/members" element={<RequireAuth><ExplorePage fullMode /></RequireAuth>} />
    <Route path="/new/explore/suggestions" element={<RequireAuth><ExploreSuggestionsPage /></RequireAuth>} />
    <Route path="/new/following" element={<RequireAuth><FollowingPage /></RequireAuth>} />
    <Route path="/new/members/:id" element={<RequireAuth><MemberDetailPage /></RequireAuth>} />
    <Route path="/new/groups" element={<RequireAuth><GroupsPage /></RequireAuth>} />
    <Route path="/new/groups/:id" element={<RequireAuth><GroupDetailPage /></RequireAuth>} />
    <Route path="/new/messages" element={<RequireAuth><MessagesPage /></RequireAuth>} />
    <Route path="/new/messenger" element={<RequireAuth><MessengerPage /></RequireAuth>} />
    <Route path="/new/notifications" element={<RequireAuth><NotificationsPage /></RequireAuth>} />
    <Route path="/new/messages/compose" element={<RequireAuth><MessageComposePage /></RequireAuth>} />
    <Route path="/new/messages/:id" element={<RequireAuth><MessageDetailPage /></RequireAuth>} />
    <Route path="/new/albums" element={<RequireAuth><AlbumsPage /></RequireAuth>} />
    <Route path="/new/albums/upload" element={<RequireAuth><AlbumUploadPage /></RequireAuth>} />
    <Route path="/new/albums/photo/:id" element={<RequireAuth><AlbumPhotoPage /></RequireAuth>} />
    <Route path="/new/albums/:id" element={<RequireAuth><AlbumCategoryPage /></RequireAuth>} />
    <Route path="/new/events" element={<RequireAuth><EventsPage /></RequireAuth>} />
    <Route path="/new/announcements" element={<RequireAuth><AnnouncementsPage /></RequireAuth>} />
    <Route path="/new/jobs" element={<RequireAuth><JobsPage /></RequireAuth>} />
    <Route path="/new/opportunities" element={<RequireAuth><OpportunityInboxPage /></RequireAuth>} />
    <Route path="/new/network/hub" element={<RequireAuth><NetworkingHubPage /></RequireAuth>} />
    <Route path="/new/network/inbox" element={<RequireAuth><NetworkingHubPage /></RequireAuth>} />
    <Route path="/new/network/teachers" element={<RequireAuth><TeachersNetworkPage /></RequireAuth>} />
    <Route path="/new/games" element={<RequireAuth><GamesPage /></RequireAuth>} />
    <Route path="/new/games/:game" element={<RequireAuth><GamesPage /></RequireAuth>} />
    <Route path="/new/profile" element={<RequireAuth><ProfilePage /></RequireAuth>} />
    <Route path="/new/profile/photo" element={<RequireAuth><ProfilePhotoPage /></RequireAuth>} />
    <Route path="/new/profile/verification" element={<RequireAuth><ProfileVerificationPage /></RequireAuth>} />
    <Route path="/new/profile/email-change" element={<RequireAuth><ProfileEmailChangePage /></RequireAuth>} />
    <Route path="/new/requests" element={<RequireAuth><MemberRequestsPage /></RequireAuth>} />
    <Route path="/new/help" element={<RequireAuth><HelpPage /></RequireAuth>} />
    <Route path="/new/admin" element={<RequireAuth><AdminPage /></RequireAuth>} />
    <Route path="/new/*" element={<Navigate to="/new" replace />} />
  </Route>
);
