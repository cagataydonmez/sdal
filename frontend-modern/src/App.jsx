import React, { useEffect } from 'react';
import { Navigate, Outlet, Route, createRoutesFromElements, useLocation } from './router.jsx';
import { AuthProvider, useAuth } from './utils/auth.jsx';
import GlobalActionFeedback from './components/GlobalActionFeedback.jsx';
import { ThemeProvider } from './utils/theme.jsx';
import { I18nProvider, useI18n } from './utils/i18n.jsx';
import { resolveLandingPathFromSiteAccess } from './utils/moduleNavigation.js';
import { fetchSiteAccess, getCachedSiteAccess } from './utils/siteAccess.js';

const LoginPage = React.lazy(() => import('./pages/LoginPage.jsx'));
const RootLoginPage = React.lazy(() => import('./pages/RootLoginPage.jsx'));
const RegisterPage = React.lazy(() => import('./pages/RegisterPage.jsx'));
const ActivationPage = React.lazy(() => import('./pages/ActivationPage.jsx'));
const ActivationResendPage = React.lazy(() => import('./pages/ActivationResendPage.jsx'));
const PasswordResetPage = React.lazy(() => import('./pages/PasswordResetPage.jsx'));
const ModuleInactivePage = React.lazy(() => import('./pages/ModuleInactivePage.jsx'));

const ExplorePage = React.lazy(() => import('./pages/ExplorePage.jsx'));
const FeedPage = React.lazy(() => import('./pages/FeedPage.jsx'));
const PostPage = React.lazy(() => import('./pages/PostPage.jsx'));
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
const LegacyOpportunitiesRedirect = React.lazy(() => import('./pages/LegacyOpportunitiesRedirect.jsx'));

function buildAccessState(payload, moduleKey) {
  return {
    loading: false,
    moduleOpen: payload?.moduleOpen !== false,
    moduleKey: payload?.moduleKey || moduleKey,
    message: payload?.moduleOpen === false ? (payload?.message || 'Bu modül geçici olarak kapatıldı.') : ''
  };
}

function RequireModuleAccess({ moduleKey, accessPath, children }) {
  const location = useLocation();
  const [accessState, setAccessState] = React.useState({ loading: true, moduleOpen: true, moduleKey, message: '' });
  const requestedPath = accessPath || location.pathname;

  useEffect(() => {
    let mounted = true;
    const cached = getCachedSiteAccess(requestedPath);
    if (cached?.data) {
      setAccessState(buildAccessState(cached.data, moduleKey));
      if (!cached.stale) return () => {
        mounted = false;
      };
    } else {
      setAccessState((prev) => ({ ...prev, loading: true }));
    }
    fetchSiteAccess(requestedPath, { force: Boolean(cached?.stale) })
      .then((payload) => {
        if (!mounted) return;
        setAccessState(buildAccessState(payload, moduleKey));
      })
      .catch(() => {
        if (!mounted) return;
        setAccessState({ loading: false, moduleOpen: true, moduleKey, message: '' });
      });
    return () => {
      mounted = false;
    };
  }, [moduleKey, requestedPath]);

  if (accessState.loading) return <RouteFallback />;
  if (!accessState.moduleOpen) return <ModuleInactivePage moduleKey={accessState.moduleKey} message={accessState.message} />;
  return children;
}

function LegacyOpportunityRoute() {
  return (
    <RequireAuth>
      <RequireModuleAccess moduleKey="explore" accessPath="/new/explore">
        <LegacyOpportunitiesRedirect />
      </RequireModuleAccess>
    </RequireAuth>
  );
}

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

  if (loading) return <RouteFallback fullPage />;
  if (!user) return <Navigate to="/new/login" replace />;
  if (location.pathname === '/new/profile/verification' && Number(user?.verified || 0) === 1) {
    return <Navigate to="/new/profile" replace />;
  }
  if (isProfileCompletionRequired() && !canAccessRouteDuringCompletion()) {
    return <Navigate to="/new/profile?complete=1" replace />;
  }
  return children;
}

function RouteFallback({ fullPage = false }) {
  const { t } = useI18n();
  return (
    <div className={`route-fallback-shell ${fullPage ? 'is-page' : ''}`} role="status" aria-live="polite">
      <div className="route-fallback-card">
        <span className="route-fallback-kicker">{t('loading')}</span>
        <div className="route-fallback-dots" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
      </div>
    </div>
  );
}

function DefaultLandingRoute() {
  const [targetPath, setTargetPath] = React.useState('');
  const [loadingTarget, setLoadingTarget] = React.useState(() => !getCachedSiteAccess('/new')?.data);

  useEffect(() => {
    let mounted = true;
    const cached = getCachedSiteAccess('/new');
    if (cached?.data) {
      setTargetPath(resolveLandingPathFromSiteAccess(cached.data || {}));
      if (!cached.stale) {
        setLoadingTarget(false);
        return () => {
          mounted = false;
        };
      }
    }
    fetchSiteAccess('/new', { force: Boolean(cached?.stale) })
      .then((payload) => {
        if (!mounted) return;
        setTargetPath(resolveLandingPathFromSiteAccess(payload || {}));
      })
      .catch(() => {
        if (!mounted) return;
        setTargetPath('/new');
      })
      .finally(() => {
        if (mounted) setLoadingTarget(false);
      });
    return () => {
      mounted = false;
    };
  }, []);

  if (loadingTarget) return <RouteFallback fullPage />;
  if (!targetPath || targetPath === '/new') return <FeedPage />;
  return <Navigate to={targetPath} replace />;
}

