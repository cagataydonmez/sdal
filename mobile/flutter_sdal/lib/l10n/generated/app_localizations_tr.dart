// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'SDAL Sosyal';

  @override
  String get appInitFailedTitle => 'Başlatılamadı';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get refreshAction => 'Yenile';

  @override
  String get backAction => 'Geri';

  @override
  String get quickMenuAction => 'Hızlı menü';

  @override
  String get profileOpenAction => 'Profili aç';

  @override
  String openMemberProfileForName(Object name) {
    return '$name profilini aç';
  }

  @override
  String get moreActions => 'Diğer işlemler';

  @override
  String get removeImageAction => 'Görseli kaldır';

  @override
  String get quickAccessRemoveAction => 'Hızlı erişimden kaldır';

  @override
  String openPostByAuthor(Object name) {
    return '$name gönderisini aç';
  }

  @override
  String feedLikesCount(Object count) {
    return '$count beğeni';
  }

  @override
  String feedCommentsCount(Object count) {
    return '$count yorum';
  }

  @override
  String get eventsTitle => 'Etkinlikler';

  @override
  String get announcementsTitle => 'Duyurular';

  @override
  String get networkingTitle => 'Networking';

  @override
  String get teacherConnectionsTitle => 'Öğretmen bağlantıları';

  @override
  String get opportunitiesTitle => 'Fırsatlar';

  @override
  String get exploreOpportunitySectionTitle => 'Öncelikli akış';

  @override
  String get exploreOpportunitySectionDescription =>
      'Kişiler, işler ve güncellemeler için tek akışta aksiyon sırası.';

  @override
  String get opportunitiesTabAll => 'Tümü';

  @override
  String get opportunitiesTabNow => 'Şimdi';

  @override
  String get opportunitiesTabNetworking => 'Kişiler';

  @override
  String get opportunitiesTabJobs => 'İşler';

  @override
  String get opportunitiesTabUpdates => 'Güncellemeler';

  @override
  String get opportunitiesPriorityNow => 'Öncelikli';

  @override
  String get opportunitiesPrioritySoon => 'Yakında';

  @override
  String get opportunitiesPriorityFollow => 'Takip et';

  @override
  String get opportunitiesCategoryNetworking => 'Networking';

  @override
  String get opportunitiesCategoryJob => 'İş';

  @override
  String get opportunitiesCategoryUpdate => 'Güncelleme';

  @override
  String get opportunitiesEmptyTitle => 'Şu anda bekleyen bir şey yok';

  @override
  String get opportunitiesEmptyDescription =>
      'Yeni kişi, iş ve güncellemeler için biraz sonra tekrar yenile.';

  @override
  String get opportunitiesLoadMoreAction => 'Daha fazla yükle';

  @override
  String get opportunitiesLoading => 'Fırsatlar hazırlanıyor...';

  @override
  String get followingTitle => 'Takipler';

  @override
  String get followingEmptyTitle => 'Henüz takip ettiğin üye yok';

  @override
  String get followingEmptyMessage =>
      'Tekrar ulaşmak istediğin üyeler için Keşfet ekranından takip listeni oluşturmaya başla.';

  @override
  String get mainNavigationTitle => 'Ana gezinme';

  @override
  String get communitySectionTitle => 'Topluluk';

  @override
  String get extraPagesSectionTitle => 'Ek sayfalar';

  @override
  String get adminSectionTitle => 'Yönetim';

  @override
  String get adminPanelTitle => 'Admin paneli';

  @override
  String get quickAccessTitle => 'Hızlı erişim';

  @override
  String get quickAccessRemovedMessage => 'Hızlı erişimden kaldırıldı.';

  @override
  String get actionFailedGeneric => 'İşlem tamamlanamadı.';

  @override
  String get feedPostNotFound => 'Gönderi bulunamadı.';

  @override
  String get feedCommentAddTitle => 'Yorum ekle';

  @override
  String get feedCommentFieldLabel => 'Yorumun';

  @override
  String get feedCommentSubmitAction => 'Yorumu gönder';

  @override
  String get feedCommentsTitle => 'Yorumlar';

  @override
  String get feedCommentsEmpty => 'Henüz yorum yok.';

  @override
  String get feedCommentsEmptyTitle => 'Henüz yorum yok';

  @override
  String get feedCommentsEmptyMessage =>
      'Diğer üyelerin katılabilmesi için ilk yorumu sen bırak.';

  @override
  String get feedCommentDeleteTitle => 'Yorumu sil';

  @override
  String get feedCommentDeleteMessage => 'Bu yorumu silmek istiyor musun?';

  @override
  String get feedCommentDeleted => 'Yorum silindi.';

  @override
  String get feedCommentDeleteFailed => 'Yorum silinemedi.';

  @override
  String get feedCommentSubmitFailed => 'Yorum gönderilemedi.';

  @override
  String get feedPostDeleteTitle => 'Gönderiyi sil';

  @override
  String get feedPostDeleteMessage =>
      'Bu gönderi kalıcı olarak silinecek. Devam etmek istiyor musun?';

  @override
  String get feedPostDeleted => 'Gönderi silindi.';

  @override
  String get feedPostDeleteFailed => 'Gönderi silinemedi.';

  @override
  String sidebarOnlineUsersCount(Object count) {
    return '$count çevrim içi üye';
  }

  @override
  String sidebarNewMessagesCount(Object count) {
    return '$count yeni mesaj';
  }

  @override
  String sidebarNewMembersCount(Object count) {
    return '$count yeni üye';
  }

  @override
  String get siteClosedTitle => 'SDAL şu anda kapalı';

  @override
  String get siteClosedFallbackMessage =>
      'Bakım çalışması nedeniyle uygulama geçici olarak kullanılamıyor.';

  @override
  String get moduleClosedTitle => 'Modül kapalı';

  @override
  String get moduleClosedDefaultMessage => 'Bu özellik şu anda kullanılamıyor.';

  @override
  String moduleClosedWithName(Object module) {
    return '$module modülü geçici olarak kapatıldı.';
  }

  @override
  String get accountBannedTitle => 'Hesap erişime kapatıldı';

  @override
  String get accountBannedMessage =>
      'Bu hesap yasaklandığı için uygulama içinde işlem yapılamıyor. Destek için SDAL yönetimiyle iletişime geçin.';

  @override
  String get verificationRequiredTitle => 'Doğrulama gerekli';

  @override
  String verificationRequiredMessage(Object feature) {
    return '$feature özellikleri için profil doğrulaması gerekiyor. Profil ekranından doğrulama talebi gönderebilirsiniz.';
  }

  @override
  String get splashLoading => 'Yükleniyor...';

  @override
  String get splashPreparing => 'SDAL hazırlanıyor';

  @override
  String get tabFeed => 'Akış';

  @override
  String get tabExplore => 'Keşfet';

  @override
  String get tabInbox => 'Mesajlar';

  @override
  String get tabNotifications => 'Bildirim';

  @override
  String get tabProfile => 'Profil';

  @override
  String get loginTitle => 'SDAL Sosyal';

  @override
  String get loginSubtitle => 'SDAL Sosyal uygulamasına giriş yapın.';

  @override
  String get registerTitle => 'Kayıt ol';

  @override
  String get registerSubtitle =>
      'V1 için yeni Flutter istemcisinden hesap oluşturun.';

  @override
  String get activationTitle => 'Aktivasyon';

  @override
  String get activationSubtitle =>
      'E-posta bağlantınız iOS uygulamasını açtıysa burada tamamlayın.';

  @override
  String get resendActivationTitle => 'Aktivasyon tekrar gönder';

  @override
  String get resendActivationSubtitle =>
      'Eski üyelik aktivasyon akışı için destek ekranı.';

  @override
  String get resetPasswordTitle => 'Şifre sıfırla';

  @override
  String get resetPasswordSubtitle =>
      'Eski SDAL hesap kurtarma uç noktasını kullanır.';

  @override
  String get oauthTitle => 'OAuth';

  @override
  String get oauthSubtitle => 'Bu ekran genellikle kısa süreliğine görünür.';

  @override
  String get oauthInfoMessage =>
      'Tarayıcı akışı uygulamaya geri döndüğünde oturum otomatik açılır.';

  @override
  String get register => 'Kayıt ol';

  @override
  String get resendActivation => 'Aktivasyon tekrar gönder';

  @override
  String get resetPassword => 'Şifre sıfırla';

  @override
  String get username => 'Kullanıcı adı';

  @override
  String get password => 'Şifre';

  @override
  String get email => 'E-posta';

  @override
  String get firstName => 'Ad';

  @override
  String get lastName => 'Soyad';

  @override
  String get captionLabel => 'Açıklama';

  @override
  String get memberId => 'Üye kimliği';

  @override
  String get activationCode => 'Aktivasyon kodu';

  @override
  String get captchaCode => 'Captcha kodu';

  @override
  String get graduationYear => 'Mezuniyet yılı / Teacher';

  @override
  String get passwordRepeat => 'Şifre tekrar';

  @override
  String registerFieldRequired(Object field) {
    return '$field alanı zorunludur.';
  }

  @override
  String registerFieldTooLong(Object field, Object max) {
    return '$field alanı en fazla $max karakter olabilir.';
  }

  @override
  String get registerEmailInvalid => 'Geçerli bir e-posta adresi gir.';

  @override
  String get registerPasswordMismatch =>
      'Şifre alanları birbiriyle aynı olmalıdır.';

  @override
  String get registerPasswordHint =>
      '8-20 karakter kullan. Büyük harf, küçük harf, sayı ve sembol karışımı hesabını daha iyi korur.';

  @override
  String get registerPasswordStrengthNone => 'Şifre gücü';

  @override
  String get registerPasswordStrengthWeak => 'Şifre gücü: Zayıf';

  @override
  String get registerPasswordStrengthMedium => 'Şifre gücü: Orta';

  @override
  String get registerPasswordStrengthStrong => 'Şifre gücü: Güçlü';

  @override
  String get registerGraduationYearInvalid =>
      '1999 ile içinde bulunduğumuz yıl arasında geçerli bir mezuniyet yılı veya Öğretmen gir.';

  @override
  String get registerKvkkConsentLabel =>
      'KVKK Aydınlatma Metni\'ni okudum ve onaylıyorum.';

  @override
  String get registerKvkkConsentError =>
      'Kayıt olmadan önce KVKK Aydınlatma Metni onayı gerekiyor.';

  @override
  String get registerKvkkTitle => 'KVKK Aydınlatma Metni';

  @override
  String get registerKvkkOpenAction => 'KVKK metnini aç';

  @override
  String get registerDirectoryConsentLabel =>
      'Mezun Rehberi açık rıza onayını veriyorum.';

  @override
  String get registerDirectoryConsentError =>
      'Kayıt olmadan önce Mezun Rehberi açık rıza onayı gerekiyor.';

  @override
  String get registerDirectoryConsentTitle => 'Mezun Rehberi Açık Rıza Metni';

  @override
  String get registerDirectoryConsentOpenAction => 'Açık rıza metnini aç';

  @override
  String get registerCaptchaLoading => 'Güvenlik kodu yükleniyor...';

  @override
  String get registerCaptchaUnavailable =>
      'Güvenlik kodu yüklenemedi. Kodu yenileyip tekrar deneyin.';

  @override
  String get registerCaptchaRetryAction => 'Kodu yenile';

  @override
  String get registerCaptchaCodeRequired => 'Güvenlik kodunu gir.';

  @override
  String get registerCaptchaDigitsOnly =>
      'Güvenlik kodu yalnızca rakamlardan oluşmalıdır.';

  @override
  String get registerPreviewFailed => 'Kayıt bilgileri doğrulanamadı.';

  @override
  String get registerAvailabilityCheckFailed =>
      'Kullanılabilirlik şu anda kontrol edilemedi.';

  @override
  String get registerUsernameTaken => 'Bu kullanıcı adı zaten kayıtlı.';

  @override
  String get registerUsernameAvailable => 'Bu kullanıcı adı uygun görünüyor.';

  @override
  String get registerEmailTaken => 'Bu e-posta adresi zaten kayıtlı.';

  @override
  String get registerEmailAvailable => 'Bu e-posta adresi uygun görünüyor.';

  @override
  String get loginInProgress => 'Giriş yapılıyor...';

  @override
  String get loginAction => 'Giriş yap';

  @override
  String get continueWithGoogle => 'Google ile devam et';

  @override
  String get continueWithX => 'X ile devam et';

  @override
  String get submitInProgress => 'Gönderiliyor...';

  @override
  String get registerSubmitAction => 'Kayıt isteği gönder';

  @override
  String get resendAction => 'Tekrar gönder';

  @override
  String get passwordResetSubmitAction => 'Sıfırlama isteği gönder';

  @override
  String get activationSubmitAction => 'Aktivasyonu tamamla';

  @override
  String get activationChecking => 'Kontrol ediliyor...';

  @override
  String get feedTitle => 'Ana Akış';

  @override
  String get feedRefresh => 'Yenile';

  @override
  String get feedPostAction => 'Gönderi';

  @override
  String get feedEmptyContent => 'Bu gönderi içerik taşımıyor.';

  @override
  String get feedComposerTitle => 'Yeni gönderi';

  @override
  String get feedComposerHint => 'Ne paylaşmak istiyorsun?';

  @override
  String get pickFromGallery => 'Galeriden seç';

  @override
  String get shareInProgress => 'Paylaşılıyor...';

  @override
  String get shareAction => 'Paylaş';

  @override
  String get postShared => 'Gönderi paylaşıldı.';

  @override
  String get postShareFailed => 'Gönderi paylaşılamadı.';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String get notificationsUnreadLoading => 'Okunmamış sayısı yükleniyor...';

  @override
  String notificationsUnreadCount(Object count) {
    return 'Okunmamış bildirim: $count';
  }

  @override
  String messagesUnreadCount(Object count) {
    return 'Okunmamış mesaj: $count';
  }

  @override
  String get notificationsMarkAllRead => 'Tümünü oku';

  @override
  String get notificationsUpdatedAllRead =>
      'Bildirimler okundu olarak işaretlendi.';

  @override
  String get notificationsActionFailed => 'İşlem başarısız oldu.';

  @override
  String get notificationsPreferencesUpdated =>
      'Bildirim tercihleri güncellendi.';

  @override
  String get notificationsPreferencesFailed => 'Tercihler kaydedilemedi.';

  @override
  String get notificationsInboxTitle => 'Gelenler';

  @override
  String get notificationsEmpty => 'Henüz bildirim yok.';

  @override
  String get notificationsEmptyTitle => 'Henüz bildirim yok';

  @override
  String get notificationsEmptyMessage =>
      'Dikkatini gerektiren hareketler burada hızlı işlemlerle görünecek.';

  @override
  String get notificationsReadAction => 'Okundu';

  @override
  String get openAction => 'Aç';

  @override
  String get notificationOpenedFailed => 'Bildirim açılamadı.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMissing => 'Profil verisi bulunamadı.';

  @override
  String get profileVerified => 'Doğrulandı';

  @override
  String get profilePendingVerification => 'Doğrulama bekliyor';

  @override
  String get profilePhotoAction => 'Fotoğraf';

  @override
  String get profileVerificationAction => 'Doğrulama';

  @override
  String get profileAccountDetailsTitle => 'Hesap bilgileri';

  @override
  String get profileDetailsGraduationYearLabel => 'Mezuniyet yılı';

  @override
  String get editAction => 'Düzenle';

  @override
  String get profileEditPageTitle => 'Profili düzenle';

  @override
  String get profileEditIdentitySectionTitle => 'Temel bilgiler';

  @override
  String get profileEditIdentitySectionDescription =>
      'Profilinde görünen temel alanları güncelle ve seni tanımayı kolaylaştır.';

  @override
  String get profileEditContactSectionTitle => 'Bağlantılar ve geçmiş';

  @override
  String get profileEditContactSectionDescription =>
      'İsteğe bağlı bağlantılarını, okul bilgisini ve mentorluk konularını uygulama genelinde düzgün görünecek biçimde paylaş.';

  @override
  String get profileEditPrivacySectionTitle => 'Görünürlük ve onaylar';

  @override
  String get profileEditPrivacySectionDescription =>
      'Profilinin rehberde nasıl görüneceğini yönet ve gerekli onayları güncel tut.';

  @override
  String get profileEditFirstNameLabel => 'Ad';

  @override
  String get profileEditLastNameLabel => 'Soyad';

  @override
  String get profileEditGraduationYearLabel => 'Mezuniyet yılı / Öğretmen';

  @override
  String get profileEditGraduationYearHint => '1999-2100 veya Öğretmen';

  @override
  String get profileEditCityLabel => 'Şehir';

  @override
  String get profileEditProfessionLabel => 'Meslek';

  @override
  String get profileEditCompanyLabel => 'Şirket';

  @override
  String get profileEditTitleLabel => 'Unvan';

  @override
  String get profileEditExpertiseLabel => 'Uzmanlık';

  @override
  String get profileEditWebsiteLabel => 'Web sitesi';

  @override
  String get profileEditLinkedinLabel => 'LinkedIn';

  @override
  String get profileEditUniversityLabel => 'Üniversite';

  @override
  String get profileEditDepartmentLabel => 'Üniversite bölümü';

  @override
  String get profileEditMentorTopicsLabel => 'Mentorluk konuları';

  @override
  String get profileEditSignatureLabel => 'İmza';

  @override
  String get profileEditMentorVisibleLabel => 'Beni mentor olarak göster';

  @override
  String get profileEditKvkkConsentLabel => 'KVKK onayı';

  @override
  String get profileEditDirectoryConsentLabel => 'Rehber onayı';

  @override
  String get profileEditHideEmailLabel => 'E-postamı gizle';

  @override
  String get profileEditSaveInProgress => 'Kaydediliyor...';

  @override
  String get profileEditSaved => 'Profil güncellendi.';

  @override
  String get profileEditSaveFailed => 'Profil güncellenemedi.';

  @override
  String get profileEditGraduationYearError =>
      '1999-2100 arasında bir mezuniyet yılı veya Öğretmen gir.';

  @override
  String get profileEditWebsiteError => 'Geçerli bir web sitesi adresi gir.';

  @override
  String get profileEditLinkedinError => 'Geçerli bir LinkedIn adresi gir.';

  @override
  String profileEditRequiredField(Object field) {
    return '$field alanı zorunludur.';
  }

  @override
  String get profileAccountActionsTitle => 'Hesap işlemleri';

  @override
  String get changeEmailAction => 'E-posta değiştir';

  @override
  String get profileEmailChangeNewEmailLabel => 'Yeni e-posta';

  @override
  String get profileEmailChangeSubmitAction => 'Gönder';

  @override
  String get profileEmailChangeSuccess => 'Doğrulama e-postası gönderildi.';

  @override
  String get profileEmailChangeFailed => 'İstek başarısız oldu.';

  @override
  String get changePasswordAction => 'Şifre değiştir';

  @override
  String get profilePasswordChangeCurrentPasswordLabel => 'Eski şifre';

  @override
  String get profilePasswordChangeNewPasswordLabel => 'Yeni şifre';

  @override
  String get profilePasswordChangeRepeatPasswordLabel => 'Yeni şifre tekrar';

  @override
  String get profilePasswordChangeSubmitAction => 'Güncelle';

  @override
  String get profilePasswordChangeSuccess => 'Şifre güncellendi.';

  @override
  String get profilePasswordChangeFailed => 'Şifre güncellenemedi.';

  @override
  String get logoutAction => 'Çıkış yap';

  @override
  String get profileVerificationPageTitle => 'Profil doğrulama';

  @override
  String get statusLabel => 'Durum';

  @override
  String get profileVerifiedMessage => 'Profilin doğrulanmış görünüyor.';

  @override
  String get profileVerificationHint =>
      'Networking ve bazı sosyal akışlar için doğrulama gerekiyor. Kimlik veya okul bağlantısını gösteren bir görsel yükleyebilirsin.';

  @override
  String get proofUploadTitle => 'Kanıt yükle';

  @override
  String get proofUploadHint =>
      'Fotoğraf galerinden veya kameradan bir görsel seç.';

  @override
  String proofSelectedFile(Object fileName) {
    return 'Seçilen dosya: $fileName';
  }

  @override
  String get proofReady => 'Yüklenen kanıt hazır.';

  @override
  String get cameraAction => 'Kamera';

  @override
  String get proofUploadInProgress => 'Kanıt yükleniyor...';

  @override
  String get proofUploadAction => 'Kanıtı yükle';

  @override
  String get proofRequestTitle => 'Talebi gönder';

  @override
  String get proofRequestHint =>
      'İstersen önce kanıt yükle, istersen sadece doğrulama talebini gönder.';

  @override
  String get verificationSubmitInProgress => 'Gönderiliyor...';

  @override
  String get verificationSubmitAction => 'Doğrulama talebini gönder';

  @override
  String get proofUploadFailed => 'Kanıt yüklenemedi.';

  @override
  String get proofUploaded => 'Kanıt dosyası yüklendi.';

  @override
  String get verificationSubmitted => 'Doğrulama talebi gönderildi.';

  @override
  String get verificationSubmitFailed => 'Talep gönderilemedi.';

  @override
  String get messagesTitle => 'Mesajlar';

  @override
  String get messagesEmptyTitle => 'Henüz konuşma yok';

  @override
  String get messagesEmptyMessage =>
      'Bir üyeye doğrudan ulaşmak için yeni bir sohbet başlat.';

  @override
  String get announcementsEmptyTitle => 'Henüz yayınlanmış duyuru yok';

  @override
  String get announcementsEmptyMessage =>
      'Topluluk ekibinden onaylanan duyurular burada yayınlandığında görünür.';

  @override
  String get eventsEmptyTitle => 'Henüz yayınlanmış etkinlik yok';

  @override
  String get eventsEmptyMessage =>
      'Yeni topluluk etkinlikleri ve katılım fırsatları için yenileyip tekrar kontrol et.';

  @override
  String get albumPhotoMissingTitle => 'Fotoğraf şu anda kullanılamıyor';

  @override
  String get albumPhotoMissingMessage =>
      'Bu fotoğraf şu anda yüklenemedi. Tekrar denemek için sayfayı yenile.';

  @override
  String get albumCommentsEmptyTitle => 'Henüz yorum yok';

  @override
  String get albumCommentsEmptyMessage =>
      'Diğer üyelerin sohbete katılması için bu fotoğrafa ilk yorumu sen bırak.';

  @override
  String get newChatAction => 'Yeni sohbet';

  @override
  String get searchPeopleHint => 'Kişi veya kullanıcı adı ara';

  @override
  String get noThreads =>
      'Henüz konuşma yok. Yeni bir mesaj başlatmak için sağ alttaki düğmeyi kullan.';

  @override
  String get startNewChat => 'Yeni sohbete başla';

  @override
  String get newChatTitle => 'Yeni sohbet';

  @override
  String get searchPersonHint => 'Kişi ara';

  @override
  String get searchPrompt => 'Kullanıcı adı veya isim gir.';

  @override
  String get searchNoResults => 'Eşleşen kişi bulunamadı.';

  @override
  String get threadFallbackTitle => 'Sohbet';

  @override
  String get threadEmptyTitle => 'Henüz mesaj yok';

  @override
  String get threadEmptyMessage =>
      'Bu konuşmayı başlatmak için ilk mesajı sen gönder.';

  @override
  String get chatJumpToLatestAction => 'En yeniye git';

  @override
  String get chatNewMessagesAction => 'Yeni mesajlar';

  @override
  String get teacherSearchHintTitle => 'Bir öğretmen ara';

  @override
  String get teacherSearchHintMessage =>
      'Bağlantı eklemeden önce isim veya kullanıcı adı ile öğretmen ara.';

  @override
  String get teacherSearchEmptyTitle => 'Eşleşen öğretmen bulunamadı';

  @override
  String get teacherSearchEmptyMessage =>
      'Aramayı genişletmek için farklı bir isim, kullanıcı adı veya yazım dene.';

  @override
  String get teacherConnectionsEmptyTitle => 'Henüz öğretmen bağlantısı yok';

  @override
  String get teacherConnectionsEmptyMessage =>
      'İlk öğretmen bağlantını oluşturmak için yukarıdan bir öğretmen ara.';

  @override
  String get networkConnectionsEmptyTitle => 'Bu görünümde bağlantı isteği yok';

  @override
  String networkConnectionsEmptyMessage(Object direction, Object status) {
    return 'Şu anda $direction $status bağlantı isteği yok.';
  }

  @override
  String get networkMentorshipEmptyTitle => 'Bu görünümde mentorluk talebi yok';

  @override
  String networkMentorshipEmptyMessage(Object direction, Object status) {
    return 'Şu anda $direction $status mentorluk talebi yok.';
  }

  @override
  String get networkDirectionIncoming => 'gelen';

  @override
  String get networkDirectionOutgoing => 'giden';

  @override
  String get realtimeConnected => 'Canlı';

  @override
  String get realtimeReconnecting => 'Yeniden bağlanıyor';

  @override
  String get realtimeFailed => 'Bağlantı yok';

  @override
  String get realtimeConnecting => 'Bağlanıyor';

  @override
  String get realtimeDisconnected => 'Kapalı';

  @override
  String get threadEmpty => 'Henüz mesaj yok. İlk mesajı sen gönder.';

  @override
  String get messageFieldLabel => 'Mesaj';

  @override
  String get messageSendAction => 'Gönder';

  @override
  String get messageSendInProgress => 'Gönderiliyor...';

  @override
  String get messageSendFailed => 'Mesaj gönderilemedi.';

  @override
  String get themeModeTitle => 'Görünüm';

  @override
  String get themeModeHelper =>
      'Sistem ayarını izleyin veya uygulama için kalıcı bir görünüm seçin.';

  @override
  String get themeModeSystem => 'Sistem';

  @override
  String get themeModeLight => 'Açık';

  @override
  String get themeModeDark => 'Koyu';

  @override
  String get cancelAction => 'Vazgeç';

  @override
  String get previousAction => 'Önceki';

  @override
  String get nextAction => 'Sonraki';

  @override
  String get saveAction => 'Kaydet';

  @override
  String get createAction => 'Oluştur';

  @override
  String get deleteAction => 'Sil';

  @override
  String get groupsTitle => 'Gruplar';

  @override
  String get groupsNewGroupAction => 'Yeni grup';

  @override
  String get groupsOpenAction => 'Aç';

  @override
  String get groupsLeaveAction => 'Ayrıl';

  @override
  String get groupsWithdrawRequestAction => 'Talebi çek';

  @override
  String get groupsAcceptInviteAction => 'Daveti kabul et';

  @override
  String get groupsJoinAction => 'Katıl';

  @override
  String get groupsPendingApproval => 'Onay bekliyor';

  @override
  String get groupsInvitePending => 'Davet bekliyor';

  @override
  String get groupsNewGroupTitle => 'Yeni grup';

  @override
  String get groupsNameLabel => 'Grup adı';

  @override
  String get groupsDescriptionLabel => 'Açıklama';

  @override
  String get groupsCreating => 'Oluşturuluyor...';

  @override
  String groupsMembersCount(Object count) {
    return '$count üye';
  }

  @override
  String get storiesTitle => 'Hikayeler';

  @override
  String get profileMainFeedStoriesTitle => 'Ana akış hikayelerim';

  @override
  String get profileCommunityStoriesTitle => 'Topluluk hikayelerim';

  @override
  String get profileExpiredMainFeedStoriesTitle =>
      'Süresi dolan ana akış hikayeleri';

  @override
  String get profileExpiredCommunityStoriesTitle =>
      'Süresi dolan topluluk hikayeleri';

  @override
  String profileExpiredStoriesCountLabel(Object title, Object count) {
    return '$title ($count)';
  }

  @override
  String get storiesEmpty => 'Henüz aktif hikaye yok.';

  @override
  String get storiesUploadAction => 'Hikaye ekle';

  @override
  String get storiesUploadHint => '24 saat görünür';

  @override
  String get storiesPublishAction => 'Hikayeyi paylaş';

  @override
  String get storiesViewed => 'Görüldü';

  @override
  String storiesNewCount(Object count) {
    return '$count yeni';
  }

  @override
  String get storiesNewStoryTitle => 'Yeni hikaye';

  @override
  String get storiesEditTitleAction => 'Başlığı düzenle';

  @override
  String get storiesDeleteAction => 'Hikayeyi sil';

  @override
  String get storiesRepostAction => 'Yeniden paylaş';

  @override
  String get storiesCaptionDialogTitle => 'Hikaye başlığı';

  @override
  String get storiesCaptionHint => 'Kısa bir açıklama ekle';

  @override
  String get storiesDeleteConfirmTitle => 'Hikaye silinsin mi?';

  @override
  String storiesViewStorySemantic(Object name) {
    return '$name hikayesini aç';
  }

  @override
  String get storiesPreviousStoryHint => 'Önceki hikayeyi aç';

  @override
  String get storiesNextStoryHint => 'Sonraki hikayeyi aç';

  @override
  String get liveChatTitle => 'Canlı sohbet';

  @override
  String get liveChatConnected => 'Canlı bağlantı aktif';

  @override
  String get liveChatReconnecting => 'Bağlantı yeniden kuruluyor...';

  @override
  String get liveChatComposerHint => 'Mesajını yaz';

  @override
  String get liveChatEditMessageAction => 'Mesajı düzenle';

  @override
  String get liveChatDeleteMessageAction => 'Mesajı sil';

  @override
  String get liveChatEditDialogTitle => 'Mesajı düzenle';

  @override
  String get groupDetailTitle => 'Grup detayları';

  @override
  String get groupNotFound => 'Grup bulunamadı.';

  @override
  String get groupVisibilityPrivate => 'Özel';

  @override
  String get groupVisibilityPublic => 'Herkese açık';

  @override
  String get groupManagersVisible => 'Yöneticiler görünür';

  @override
  String get groupRejectInviteAction => 'Daveti reddet';

  @override
  String get groupSettingsAction => 'Ayarlar';

  @override
  String get groupInviteMembersAction => 'Üye davet et';

  @override
  String get groupUpdateCoverAction => 'Kapak güncelle';

  @override
  String get groupManagersTitle => 'Yöneticiler';

  @override
  String get groupJoinRequestsTitle => 'Katılım istekleri';

  @override
  String get groupPendingInvitesTitle => 'Bekleyen davetler';

  @override
  String get groupPostsTitle => 'Paylaşımlar';

  @override
  String get groupNoPosts => 'Henüz grup paylaşımı yok.';

  @override
  String get groupEventsTitle => 'Etkinlikler';

  @override
  String get groupAddEventAction => 'Etkinlik ekle';

  @override
  String get groupNoEvents => 'Bu grup için planlanmış etkinlik yok.';

  @override
  String get groupAnnouncementsTitle => 'Duyurular';

  @override
  String get groupAddAnnouncementAction => 'Duyuru ekle';

  @override
  String get groupNoAnnouncements => 'Bu grup için duyuru yok.';

  @override
  String get groupMembersTitle => 'Üyeler';

  @override
  String get groupContentMembersOnlyTitle => 'İçerik üyeler için açık';

  @override
  String get groupContentMembersOnlyBody =>
      'Bu grubun içeriğini görmek için üyelik onayı gerekli.';

  @override
  String get groupDetailLeaveAction => 'Gruptan ayrıl';

  @override
  String get groupDetailWithdrawRequestAction => 'Talebi geri çek';

  @override
  String get groupDetailAcceptInviteAction => 'Daveti kabul et';

  @override
  String get groupDetailJoinAction => 'Katılım isteği gönder';

  @override
  String get groupAdminPanelTitle => 'Yönetim araçları';

  @override
  String get groupAdminPanelHelper =>
      'Katılım isteklerini incele, yeni üyeler davet et ve grubun görünürlüğünü tek yerden düzenle.';

  @override
  String get groupTimelineTitle => 'Grup akışı';

  @override
  String get groupPostsHelper =>
      'Duyuru açmadan gruba kısa güncellemeler paylaş.';

  @override
  String get groupTimelineHelper =>
      'Yaklaşan etkinlikleri ve önemli duyuruları daha rahat taranır halde tut.';

  @override
  String get groupMembersHelper =>
      'Yöneticiler önce gösterilir. Rol değişiklikleri moderasyon yetkilerini etkilediği için dikkatli kullanılmalıdır.';

  @override
  String get groupInviteSearchHint => 'Ad veya kullanıcı adı ile ara';

  @override
  String groupSelectedCount(Object count) {
    return '$count kişi seçildi';
  }

  @override
  String groupInvitesSent(Object count) {
    return '$count davet gönderildi.';
  }

  @override
  String get groupRoleMakeMember => 'Üye yap';

  @override
  String get groupRoleMakeModerator => 'Moderatör yap';

  @override
  String get groupRoleMakeOwner => 'Sahipliği devret';

  @override
  String get groupSettingsTitle => 'Grup ayarları';

  @override
  String get groupVisibilityLabel => 'Görünürlük';

  @override
  String get groupVisibilityPublicOption => 'Herkese açık';

  @override
  String get groupVisibilityMembersOnlyOption => 'Yalnızca üyeler';

  @override
  String get groupVisibilityHint =>
      'Yalnızca üyeler seçildiğinde paylaşımlar, etkinlikler, duyurular ve üye listesi katılım isteği onaylanana kadar gizlenir.';

  @override
  String get groupManagersVisibilityTitle =>
      'Yöneticileri üye olmayanlara da göster';

  @override
  String get groupManagersVisibilityHint =>
      'Bunu yalnızca katılmadan önce kiminle iletişim kurulacağını ziyaretçilere göstermek istiyorsan aç.';

  @override
  String get groupNewPostTitle => 'Yeni paylaşım';

  @override
  String get groupPostHint => 'Grup için kısa bir güncelleme yaz';

  @override
  String get groupAddImageAction => 'Görsel ekle';

  @override
  String get groupCreatePostAction => 'Paylaşımı gönder';

  @override
  String get groupNewEventTitle => 'Yeni etkinlik';

  @override
  String get groupEventTitleLabel => 'Başlık';

  @override
  String get groupEventDescriptionLabel => 'Açıklama';

  @override
  String get groupEventLocationLabel => 'Konum';

  @override
  String get groupEventStartsAtLabel => 'Başlangıç tarihi';

  @override
  String get groupEventEndsAtLabel => 'Bitiş tarihi';

  @override
  String get groupEventScheduleHint =>
      'Tarihler üyelere girildiği biçimde gösterilir; gerekiyorsa saat dilimi veya format bilgisini ekle.';

  @override
  String get groupCreateEventAction => 'Etkinlik ekle';

  @override
  String get groupNewAnnouncementTitle => 'Yeni duyuru';

  @override
  String get groupAnnouncementTitleLabel => 'Başlık';

  @override
  String get groupAnnouncementBodyLabel => 'İçerik';

  @override
  String get groupCreateAnnouncementAction => 'Duyuru ekle';

  @override
  String groupEventLocationValue(Object value) {
    return 'Konum: $value';
  }

  @override
  String groupEventStartsAtValue(Object value) {
    return 'Başlangıç: $value';
  }

  @override
  String groupEventEndsAtValue(Object value) {
    return 'Bitiş: $value';
  }

  @override
  String groupLikesCount(Object count) {
    return '$count beğeni';
  }

  @override
  String groupCommentsCount(Object count) {
    return '$count yorum';
  }

  @override
  String get approveAction => 'Onayla';

  @override
  String get rejectAction => 'Reddet';

  @override
  String get genericMemberLabel => 'SDAL Üyesi';

  @override
  String get genericRequestFailed => 'İstek tamamlanamadı.';

  @override
  String get feedStoriesTitle => 'Topluluktan hikayeler';

  @override
  String get exploreTitle => 'Keşfet';

  @override
  String get exploreLatestMembersTitle => 'En yeni üyeler';

  @override
  String get exploreSuggestionsTitle => 'Öneriler';

  @override
  String get exploreNoSuggestions => 'Şu anda öneri yok.';

  @override
  String get exploreSuggestionsEmptyTitle => 'Şu anda öneri yok';

  @override
  String get exploreSuggestionsEmptyMessage =>
      'Yeni üye ve öneriler için bu listeyi daha sonra yenile.';

  @override
  String get exploreDirectoryTitle => 'Üye rehberi';

  @override
  String get exploreDirectoryFiltersTitle => 'Rehber filtreleri';

  @override
  String get exploreSearchLabel => 'Ara';

  @override
  String get exploreGraduationYearLabel => 'Mezuniyet yılı';

  @override
  String get exploreApplyFiltersAction => 'Filtreleri uygula';

  @override
  String get exploreClearFiltersAction => 'Temizle';

  @override
  String explorePageLabel(Object page) {
    return 'Sayfa $page';
  }

  @override
  String memberGraduationYearValue(Object year) {
    return '$year mezunu';
  }

  @override
  String get followAction => 'Takip et';

  @override
  String get unfollowAction => 'Takibi bırak';

  @override
  String get albumsTitle => 'Albümler';

  @override
  String get albumsUploadAction => 'Yükle';

  @override
  String get albumsEmpty => 'Henüz albüm fotoğrafı yok.';

  @override
  String get albumsLoadMore => 'Daha fazla fotoğraf';

  @override
  String get albumTitleFallback => 'Albüm';

  @override
  String get albumsCategoryMissing => 'Kategori bulunamadı.';

  @override
  String albumsOpenPhotoSemantic(Object label) {
    return '$label fotoğrafını aç';
  }

  @override
  String get profileStoriesTitle => 'Benim hikayelerim';

  @override
  String get retryAction => 'Tekrar dene';

  @override
  String get errorGenericTitle => 'Bir şeyler ters gitti.';

  @override
  String get errorGenericMessage =>
      'Biraz sonra yeniden dene veya bu ekranı yenile.';

  @override
  String get errorNetworkTitle => 'Bağlantı sorunu';

  @override
  String get errorNetworkMessage =>
      'İnternet bağlantını kontrol edip yeniden dene.';

  @override
  String get statusApproved => 'Onaylandı';

  @override
  String get statusRejected => 'Reddedildi';

  @override
  String get statusReviewed => 'İncelendi';

  @override
  String get statusPending => 'Bekliyor';

  @override
  String get requestsTitle => 'Üye talepleri';

  @override
  String get requestsCreateTitle => 'Yeni talep oluştur';

  @override
  String get requestsCreateHelper =>
      'Profil ve üyelik işlemleri için talep oluşturabilir, destekleyici dosyalar ekleyebilir ve son durumu aşağıdan takip edebilirsin.';

  @override
  String get requestsCategoryLabel => 'Talep kategorisi';

  @override
  String get requestsGraduationYearLabel => 'İstenen mezuniyet yılı';

  @override
  String get requestsTeacherOption => 'Öğretmen';

  @override
  String get requestsDescriptionLabel => 'Açıklama';

  @override
  String get requestsPickFromGallery => 'Galeriden ekle';

  @override
  String get requestsUseCamera => 'Kamera';

  @override
  String get requestsSendAction => 'Talebi gönder';

  @override
  String get requestsListTitle => 'Taleplerim';

  @override
  String get requestsNotificationApproved =>
      'Talep sonucu güncellendi. Onaylanan kayıt aşağıda vurgulandı.';

  @override
  String get requestsNotificationUpdated =>
      'Talep sonucu güncellendi. İlgili kayıt aşağıda vurgulandı.';

  @override
  String get requestsEmpty => 'Henüz gönderilmiş talep yok.';

  @override
  String get requestsEmptyTitle => 'Henüz talep yok';

  @override
  String get requestsEmptyMessage =>
      'Admin incelemesi gerektiren durumlarda yukarıdaki formu kullanarak profil veya üyelik talebi gönderebilirsin.';

  @override
  String get requestsAttachmentUploadFailed => 'Ek dosya yüklenemedi.';

  @override
  String get requestsAttachmentUploaded => 'Ek dosya yüklendi.';

  @override
  String get requestsSelectCategoryError => 'Bir talep kategorisi seç.';

  @override
  String get requestsSelectGraduationYearError =>
      'İstenen mezuniyet yılını seç.';

  @override
  String get requestsSubmitSuccess => 'Talep gönderildi.';

  @override
  String get requestsSubmitFailed => 'Talep gönderilemedi.';

  @override
  String requestsGraduationYearValue(Object value) {
    return 'İstenen mezuniyet yılı: $value';
  }

  @override
  String requestsResolutionNote(Object note) {
    return 'Not: $note';
  }

  @override
  String get jobsTitle => 'İş ilanları';

  @override
  String get jobsCreateTitle => 'Yeni iş ilanı';

  @override
  String get jobsCreateHelper =>
      'Üyelerin hızlı karar verebilmesi için ilanı kısa, net ve uygulanabilir tut.';

  @override
  String get jobsCompanyLabel => 'Şirket';

  @override
  String get jobsPositionLabel => 'Pozisyon';

  @override
  String get jobsDescriptionLabel => 'Açıklama';

  @override
  String get jobsLocationLabel => 'Konum';

  @override
  String get jobsTypeLabel => 'İş tipi';

  @override
  String get jobsLinkLabel => 'Başvuru linki';

  @override
  String get jobsLinkHint => 'https://...';

  @override
  String get jobsCreateAction => 'İlanı yayınla';

  @override
  String get jobsCreateInProgress => 'Yayınlanıyor...';

  @override
  String get jobsSearchTitle => 'İlanları filtrele';

  @override
  String get jobsSearchHelper =>
      'Mevcut ilanları pozisyon, konum veya iş tipine göre daralt.';

  @override
  String get jobsSearchLabel => 'Arama';

  @override
  String get jobsLocationFilterLabel => 'Konum filtresi';

  @override
  String get jobsTypeFilterLabel => 'İş tipi filtresi';

  @override
  String get jobsApplyFiltersAction => 'Filtreleri uygula';

  @override
  String get jobsEmpty => 'Henüz iş ilanı yok.';

  @override
  String jobsApplicationStatus(Object status) {
    return 'Başvuru durumu: $status';
  }

  @override
  String get jobsShortNoteLabel => 'Kısa başvuru notu';

  @override
  String get jobsApplyAction => 'Başvur';

  @override
  String get jobsLoadApplicationsAction => 'Başvuruları yükle';

  @override
  String get jobsRefreshApplicationsAction => 'Başvuruları yenile';

  @override
  String get jobsReviewNoteLabel => 'Karar notu';

  @override
  String get jobsMarkReviewedAction => 'İncelemede';

  @override
  String get jobsAcceptAction => 'Kabul et';

  @override
  String jobsApplicationsStatus(Object status) {
    return 'Durum: $status';
  }

  @override
  String get jobsCreateSuccess => 'İş ilanı yayınlandı.';

  @override
  String get jobsCreateFailed => 'İlan oluşturulamadı.';

  @override
  String get jobsApplySuccess => 'Başvuru gönderildi.';

  @override
  String get jobsApplyFailed => 'Başvuru gönderilemedi.';

  @override
  String get jobsDeleteSuccess => 'İlan silindi.';

  @override
  String get jobsDeleteFailed => 'İlan silinemedi.';

  @override
  String get jobsReviewSuccess => 'Başvuru güncellendi.';

  @override
  String get jobsReviewFailed => 'Başvuru güncellenemedi.';

  @override
  String get jobsPosterPendingApproval => 'Onay bekliyor';

  @override
  String get eventVisibilityTitle => 'Katılım görünürlüğü';

  @override
  String get eventVisibilityHelper =>
      'Bu ayarlar etkinliği gören üyelerin hangi katılım bilgilerine erişebileceğini belirler.';

  @override
  String get eventVisibilityShowCounts => 'Sayıları göster';

  @override
  String get eventVisibilityShowCountsHint =>
      'Katılan ve katılamayan kişi sayıları görünür olur.';

  @override
  String get eventVisibilityShowAttendees => 'Katılan isimlerini göster';

  @override
  String get eventVisibilityShowAttendeesHint =>
      'Etkinliği görebilen herkes katılan listesini de görebilir.';

  @override
  String get eventVisibilityShowDecliners => 'Katılamayan isimlerini göster';

  @override
  String get eventVisibilityShowDeclinersHint =>
      'Etkinliği görebilen herkes katılamayanları da görür.';

  @override
  String get eventVisibilitySaveAction => 'Görünürlük ayarlarını kaydet';

  @override
  String oauthFailedWithReason(Object reason) {
    return 'OAuth akışı tamamlanamadı: $reason';
  }

  @override
  String get oauthTokenMissing => 'OAuth dönüşünde oturum jetonu bulunamadı.';
}
