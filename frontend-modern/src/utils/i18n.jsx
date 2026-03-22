import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { trFallbackMessages } from './i18nFallbackMessages.js';

const I18N_KEY = 'sdal_new_lang';
const I18N_SOURCE_KEY = 'sdal_new_lang_source';
const LANG_SOURCE_USER = 'user';
const LANG_SOURCE_DEFAULT = 'default';

const messages = {
  tr: {
    lang_tr: 'Türkçe',
    lang_en: 'İngilizce',
    lang_de: 'Almanca',
    lang_fr: 'Fransızca',
    nav_feed: 'Akış',
    main_feed: 'Ana Akış',
    community_feed: 'Topluluk Akışı',
    main_feed_public_note: 'Ana Akış herkese açıktır.',
    community_feed_note: 'Topluluk Akışı sadece kendi topluluğunuzun gönderilerini gösterir.',
    nav_explore: 'Keşfet',
    nav_following: 'Takip Ettiklerim',
    nav_groups: 'Gruplar',
    nav_messages: 'SDAL Inbox',
    nav_messenger: 'SDAL Messenger',
    nav_photos: 'Fotoğraflar',
    nav_games: 'Oyunlar',
    nav_events: 'Etkinlikler',
    nav_announcements: 'Duyurular',
    nav_jobs: 'İş İlanları',
    nav_opportunities: 'Fırsatlar',
    nav_teacher_network: 'Öğretmen Ağı',
    nav_network_hub: 'Ağ Merkezi',
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
    latest: 'En Yeni',
    popular: 'Popüler',
    all: 'Tümü',
    following: 'Takip Ettiklerim',
    advanced_format: 'Gelişmiş Biçimlendirme',
    formatting: 'Biçimlendirme',
    help_engagement: 'Etkileşim Skoru Yardımı',
    post_placeholder: 'Bugün neler oluyor?',
    post_share: 'Paylaş',
    comment_placeholder: 'Yorum yaz...',
    send: 'Gönder',
    no_comments_yet: 'Henüz yorum yok.',
    post_confirm_delete: 'Bu postu silmek istediğine emin misin?',
    post_delete_failed: 'Post silinemedi.',
    post_update_failed: 'Post güncellenemedi.',
    live_chat_edit_failed: 'Mesaj güncellenemedi.',
    live_chat_delete_failed: 'Mesaj silinemedi.',
    filter_none: 'Filtre Yok',
    filter_grayscale: 'Siyah Beyaz',
    filter_sepia: 'Sepya',
    filter_vivid: 'Canlı',
    filter_cool: 'Soğuk',
    filter_warm: 'Sıcak',
    filter_blur: 'Blur',
    filter_sharp: 'Sharp',
    translate_button: 'Çevir',
    translate_loading: 'Çevriliyor...',
    show_original: 'Orijinali Göster',
    translate_failed: 'Çeviri başarısız.',
    rt_undo: 'Geri Al',
    rt_redo: 'Yinele',
    rt_font_size: 'Yazı boyutu',
    rt_color: 'Renk',
    rt_align_left: 'Sola hizala',
    rt_align_center: 'Ortala',
    rt_align_right: 'Sağa hizala',
    rt_align_justify: 'İki yana yasla',
    rt_bullet_list: 'Madde listesi',
    rt_numbered_list: 'Numaralı liste',
    rt_quote: 'Alıntı',
    rt_clear_format: 'Biçimlendirmeyi temizle',
    rt_clear: 'Temizle'
  },
  en: {
    lang_tr: 'Turkish',
    lang_en: 'English',
    lang_de: 'German',
    lang_fr: 'French',
    nav_feed: 'Feed',
    main_feed: 'Main Feed',
    community_feed: 'Community Feed',
    main_feed_public_note: 'Main Feed is visible to everyone.',
    community_feed_note: 'Community Feed only shows posts from your own community.',
    nav_explore: 'Explore',
    nav_following: 'Following',
    nav_groups: 'Groups',
    nav_messages: 'SDAL Inbox',
    nav_messenger: 'SDAL Messenger',
    nav_photos: 'Photos',
    nav_games: 'Games',
    nav_events: 'Events',
    nav_announcements: 'Announcements',
    nav_jobs: 'Jobs',
    nav_opportunities: 'Opportunities',
    nav_teacher_network: 'Teacher Network',
    nav_network_hub: 'Network Hub',
    trust_badge_verified_alumni: 'Verified Alumni',
    trust_badge_mentor: 'Mentor',
    trust_badge_teacher_network: 'In Teacher Network',
    nav_profile: 'Profile',
    nav_help: 'Help',
    nav_admin: 'Admin',
    nav_notifications: 'Notifications',
    profile_preview_members: 'How my profile appears?',
    login_welcome_eyebrow: 'Return to the SDAL community',
    login_welcome_title: 'Your connections, feed, and school memory continue here.',
    login_welcome_subtitle: 'After signing in, you can follow the feed, rediscover alumni, and make your place in the community visible again.',
    login_welcome_step_feed: 'See who is active in the feed.',
    login_welcome_step_people: 'Rediscover alumni and reconnect.',
    login_welcome_step_groups: 'Join the community through groups, stories, and messages.',
    login_form_intro: 'A few steps and you are back inside your network.',
    login_oauth_title: 'Or continue with a social account',
    login_register_hint: 'If this is your first visit, you can create your account in a few minutes.',
    profile_editor_title: 'Make yourself visible in the community',
    profile_editor_subtitle: 'Complete the core details that help people recognize you. Start with who you are, then add your professional context.',
    profile_editor_progress_label: 'Profile visibility',
    profile_editor_progress_ready: 'Your profile already looks recognizable in the community.',
    profile_editor_check_identity: 'Identity and graduation details',
    profile_editor_check_professional: 'Job, company, or expertise',
    profile_editor_check_community: 'Mentoring, signature, or connection signals',
    profile_editor_identity_title: 'Core identity',
    profile_editor_identity_hint: 'The details people will use to recognize you at a glance.',
    profile_editor_presence_title: 'Professional presence',
    profile_editor_presence_hint: 'Help people who rediscover you quickly understand what you do today.',
    profile_editor_community_title: 'Community contribution',
    profile_editor_community_hint: 'Signals like mentoring and a short signature make your profile feel warmer and easier to approach.',
    profile_editor_consent_title: 'Permissions and verification',
    profile_editor_consent_hint: 'Only shown when needed; these unlock visibility and account access.',
    profile_editor_sidebar_title: 'Profile snapshot',
    profile_editor_sidebar_hint: 'This is the first impression members get when they find you.',
    profile_editor_name_empty: 'Your name will appear here once it is complete.',
    profile_editor_city_empty: 'Add your city',
    profile_editor_work_empty: 'Add a job, company, or title',
    profile_editor_visibility_ready: 'Your profile is ready to help you reconnect.',
    profile_editor_visibility_incomplete: 'A few more details will make your profile easier to find and trust.',
    profile_editor_actions_title: 'Quick steps',
    profile_editor_email_note: 'The email field is view-only for security.',
    profile_editor_story_active_hint: 'When you share a new story, the community notices you faster in the feed.',
    profile_editor_story_expired_hint: 'You can repost an older story or return with a fresh update.',
    follow: 'Follow',
    unfollow: 'Unfollow',
    all_notifications: 'View All Notifications',
    see_all: 'See All',
    online_members: 'Online Members',
    latest: 'Latest',
    popular: 'Popular',
    all: 'All',
    following: 'Following',
    advanced_format: 'Advanced Formatting',
    formatting: 'Formatting',
    help_engagement: 'Engagement Score Help',
    post_placeholder: "What's happening today?",
    post_share: 'Share',
    comment_placeholder: 'Write a comment...',
    send: 'Send',
    no_comments_yet: 'No comments yet.',
    post_confirm_delete: 'Are you sure you want to delete this post?',
    post_delete_failed: 'Post could not be deleted.',
    post_update_failed: 'Post could not be updated.',
    live_chat_edit_failed: 'Message could not be updated.',
    live_chat_delete_failed: 'Message could not be deleted.',
    filter_none: 'No Filter',
    filter_grayscale: 'Grayscale',
    filter_sepia: 'Sepia',
    filter_vivid: 'Vivid',
    filter_cool: 'Cool',
    filter_warm: 'Warm',
    filter_blur: 'Blur',
    filter_sharp: 'Sharp',
    translate_button: 'Translate',
    translate_loading: 'Translating...',
    show_original: 'Show Original',
    translate_failed: 'Translation failed.',
    rt_undo: 'Undo',
    rt_redo: 'Redo',
    rt_font_size: 'Font size',
    rt_color: 'Color',
    rt_align_left: 'Align left',
    rt_align_center: 'Align center',
    rt_align_right: 'Align right',
    rt_align_justify: 'Justify',
    rt_bullet_list: 'Bullet list',
    rt_numbered_list: 'Numbered list',
    rt_quote: 'Quote',
    rt_clear_format: 'Clear formatting',
    rt_clear: 'Clear'
  },
  de: {
    lang_tr: 'Türkisch',
    lang_en: 'Englisch',
    lang_de: 'Deutsch',
    lang_fr: 'Französisch',
    nav_feed: 'Feed',
    main_feed: 'Haupt-Feed',
    community_feed: 'Community-Feed',
    main_feed_public_note: 'Der Haupt-Feed ist für alle sichtbar.',
    community_feed_note: 'Der Community-Feed zeigt nur Beiträge aus deiner eigenen Community.',
    nav_explore: 'Entdecken',
    nav_following: 'Gefolgte',
    nav_groups: 'Gruppen',
    nav_messages: 'SDAL Inbox',
    nav_messenger: 'SDAL Messenger',
    nav_photos: 'Fotos',
    nav_games: 'Spiele',
    nav_events: 'Veranstaltungen',
    nav_announcements: 'Ankündigungen',
    nav_jobs: 'Jobs',
    nav_teacher_network: 'Lehrernetzwerk',
    nav_network_hub: 'Netzwerk-Hub',
    trust_badge_verified_alumni: 'Verifizierte Alumni',
    trust_badge_mentor: 'Mentor',
    trust_badge_teacher_network: 'Im Lehrernetzwerk',
    nav_profile: 'Profil',
    nav_help: 'Hilfe',
    nav_admin: 'Verwaltung',
    nav_notifications: 'Benachrichtigungen',
    profile_preview_members: 'Wie sieht mein Profil aus?',
    login_welcome_eyebrow: 'Zur SDAL-Community zuruckkehren',
    login_welcome_title: 'Deine Verbindungen, dein Feed und die Erinnerung an die Schule leben hier weiter.',
    login_welcome_subtitle: 'Nach dem Anmelden kannst du dem Feed folgen, Alumni wiederentdecken und deinen Platz in der Community sichtbar machen.',
    login_welcome_step_feed: 'Sieh, wer im Feed aktiv ist.',
    login_welcome_step_people: 'Entdecke Alumni neu und knupfe wieder Kontakte.',
    login_welcome_step_groups: 'Werde uber Gruppen, Stories und Nachrichten wieder Teil der Community.',
    login_form_intro: 'Noch ein paar Schritte und du bist wieder in deinem Netzwerk.',
    login_oauth_title: 'Oder mit einem sozialen Konto fortfahren',
    login_register_hint: 'Wenn du zum ersten Mal hier bist, kannst du dein Konto in wenigen Minuten erstellen.',
    profile_editor_title: 'Mach dich in der Community sichtbar',
    profile_editor_subtitle: 'Erganz die wichtigsten Angaben, damit man dich leicht wiedererkennt. Beginne mit deiner Identitat und erganze danach deinen beruflichen Kontext.',
    profile_editor_progress_label: 'Profilsichtbarkeit',
    profile_editor_progress_ready: 'Dein Profil wirkt in der Community bereits gut erkennbar.',
    profile_editor_check_identity: 'Identitat und Abschlussangaben',
    profile_editor_check_professional: 'Beruf, Unternehmen oder Fachgebiet',
    profile_editor_check_community: 'Mentoring, Signatur oder Verbindungssignale',
    profile_editor_identity_title: 'Grundidentitat',
    profile_editor_identity_hint: 'Die Angaben, an denen man dich sofort erkennt.',
    profile_editor_presence_title: 'Berufliche Prasenz',
    profile_editor_presence_hint: 'Hilf Menschen, die dich wiederfinden, schnell zu verstehen, was du heute machst.',
    profile_editor_community_title: 'Beitrag zur Community',
    profile_editor_community_hint: 'Signale wie Mentoring und eine kurze Signatur lassen dein Profil warmer und nahbarer wirken.',
    profile_editor_consent_title: 'Freigaben und Verifizierung',
    profile_editor_consent_hint: 'Nur sichtbar, wenn notig; diese Angaben schalten Sichtbarkeit und Zugriff frei.',
    profile_editor_sidebar_title: 'Profilubersicht',
    profile_editor_sidebar_hint: 'Das ist der erste Eindruck, den andere Mitglieder von dir bekommen.',
    profile_editor_name_empty: 'Dein Name erscheint hier, sobald er vollstandig ist.',
    profile_editor_city_empty: 'Stadt hinzufugen',
    profile_editor_work_empty: 'Beruf, Unternehmen oder Titel hinzufugen',
    profile_editor_visibility_ready: 'Dein Profil ist bereit, dir beim Wiederanknupfen zu helfen.',
    profile_editor_visibility_incomplete: 'Mit ein paar weiteren Angaben wird dein Profil leichter auffindbar und vertrauenswurdiger.',
    profile_editor_actions_title: 'Schnelle Schritte',
    profile_editor_email_note: 'Das E-Mail-Feld ist aus Sicherheitsgrunden nur lesbar.',
    profile_editor_story_active_hint: 'Wenn du eine neue Story teilst, wird die Community im Feed schneller auf dich aufmerksam.',
    profile_editor_story_expired_hint: 'Du kannst eine alte Story erneut teilen oder mit einem frischen Update zuruckkommen.',
    follow: 'Folgen',
    unfollow: 'Entfolgen',
    all_notifications: 'Alle Benachrichtigungen',
    see_all: 'Alle anzeigen',
    online_members: 'Online-Mitglieder',
    latest: 'Neueste',
    popular: 'Beliebt',
    all: 'Alle',
    following: 'Gefolgte',
    advanced_format: 'Erweiterte Formatierung',
    formatting: 'Formatierung',
    help_engagement: 'Hilfe zum Interaktionswert',
    post_placeholder: 'Was passiert heute?',
    post_share: 'Teilen',
    comment_placeholder: 'Kommentar schreiben...',
    send: 'Senden',
    no_comments_yet: 'Noch keine Kommentare.',
    post_confirm_delete: 'Möchtest du diesen Beitrag wirklich löschen?',
    post_delete_failed: 'Beitrag konnte nicht gelöscht werden.',
    post_update_failed: 'Beitrag konnte nicht aktualisiert werden.',
    live_chat_edit_failed: 'Nachricht konnte nicht aktualisiert werden.',
    live_chat_delete_failed: 'Nachricht konnte nicht gelöscht werden.',
    filter_none: 'Kein Filter',
    filter_grayscale: 'Graustufen',
    filter_sepia: 'Sepia',
    filter_vivid: 'Lebhaft',
    filter_cool: 'Kühl',
    filter_warm: 'Warm',
    filter_blur: 'Weichzeichnen',
    filter_sharp: 'Scharf',
    translate_button: 'Übersetzen',
    translate_loading: 'Wird übersetzt...',
    show_original: 'Original anzeigen',
    translate_failed: 'Übersetzung fehlgeschlagen.',
    rt_undo: 'Rückgängig',
    rt_redo: 'Wiederholen',
    rt_font_size: 'Schriftgröße',
    rt_color: 'Farbe',
    rt_align_left: 'Linksbündig',
    rt_align_center: 'Zentriert',
    rt_align_right: 'Rechtsbündig',
    rt_align_justify: 'Blocksatz',
    rt_bullet_list: 'Aufzählung',
    rt_numbered_list: 'Nummerierte Liste',
    rt_quote: 'Zitat',
    rt_clear_format: 'Formatierung entfernen',
    rt_clear: 'Löschen'
  },
  fr: {
    lang_tr: 'Turc',
    lang_en: 'Anglais',
    lang_de: 'Allemand',
    lang_fr: 'Français',
    nav_feed: 'Fil',
    main_feed: 'Flux principal',
    community_feed: 'Flux de communauté',
    main_feed_public_note: 'Le flux principal est visible par tout le monde.',
    community_feed_note: 'Le flux de communauté affiche uniquement les publications de votre communauté.',
    nav_explore: 'Explorer',
    nav_following: 'Abonnements',
    nav_groups: 'Groupes',
    nav_messages: 'SDAL Inbox',
    nav_messenger: 'SDAL Messenger',
    nav_photos: 'Photos',
    nav_games: 'Jeux',
    nav_events: 'Événements',
    nav_announcements: 'Annonces',
    nav_jobs: 'Offres',
    nav_teacher_network: 'Réseau des enseignants',
    nav_network_hub: 'Hub Réseau',
    trust_badge_verified_alumni: 'Alumni vérifié',
    trust_badge_mentor: 'Mentor',
    trust_badge_teacher_network: 'Dans le réseau enseignant',
    nav_profile: 'Profil',
    nav_help: 'Aide',
    nav_admin: 'Administration',
    nav_notifications: 'Notifications',
    profile_preview_members: 'Comment mon profil apparaît ?',
    login_welcome_eyebrow: 'Revenir dans la communaute SDAL',
    login_welcome_title: 'Vos liens, votre fil et la memoire de l ecole continuent ici.',
    login_welcome_subtitle: 'Une fois connecte, vous pouvez suivre le fil, retrouver des anciens eleves et rendre votre place dans la communaute plus visible.',
    login_welcome_step_feed: 'Voyez qui est actif dans le fil.',
    login_welcome_step_people: 'Retrouvez des anciens eleves et renouez le contact.',
    login_welcome_step_groups: 'Reprenez place dans la communaute via les groupes, les stories et les messages.',
    login_form_intro: 'Encore quelques instants et vous etes de retour dans votre reseau.',
    login_oauth_title: 'Ou continuer avec un compte social',
    login_register_hint: 'Si c est votre premiere visite, vous pouvez creer votre compte en quelques minutes.',
    profile_editor_title: 'Rendez votre presence visible dans la communaute',
    profile_editor_subtitle: 'Completez les informations essentielles qui aident les autres a vous reconnaitre. Commencez par votre identite, puis ajoutez votre contexte professionnel.',
    profile_editor_progress_label: 'Visibilite du profil',
    profile_editor_progress_ready: 'Votre profil semble deja bien identifiable dans la communaute.',
    profile_editor_check_identity: 'Identite et promotion',
    profile_editor_check_professional: 'Metier, entreprise ou expertise',
    profile_editor_check_community: 'Mentorat, signature ou signaux de lien',
    profile_editor_identity_title: 'Identite essentielle',
    profile_editor_identity_hint: 'Les informations qui permettent de vous reconnaitre au premier regard.',
    profile_editor_presence_title: 'Presence professionnelle',
    profile_editor_presence_hint: 'Aidez les personnes qui vous retrouvent a comprendre rapidement ce que vous faites aujourd hui.',
    profile_editor_community_title: 'Contribution a la communaute',
    profile_editor_community_hint: 'Des signaux comme le mentorat et une courte signature rendent votre profil plus chaleureux et plus approachable.',
    profile_editor_consent_title: 'Autorisations et verification',
    profile_editor_consent_hint: 'Affiche seulement si necessaire; ces elements ouvrent la visibilite et certains acces du compte.',
    profile_editor_sidebar_title: 'Apercu du profil',
    profile_editor_sidebar_hint: 'C est la premiere impression que les membres auront en vous retrouvant.',
    profile_editor_name_empty: 'Votre nom apparaitra ici une fois complete.',
    profile_editor_city_empty: 'Ajoutez votre ville',
    profile_editor_work_empty: 'Ajoutez un metier, une entreprise ou un titre',
    profile_editor_visibility_ready: 'Votre profil est pret a vous aider a renouer le contact.',
    profile_editor_visibility_incomplete: 'Quelques details de plus rendront votre profil plus facile a trouver et a faire confiance.',
    profile_editor_actions_title: 'Etapes rapides',
    profile_editor_email_note: 'Le champ e-mail est en lecture seule pour des raisons de securite.',
    profile_editor_story_active_hint: 'Quand vous partagez une nouvelle story, la communaute vous remarque plus vite dans le fil.',
    profile_editor_story_expired_hint: 'Vous pouvez repartager une ancienne story ou revenir avec une nouvelle mise a jour.',
    follow: 'Suivre',
    unfollow: 'Ne plus suivre',
    all_notifications: 'Voir toutes les notifications',
    see_all: 'Voir tout',
    online_members: 'Membres en ligne',
    latest: 'Plus récent',
    popular: 'Populaire',
    all: 'Tout',
    following: 'Abonnements',
    advanced_format: 'Mise en forme avancée',
    formatting: 'Mise en forme',
    help_engagement: "Aide score d'engagement",
    post_placeholder: "Quoi de neuf aujourd'hui ?",
    post_share: 'Publier',
    comment_placeholder: 'Écrire un commentaire...',
    send: 'Envoyer',
    no_comments_yet: 'Aucun commentaire pour le moment.',
    post_confirm_delete: 'Voulez-vous vraiment supprimer cette publication ?',
    post_delete_failed: 'La publication n\u2019a pas pu être supprimée.',
    post_update_failed: 'La publication n\u2019a pas pu être mise à jour.',
    live_chat_edit_failed: 'Le message n\u2019a pas pu être mis à jour.',
    live_chat_delete_failed: 'Le message n\u2019a pas pu être supprimé.',
    filter_none: 'Sans filtre',
    filter_grayscale: 'Niveaux de gris',
    filter_sepia: 'Sépia',
    filter_vivid: 'Vif',
    filter_cool: 'Froid',
    filter_warm: 'Chaud',
    filter_blur: 'Flou',
    filter_sharp: 'Net',
    translate_button: 'Traduire',
    translate_loading: 'Traduction...',
    show_original: "Voir l'original",
    translate_failed: 'Échec de la traduction.',
    rt_undo: 'Annuler',
    rt_redo: 'Rétablir',
    rt_font_size: 'Taille de police',
    rt_color: 'Couleur',
    rt_align_left: 'Aligner à gauche',
    rt_align_center: 'Centrer',
    rt_align_right: 'Aligner à droite',
    rt_align_justify: 'Justifier',
    rt_bullet_list: 'Liste à puces',
    rt_numbered_list: 'Liste numérotée',
    rt_quote: 'Citation',
    rt_clear_format: 'Effacer la mise en forme',
    rt_clear: 'Effacer'
  }
};

