import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In tr, this message translates to:
  /// **'SDAL'**
  String get appName;

  /// No description provided for @appInitFailedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlatılamadı'**
  String get appInitFailedTitle;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @siteClosedTitle.
  ///
  /// In tr, this message translates to:
  /// **'SDAL şu anda kapalı'**
  String get siteClosedTitle;

  /// No description provided for @siteClosedFallbackMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bakım çalışması nedeniyle uygulama geçici olarak kullanılamıyor.'**
  String get siteClosedFallbackMessage;

  /// No description provided for @moduleClosedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Modül kapalı'**
  String get moduleClosedTitle;

  /// No description provided for @moduleClosedDefaultMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu özellik şu anda kullanılamıyor.'**
  String get moduleClosedDefaultMessage;

  /// No description provided for @moduleClosedWithName.
  ///
  /// In tr, this message translates to:
  /// **'{module} modülü geçici olarak kapatıldı.'**
  String moduleClosedWithName(Object module);

  /// No description provided for @accountBannedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap erişime kapatıldı'**
  String get accountBannedTitle;

  /// No description provided for @accountBannedMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu hesap yasaklandığı için uygulama içinde işlem yapılamıyor. Destek için SDAL yönetimiyle iletişime geçin.'**
  String get accountBannedMessage;

  /// No description provided for @verificationRequiredTitle.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama gerekli'**
  String get verificationRequiredTitle;

  /// No description provided for @verificationRequiredMessage.
  ///
  /// In tr, this message translates to:
  /// **'{feature} özellikleri için profil doğrulaması gerekiyor. Profil ekranından doğrulama talebi gönderebilirsiniz.'**
  String verificationRequiredMessage(Object feature);

  /// No description provided for @splashLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get splashLoading;

  /// No description provided for @splashPreparing.
  ///
  /// In tr, this message translates to:
  /// **'SDAL hazırlanıyor'**
  String get splashPreparing;

  /// No description provided for @tabFeed.
  ///
  /// In tr, this message translates to:
  /// **'Akış'**
  String get tabFeed;

  /// No description provided for @tabExplore.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get tabExplore;

  /// No description provided for @tabInbox.
  ///
  /// In tr, this message translates to:
  /// **'İç Kutu'**
  String get tabInbox;

  /// No description provided for @tabNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim'**
  String get tabNotifications;

  /// No description provided for @tabProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get tabProfile;

  /// No description provided for @loginTitle.
  ///
  /// In tr, this message translates to:
  /// **'SDAL'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Flutter iOS istemcisine giriş yapın.'**
  String get loginSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ol'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'V1 için yeni Flutter istemcisinden hesap oluşturun.'**
  String get registerSubtitle;

  /// No description provided for @activationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Aktivasyon'**
  String get activationTitle;

  /// No description provided for @activationSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'E-posta bağlantınız iOS uygulamasını açtıysa burada tamamlayın.'**
  String get activationSubtitle;

  /// No description provided for @resendActivationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Aktivasyon tekrar gönder'**
  String get resendActivationTitle;

  /// No description provided for @resendActivationSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Eski üyelik aktivasyon akışı için destek ekranı.'**
  String get resendActivationSubtitle;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırla'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Eski SDAL hesap kurtarma uç noktasını kullanır.'**
  String get resetPasswordSubtitle;

  /// No description provided for @oauthTitle.
  ///
  /// In tr, this message translates to:
  /// **'OAuth'**
  String get oauthTitle;

  /// No description provided for @oauthSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu ekran genellikle kısa süreliğine görünür.'**
  String get oauthSubtitle;

  /// No description provided for @oauthInfoMessage.
  ///
  /// In tr, this message translates to:
  /// **'Tarayıcı akışı uygulamaya geri döndüğünde oturum otomatik açılır.'**
  String get oauthInfoMessage;

  /// No description provided for @register.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ol'**
  String get register;

  /// No description provided for @resendActivation.
  ///
  /// In tr, this message translates to:
  /// **'Aktivasyon tekrar gönder'**
  String get resendActivation;

  /// No description provided for @resetPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırla'**
  String get resetPassword;

  /// No description provided for @username.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı'**
  String get username;

  /// No description provided for @password.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get password;

  /// No description provided for @email.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get email;

  /// No description provided for @firstName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get lastName;

  /// No description provided for @memberId.
  ///
  /// In tr, this message translates to:
  /// **'Üye kimliği'**
  String get memberId;

  /// No description provided for @activationCode.
  ///
  /// In tr, this message translates to:
  /// **'Aktivasyon kodu'**
  String get activationCode;

  /// No description provided for @captchaCode.
  ///
  /// In tr, this message translates to:
  /// **'Captcha kodu'**
  String get captchaCode;

  /// No description provided for @graduationYear.
  ///
  /// In tr, this message translates to:
  /// **'Mezuniyet yılı / Teacher'**
  String get graduationYear;

  /// No description provided for @passwordRepeat.
  ///
  /// In tr, this message translates to:
  /// **'Şifre tekrar'**
  String get passwordRepeat;

  /// No description provided for @loginInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yapılıyor...'**
  String get loginInProgress;

  /// No description provided for @loginAction.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get loginAction;

  /// No description provided for @continueWithGoogle.
  ///
  /// In tr, this message translates to:
  /// **'Google ile devam et'**
  String get continueWithGoogle;

  /// No description provided for @continueWithX.
  ///
  /// In tr, this message translates to:
  /// **'X ile devam et'**
  String get continueWithX;

  /// No description provided for @submitInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor...'**
  String get submitInProgress;

  /// No description provided for @registerSubmitAction.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt isteği gönder'**
  String get registerSubmitAction;

  /// No description provided for @resendAction.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar gönder'**
  String get resendAction;

  /// No description provided for @passwordResetSubmitAction.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırlama isteği gönder'**
  String get passwordResetSubmitAction;

  /// No description provided for @activationSubmitAction.
  ///
  /// In tr, this message translates to:
  /// **'Aktivasyonu tamamla'**
  String get activationSubmitAction;

  /// No description provided for @activationChecking.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol ediliyor...'**
  String get activationChecking;

  /// No description provided for @feedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ana Akış'**
  String get feedTitle;

  /// No description provided for @feedRefresh.
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get feedRefresh;

  /// No description provided for @feedPostAction.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi'**
  String get feedPostAction;

  /// No description provided for @feedEmptyContent.
  ///
  /// In tr, this message translates to:
  /// **'Bu gönderi içerik taşımıyor.'**
  String get feedEmptyContent;

  /// No description provided for @feedComposerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni gönderi'**
  String get feedComposerTitle;

  /// No description provided for @feedComposerHint.
  ///
  /// In tr, this message translates to:
  /// **'Ne paylaşmak istiyorsun?'**
  String get feedComposerHint;

  /// No description provided for @pickFromGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get pickFromGallery;

  /// No description provided for @shareInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşılıyor...'**
  String get shareInProgress;

  /// No description provided for @shareAction.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get shareAction;

  /// No description provided for @postShared.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi paylaşıldı.'**
  String get postShared;

  /// No description provided for @postShareFailed.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi paylaşılamadı.'**
  String get postShareFailed;

  /// No description provided for @notificationsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnreadLoading.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış sayısı yükleniyor...'**
  String get notificationsUnreadLoading;

  /// No description provided for @notificationsUnreadCount.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış bildirim: {count}'**
  String notificationsUnreadCount(Object count);

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü oku'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsUpdatedAllRead.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler okundu olarak işaretlendi.'**
  String get notificationsUpdatedAllRead;

  /// No description provided for @notificationsActionFailed.
  ///
  /// In tr, this message translates to:
  /// **'İşlem başarısız oldu.'**
  String get notificationsActionFailed;

  /// No description provided for @notificationsPreferencesUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim tercihleri güncellendi.'**
  String get notificationsPreferencesUpdated;

  /// No description provided for @notificationsPreferencesFailed.
  ///
  /// In tr, this message translates to:
  /// **'Tercihler kaydedilemedi.'**
  String get notificationsPreferencesFailed;

  /// No description provided for @notificationsInboxTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gelenler'**
  String get notificationsInboxTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bildirim yok.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsReadAction.
  ///
  /// In tr, this message translates to:
  /// **'Okundu'**
  String get notificationsReadAction;

  /// No description provided for @openAction.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get openAction;

  /// No description provided for @notificationOpenedFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim açılamadı.'**
  String get notificationOpenedFailed;

  /// No description provided for @profileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileMissing.
  ///
  /// In tr, this message translates to:
  /// **'Profil verisi bulunamadı.'**
  String get profileMissing;

  /// No description provided for @profileVerified.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulandı'**
  String get profileVerified;

  /// No description provided for @profilePendingVerification.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama bekliyor'**
  String get profilePendingVerification;

  /// No description provided for @profilePhotoAction.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get profilePhotoAction;

  /// No description provided for @profileVerificationAction.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama'**
  String get profileVerificationAction;

  /// No description provided for @profileAccountDetailsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap bilgileri'**
  String get profileAccountDetailsTitle;

  /// No description provided for @editAction.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get editAction;

  /// No description provided for @profileAccountActionsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap işlemleri'**
  String get profileAccountActionsTitle;

  /// No description provided for @changeEmailAction.
  ///
  /// In tr, this message translates to:
  /// **'E-posta değiştir'**
  String get changeEmailAction;

  /// No description provided for @changePasswordAction.
  ///
  /// In tr, this message translates to:
  /// **'Şifre değiştir'**
  String get changePasswordAction;

  /// No description provided for @logoutAction.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get logoutAction;

  /// No description provided for @profileVerificationPageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil doğrulama'**
  String get profileVerificationPageTitle;

  /// No description provided for @statusLabel.
  ///
  /// In tr, this message translates to:
  /// **'Durum'**
  String get statusLabel;

  /// No description provided for @profileVerifiedMessage.
  ///
  /// In tr, this message translates to:
  /// **'Profilin doğrulanmış görünüyor.'**
  String get profileVerifiedMessage;

  /// No description provided for @profileVerificationHint.
  ///
  /// In tr, this message translates to:
  /// **'Networking ve bazı sosyal akışlar için doğrulama gerekiyor. Kimlik veya okul bağlantısını gösteren bir görsel yükleyebilirsin.'**
  String get profileVerificationHint;

  /// No description provided for @proofUploadTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kanıt yükle'**
  String get proofUploadTitle;

  /// No description provided for @proofUploadHint.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf galerinden veya kameradan bir görsel seç.'**
  String get proofUploadHint;

  /// No description provided for @proofSelectedFile.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen dosya: {fileName}'**
  String proofSelectedFile(Object fileName);

  /// No description provided for @proofReady.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenen kanıt hazır.'**
  String get proofReady;

  /// No description provided for @cameraAction.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get cameraAction;

  /// No description provided for @proofUploadInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Kanıt yükleniyor...'**
  String get proofUploadInProgress;

  /// No description provided for @proofUploadAction.
  ///
  /// In tr, this message translates to:
  /// **'Kanıtı yükle'**
  String get proofUploadAction;

  /// No description provided for @proofRequestTitle.
  ///
  /// In tr, this message translates to:
  /// **'Talebi gönder'**
  String get proofRequestTitle;

  /// No description provided for @proofRequestHint.
  ///
  /// In tr, this message translates to:
  /// **'İstersen önce kanıt yükle, istersen sadece doğrulama talebini gönder.'**
  String get proofRequestHint;

  /// No description provided for @verificationSubmitInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor...'**
  String get verificationSubmitInProgress;

  /// No description provided for @verificationSubmitAction.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama talebini gönder'**
  String get verificationSubmitAction;

  /// No description provided for @proofUploadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kanıt yüklenemedi.'**
  String get proofUploadFailed;

  /// No description provided for @proofUploaded.
  ///
  /// In tr, this message translates to:
  /// **'Kanıt dosyası yüklendi.'**
  String get proofUploaded;

  /// No description provided for @verificationSubmitted.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama talebi gönderildi.'**
  String get verificationSubmitted;

  /// No description provided for @verificationSubmitFailed.
  ///
  /// In tr, this message translates to:
  /// **'Talep gönderilemedi.'**
  String get verificationSubmitFailed;

  /// No description provided for @messagesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get messagesTitle;

  /// No description provided for @newChatAction.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sohbet'**
  String get newChatAction;

  /// No description provided for @searchPeopleHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişi veya kullanıcı adı ara'**
  String get searchPeopleHint;

  /// No description provided for @noThreads.
  ///
  /// In tr, this message translates to:
  /// **'Henüz konuşma yok. Yeni bir mesaj başlatmak için sağ alttaki düğmeyi kullan.'**
  String get noThreads;

  /// No description provided for @startNewChat.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sohbete başla'**
  String get startNewChat;

  /// No description provided for @newChatTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sohbet'**
  String get newChatTitle;

  /// No description provided for @searchPersonHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişi ara'**
  String get searchPersonHint;

  /// No description provided for @searchPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı veya isim gir.'**
  String get searchPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen kişi bulunamadı.'**
  String get searchNoResults;

  /// No description provided for @threadFallbackTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get threadFallbackTitle;

  /// No description provided for @realtimeConnected.
  ///
  /// In tr, this message translates to:
  /// **'Canlı'**
  String get realtimeConnected;

  /// No description provided for @realtimeReconnecting.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden bağlanıyor'**
  String get realtimeReconnecting;

  /// No description provided for @realtimeFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok'**
  String get realtimeFailed;

  /// No description provided for @realtimeConnecting.
  ///
  /// In tr, this message translates to:
  /// **'Bağlanıyor'**
  String get realtimeConnecting;

  /// No description provided for @realtimeDisconnected.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get realtimeDisconnected;

  /// No description provided for @threadEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mesaj yok. İlk mesajı sen gönder.'**
  String get threadEmpty;

  /// No description provided for @messageFieldLabel.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj'**
  String get messageFieldLabel;

  /// No description provided for @messageSendAction.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get messageSendAction;

  /// No description provided for @messageSendInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor...'**
  String get messageSendInProgress;

  /// No description provided for @messageSendFailed.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj gönderilemedi.'**
  String get messageSendFailed;

  /// No description provided for @genericMemberLabel.
  ///
  /// In tr, this message translates to:
  /// **'SDAL Üyesi'**
  String get genericMemberLabel;

  /// No description provided for @genericRequestFailed.
  ///
  /// In tr, this message translates to:
  /// **'İstek tamamlanamadı.'**
  String get genericRequestFailed;

  /// No description provided for @oauthFailedWithReason.
  ///
  /// In tr, this message translates to:
  /// **'OAuth akışı tamamlanamadı: {reason}'**
  String oauthFailedWithReason(Object reason);

  /// No description provided for @oauthTokenMissing.
  ///
  /// In tr, this message translates to:
  /// **'OAuth dönüşünde oturum jetonu bulunamadı.'**
  String get oauthTokenMissing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
