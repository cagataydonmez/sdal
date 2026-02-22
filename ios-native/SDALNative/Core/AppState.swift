import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: SessionUser?
    @Published var isBootstrapping = true

    private let api = APIClient.shared

    func bootstrapSession() async {
        defer { isBootstrapping = false }
        do {
            session = try await api.fetchSession()
        } catch {
            session = nil
        }
    }

    func login(username: String, password: String) async throws {
        try await api.login(username: username, password: password)
        session = try await api.fetchSession()
    }

    func logout() async {
        do {
            try await api.logout()
        } catch {
            // Ignore logout failures and clear local state anyway.
        }
        session = nil
    }
}

enum AppTab: Hashable {
    case feed
    case explore
    case messages
    case notifications
    case profile
}

enum AppCommunityDestination: String, Identifiable {
    case events
    case announcements
    case groups
    case games

    var id: String { rawValue }
}

enum AppMessagesDestination: String {
    case chat
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .feed
    @Published var openMessageId: Int?
    @Published var openCommunityDestination: AppCommunityDestination?
    @Published var openMessagesDestination: AppMessagesDestination?

    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        let path = userInfo["path"] as? String
        let screen = userInfo["screen"] as? String
        let type = userInfo["type"] as? String

        if let path {
            route(path: path)
            return
        }

        if let screen {
            route(path: screen)
            return
        }