const DEFAULT_LANG_CONFIG = { lang_selection_enabled: true, default_lang_open: 'tr', default_lang_closed: 'tr' };

const I18nContext = createContext({
  lang: 'tr',
  availableLangs: [{ code: 'tr', name: 'Turkish', native_name: 'Türkçe' }],
  langConfig: DEFAULT_LANG_CONFIG,
  langSelectionEnabled: true,
  setLang: () => {},
  applyLangDefault: () => {},
  reloadI18nConfig: async () => {},
  t: (key, params) => {
    const text = trFallbackMessages[key] || key;
    if (!params) return text;
    return Object.entries(params).reduce((acc, [name, value]) => acc.replaceAll(`{${name}}`, String(value ?? '')), text);
  }
});

function readInitialLang() {
  if (typeof window === 'undefined') return 'tr';
  const stored = window.localStorage.getItem(I18N_KEY);
  if (stored) return stored;
  return 'tr';
}

function readLangSource() {
  if (typeof window === 'undefined') return '';
  return String(window.localStorage.getItem(I18N_SOURCE_KEY) || '').trim().toLowerCase();
}

function persistLang(code, source) {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(I18N_KEY, code);
  if (source) {
    window.localStorage.setItem(I18N_SOURCE_KEY, source);
  } else {
    window.localStorage.removeItem(I18N_SOURCE_KEY);
  }
}