// Syncs auth state with language defaults configured by admin
function LangAuthSync() {
  const { user, loading } = useAuth();
  const { applyLangDefault, langConfig } = useI18n();
  useEffect(() => {
    if (loading) return;
    applyLangDefault(!!user);
  }, [user, loading, langConfig, applyLangDefault]);
  return null;
}

function AppProviders() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <AuthProvider>
          <LangAuthSync />
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
    <Route path="/new" element={<RequireAuth><DefaultLandingRoute /></RequireAuth>} />
    <Route path="/new/posts/:id" element={<RequireAuth><RequireModuleAccess moduleKey="feed" accessPath="/new"><PostPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/explore" element={<RequireAuth><RequireModuleAccess moduleKey="explore" accessPath="/new/explore"><ExplorePage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/explore/members" element={<RequireAuth><RequireModuleAccess moduleKey="explore" accessPath="/new/explore"><ExplorePage fullMode /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/explore/suggestions" element={<RequireAuth><RequireModuleAccess moduleKey="explore" accessPath="/new/explore"><ExploreSuggestionsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/following" element={<RequireAuth><RequireModuleAccess moduleKey="following" accessPath="/new/following"><FollowingPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/members/:id" element={<RequireAuth><MemberDetailPage /></RequireAuth>} />
    <Route path="/new/groups" element={<RequireAuth><RequireModuleAccess moduleKey="groups" accessPath="/new/groups"><GroupsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/groups/:id" element={<RequireAuth><RequireModuleAccess moduleKey="groups" accessPath="/new/groups"><GroupDetailPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/messages" element={<RequireAuth><RequireModuleAccess moduleKey="messages" accessPath="/new/messages"><MessagesPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/messenger" element={<RequireAuth><RequireModuleAccess moduleKey="messenger" accessPath="/new/messenger"><MessengerPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/notifications" element={<RequireAuth><RequireModuleAccess moduleKey="notifications" accessPath="/new/notifications"><NotificationsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/messages/compose" element={<RequireAuth><RequireModuleAccess moduleKey="messages" accessPath="/new/messages"><MessageComposePage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/messages/:id" element={<RequireAuth><RequireModuleAccess moduleKey="messages" accessPath="/new/messages"><MessageDetailPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/albums" element={<RequireAuth><RequireModuleAccess moduleKey="albums" accessPath="/new/albums"><AlbumsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/albums/upload" element={<RequireAuth><RequireModuleAccess moduleKey="albums" accessPath="/new/albums"><AlbumUploadPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/albums/photo/:id" element={<RequireAuth><RequireModuleAccess moduleKey="albums" accessPath="/new/albums"><AlbumPhotoPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/albums/:id" element={<RequireAuth><RequireModuleAccess moduleKey="albums" accessPath="/new/albums"><AlbumCategoryPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/events" element={<RequireAuth><RequireModuleAccess moduleKey="events" accessPath="/new/events"><EventsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/announcements" element={<RequireAuth><RequireModuleAccess moduleKey="announcements" accessPath="/new/announcements"><AnnouncementsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/jobs" element={<RequireAuth><RequireModuleAccess moduleKey="jobs" accessPath="/new/jobs"><JobsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/opportunities" element={<LegacyOpportunityRoute />} />
    <Route path="/new/network/hub" element={<RequireAuth><RequireModuleAccess moduleKey="networking" accessPath="/new/network/hub"><NetworkingHubPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/network/inbox" element={<RequireAuth><RequireModuleAccess moduleKey="networking" accessPath="/new/network/hub"><NetworkingHubPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/network/teachers" element={<RequireAuth><RequireModuleAccess moduleKey="teachers_network" accessPath="/new/network/teachers"><TeachersNetworkPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/games" element={<RequireAuth><RequireModuleAccess moduleKey="games" accessPath="/new/games"><GamesPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/games/:game" element={<RequireAuth><RequireModuleAccess moduleKey="games" accessPath="/new/games"><GamesPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/profile" element={<RequireAuth><RequireModuleAccess moduleKey="profile" accessPath="/new/profile"><ProfilePage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/profile/photo" element={<RequireAuth><RequireModuleAccess moduleKey="profile" accessPath="/new/profile"><ProfilePhotoPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/profile/verification" element={<RequireAuth><RequireModuleAccess moduleKey="profile" accessPath="/new/profile"><ProfileVerificationPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/profile/email-change" element={<RequireAuth><RequireModuleAccess moduleKey="profile" accessPath="/new/profile"><ProfileEmailChangePage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/requests" element={<RequireAuth><RequireModuleAccess moduleKey="requests" accessPath="/new/requests"><MemberRequestsPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/help" element={<RequireAuth><RequireModuleAccess moduleKey="help" accessPath="/new/help"><HelpPage /></RequireModuleAccess></RequireAuth>} />
    <Route path="/new/admin" element={<RequireAuth><AdminPage /></RequireAuth>} />
    <Route path="/new/*" element={<Navigate to="/new" replace />} />
  </Route>
);
