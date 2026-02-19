import React, { createContext, useContext, useMemo, useState } from 'react';

const I18N_KEY = 'sdal_new_lang';

const messages = {
  tr: {
    lang_tr: 'Türkçe',
    lang_en: 'İngilizce',
    lang_de: 'Almanca',
    lang_fr: 'Fransızca',
    nav_feed: 'Akış',
    nav_explore: 'Keşfet',
    nav_following: 'Takip Ettiklerim',
    nav_groups: 'Gruplar',
    nav_messages: 'Mesajlar',
    nav_photos: 'Fotoğraflar',
    nav_games: 'Oyunlar',
    nav_events: 'Etkinlikler',
    nav_announcements: 'Duyurular',
    nav_profile: 'Profil',
    nav_help: 'Yardım',
    nav_admin: 'Yönetim',
    nav_notifications: 'Bildirimler',
    profile_preview_members: 'Profilim nasıl görünüyor?',
    follow: 'Takip Et',
    unfollow: 'Takibi Bırak',
    all_notifications: 'Tüm Bildirimleri Gör',
    see_all: 'Tümünü Gör',
    online_members: 'Çevrimiçi Üyeler',
    popular: 'Popüler',
    all: 'Tümü',
    following: 'Takip Ettiklerim',
    advanced_format: 'Gelişmiş Biçimlendirme',
    formatting: 'Biçimlendirme',
    help_engagement: 'Etkileşim Skoru Yardımı'
  },
  en: {
    lang_tr: 'Turkish',
    lang_en: 'English',
    lang_de: 'German',
    lang_fr: 'French',
    nav_feed: 'Feed',
    nav_explore: 'Explore',
    nav_following: 'Following',
    nav_groups: 'Groups',
    nav_messages: 'Messages',
    nav_photos: 'Photos',
    nav_games: 'Games',
    nav_events: 'Events',
    nav_announcements: 'Announcements',
    nav_profile: 'Profile',
    nav_help: 'Help',
    nav_admin: 'Admin',
    nav_notifications: 'Notifications',
    profile_preview_members: 'How my profile appears?',
    follow: 'Follow',
    unfollow: 'Unfollow',
    all_notifications: 'View All Notifications',
    see_all: 'See All',
    online_members: 'Online Members',
    popular: 'Popular',
    all: 'All',
    following: 'Following',
    advanced_format: 'Advanced Formatting',
    formatting: 'Formatting',
    help_engagement: 'Engagement Score Help'
  },
  de: {
    lang_tr: 'Türkisch',
    lang_en: 'Englisch',
    lang_de: 'Deutsch',
    lang_fr: 'Französisch',
    nav_feed: 'Feed',
    nav_explore: 'Entdecken',
    nav_following: 'Gefolgte',
    nav_groups: 'Gruppen',
    nav_messages: 'Nachrichten',
    nav_photos: 'Fotos',
    nav_games: 'Spiele',
    nav_events: 'Veranstaltungen',
    nav_announcements: 'Ankündigungen',
    nav_profile: 'Profil',
    nav_help: 'Hilfe',
    nav_admin: 'Verwaltung',
    nav_notifications: 'Benachrichtigungen',
    profile_preview_members: 'Wie sieht mein Profil aus?',
    follow: 'Folgen',
    unfollow: 'Entfolgen',
    all_notifications: 'Alle Benachrichtigungen',
    see_all: 'Alle anzeigen',
    online_members: 'Online-Mitglieder',
    popular: 'Beliebt',
    all: 'Alle',
    following: 'Gefolgte',
    advanced_format: 'Erweiterte Formatierung',
    formatting: 'Formatierung',
    help_engagement: 'Hilfe zum Interaktionswert'
  },
  fr: {
    lang_tr: 'Turc',
    lang_en: 'Anglais',
    lang_de: 'Allemand',
    lang_fr: 'Français',
    nav_feed: 'Fil',
    nav_explore: 'Explorer',
    nav_following: 'Abonnements',
    nav_groups: 'Groupes',
    nav_messages: 'Messages',
    nav_photos: 'Photos',
    nav_games: 'Jeux',
    nav_events: 'Événements',
    nav_announcements: 'Annonces',
    nav_profile: 'Profil',
    nav_help: 'Aide',
    nav_admin: 'Administration',
    nav_notifications: 'Notifications',
    profile_preview_members: 'Comment mon profil apparaît ?',
    follow: 'Suivre',
    unfollow: 'Ne plus suivre',
    all_notifications: 'Voir toutes les notifications',
    see_all: 'Voir tout',
    online_members: 'Membres en ligne',
    popular: 'Populaire',
    all: 'Tout',
    following: 'Abonnements',
    advanced_format: 'Mise en forme avancée',
    formatting: 'Mise en forme',
    help_engagement: "Aide score d'engagement"
  }
};

const I18nContext = createContext({
  lang: 'tr',
  setLang: () => {},
  t: (key) => key
});

function readInitialLang() {
  if (typeof window === 'undefined') return 'tr';
  const value = String(window.localStorage.getItem(I18N_KEY) || 'tr').toLowerCase();
  if (['tr', 'en', 'de', 'fr'].includes(value)) return value;
  return 'tr';
}

export function I18nProvider({ children }) {
  const [lang, setLangState] = useState(() => readInitialLang());

  const setLang = (value) => {
    const next = ['tr', 'en', 'de', 'fr'].includes(value) ? value : 'tr';
    setLangState(next);
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(I18N_KEY, next);
    }
  };

  const t = (key) => messages[lang]?.[key] || messages.tr?.[key] || key;

  const value = useMemo(() => ({ lang, setLang, t }), [lang]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  return useContext(I18nContext);
}