        if let type {
            switch type.lowercased() {
            case "message", "mention_message":
                selectedTab = .messages
                if let rawId = userInfo["entity_id"] {
                    openMessageId = Int("\(rawId)")
                }
            case "like", "comment", "mention_post", "post":
                selectedTab = .feed
            case "group_invite", "notification":
                selectedTab = .notifications
            default:
                break
            }
        }
    }

    private func route(path: String) {
        let normalized = path.lowercased()
        if normalized.contains("/chat") {
            selectedTab = .messages
            openMessagesDestination = .chat
            return
        }
        if normalized.contains("/notifications") {
            selectedTab = .notifications
            return
        }
        if normalized.contains("/messages/") {
            selectedTab = .messages
            let idPart = normalized.split(separator: "/").last
            if let idPart, let id = Int(idPart) {
                openMessageId = id
            }
            return
        }
        if normalized.contains("/messages") {
            selectedTab = .messages
            return
        }
        if normalized.contains("/events") {
            selectedTab = .feed
            openCommunityDestination = .events
            return
        }
        if normalized.contains("/announcements") {
            selectedTab = .feed
            openCommunityDestination = .announcements
            return
        }
        if normalized.contains("/groups") {
            selectedTab = .feed
            openCommunityDestination = .groups
            return
        }
        if normalized.contains("/games") {
            selectedTab = .feed
            openCommunityDestination = .games
            return
        }
        if normalized.contains("/explore") {
            selectedTab = .explore
            return
        }
        if normalized.contains("/profile") {
            selectedTab = .profile
            return
        }
        selectedTab = .feed
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case tr
    case en
    case de
    case fr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tr: return "Turkce"
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Francais"
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let storageKey = "sdal_native_theme_mode"

    @Published var mode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        mode = AppThemeMode(rawValue: raw ?? AppThemeMode.auto.rawValue) ?? .auto
    }

    var preferredColorScheme: ColorScheme? {
        switch mode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    static let storageKey = "sdal_native_lang"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        language = AppLanguage(rawValue: stored ?? "tr") ?? .tr
    }

    func t(_ key: String) -> String {
        let tr: [String: String] = [
            "loading": "Yukleniyor...",
            "sign_in": "Giris Yap",
            "signing_in": "Giris yapiliyor...",
            "username": "Kullanici adi",
            "password": "Sifre",
            "feed": "Akis",
            "explore": "Kesfet",
            "messages": "Mesajlar",
            "notifications": "Bildirimler",
            "profile": "Profil",
            "create_post": "Gonderi Olustur",
            "post_placeholder": "Ne paylasmak istersin?",
            "share": "Paylas",
            "add_photo": "Fotograf Ekle",
            "change_photo": "Fotografi Degistir",
            "remove": "Kaldir",
            "stories": "Hikayeler",
            "add_story": "Hikaye Ekle",
            "loading_feed": "Akis yukleniyor...",
            "loading_messages": "Mesajlar yukleniyor...",
            "loading_notifications": "Bildirimler yukleniyor...",
            "loading_suggestions": "Oneriler yukleniyor...",
            "inbox": "Gelen Kutusu",
            "compose": "Yaz",
            "subject": "Konu",
            "recipient": "Alici",
            "message": "Mesaj",
            "send": "Gonder",
            "no_subject": "(Konu yok)",
            "from": "Gonderen",
            "new_message": "Yeni Mesaj",
            "push_notifications": "Push Bildirimleri",
            "enable_push": "Push Bildirimlerini Ac",
            "push_enabled": "Acik",
            "push_denied": "Ayarlardan kapatildi",
            "push_not_determined": "Henuz istenmedi",
            "push_unknown": "Bilinmiyor",
            "sign_out": "Cikis Yap",
            "language": "Dil",
            "retry": "Tekrar Dene",
            "view": "Gor",
            "close": "Kapat",
            "follow": "Takip Et",
            "unfollow": "Takibi Birak",
            "albums": "Albumler",
            "suggestions": "Oneriler",
            "following": "Takip Edilenler",
            "save": "Kaydet",
            "saving": "Kaydediliyor...",
            "upload": "Yukle",
            "search": "Ara",
            "events": "Etkinlikler",
            "announcements": "Duyurular",
            "groups": "Gruplar",
            "games": "Oyunlar",
            "tournament": "Turnuva",
            "help": "Yardim",
            "create": "Olustur",
            "join": "Katil",
            "leave": "Ayril",
            "all": "Tum Akis",
            "popular": "Populer",
            "camera": "Kamera",
            "manage": "Yonet",
            "comment": "Yorum",
            "comments": "Yorumlar",
            "leaderboard": "Liderlik Tablosu",
            "play": "Oyna",
            "score": "Skor",
            "notify": "Bildir",
            "message_sent": "Mesaj gonderildi",
            "post_deleted": "Gonderi silindi",
            "reaction_updated": "Etkilesim guncellendi",
            "removed_from_quick_access": "Hizli erisimden kaldirildi",
            "write_to_chat": "Sohbete yaz...",
            "new_posts_label": "Yeni gonderiler: %d"
            ,"edit_post": "Gonderiyi Duzenle"
            ,"content": "Icerik"
            ,"write_comment": "Yorum yaz"
            ,"pending_approval": "Onay bekliyor"
            ,"attend": "Katil"
            ,"decline": "Reddet"
            ,"counts": "Sayilar"
            ,"attendees": "Katilimcilar"
            ,"on": "Acik"
            ,"off": "Kapali"
            ,"approve": "Onayla"
            ,"unapprove": "Onayi Kaldir"
            ,"title": "Baslik"
            ,"description": "Aciklama"
            ,"location": "Konum"
            ,"starts_at_iso": "Baslangic (ISO)"
            ,"ends_at_iso": "Bitis (ISO)"
            ,"body": "Icerik"
            ,"event": "Etkinlik"
            ,"admin_menu": "Admin Menusu"
            ,"admin_sign_in": "Admin Girisi"
            ,"admin_sign_in_hint": "Admin paneli icin aktif bir admin hesap oturumu ve admin sifresi gerekir."
            ,"menu": "Menu"
            ,"logout": "Cikis"
            ,"panel": "Panel"
            ,"overview": "Genel"
            ,"moderation": "Moderasyon"
            ,"operations": "Islemler"
            ,"admin_navigation": "Admin Navigasyon"
            ,"posts": "Gonderiler"
            ,"chat": "Sohbet"
            ,"edit": "Duzenle"
            ,"delete": "Sil"
            ,"repost": "Yeniden Paylas"
            ,"my_stories": "Hikayelerim"
            ,"caption": "Aciklama"
            ,"update_story_caption": "Hikaye aciklamasini guncelle"
            ,"new_story": "Yeni Hikaye"
            ,"caption_optional": "Aciklama (istege bagli)"
            ,"image_unavailable": "Gorsel kullanilamiyor"
            ,"story_title_format": "Hikaye #%d"
            ,"views_label_format": "Goruntulenme: %d"
            ,"mailbox": "Posta Kutusu"
            ,"outbox": "Giden Kutusu"
            ,"to": "Alici"
            ,"open": "Ac"
            ,"reply": "Yanitla"
            ,"select_message": "Bir mesaj sec"
            ,"edit_chat_message": "Sohbet Mesajini Duzenle"
            ,"translate": "Cevir"
            ,"translating": "Cevriliyor..."
            ,"cancel": "Iptal"
            ,"appearance": "Gorunum"
            ,"first_name": "Isim"
            ,"last_name": "Soyisim"
            ,"city": "Sehir"
            ,"job": "Meslek"
            ,"university": "Universite"
            ,"website": "Web"
            ,"signature": "Imza"
            ,"email_private": "E-posta gizli"
            ,"request_verification": "Mavi tik talebi gonder"
            ,"admin_tools": "Admin"
            ,"moderation_tools": "Moderasyon ve yonetim araclari"
            ,"change_password_desc": "Hesap sifreni degistir"
            ,"boards": "Panolar"
            ,"boards_desc": "Topluluk pano mesajlari"
            ,"tournament_desc": "Takimini kaydet"
            ,"menu_sidebar": "Menu ve Sidebar"
            ,"menu_sidebar_desc": "Portal menu ve yan panel istatistikleri"
            ,"help_desc": "SDAL New kilavuz ve sorun giderme"
            ,"profile_updated": "Profil guncellendi"
            ,"profile_photo_updated": "Profil fotografi guncellendi"
            ,"verification_request_sent": "Dogrulama talebi gonderildi"
            ,"old_password": "Eski sifre"
            ,"new_password": "Yeni sifre"
            ,"repeat_new_password": "Yeni sifre tekrar"
            ,"change_password": "Sifreyi Degistir"
            ,"password_updated": "Sifre guncellendi."
            ,"verification": "Dogrulama"
            ,"app_tagline": "Toplulugunla baglan"
            ,"register": "Kayit Ol"
            ,"activate": "Aktif Et"
            ,"resend_activation": "Aktivasyonu Tekrar Gonder"
            ,"forgot_password": "Sifremi Unuttum"
            ,"repeat_password": "Sifre Tekrar"
            ,"email": "E-posta"
            ,"graduation_year": "Mezuniyet Yili"
            ,"captcha_load_failed": "Captcha yuklenemedi"
            ,"refresh_captcha": "Captcha Yenile"
            ,"security_code": "Guvenlik Kodu (gkodu)"
            ,"submit": "Gonder"
            ,"registration_completed": "Kayit tamamlandi. Aktivasyon icin e-postani kontrol et."
            ,"member_id": "Uye ID"
            ,"activation_code": "Aktivasyon Kodu"
            ,"verify": "Dogrula"
            ,"activated_for": "@%s icin aktivasyon tamamlandi."
            ,"activation_email_sent": "Aktivasyon e-postasi gonderildi."
            ,"password_reset": "Sifre Sifirlama"
            ,"password_reset_sent": "Sifre sifirlama e-postasi gonderildi."
            ,"mode": "Mod"
            ,"reload": "Yeniden Yukle"
            ,"no_members_for_filters": "Secili filtreler icin uye bulunamadi."
            ,"user": "uye"
            ,"member": "Uye"
            ,"graduation": "Mezuniyet"
            ,"add_to_quick_access": "Hizli Erisime Ekle"
            ,"added_to_quick_access": "Hizli Erisime Eklendi"
            ,"latest_photos": "Son Fotograflar"
            ,"categories": "Kategoriler"
            ,"category": "Kategori"
            ,"photo_count": "%d fotograf"
            ,"photo": "Fotograf"
            ,"add_comment": "Yorum Ekle"
            ,"select": "Seciniz"
            ,"select_photo": "Fotograf Sec"
            ,"upload_photo": "Fotograf Yukle"
            ,"admin": "Admin"
            ,"queue": "Kuyruk"
            ,"no_comments": "Yorum yok"
            ,"photo_comments": "Fotograf Yorumlari"
            ,"no_items_in_queue": "Kuyrukta oge yok"
            ,"no_pending_verification_requests": "Bekleyen dogrulama talebi yok"
            ,"reject": "Reddet"
            ,"users": "Uyeler"
            ,"follows": "Takipler"
            ,"pages": "Sayfalar"
            ,"logs": "Kayitlar"
            ,"album": "Album"
            ,"refresh": "Yenile"
            ,"no_menu_items": "Menu ogesi yok"
            ,"sidebar": "Yan Panel"
            ,"new_messages_count": "Yeni mesajlar: %d"
            ,"online_users_count": "Cevrimici uyeler: %d"
            ,"new_members_count": "Yeni uyeler: %d"
            ,"new_photos_count": "Yeni fotograflar: %d"
            ,"category_id": "Kategori ID"
            ,"prev": "Onceki"
            ,"next": "Sonraki"
            ,"page_count_format": "Sayfa %d/%d"
            ,"write_message": "Mesaj yaz..."
            ,"post": "Paylas"
            ,"team_name": "Takim adi"
            ,"captain_phone": "Kaptan telefon"
            ,"player_1": "Oyuncu 1"
            ,"player_1_graduation": "Oyuncu 1 Mezuniyet"
            ,"player_2": "Oyuncu 2"
            ,"player_2_graduation": "Oyuncu 2 Mezuniyet"
            ,"player_3": "Oyuncu 3"
            ,"player_3_graduation": "Oyuncu 3 Mezuniyet"
            ,"player_4": "Oyuncu 4"
            ,"player_4_graduation": "Oyuncu 4 Mezuniyet"
            ,"register_team": "Takimi Kaydet"
            ,"team_registration_submitted": "Takim kaydi gonderildi."
            ,"system_health": "Sistem Durumu"
            ,"check": "Kontrol Et"
            ,"ok": "Durum"
            ,"yes": "evet"
            ,"no": "hayir"
            ,"sdal_new_help": "SDAL New Yardim"
            ,"help_overview": "Akis ile gonderi/hikaye paylas, Kesfet ile uye bul, Mesajlar ile gelen kutusu/sohbet kullan, Bildirimler ile davet ve guncellemeleri takip et."
            ,"quick_troubleshooting": "Hizli Sorun Giderme"
            ,"troubleshoot_1": "1. Login/Admin 403: once normal kullanici ile giris yap, sonra Admin panelinde admin sifresini gir."
            ,"troubleshoot_2": "2. Parse hatalari: sayfayi yenile; surerse endpoint ve payload ornegi bildir."
            ,"troubleshoot_3": "3. Push kapaliysa: iOS Ayarlar > SDAL Native icinden bildirimleri ac."
            ,"troubleshoot_4": "4. Yukleme hatasi: gorsel boyut/format ve ag baglantisini kontrol et."
            ,"mail_test": "Mail Test"
            ,"send_test_mail": "Test Mail Gonder"
            ,"test_mail_sent": "Test maili gonderildi."
            ,"user_management": "Kullanici Yonetimi"
            ,"search_username_name_email": "Kullanici adi / isim / e-posta ara"
            ,"load": "Yukle"
            ,"filter": "Filtre"
            ,"active": "Aktif"
            ,"pending": "Beklemede"
            ,"banned": "Yasakli"
            ,"online": "Cevrimici"
            ,"sort": "Sirala"
            ,"engagement_desc": "Etkilesim ↓"
            ,"engagement_asc": "Etkilesim ↑"
            ,"recent": "Yeni"
            ,"name": "Isim"
            ,"with_photo": "Fotografli"
            ,"verified_only": "Sadece dogrulanmis"
            ,"online_only": "Sadece cevrimici"
            ,"admin_only": "Sadece admin"
            ,"total_returned_format": "Toplam: %d • Donen: %d"
            ,"no_users_loaded": "Kullanici yuklenmedi"
            ,"unverify": "Dogrulamayi Kaldir"
            ,"score_format": "Skor %.2f"
            ,"follow_inspector": "Takip Inceleme"
            ,"user_id": "Kullanici ID"
            ,"user_format": "Kullanici: @%1$@ (%2$d)"
            ,"no_follow_rows": "Takip satiri yok"
            ,"messages_count": "Mesajlar: %d"
            ,"quotes_count": "Alintilar: %d"
            ,"groups_admin": "Grup Yonetimi"
            ,"no_groups": "Grup yok"
            ,"id_format": "ID: %d"
            ,"new_blocked_word": "Yeni engelli kelime"
            ,"add": "Ekle"
            ,"no_filter_words": "Filtre kelimesi yok"
            ,"word": "Kelime"
            ,"engagement_controls": "Etkilesim Kontrolleri"
            ,"recalculate_scores": "Skorlari Yeniden Hesapla"
            ,"rebalance_ab": "AB Dengesini Kur"
            ,"traffic": "Trafik"
            ,"enabled": "Aktif"
            ,"apply": "Uygula"
            ,"engagement_scores": "Etkilesim Skorlari"
            ,"search_user": "Kullanici ara"
            ,"status": "Durum"
            ,"variant": "Varyant"
            ,"identity": "Kimlik"
            ,"photo_file": "Fotograf dosyasi"
            ,"first_login_done": "Ilk giris tamam"
            ,"mail_hidden": "Mail gizli"
            ,"hit": "Hit"
            ,"birth_date": "Dogum Tarihi"
            ,"day": "Gun"
            ,"month": "Ay"
            ,"year": "Yil"
            ,"admin_edit_password_hint": "Sifre (kullanici #1 duzenlenirken zorunlu)"
            ,"email_center": "E-posta Merkezi"
            ,"send_mode": "Gonderim Modu"
            ,"single": "Tekli"
            ,"bulk": "Toplu"
            ,"select_category": "Kategori sec"
            ,"html_body": "HTML Icerik"
            ,"send_email": "E-posta Gonder"
            ,"send_bulk": "Toplu Gonder"
            ,"create_category": "Kategori Olustur"
            ,"type": "Tur"
            ,"value": "Deger"
            ,"no_email_categories": "E-posta kategorisi yok"
            ,"create_template": "Sablon Olustur"
            ,"template": "Sablon"
            ,"template_name": "Sablon adi"
            ,"html": "HTML"
            ,"no_email_templates": "E-posta sablonu yok"
            ,"use": "Kullan"
            ,"database_tools": "Veritabani Araclari"
            ,"backup_label": "Yedek etiketi"
            ,"create_backup": "Yedek Olustur"
            ,"restore_from_file": "Dosyadan Geri Yukle"
            ,"last_restore": "Son geri yukleme"
            ,"tables": "Tablolar"
            ,"no_tables_loaded": "Tablo yuklenmedi"
            ,"table": "Tablo"
            ,"select_table": "Tablo sec"
            ,"columns": "Kolonlar"
            ,"rows_preview": "Satirlar (onizleme)"
            ,"backups": "Yedekler"
            ,"no_backups": "Yedek yok"
            ,"size": "Boyut"
            ,"download": "Indir"
            ,"create_page": "Sayfa Olustur"
            ,"menu_visible": "Menude gorunsun"
            ,"redirect": "Yonlendir"
            ,"no_pages": "Sayfa yok"
            ,"load_files": "Dosyalari Yukle"
            ,"apply_filters": "Filtreleri Uygula"
            ,"files": "Dosyalar"
            ,"create_album_category": "Album Kategorisi Olustur"
            ,"album_photos": "Album Fotograflari"
            ,"by_category": "Kategoriye gore"
            ,"active_desc": "Aktif ↓"
            ,"date_desc": "Tarih ↓"
            ,"title_asc": "Baslik ↑"
            ,"hits_desc": "Hit ↓"
            ,"bulk_active": "Toplu Aktif"
            ,"bulk_inactive": "Toplu Pasif"
            ,"bulk_delete": "Toplu Sil"
            ,"tournament_teams": "Turnuva Takimlari"
            ,"no_teams": "Takim yok"
            ,"stats": "Istatistik"
            ,"active_users": "Aktif Uyeler"
            ,"pending_verification": "Bekleyen Dogrulama"
            ,"live": "Canli"
            ,"online_members": "Cevrimici Uyeler"
            ,"unread_messages": "Okunmamis Mesajlar"
            ,"pending_invites": "Bekleyen Davetler"
            ,"active_rooms": "Aktif Odalar"
            ,"custom": "Ozel"
            ,"page_name": "Sayfa adi"
            ,"page_url": "Sayfa URL"
            ,"parent_id": "Ust ID"
            ,"image": "Resim"
            ,"feature_flag": "Ozellik"
            ,"id_parent_format": "ID: %d • Ust: %d"
            ,"page": "sayfa"
            ,"app": "uygulama"
            ,"error": "hata"
            ,"from_date": "Baslangic (YYYY-MM-DD)"
            ,"to_date": "Bitis (YYYY-MM-DD)"
            ,"activity": "Aktivite"
            ,"limit": "Limit"
            ,"file": "Dosya"
            ,"matched_format": "Eslesen %d / %d"
            ,"active_pending_format": "Aktif: %d • Bekleyen: %d"
            ,"by_comments_format": "Ekleyen: %1$@ • Yorum: %2$d"
            ,"team": "Takim"
            ,"login_as_normal_user_first": "Once normal kullanici olarak giris yapmalisin."
            ,"admin_login_required_not_admin": "Admin girisi gerekli. Bu kullanici admin yetkisine sahip degil."
            ,"enter_valid_user_id": "Gecerli bir kullanici ID gir."
            ,"recipient_required_single_send": "Tekli gonderim icin alici e-posta zorunlu."
            ,"select_email_category_bulk_send": "Toplu gonderim icin bir e-posta kategorisi sec."
            ,"page_name_url_image_required": "Sayfa adi/url/resim zorunlu."
            ,"category_description_required": "Kategori ve aciklama zorunlu."
        ]

        let en: [String: String] = [
            "loading": "Loading...",
            "sign_in": "Sign in",
            "signing_in": "Signing in...",
            "username": "Username",
            "password": "Password",
            "feed": "Feed",
            "explore": "Explore",
            "messages": "Messages",
            "notifications": "Notifications",
            "profile": "Profile",
            "create_post": "Create Post",
            "post_placeholder": "What do you want to share?",
            "share": "Share",
            "add_photo": "Add Photo",
            "change_photo": "Change Photo",
            "remove": "Remove",
            "stories": "Stories",
            "add_story": "Add Story",
            "loading_feed": "Loading feed...",
            "loading_messages": "Loading messages...",
            "loading_notifications": "Loading notifications...",
            "loading_suggestions": "Loading suggestions...",
            "inbox": "Inbox",
            "compose": "Compose",
            "subject": "Subject",
            "recipient": "Recipient",
            "message": "Message",
            "send": "Send",
            "no_subject": "(No subject)",
            "from": "From",
            "new_message": "New Message",
            "push_notifications": "Push Notifications",
            "enable_push": "Enable Push Notifications",
            "push_enabled": "Enabled",
            "push_denied": "Denied in Settings",
            "push_not_determined": "Not requested yet",
            "push_unknown": "Unknown",
            "sign_out": "Sign out",
            "language": "Language",
            "retry": "Retry",
            "view": "View",
            "close": "Close",
            "follow": "Follow",
            "unfollow": "Unfollow",
            "albums": "Albums",
            "suggestions": "Suggestions",
            "following": "Following",
            "save": "Save",
            "saving": "Saving...",
            "upload": "Upload",
            "search": "Search",
            "events": "Events",
            "announcements": "Announcements",
            "groups": "Groups",
            "games": "Games",
            "tournament": "Tournament",
            "help": "Help",
            "create": "Create",
            "join": "Join",
            "leave": "Leave",
            "all": "All",
            "popular": "Popular",
            "camera": "Camera",
            "manage": "Manage",
            "comment": "Comment",
            "comments": "Comments",
            "leaderboard": "Leaderboard",
            "play": "Play",
            "score": "Score",
            "notify": "Notify",
            "message_sent": "Message sent",
            "post_deleted": "Post deleted",
            "reaction_updated": "Reaction updated",
            "removed_from_quick_access": "Removed from quick access",
            "write_to_chat": "Write to chat...",
            "new_posts_label": "New posts: %d"
            ,"edit_post": "Edit Post"
            ,"content": "Content"
            ,"write_comment": "Write a comment"
            ,"pending_approval": "Pending approval"
            ,"attend": "Attend"
            ,"decline": "Decline"
            ,"counts": "Counts"
            ,"attendees": "Attendees"
            ,"on": "On"
            ,"off": "Off"
            ,"approve": "Approve"
            ,"unapprove": "Unapprove"
            ,"title": "Title"
            ,"description": "Description"
            ,"location": "Location"
            ,"starts_at_iso": "Starts at (ISO)"
            ,"ends_at_iso": "Ends at (ISO)"
            ,"body": "Body"
            ,"event": "Event"
            ,"admin_menu": "Admin Menu"
            ,"admin_sign_in": "Admin Sign In"
            ,"admin_sign_in_hint": "Admin panel requires an active signed-in admin account and one admin password."
            ,"menu": "Menu"
            ,"logout": "Logout"
            ,"panel": "Panel"
            ,"overview": "Overview"
            ,"moderation": "Moderation"
            ,"operations": "Operations"
            ,"admin_navigation": "Admin Navigation"
            ,"posts": "Posts"
            ,"chat": "Chat"
            ,"edit": "Edit"
            ,"delete": "Delete"
            ,"repost": "Repost"
            ,"my_stories": "My Stories"
            ,"caption": "Caption"
            ,"update_story_caption": "Update story caption"
            ,"new_story": "New Story"
            ,"caption_optional": "Caption (optional)"
            ,"image_unavailable": "Image unavailable"
            ,"story_title_format": "Story #%d"
            ,"views_label_format": "Views: %d"
            ,"mailbox": "Mailbox"
            ,"outbox": "Outbox"
            ,"to": "To"
            ,"open": "Open"
            ,"reply": "Reply"
            ,"select_message": "Select a message"
            ,"edit_chat_message": "Edit Chat Message"
            ,"translate": "Translate"
            ,"translating": "Translating..."
            ,"cancel": "Cancel"
            ,"appearance": "Appearance"
            ,"first_name": "First name"
            ,"last_name": "Last name"
            ,"city": "City"
            ,"job": "Job"
            ,"university": "University"
            ,"website": "Website"
            ,"signature": "Signature"
            ,"email_private": "Email private"
            ,"request_verification": "Send verification request"
            ,"admin_tools": "Admin"
            ,"moderation_tools": "Moderation and management tools"
            ,"change_password_desc": "Change your account password"
            ,"boards": "Boards"
            ,"boards_desc": "Community board messages"
            ,"tournament_desc": "Register your team"
            ,"menu_sidebar": "Menu & Sidebar"
            ,"menu_sidebar_desc": "Portal navigation and sidebar stats"
            ,"help_desc": "Guides and troubleshooting for SDAL New"
            ,"profile_updated": "Profile updated"
            ,"profile_photo_updated": "Profile photo updated"
            ,"verification_request_sent": "Verification request sent"
            ,"old_password": "Old password"
            ,"new_password": "New password"
            ,"repeat_new_password": "Repeat new password"
            ,"change_password": "Change Password"
            ,"password_updated": "Password updated."
            ,"verification": "Verification"
            ,"app_tagline": "Connect with your community"
            ,"register": "Register"
            ,"activate": "Activate"
            ,"resend_activation": "Resend Activation"
            ,"forgot_password": "Forgot Password"
            ,"repeat_password": "Repeat Password"
            ,"email": "Email"
            ,"graduation_year": "Graduation Year"
            ,"captcha_load_failed": "Captcha failed to load"
            ,"refresh_captcha": "Refresh Captcha"
            ,"security_code": "Security Code (gkodu)"
            ,"submit": "Submit"
            ,"registration_completed": "Registration completed. Check your email for activation."
            ,"member_id": "Member ID"
            ,"activation_code": "Activation Code"
            ,"verify": "Verify"
            ,"activated_for": "Activated for @%s."
            ,"activation_email_sent": "Activation email sent."
            ,"password_reset": "Password Reset"
            ,"password_reset_sent": "Password reset email sent."
            ,"mode": "Mode"
            ,"reload": "Reload"
            ,"no_members_for_filters": "No members found for the selected filters."
            ,"user": "user"
            ,"member": "Member"
            ,"graduation": "Graduation"
            ,"add_to_quick_access": "Add to Quick Access"
            ,"added_to_quick_access": "Added to Quick Access"
            ,"latest_photos": "Latest Photos"
            ,"categories": "Categories"
            ,"category": "Category"
            ,"photo_count": "%d photos"
            ,"photo": "Photo"
            ,"add_comment": "Add Comment"
            ,"select": "Select"
            ,"select_photo": "Select Photo"
            ,"upload_photo": "Upload Photo"
            ,"admin": "Admin"
            ,"queue": "Queue"
            ,"no_comments": "No comments"
            ,"photo_comments": "Photo Comments"
            ,"no_items_in_queue": "No items in queue"
            ,"no_pending_verification_requests": "No pending verification requests"
            ,"reject": "Reject"
            ,"users": "Users"
            ,"follows": "Follows"
            ,"pages": "Pages"
            ,"logs": "Logs"
            ,"album": "Album"
            ,"refresh": "Refresh"
            ,"no_menu_items": "No menu items"
            ,"sidebar": "Sidebar"
            ,"new_messages_count": "New messages: %d"
            ,"online_users_count": "Online users: %d"
            ,"new_members_count": "New members: %d"
            ,"new_photos_count": "New photos: %d"
            ,"category_id": "Category ID"
            ,"prev": "Prev"
            ,"next": "Next"
            ,"page_count_format": "Page %d/%d"
            ,"write_message": "Write message..."
            ,"post": "Post"
            ,"team_name": "Team name"
            ,"captain_phone": "Captain phone"
            ,"player_1": "Player 1"
            ,"player_1_graduation": "Player 1 Graduation"
            ,"player_2": "Player 2"
            ,"player_2_graduation": "Player 2 Graduation"
            ,"player_3": "Player 3"
            ,"player_3_graduation": "Player 3 Graduation"
            ,"player_4": "Player 4"
            ,"player_4_graduation": "Player 4 Graduation"
            ,"register_team": "Register Team"
            ,"team_registration_submitted": "Team registration submitted."
            ,"system_health": "System Health"
            ,"check": "Check"
            ,"ok": "OK"
            ,"yes": "true"
            ,"no": "false"
            ,"sdal_new_help": "SDAL New Help"
            ,"help_overview": "Use Feed to share posts/stories, Explore to find members, Messages for inbox/chat, and Notifications for invites and updates."
            ,"quick_troubleshooting": "Quick Troubleshooting"
            ,"troubleshoot_1": "1. Login/Admin 403: first login as a normal user, then enter admin password in Admin panel."
            ,"troubleshoot_2": "2. Parsing errors: refresh the page; if persistent, report endpoint and payload sample."
            ,"troubleshoot_3": "3. Push disabled: enable notifications in iOS Settings for SDAL Native."
            ,"troubleshoot_4": "4. Upload failures: verify image size/format and network connectivity."
            ,"mail_test": "Mail Test"
            ,"send_test_mail": "Send Test Mail"
            ,"test_mail_sent": "Test mail sent."
            ,"user_management": "User Management"
            ,"search_username_name_email": "Search username / name / email"
            ,"load": "Load"
            ,"filter": "Filter"
            ,"active": "Active"
            ,"pending": "Pending"
            ,"banned": "Banned"
            ,"online": "Online"
            ,"sort": "Sort"
            ,"engagement_desc": "Engagement ↓"
            ,"engagement_asc": "Engagement ↑"
            ,"recent": "Recent"
            ,"name": "Name"
            ,"with_photo": "With photo"
            ,"verified_only": "Verified only"
            ,"online_only": "Online only"
            ,"admin_only": "Admin only"
            ,"total_returned_format": "Total: %d • Returned: %d"
            ,"no_users_loaded": "No users loaded"
            ,"unverify": "Unverify"
            ,"score_format": "Score %.2f"
            ,"follow_inspector": "Follow Inspector"
            ,"user_id": "User ID"
            ,"user_format": "User: @%1$@ (%2$d)"
            ,"no_follow_rows": "No follow rows"
            ,"messages_count": "Messages: %d"
            ,"quotes_count": "Quotes: %d"
            ,"groups_admin": "Groups Admin"
            ,"no_groups": "No groups"
            ,"id_format": "ID: %d"
            ,"new_blocked_word": "New blocked word"
            ,"add": "Add"
            ,"no_filter_words": "No filter words"
            ,"word": "Word"
            ,"engagement_controls": "Engagement Controls"
            ,"recalculate_scores": "Recalculate Scores"
            ,"rebalance_ab": "Rebalance AB"
            ,"traffic": "Traffic"
            ,"enabled": "Enabled"
            ,"apply": "Apply"
            ,"engagement_scores": "Engagement Scores"
            ,"search_user": "Search user"
            ,"status": "Status"
            ,"variant": "Variant"
            ,"identity": "Identity"
            ,"photo_file": "Photo file"
            ,"first_login_done": "First login done"
            ,"mail_hidden": "Mail hidden"
            ,"hit": "Hit"
            ,"birth_date": "Birth Date"
            ,"day": "Day"
            ,"month": "Month"
            ,"year": "Year"
            ,"admin_edit_password_hint": "Password (required when editing user #1)"
            ,"email_center": "Email Center"
            ,"send_mode": "Send Mode"
            ,"single": "Single"
            ,"bulk": "Bulk"
            ,"select_category": "Select category"
            ,"html_body": "HTML Body"
            ,"send_email": "Send Email"
            ,"send_bulk": "Send Bulk"
            ,"create_category": "Create Category"
            ,"type": "Type"
            ,"value": "Value"
            ,"no_email_categories": "No email categories"
            ,"create_template": "Create Template"
            ,"template": "Template"
            ,"template_name": "Template name"
            ,"html": "HTML"
            ,"no_email_templates": "No email templates"
            ,"use": "Use"
            ,"database_tools": "Database Tools"
            ,"backup_label": "Backup label"
            ,"create_backup": "Create Backup"
            ,"restore_from_file": "Restore from File"
            ,"last_restore": "Last restore"
            ,"tables": "Tables"
            ,"no_tables_loaded": "No tables loaded"
            ,"table": "Table"
            ,"select_table": "Select table"
            ,"columns": "Columns"
            ,"rows_preview": "Rows (preview)"
            ,"backups": "Backups"
            ,"no_backups": "No backups"
            ,"size": "Size"
            ,"download": "Download"
            ,"create_page": "Create Page"
            ,"menu_visible": "Menu visible"
            ,"redirect": "Redirect"
            ,"no_pages": "No pages"
            ,"load_files": "Load Files"
            ,"apply_filters": "Apply Filters"
            ,"files": "Files"
            ,"create_album_category": "Create Album Category"
            ,"album_photos": "Album Photos"
            ,"by_category": "By Category"
            ,"active_desc": "Active ↓"
            ,"date_desc": "Date ↓"
            ,"title_asc": "Title ↑"
            ,"hits_desc": "Hits ↓"
            ,"bulk_active": "Bulk Active"
            ,"bulk_inactive": "Bulk Inactive"
            ,"bulk_delete": "Bulk Delete"
            ,"tournament_teams": "Tournament Teams"
            ,"no_teams": "No teams"
            ,"stats": "Stats"
            ,"active_users": "Active Users"
            ,"pending_verification": "Pending Verification"
            ,"live": "Live"
            ,"online_members": "Online Members"
            ,"unread_messages": "Unread Messages"
            ,"pending_invites": "Pending Invites"
            ,"active_rooms": "Active Rooms"
            ,"custom": "Custom"
            ,"page_name": "Page name"
            ,"page_url": "Page URL"
            ,"parent_id": "Parent ID"
            ,"image": "Image"
            ,"feature_flag": "Feature"
            ,"id_parent_format": "ID: %d • Parent: %d"
            ,"page": "page"
            ,"app": "app"
            ,"error": "error"
            ,"from_date": "From (YYYY-MM-DD)"
            ,"to_date": "To (YYYY-MM-DD)"
            ,"activity": "Activity"
            ,"limit": "Limit"
            ,"file": "File"
            ,"matched_format": "Matched %d / %d"
            ,"active_pending_format": "Active: %d • Pending: %d"
            ,"by_comments_format": "By: %1$@ • Comments: %2$d"
            ,"team": "Team"
            ,"login_as_normal_user_first": "First sign in as a normal user."
            ,"admin_login_required_not_admin": "Admin sign-in required. This user does not have admin rights."
            ,"enter_valid_user_id": "Enter a valid user ID."
            ,"recipient_required_single_send": "Recipient email is required for single send."
            ,"select_email_category_bulk_send": "Select an email category for bulk send."
            ,"page_name_url_image_required": "Page name/url/image are required."
            ,"category_description_required": "Category and description are required."
        ]

        let source: [String: String]
        switch language {
        case .tr: source = tr
        case .en, .de, .fr: source = en
        }
        return source[key] ?? tr[key] ?? key
    }
}
