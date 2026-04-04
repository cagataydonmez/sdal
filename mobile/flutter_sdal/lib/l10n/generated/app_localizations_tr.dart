// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'SDAL';

  @override
  String get appInitFailedTitle => 'Başlatılamadı';

  @override
  String get retry => 'Tekrar dene';

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
  String get tabInbox => 'İç Kutu';

  @override
  String get tabNotifications => 'Bildirim';

  @override
  String get tabProfile => 'Profil';

  @override
  String get loginTitle => 'SDAL';

  @override
  String get loginSubtitle => 'Yeni Flutter iOS istemcisine giriş yapın.';

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
  String get editAction => 'Düzenle';

  @override
  String get profileAccountActionsTitle => 'Hesap işlemleri';

  @override
  String get changeEmailAction => 'E-posta değiştir';

  @override
  String get changePasswordAction => 'Şifre değiştir';

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
  String get genericMemberLabel => 'SDAL Üyesi';

  @override
  String get genericRequestFailed => 'İstek tamamlanamadı.';

  @override
  String oauthFailedWithReason(Object reason) {
    return 'OAuth akışı tamamlanamadı: $reason';
  }

  @override
  String get oauthTokenMissing => 'OAuth dönüşünde oturum jetonu bulunamadı.';
}