function interpolate(text, params) {
  if (!params || typeof params !== 'object') return text;
  return Object.entries(params).reduce((acc, [name, value]) => acc.replaceAll(`{${name}}`, String(value ?? '')), text);
}

function normalizeSourceText(key) {
  if (messages.tr?.[key]) return messages.tr[key];
  if (trFallbackMessages[key]) return trFallbackMessages[key];
  if (!key.includes('_')) return key;
  return key
    .split('_')
    .filter(Boolean)
    .join(' ');
}

export function I18nProvider({ children }) {
  const [lang, setLangState] = useState(() => readInitialLang());
  // dbMessages holds strings loaded from the backend DB per language code
  const [dbMessages, setDbMessages] = useState({});
  const [availableLangs, setAvailableLangs] = useState([]);
  const [langConfig, setLangConfig] = useState(DEFAULT_LANG_CONFIG);
  const [runtimeMessages, setRuntimeMessages] = useState(() => ({ en: {}, de: {}, fr: {} }));
  const runtimeRef = useRef(runtimeMessages);
  const dbRef = useRef(dbMessages);
  const langConfigRef = useRef(langConfig);
  const pendingRef = useRef(new Set());
  const failedRef = useRef(new Set());

  useEffect(() => {
    runtimeRef.current = runtimeMessages;
  }, [runtimeMessages]);

  useEffect(() => {
    dbRef.current = dbMessages;
  }, [dbMessages]);

  useEffect(() => {
    langConfigRef.current = langConfig;
  }, [langConfig]);

  const reloadI18nConfig = useCallback(async () => {
    if (typeof window === 'undefined') return;
    const [config, langsData] = await Promise.all([
      fetch('/api/new/lang-config', { credentials: 'include' }).then((r) => r.ok ? r.json() : DEFAULT_LANG_CONFIG).catch(() => DEFAULT_LANG_CONFIG),
      fetch('/api/new/languages', { credentials: 'include' }).then((r) => r.ok ? r.json() : { languages: [] }).catch(() => ({ languages: [] }))
    ]);
    setLangConfig(config);
    const langs = langsData.languages || [];
    if (!langs.length) return;
    setAvailableLangs(langs);
    const activeCodes = new Set(langs.map((item) => String(item.code || '').trim().toLowerCase()).filter(Boolean));
    const currentLang = String(window.localStorage.getItem(I18N_KEY) || lang || '').trim().toLowerCase();
    const source = readLangSource();
    const fallbackLang = config.default_lang_open || config.default_lang_closed || 'tr';
    if (currentLang && !activeCodes.has(currentLang)) {
      setLangState(fallbackLang);
      persistLang(fallbackLang, LANG_SOURCE_DEFAULT);
      return;
    }
    if (source !== LANG_SOURCE_USER && currentLang !== fallbackLang) {
      setLangState(fallbackLang);
      persistLang(fallbackLang, LANG_SOURCE_DEFAULT);
    }
  }, [lang]);

  // Fetch lang config and available languages from backend on mount
  useEffect(() => {
    void reloadI18nConfig();
  }, [reloadI18nConfig]);

  // Fetch DB strings for current language whenever it changes
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (dbRef.current[lang]) return; // already loaded
    fetch(`/api/new/lang-strings/${lang}`, { credentials: 'include' })
      .then((r) => r.ok ? r.json() : { strings: {} })
      .then((data) => {
        const strings = data.strings || {};
        if (Object.keys(strings).length > 0) {
          setDbMessages((prev) => ({ ...prev, [lang]: strings }));
        }
      })
      .catch(() => {});
  }, [lang]);

  // Apply the site-configured default language based on auth state.
  // Call this from a component that has access to auth (e.g. LangAuthSync in App.jsx).
  const applyLangDefault = useCallback((isAuthenticated) => {
    const config = langConfigRef.current;
    const defaultLang = isAuthenticated ? (config.default_lang_open || 'tr') : (config.default_lang_closed || 'tr');
    const source = readLangSource();
    if (!config.lang_selection_enabled) {
      // Selection disabled: always force the configured default
      setLangState(defaultLang);
      persistLang(defaultLang, LANG_SOURCE_DEFAULT);
    } else {
      // Selection enabled: only preserve explicit user choices.
      const stored = typeof window !== 'undefined' ? window.localStorage.getItem(I18N_KEY) : null;
      if (!stored || source !== LANG_SOURCE_USER) {
        setLangState(defaultLang);
        persistLang(defaultLang, LANG_SOURCE_DEFAULT);
      }
    }
  }, []);

  const setLang = (code) => {
    if (!code) return;
    // Respect lang_selection_enabled: if disabled, ignore user attempts to change
    if (!langConfigRef.current.lang_selection_enabled) return;
    setLangState(code);
    persistLang(code, LANG_SOURCE_USER);
  };

  const t = (key, params) => {
    const sourceText = normalizeSourceText(key);

    // DB strings take highest priority (admin-managed overrides)
    const dbHit = dbRef.current[lang]?.[key];
    if (dbHit) return interpolate(dbHit, params);

    // Static bundled messages
    const staticHit = messages[lang]?.[key];
    if (staticHit) return interpolate(staticHit, params);

    // For Turkish, fall back to trFallbackMessages
    if (lang === 'tr') {
      const fallback = trFallbackMessages[key];
      if (fallback) return interpolate(fallback, params);
      return interpolate(sourceText, params);
    }

    // For other languages, check runtime-translated cache then trigger translation
    const runtimeHit = runtimeRef.current[lang]?.[sourceText];
    if (runtimeHit) return interpolate(runtimeHit, params);

    if (sourceText && sourceText !== key && typeof window !== 'undefined') {
      const cacheKey = `${lang}:${sourceText}`;
      if (!pendingRef.current.has(cacheKey) && !failedRef.current.has(cacheKey)) {
        pendingRef.current.add(cacheKey);
        fetch('/api/new/translate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ text: sourceText, target: lang })
        })
          .then(async (res) => {
            if (!res.ok) throw new Error(await res.text());
            return res.json();
          })
          .then((payload) => {
            const translated = String(payload?.translatedText || '').trim();
            if (!translated) return;
            setRuntimeMessages((prev) => ({
              ...prev,
              [lang]: {
                ...(prev[lang] || {}),
                [sourceText]: translated
              }
            }));
          })
          .catch(() => {
            failedRef.current.add(cacheKey);
          })
          .finally(() => {
            pendingRef.current.delete(cacheKey);
          });
      }
    }

    // Fall back to Turkish source text while translation is pending
    return interpolate(sourceText, params);
  };

  const langSelectionEnabled = langConfig.lang_selection_enabled;
  const value = useMemo(
    () => ({ lang, availableLangs, langConfig, langSelectionEnabled, setLang, applyLangDefault, reloadI18nConfig, t }),
    [lang, availableLangs, langConfig, dbMessages, runtimeMessages, reloadI18nConfig]
  );
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  return useContext(I18nContext);
}
