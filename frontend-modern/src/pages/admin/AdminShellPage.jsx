import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Layout from '../../components/Layout.jsx';
import AccessDeniedView from '../../components/admin/AccessDeniedView.jsx';
import { useAuth } from '../../utils/auth.jsx';
import AdminSidebar from '../../admin/components/AdminSidebar.jsx';
import DashboardSection from './sections/DashboardSection.jsx';
import UsersSection from './sections/UsersSection.jsx';
import ContentModerationSection from './sections/ContentModerationSection.jsx';
import MessagingSafetySection from './sections/MessagingSafetySection.jsx';
import GroupsEventsSection from './sections/GroupsEventsSection.jsx';
import NotificationsSection from './sections/NotificationsSection.jsx';
import SettingsSection from './sections/SettingsSection.jsx';
import SystemSection from './sections/SystemSection.jsx';

function normalizeRole(value) {
  return String(value || '').trim().toLowerCase();
}

export default function AdminShellPage() {
  const { user } = useAuth();
  const role = normalizeRole(user?.role);
  const isRoot = role === 'root';
  const isAdmin = isRoot || role === 'admin' || Number(user?.admin || 0) === 1;
  const isModerator = role === 'mod';
  const canUseAdminConsole = isAdmin || isModerator;

  const permissionSet = useMemo(() => new Set(user?.moderationPermissionKeys || []), [user?.moderationPermissionKeys]);
  const hasPermission = useCallback((permissionKey) => isAdmin || permissionSet.has(permissionKey), [isAdmin, permissionSet]);

  const sections = useMemo(() => {
    const definition = [
      {
        key: 'dashboard',
        label: 'Dashboard',
        hint: 'Operations health and queue pulse',
        visible: isAdmin,
        render: (navigate) => <DashboardSection onNavigate={navigate} />
      },
      {
        key: 'users',
        label: 'Users',
        hint: 'Profiles, roles, and lifecycle controls',
        visible: isAdmin,
        render: () => <UsersSection canManageRoles={isAdmin} />
      },
      {
        key: 'content',
        label: 'Content Moderation',
        hint: 'Posts and stories moderation queues',
        visible: hasPermission('posts.view') || hasPermission('stories.view'),
        render: () => (
          <ContentModerationSection
            canViewPosts={hasPermission('posts.view')}
            canViewStories={hasPermission('stories.view')}
            canDeletePosts={hasPermission('posts.delete')}
            canDeleteStories={hasPermission('stories.delete')}
          />
        )
      },
      {
        key: 'messaging',
        label: 'Messaging & Safety',
        hint: 'Chat, direct message, and term moderation',
        visible: hasPermission('chat.view') || hasPermission('messages.view') || isAdmin,
        render: () => (
          <MessagingSafetySection
            canViewChat={hasPermission('chat.view')}
            canDeleteChat={hasPermission('chat.delete')}
            canViewDirectMessages={hasPermission('messages.view')}
            canDeleteDirectMessages={hasPermission('messages.delete')}
            canManageTerms={isAdmin}
          />
        )
      },
      {
        key: 'groups',
        label: 'Groups / Events',
        hint: 'Community-level governance controls',
        visible: hasPermission('groups.view') || isAdmin,
        render: () => (
          <GroupsEventsSection
            canViewGroups={hasPermission('groups.view')}
            canDeleteGroups={hasPermission('groups.delete')}
            isAdmin={isAdmin}
          />
        )
      },
      {
        key: 'notifications',
        label: 'Notifications',
        hint: 'Verification and support request queues',
        visible: hasPermission('requests.view'),
        render: () => (
          <NotificationsSection
            canViewRequests={hasPermission('requests.view')}
            canModerateRequests={hasPermission('requests.moderate')}
            isAdmin={isAdmin}
          />
        )
      },
      {
        key: 'settings',
        label: 'Settings',
        hint: 'Site, modules, media, and email config',
        visible: isAdmin,
        render: () => <SettingsSection isAdmin={isAdmin} />
      },
      {
        key: 'system',
        label: 'System',
        hint: 'Logs, database tools, and backups',
        visible: isAdmin,
        render: () => <SystemSection isAdmin={isAdmin} />
      }
    ];

    return definition.filter((item) => item.visible);
  }, [hasPermission, isAdmin]);

  const [activeKey, setActiveKey] = useState('dashboard');

  useEffect(() => {
    if (!sections.length) return;
    if (!sections.some((item) => item.key === activeKey)) {
      setActiveKey(sections[0].key);
    }
  }, [activeKey, sections]);

  const activeSection = sections.find((item) => item.key === activeKey) || sections[0] || null;

  if (!canUseAdminConsole) {
    return (
      <Layout title="Admin">
        <AccessDeniedView />
      </Layout>
    );
  }

  if (!sections.length) {
    return (
      <Layout title="Admin Console">
        <div className="panel">
          <div className="panel-body">
            <div className="muted">Your account has no assigned admin/moderation permissions yet.</div>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout title="Admin Console">
      <div className="ops-shell">
        <AdminSidebar sections={sections} activeKey={activeKey} onChange={setActiveKey} />

        <div className="ops-content stack">
          <div className="panel">
            <div className="panel-body ops-shell-header">
              <div>
                <h3>{activeSection?.label}</h3>
                <div className="muted">Role: {role || 'user'} {isRoot ? '(root)' : ''}</div>
              </div>
              <div className="ops-inline-actions">
                {isAdmin ? <span className="chip">Global admin</span> : null}
                {isModerator ? <span className="chip">Scoped moderator</span> : null}
              </div>
            </div>
          </div>

          {activeSection?.render((key) => {
            if (sections.some((item) => item.key === key)) setActiveKey(key);
          })}
        </div>
      </div>
    </Layout>
  );
}
