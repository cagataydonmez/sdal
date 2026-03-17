import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Layout from '../../components/Layout.jsx';
import AccessDeniedView from '../../components/admin/AccessDeniedView.jsx';
import { useAuth } from '../../utils/auth.jsx';
import AdminSidebar from '../../admin/components/AdminSidebar.jsx';
import DashboardSection from './sections/DashboardSection.jsx';
import UsersSection from './sections/UsersSection.jsx';
import AlbumSection from './sections/AlbumSection.jsx';
import ContentModerationSection from './sections/ContentModerationSection.jsx';
import MessagingSafetySection from './sections/MessagingSafetySection.jsx';
import GroupsEventsSection from './sections/GroupsEventsSection.jsx';
import NotificationsSection from './sections/NotificationsSection.jsx';
import SettingsSection from './sections/SettingsSection.jsx';
import SystemSection from './sections/SystemSection.jsx';
import TeacherNetworkSection from './sections/TeacherNetworkSection.jsx';
import LanguagesSection from './sections/LanguagesSection.jsx';
import { useI18n } from '../../utils/i18n.jsx';

function normalizeRole(value) {
  return String(value || '').trim().toLowerCase();
}

export default function AdminShellPage() {
  const { user } = useAuth();
  const { t } = useI18n();
  const role = normalizeRole(user?.role);
  const isRoot = role === 'root';
  const isAdmin = isRoot || role === 'admin' || Number(user?.admin || 0) === 1;
  const isAlbumAdmin = isAdmin || Number(user?.albumadmin || 0) === 1;
  const isModerator = role === 'mod';
  const canUseAdminConsole = isAlbumAdmin || isModerator;

  const permissionSet = useMemo(() => new Set(user?.moderationPermissionKeys || []), [user?.moderationPermissionKeys]);
  const hasPermission = useCallback((permissionKey) => isAdmin || permissionSet.has(permissionKey), [isAdmin, permissionSet]);

  const sections = useMemo(() => {
    const definition = [
      {
        key: 'dashboard',
        label: t('Kontrol Paneli'),
        hint: t('Operasyon sağlığı ve kuyruk durumu'),
        visible: isAdmin,
        render: (navigate) => <DashboardSection onNavigate={navigate} />
      },
      {
        key: 'users',
        label: t('Kullanıcılar'),
        hint: t('Profiller, roller ve yaşam döngüsü kontrolleri'),
        visible: isAdmin,
        render: () => <UsersSection canManageRoles={isAdmin} />
      },
      {
        key: 'content',
        label: t('İçerik Moderasyonu'),
        hint: t('Tüm içerik: gönderiler, hikayeler, kullanıcılar, fotoğraflar, sohbet, mesajlar, gruplar'),
        visible: hasPermission('posts.view') || hasPermission('stories.view') || hasPermission('chat.view') || hasPermission('messages.view') || hasPermission('groups.view') || isAdmin || isAlbumAdmin,
        render: () => (
          <ContentModerationSection
            canViewPosts={hasPermission('posts.view')}
            canViewStories={hasPermission('stories.view')}
            canDeletePosts={hasPermission('posts.delete')}
            canDeleteStories={hasPermission('stories.delete')}
            canViewChat={hasPermission('chat.view')}
            canDeleteChat={hasPermission('chat.delete')}
            canViewMessages={hasPermission('messages.view')}
            canDeleteMessages={hasPermission('messages.delete')}
            canViewGroups={hasPermission('groups.view')}
            canDeleteGroups={hasPermission('groups.delete')}
            canViewUsers={isAdmin}
            canDeleteUsers={isAdmin}
            canViewPhotos={isAlbumAdmin}
            canDeletePhotos={isAlbumAdmin}
            isAdmin={isAdmin}
          />
        )
      },
      {
        key: 'albums',
        label: t('Fotoğraf Albümleri'),
        hint: t('Albüm kategorileri ve fotoğraf moderasyonu'),
        visible: isAlbumAdmin,
        render: () => <AlbumSection canManageAlbums={isAlbumAdmin} />
      },
      {
        key: 'messaging',
        label: t('Mesajlaşma ve Güvenlik'),
        hint: t('Sohbet, direkt mesaj ve terim moderasyonu'),
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
        label: t('Gruplar / Etkinlikler'),
        hint: t('Topluluk seviyesinde yönetişim kontrolleri'),
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
        label: t('Bildirimler'),
        hint: t('Doğrulama ve destek talep kuyrukları'),
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
        key: 'teacher-network',
        label: t('Öğretmen Ağı'),
        hint: t('Öğretmen/mezun ilişki moderasyonu ve incelemesi'),
        visible: hasPermission('requests.view'),
        render: () => <TeacherNetworkSection />
      },
      {
        key: 'languages',
        label: t('Diller'),
        hint: t('Dil değişkenleri, çeviriler ve yerel ayar yönetimi'),
        visible: isAdmin,
        render: () => <LanguagesSection isAdmin={isAdmin} />
      },
      {
        key: 'settings',
        label: t('Ayarlar'),
        hint: t('Site, modüller, medya ve e-posta yapılandırması'),
        visible: isAdmin,
        render: () => <SettingsSection isAdmin={isAdmin} />
      },
      {
        key: 'system',
        label: t('Sistem'),
        hint: t('Loglar, veritabanı araçları ve yedekler'),
        visible: isAdmin,
        render: () => <SystemSection isAdmin={isAdmin} />
      }
    ];

    return definition.filter((item) => item.visible);
  }, [hasPermission, isAdmin, isAlbumAdmin, t]);

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
      <Layout title={t('Yönetim')}>
        <AccessDeniedView />
      </Layout>
    );
  }

  if (!sections.length) {
    return (
      <Layout title={t('Yönetim Konsolu')}>
        <div className="panel">
          <div className="panel-body">
            <div className="muted">{t('Hesabına henüz atanmış bir yönetim veya moderasyon izni yok.')}</div>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout title={t('Yönetim Konsolu')}>
      <div className="ops-shell">
        <AdminSidebar sections={sections} activeKey={activeKey} onChange={setActiveKey} />

        <div className="ops-content stack">
          <div className="panel">
            <div className="panel-body ops-shell-header">
              <div>
                <h3>{activeSection?.label}</h3>
                <div className="muted">{t('Rol')}: {role || 'user'} {isRoot ? '(root)' : ''}</div>
              </div>
              <div className="ops-inline-actions">
                {isAdmin ? <span className="chip">{t('Global yönetici')}</span> : null}
                {!isAdmin && isAlbumAdmin ? <span className="chip">{t('Albüm yöneticisi')}</span> : null}
                {isModerator ? <span className="chip">{t('Kapsamlı moderatör')}</span> : null}
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
