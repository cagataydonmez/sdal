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
  /// **'SDAL Sosyal'**
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

  /// No description provided for @refreshAction.
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get refreshAction;

  /// No description provided for @backAction.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get backAction;

  /// No description provided for @quickMenuAction.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı menü'**
  String get quickMenuAction;

  /// No description provided for @profileOpenAction.
  ///
  /// In tr, this message translates to:
  /// **'Profili aç'**
  String get profileOpenAction;

  /// No description provided for @openMemberProfileForName.
  ///
  /// In tr, this message translates to:
  /// **'{name} profilini aç'**
  String openMemberProfileForName(Object name);

  /// No description provided for @moreActions.
  ///
  /// In tr, this message translates to:
  /// **'Diğer işlemler'**
  String get moreActions;

  /// No description provided for @removeImageAction.
  ///
  /// In tr, this message translates to:
  /// **'Görseli kaldır'**
  String get removeImageAction;

  /// No description provided for @quickAccessRemoveAction.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı erişimden kaldır'**
  String get quickAccessRemoveAction;

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
  /// **'Mesajlar'**
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
  /// **'SDAL Sosyal'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'SDAL Sosyal uygulamasına giriş yapın.'**
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

  /// No description provided for @captionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get captionLabel;

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

  /// No description provided for @registerFieldRequired.
  ///
  /// In tr, this message translates to:
  /// **'{field} alanı zorunludur.'**
  String registerFieldRequired(Object field);

  /// No description provided for @registerFieldTooLong.
  ///
  /// In tr, this message translates to:
  /// **'{field} alanı en fazla {max} karakter olabilir.'**
  String registerFieldTooLong(Object field, Object max);

  /// No description provided for @registerEmailInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi gir.'**
  String get registerEmailInvalid;

  /// No description provided for @registerPasswordMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifre alanları birbiriyle aynı olmalıdır.'**
  String get registerPasswordMismatch;

  /// No description provided for @registerPasswordHint.
  ///
  /// In tr, this message translates to:
  /// **'8-20 karakter kullan. Büyük harf, küçük harf, sayı ve sembol karışımı hesabını daha iyi korur.'**
  String get registerPasswordHint;

  /// No description provided for @registerPasswordStrengthNone.
  ///
  /// In tr, this message translates to:
  /// **'Şifre gücü'**
  String get registerPasswordStrengthNone;

  /// No description provided for @registerPasswordStrengthWeak.
  ///
  /// In tr, this message translates to:
  /// **'Şifre gücü: Zayıf'**
  String get registerPasswordStrengthWeak;

  /// No description provided for @registerPasswordStrengthMedium.
  ///
  /// In tr, this message translates to:
  /// **'Şifre gücü: Orta'**
  String get registerPasswordStrengthMedium;

  /// No description provided for @registerPasswordStrengthStrong.
  ///
  /// In tr, this message translates to:
  /// **'Şifre gücü: Güçlü'**
  String get registerPasswordStrengthStrong;

  /// No description provided for @registerGraduationYearInvalid.
  ///
  /// In tr, this message translates to:
  /// **'1999 ile içinde bulunduğumuz yıl arasında geçerli bir mezuniyet yılı veya Öğretmen gir.'**
  String get registerGraduationYearInvalid;

  /// No description provided for @registerKvkkConsentLabel.
  ///
  /// In tr, this message translates to:
  /// **'KVKK Aydınlatma Metni\'ni okudum ve onaylıyorum.'**
  String get registerKvkkConsentLabel;

  /// No description provided for @registerKvkkConsentError.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt olmadan önce KVKK Aydınlatma Metni onayı gerekiyor.'**
  String get registerKvkkConsentError;

  /// No description provided for @registerKvkkTitle.
  ///
  /// In tr, this message translates to:
  /// **'KVKK Aydınlatma Metni'**
  String get registerKvkkTitle;

  /// No description provided for @registerKvkkOpenAction.
  ///
  /// In tr, this message translates to:
  /// **'KVKK metnini aç'**
  String get registerKvkkOpenAction;

  /// No description provided for @registerDirectoryConsentLabel.
  ///
  /// In tr, this message translates to:
  /// **'Mezun Rehberi açık rıza onayını veriyorum.'**
  String get registerDirectoryConsentLabel;

  /// No description provided for @registerDirectoryConsentError.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt olmadan önce Mezun Rehberi açık rıza onayı gerekiyor.'**
  String get registerDirectoryConsentError;

  /// No description provided for @registerDirectoryConsentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mezun Rehberi Açık Rıza Metni'**
  String get registerDirectoryConsentTitle;

  /// No description provided for @registerDirectoryConsentOpenAction.
  ///
  /// In tr, this message translates to:
  /// **'Açık rıza metnini aç'**
  String get registerDirectoryConsentOpenAction;

  /// No description provided for @registerCaptchaLoading.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik kodu yükleniyor...'**
  String get registerCaptchaLoading;

  /// No description provided for @registerCaptchaUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik kodu yüklenemedi. Kodu yenileyip tekrar deneyin.'**
  String get registerCaptchaUnavailable;

  /// No description provided for @registerCaptchaRetryAction.
  ///
  /// In tr, this message translates to:
  /// **'Kodu yenile'**
  String get registerCaptchaRetryAction;

  /// No description provided for @registerCaptchaCodeRequired.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik kodunu gir.'**
  String get registerCaptchaCodeRequired;

  /// No description provided for @registerCaptchaDigitsOnly.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik kodu yalnızca rakamlardan oluşmalıdır.'**
  String get registerCaptchaDigitsOnly;

  /// No description provided for @registerPreviewFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt bilgileri doğrulanamadı.'**
  String get registerPreviewFailed;

  /// No description provided for @registerAvailabilityCheckFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kullanılabilirlik şu anda kontrol edilemedi.'**
  String get registerAvailabilityCheckFailed;

  /// No description provided for @registerUsernameTaken.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı adı zaten kayıtlı.'**
  String get registerUsernameTaken;

  /// No description provided for @registerUsernameAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı adı uygun görünüyor.'**
  String get registerUsernameAvailable;

  /// No description provided for @registerEmailTaken.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi zaten kayıtlı.'**
  String get registerEmailTaken;

  /// No description provided for @registerEmailAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi uygun görünüyor.'**
  String get registerEmailAvailable;

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

  /// No description provided for @messagesUnreadCount.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış mesaj: {count}'**
  String messagesUnreadCount(Object count);

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

  /// No description provided for @profileEditPageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profili düzenle'**
  String get profileEditPageTitle;

  /// No description provided for @profileEditIdentitySectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Temel bilgiler'**
  String get profileEditIdentitySectionTitle;

  /// No description provided for @profileEditIdentitySectionDescription.
  ///
  /// In tr, this message translates to:
  /// **'Profilinde görünen temel alanları güncelle ve seni tanımayı kolaylaştır.'**
  String get profileEditIdentitySectionDescription;

  /// No description provided for @profileEditContactSectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantılar ve geçmiş'**
  String get profileEditContactSectionTitle;

  /// No description provided for @profileEditContactSectionDescription.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı bağlantılarını, okul bilgisini ve mentorluk konularını uygulama genelinde düzgün görünecek biçimde paylaş.'**
  String get profileEditContactSectionDescription;

  /// No description provided for @profileEditPrivacySectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Görünürlük ve onaylar'**
  String get profileEditPrivacySectionTitle;

  /// No description provided for @profileEditPrivacySectionDescription.
  ///
  /// In tr, this message translates to:
  /// **'Profilinin rehberde nasıl görüneceğini yönet ve gerekli onayları güncel tut.'**
  String get profileEditPrivacySectionDescription;

  /// No description provided for @profileEditFirstNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get profileEditFirstNameLabel;

  /// No description provided for @profileEditLastNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get profileEditLastNameLabel;

  /// No description provided for @profileEditGraduationYearLabel.
  ///
  /// In tr, this message translates to:
  /// **'Mezuniyet yılı / Öğretmen'**
  String get profileEditGraduationYearLabel;

  /// No description provided for @profileEditGraduationYearHint.
  ///
  /// In tr, this message translates to:
  /// **'1999-2100 veya Öğretmen'**
  String get profileEditGraduationYearHint;

  /// No description provided for @profileEditCityLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şehir'**
  String get profileEditCityLabel;

  /// No description provided for @profileEditProfessionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Meslek'**
  String get profileEditProfessionLabel;

  /// No description provided for @profileEditCompanyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şirket'**
  String get profileEditCompanyLabel;

  /// No description provided for @profileEditTitleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Unvan'**
  String get profileEditTitleLabel;

  /// No description provided for @profileEditExpertiseLabel.
  ///
  /// In tr, this message translates to:
  /// **'Uzmanlık'**
  String get profileEditExpertiseLabel;

  /// No description provided for @profileEditWebsiteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Web sitesi'**
  String get profileEditWebsiteLabel;

  /// No description provided for @profileEditLinkedinLabel.
  ///
  /// In tr, this message translates to:
  /// **'LinkedIn'**
  String get profileEditLinkedinLabel;

  /// No description provided for @profileEditUniversityLabel.
  ///
  /// In tr, this message translates to:
  /// **'Üniversite'**
  String get profileEditUniversityLabel;

  /// No description provided for @profileEditDepartmentLabel.
  ///
  /// In tr, this message translates to:
  /// **'Üniversite bölümü'**
  String get profileEditDepartmentLabel;

  /// No description provided for @profileEditMentorTopicsLabel.
  ///
  /// In tr, this message translates to:
  /// **'Mentorluk konuları'**
  String get profileEditMentorTopicsLabel;

  /// No description provided for @profileEditSignatureLabel.
  ///
  /// In tr, this message translates to:
  /// **'İmza'**
  String get profileEditSignatureLabel;

  /// No description provided for @profileEditMentorVisibleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Beni mentor olarak göster'**
  String get profileEditMentorVisibleLabel;

  /// No description provided for @profileEditKvkkConsentLabel.
  ///
  /// In tr, this message translates to:
  /// **'KVKK onayı'**
  String get profileEditKvkkConsentLabel;

  /// No description provided for @profileEditDirectoryConsentLabel.
  ///
  /// In tr, this message translates to:
  /// **'Rehber onayı'**
  String get profileEditDirectoryConsentLabel;

  /// No description provided for @profileEditHideEmailLabel.
  ///
  /// In tr, this message translates to:
  /// **'E-postamı gizle'**
  String get profileEditHideEmailLabel;

  /// No description provided for @profileEditSaveInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor...'**
  String get profileEditSaveInProgress;

  /// No description provided for @profileEditSaved.
  ///
  /// In tr, this message translates to:
  /// **'Profil güncellendi.'**
  String get profileEditSaved;

  /// No description provided for @profileEditSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil güncellenemedi.'**
  String get profileEditSaveFailed;

  /// No description provided for @profileEditGraduationYearError.
  ///
  /// In tr, this message translates to:
  /// **'1999-2100 arasında bir mezuniyet yılı veya Öğretmen gir.'**
  String get profileEditGraduationYearError;

  /// No description provided for @profileEditWebsiteError.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir web sitesi adresi gir.'**
  String get profileEditWebsiteError;

  /// No description provided for @profileEditLinkedinError.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir LinkedIn adresi gir.'**
  String get profileEditLinkedinError;

  /// No description provided for @profileEditRequiredField.
  ///
  /// In tr, this message translates to:
  /// **'{field} alanı zorunludur.'**
  String profileEditRequiredField(Object field);

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

  /// No description provided for @themeModeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get themeModeTitle;

  /// No description provided for @themeModeHelper.
  ///
  /// In tr, this message translates to:
  /// **'Sistem ayarını izleyin veya uygulama için kalıcı bir görünüm seçin.'**
  String get themeModeHelper;

  /// No description provided for @themeModeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeModeDark;

  /// No description provided for @cancelAction.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancelAction;

  /// No description provided for @saveAction.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get saveAction;

  /// No description provided for @createAction.
  ///
  /// In tr, this message translates to:
  /// **'Oluştur'**
  String get createAction;

  /// No description provided for @deleteAction.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get deleteAction;

  /// No description provided for @groupsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gruplar'**
  String get groupsTitle;

  /// No description provided for @groupsNewGroupAction.
  ///
  /// In tr, this message translates to:
  /// **'Yeni grup'**
  String get groupsNewGroupAction;

  /// No description provided for @groupsOpenAction.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get groupsOpenAction;

  /// No description provided for @groupsLeaveAction.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get groupsLeaveAction;

  /// No description provided for @groupsWithdrawRequestAction.
  ///
  /// In tr, this message translates to:
  /// **'Talebi çek'**
  String get groupsWithdrawRequestAction;

  /// No description provided for @groupsAcceptInviteAction.
  ///
  /// In tr, this message translates to:
  /// **'Daveti kabul et'**
  String get groupsAcceptInviteAction;

  /// No description provided for @groupsJoinAction.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get groupsJoinAction;

  /// No description provided for @groupsPendingApproval.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get groupsPendingApproval;

  /// No description provided for @groupsInvitePending.
  ///
  /// In tr, this message translates to:
  /// **'Davet bekliyor'**
  String get groupsInvitePending;

  /// No description provided for @groupsNewGroupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni grup'**
  String get groupsNewGroupTitle;

  /// No description provided for @groupsNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Grup adı'**
  String get groupsNameLabel;

  /// No description provided for @groupsDescriptionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get groupsDescriptionLabel;

  /// No description provided for @groupsCreating.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturuluyor...'**
  String get groupsCreating;

  /// No description provided for @groupsMembersCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String groupsMembersCount(Object count);

  /// No description provided for @storiesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hikayeler'**
  String get storiesTitle;

  /// No description provided for @storiesEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz aktif hikaye yok.'**
  String get storiesEmpty;

  /// No description provided for @storiesUploadAction.
  ///
  /// In tr, this message translates to:
  /// **'Hikaye ekle'**
  String get storiesUploadAction;

  /// No description provided for @storiesUploadHint.
  ///
  /// In tr, this message translates to:
  /// **'24 saat görünür'**
  String get storiesUploadHint;

  /// No description provided for @storiesPublishAction.
  ///
  /// In tr, this message translates to:
  /// **'Hikayeyi paylaş'**
  String get storiesPublishAction;

  /// No description provided for @storiesViewed.
  ///
  /// In tr, this message translates to:
  /// **'Görüldü'**
  String get storiesViewed;

  /// No description provided for @storiesNewCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} yeni'**
  String storiesNewCount(Object count);

  /// No description provided for @storiesNewStoryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni hikaye'**
  String get storiesNewStoryTitle;

  /// No description provided for @storiesEditTitleAction.
  ///
  /// In tr, this message translates to:
  /// **'Başlığı düzenle'**
  String get storiesEditTitleAction;

  /// No description provided for @storiesDeleteAction.
  ///
  /// In tr, this message translates to:
  /// **'Hikayeyi sil'**
  String get storiesDeleteAction;

  /// No description provided for @storiesRepostAction.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden paylaş'**
  String get storiesRepostAction;

  /// No description provided for @storiesCaptionDialogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hikaye başlığı'**
  String get storiesCaptionDialogTitle;

  /// No description provided for @storiesCaptionHint.
  ///
  /// In tr, this message translates to:
  /// **'Kısa bir açıklama ekle'**
  String get storiesCaptionHint;

  /// No description provided for @storiesDeleteConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hikaye silinsin mi?'**
  String get storiesDeleteConfirmTitle;

  /// No description provided for @storiesViewStorySemantic.
  ///
  /// In tr, this message translates to:
  /// **'{name} hikayesini aç'**
  String storiesViewStorySemantic(Object name);

  /// No description provided for @storiesPreviousStoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Önceki hikayeyi aç'**
  String get storiesPreviousStoryHint;

  /// No description provided for @storiesNextStoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki hikayeyi aç'**
  String get storiesNextStoryHint;

  /// No description provided for @liveChatTitle.
  ///
  /// In tr, this message translates to:
  /// **'Canlı sohbet'**
  String get liveChatTitle;

  /// No description provided for @liveChatConnected.
  ///
  /// In tr, this message translates to:
  /// **'Canlı bağlantı aktif'**
  String get liveChatConnected;

  /// No description provided for @liveChatReconnecting.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yeniden kuruluyor...'**
  String get liveChatReconnecting;

  /// No description provided for @liveChatComposerHint.
  ///
  /// In tr, this message translates to:
  /// **'Mesajını yaz'**
  String get liveChatComposerHint;

  /// No description provided for @liveChatEditMessageAction.
  ///
  /// In tr, this message translates to:
  /// **'Mesajı düzenle'**
  String get liveChatEditMessageAction;

  /// No description provided for @liveChatDeleteMessageAction.
  ///
  /// In tr, this message translates to:
  /// **'Mesajı sil'**
  String get liveChatDeleteMessageAction;

  /// No description provided for @liveChatEditDialogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mesajı düzenle'**
  String get liveChatEditDialogTitle;

  /// No description provided for @groupDetailTitle.
  ///
  /// In tr, this message translates to:
  /// **'Grup detayları'**
  String get groupDetailTitle;

  /// No description provided for @groupNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Grup bulunamadı.'**
  String get groupNotFound;

  /// No description provided for @groupVisibilityPrivate.
  ///
  /// In tr, this message translates to:
  /// **'Özel'**
  String get groupVisibilityPrivate;

  /// No description provided for @groupVisibilityPublic.
  ///
  /// In tr, this message translates to:
  /// **'Herkese açık'**
  String get groupVisibilityPublic;

  /// No description provided for @groupManagersVisible.
  ///
  /// In tr, this message translates to:
  /// **'Yöneticiler görünür'**
  String get groupManagersVisible;

  /// No description provided for @groupRejectInviteAction.
  ///
  /// In tr, this message translates to:
  /// **'Daveti reddet'**
  String get groupRejectInviteAction;

  /// No description provided for @groupSettingsAction.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get groupSettingsAction;

  /// No description provided for @groupInviteMembersAction.
  ///
  /// In tr, this message translates to:
  /// **'Üye davet et'**
  String get groupInviteMembersAction;

  /// No description provided for @groupUpdateCoverAction.
  ///
  /// In tr, this message translates to:
  /// **'Kapak güncelle'**
  String get groupUpdateCoverAction;

  /// No description provided for @groupManagersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yöneticiler'**
  String get groupManagersTitle;

  /// No description provided for @groupJoinRequestsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılım istekleri'**
  String get groupJoinRequestsTitle;

  /// No description provided for @groupPendingInvitesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen davetler'**
  String get groupPendingInvitesTitle;

  /// No description provided for @groupPostsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşımlar'**
  String get groupPostsTitle;

  /// No description provided for @groupNoPosts.
  ///
  /// In tr, this message translates to:
  /// **'Henüz grup paylaşımı yok.'**
  String get groupNoPosts;

  /// No description provided for @groupEventsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get groupEventsTitle;

  /// No description provided for @groupAddEventAction.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik ekle'**
  String get groupAddEventAction;

  /// No description provided for @groupNoEvents.
  ///
  /// In tr, this message translates to:
  /// **'Bu grup için planlanmış etkinlik yok.'**
  String get groupNoEvents;

  /// No description provided for @groupAnnouncementsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get groupAnnouncementsTitle;

  /// No description provided for @groupAddAnnouncementAction.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru ekle'**
  String get groupAddAnnouncementAction;

  /// No description provided for @groupNoAnnouncements.
  ///
  /// In tr, this message translates to:
  /// **'Bu grup için duyuru yok.'**
  String get groupNoAnnouncements;

  /// No description provided for @groupMembersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler'**
  String get groupMembersTitle;

  /// No description provided for @groupContentMembersOnlyTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerik üyeler için açık'**
  String get groupContentMembersOnlyTitle;

  /// No description provided for @groupContentMembersOnlyBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu grubun içeriğini görmek için üyelik onayı gerekli.'**
  String get groupContentMembersOnlyBody;

  /// No description provided for @groupDetailLeaveAction.
  ///
  /// In tr, this message translates to:
  /// **'Gruptan ayrıl'**
  String get groupDetailLeaveAction;

  /// No description provided for @groupDetailWithdrawRequestAction.
  ///
  /// In tr, this message translates to:
  /// **'Talebi geri çek'**
  String get groupDetailWithdrawRequestAction;

  /// No description provided for @groupDetailAcceptInviteAction.
  ///
  /// In tr, this message translates to:
  /// **'Daveti kabul et'**
  String get groupDetailAcceptInviteAction;

  /// No description provided for @groupDetailJoinAction.
  ///
  /// In tr, this message translates to:
  /// **'Katılım isteği gönder'**
  String get groupDetailJoinAction;

  /// No description provided for @groupAdminPanelTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim araçları'**
  String get groupAdminPanelTitle;

  /// No description provided for @groupAdminPanelHelper.
  ///
  /// In tr, this message translates to:
  /// **'Katılım isteklerini incele, yeni üyeler davet et ve grubun görünürlüğünü tek yerden düzenle.'**
  String get groupAdminPanelHelper;

  /// No description provided for @groupTimelineTitle.
  ///
  /// In tr, this message translates to:
  /// **'Grup akışı'**
  String get groupTimelineTitle;

  /// No description provided for @groupPostsHelper.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru açmadan gruba kısa güncellemeler paylaş.'**
  String get groupPostsHelper;

  /// No description provided for @groupTimelineHelper.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan etkinlikleri ve önemli duyuruları daha rahat taranır halde tut.'**
  String get groupTimelineHelper;

  /// No description provided for @groupMembersHelper.
  ///
  /// In tr, this message translates to:
  /// **'Yöneticiler önce gösterilir. Rol değişiklikleri moderasyon yetkilerini etkilediği için dikkatli kullanılmalıdır.'**
  String get groupMembersHelper;

  /// No description provided for @groupInviteSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ad veya kullanıcı adı ile ara'**
  String get groupInviteSearchHint;

  /// No description provided for @groupSelectedCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kişi seçildi'**
  String groupSelectedCount(Object count);

  /// No description provided for @groupInvitesSent.
  ///
  /// In tr, this message translates to:
  /// **'{count} davet gönderildi.'**
  String groupInvitesSent(Object count);

  /// No description provided for @groupRoleMakeMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye yap'**
  String get groupRoleMakeMember;

  /// No description provided for @groupRoleMakeModerator.
  ///
  /// In tr, this message translates to:
  /// **'Moderatör yap'**
  String get groupRoleMakeModerator;

  /// No description provided for @groupRoleMakeOwner.
  ///
  /// In tr, this message translates to:
  /// **'Sahipliği devret'**
  String get groupRoleMakeOwner;

  /// No description provided for @groupSettingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Grup ayarları'**
  String get groupSettingsTitle;

  /// No description provided for @groupVisibilityLabel.
  ///
  /// In tr, this message translates to:
  /// **'Görünürlük'**
  String get groupVisibilityLabel;

  /// No description provided for @groupVisibilityPublicOption.
  ///
  /// In tr, this message translates to:
  /// **'Herkese açık'**
  String get groupVisibilityPublicOption;

  /// No description provided for @groupVisibilityMembersOnlyOption.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca üyeler'**
  String get groupVisibilityMembersOnlyOption;

  /// No description provided for @groupVisibilityHint.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca üyeler seçildiğinde paylaşımlar, etkinlikler, duyurular ve üye listesi katılım isteği onaylanana kadar gizlenir.'**
  String get groupVisibilityHint;

  /// No description provided for @groupManagersVisibilityTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yöneticileri üye olmayanlara da göster'**
  String get groupManagersVisibilityTitle;

  /// No description provided for @groupManagersVisibilityHint.
  ///
  /// In tr, this message translates to:
  /// **'Bunu yalnızca katılmadan önce kiminle iletişim kurulacağını ziyaretçilere göstermek istiyorsan aç.'**
  String get groupManagersVisibilityHint;

  /// No description provided for @groupNewPostTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni paylaşım'**
  String get groupNewPostTitle;

  /// No description provided for @groupPostHint.
  ///
  /// In tr, this message translates to:
  /// **'Grup için kısa bir güncelleme yaz'**
  String get groupPostHint;

  /// No description provided for @groupAddImageAction.
  ///
  /// In tr, this message translates to:
  /// **'Görsel ekle'**
  String get groupAddImageAction;

  /// No description provided for @groupCreatePostAction.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşımı gönder'**
  String get groupCreatePostAction;

  /// No description provided for @groupNewEventTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni etkinlik'**
  String get groupNewEventTitle;

  /// No description provided for @groupEventTitleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get groupEventTitleLabel;

  /// No description provided for @groupEventDescriptionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get groupEventDescriptionLabel;

  /// No description provided for @groupEventLocationLabel.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get groupEventLocationLabel;

  /// No description provided for @groupEventStartsAtLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç tarihi'**
  String get groupEventStartsAtLabel;

  /// No description provided for @groupEventEndsAtLabel.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş tarihi'**
  String get groupEventEndsAtLabel;

  /// No description provided for @groupEventScheduleHint.
  ///
  /// In tr, this message translates to:
  /// **'Tarihler üyelere girildiği biçimde gösterilir; gerekiyorsa saat dilimi veya format bilgisini ekle.'**
  String get groupEventScheduleHint;

  /// No description provided for @groupCreateEventAction.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik ekle'**
  String get groupCreateEventAction;

  /// No description provided for @groupNewAnnouncementTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni duyuru'**
  String get groupNewAnnouncementTitle;

  /// No description provided for @groupAnnouncementTitleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get groupAnnouncementTitleLabel;

  /// No description provided for @groupAnnouncementBodyLabel.
  ///
  /// In tr, this message translates to:
  /// **'İçerik'**
  String get groupAnnouncementBodyLabel;

  /// No description provided for @groupCreateAnnouncementAction.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru ekle'**
  String get groupCreateAnnouncementAction;

  /// No description provided for @groupEventLocationValue.
  ///
  /// In tr, this message translates to:
  /// **'Konum: {value}'**
  String groupEventLocationValue(Object value);

  /// No description provided for @groupEventStartsAtValue.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç: {value}'**
  String groupEventStartsAtValue(Object value);

  /// No description provided for @groupEventEndsAtValue.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş: {value}'**
  String groupEventEndsAtValue(Object value);

  /// No description provided for @groupLikesCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} beğeni'**
  String groupLikesCount(Object count);

  /// No description provided for @groupCommentsCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} yorum'**
  String groupCommentsCount(Object count);

  /// No description provided for @approveAction.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get approveAction;

  /// No description provided for @rejectAction.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get rejectAction;

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

  /// No description provided for @feedStoriesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Topluluktan hikayeler'**
  String get feedStoriesTitle;

  /// No description provided for @exploreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get exploreTitle;

  /// No description provided for @exploreSuggestionsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Öneriler'**
  String get exploreSuggestionsTitle;

  /// No description provided for @exploreNoSuggestions.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda öneri yok.'**
  String get exploreNoSuggestions;

  /// No description provided for @exploreDirectoryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Üye rehberi'**
  String get exploreDirectoryTitle;

  /// No description provided for @followAction.
  ///
  /// In tr, this message translates to:
  /// **'Takip et'**
  String get followAction;

  /// No description provided for @albumsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Albümler'**
  String get albumsTitle;

  /// No description provided for @albumsUploadAction.
  ///
  /// In tr, this message translates to:
  /// **'Yükle'**
  String get albumsUploadAction;

  /// No description provided for @albumsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz albüm fotoğrafı yok.'**
  String get albumsEmpty;

  /// No description provided for @albumsLoadMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla fotoğraf'**
  String get albumsLoadMore;

  /// No description provided for @albumTitleFallback.
  ///
  /// In tr, this message translates to:
  /// **'Albüm'**
  String get albumTitleFallback;

  /// No description provided for @albumsCategoryMissing.
  ///
  /// In tr, this message translates to:
  /// **'Kategori bulunamadı.'**
  String get albumsCategoryMissing;

  /// No description provided for @albumsOpenPhotoSemantic.
  ///
  /// In tr, this message translates to:
  /// **'{label} fotoğrafını aç'**
  String albumsOpenPhotoSemantic(Object label);

  /// No description provided for @profileStoriesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Benim hikayelerim'**
  String get profileStoriesTitle;

  /// No description provided for @retryAction.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retryAction;

  /// No description provided for @statusApproved.
  ///
  /// In tr, this message translates to:
  /// **'Onaylandı'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get statusRejected;

  /// No description provided for @statusReviewed.
  ///
  /// In tr, this message translates to:
  /// **'İncelendi'**
  String get statusReviewed;

  /// No description provided for @statusPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get statusPending;

  /// No description provided for @requestsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Üye talepleri'**
  String get requestsTitle;

  /// No description provided for @requestsCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni talep oluştur'**
  String get requestsCreateTitle;

  /// No description provided for @requestsCreateHelper.
  ///
  /// In tr, this message translates to:
  /// **'Profil ve üyelik işlemleri için talep oluşturabilir, destekleyici dosyalar ekleyebilir ve son durumu aşağıdan takip edebilirsin.'**
  String get requestsCreateHelper;

  /// No description provided for @requestsCategoryLabel.
  ///
  /// In tr, this message translates to:
  /// **'Talep kategorisi'**
  String get requestsCategoryLabel;

  /// No description provided for @requestsGraduationYearLabel.
  ///
  /// In tr, this message translates to:
  /// **'İstenen mezuniyet yılı'**
  String get requestsGraduationYearLabel;

  /// No description provided for @requestsTeacherOption.
  ///
  /// In tr, this message translates to:
  /// **'Öğretmen'**
  String get requestsTeacherOption;

  /// No description provided for @requestsDescriptionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get requestsDescriptionLabel;

  /// No description provided for @requestsPickFromGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden ekle'**
  String get requestsPickFromGallery;

  /// No description provided for @requestsUseCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get requestsUseCamera;

  /// No description provided for @requestsSendAction.
  ///
  /// In tr, this message translates to:
  /// **'Talebi gönder'**
  String get requestsSendAction;

  /// No description provided for @requestsListTitle.
  ///
  /// In tr, this message translates to:
  /// **'Taleplerim'**
  String get requestsListTitle;

  /// No description provided for @requestsNotificationApproved.
  ///
  /// In tr, this message translates to:
  /// **'Talep sonucu güncellendi. Onaylanan kayıt aşağıda vurgulandı.'**
  String get requestsNotificationApproved;

  /// No description provided for @requestsNotificationUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Talep sonucu güncellendi. İlgili kayıt aşağıda vurgulandı.'**
  String get requestsNotificationUpdated;

  /// No description provided for @requestsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz gönderilmiş talep yok.'**
  String get requestsEmpty;

  /// No description provided for @requestsAttachmentUploadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Ek dosya yüklenemedi.'**
  String get requestsAttachmentUploadFailed;

  /// No description provided for @requestsAttachmentUploaded.
  ///
  /// In tr, this message translates to:
  /// **'Ek dosya yüklendi.'**
  String get requestsAttachmentUploaded;

  /// No description provided for @requestsSelectCategoryError.
  ///
  /// In tr, this message translates to:
  /// **'Bir talep kategorisi seç.'**
  String get requestsSelectCategoryError;

  /// No description provided for @requestsSelectGraduationYearError.
  ///
  /// In tr, this message translates to:
  /// **'İstenen mezuniyet yılını seç.'**
  String get requestsSelectGraduationYearError;

  /// No description provided for @requestsSubmitSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Talep gönderildi.'**
  String get requestsSubmitSuccess;

  /// No description provided for @requestsSubmitFailed.
  ///
  /// In tr, this message translates to:
  /// **'Talep gönderilemedi.'**
  String get requestsSubmitFailed;

  /// No description provided for @requestsGraduationYearValue.
  ///
  /// In tr, this message translates to:
  /// **'İstenen mezuniyet yılı: {value}'**
  String requestsGraduationYearValue(Object value);

  /// No description provided for @requestsResolutionNote.
  ///
  /// In tr, this message translates to:
  /// **'Not: {note}'**
  String requestsResolutionNote(Object note);

  /// No description provided for @jobsTitle.
  ///
  /// In tr, this message translates to:
  /// **'İş ilanları'**
  String get jobsTitle;

  /// No description provided for @jobsCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni iş ilanı'**
  String get jobsCreateTitle;

  /// No description provided for @jobsCreateHelper.
  ///
  /// In tr, this message translates to:
  /// **'Üyelerin hızlı karar verebilmesi için ilanı kısa, net ve uygulanabilir tut.'**
  String get jobsCreateHelper;

  /// No description provided for @jobsCompanyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şirket'**
  String get jobsCompanyLabel;

  /// No description provided for @jobsPositionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Pozisyon'**
  String get jobsPositionLabel;

  /// No description provided for @jobsDescriptionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get jobsDescriptionLabel;

  /// No description provided for @jobsLocationLabel.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get jobsLocationLabel;

  /// No description provided for @jobsTypeLabel.
  ///
  /// In tr, this message translates to:
  /// **'İş tipi'**
  String get jobsTypeLabel;

  /// No description provided for @jobsLinkLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru linki'**
  String get jobsLinkLabel;

  /// No description provided for @jobsLinkHint.
  ///
  /// In tr, this message translates to:
  /// **'https://...'**
  String get jobsLinkHint;

  /// No description provided for @jobsCreateAction.
  ///
  /// In tr, this message translates to:
  /// **'İlanı yayınla'**
  String get jobsCreateAction;

  /// No description provided for @jobsCreateInProgress.
  ///
  /// In tr, this message translates to:
  /// **'Yayınlanıyor...'**
  String get jobsCreateInProgress;

  /// No description provided for @jobsSearchTitle.
  ///
  /// In tr, this message translates to:
  /// **'İlanları filtrele'**
  String get jobsSearchTitle;

  /// No description provided for @jobsSearchHelper.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut ilanları pozisyon, konum veya iş tipine göre daralt.'**
  String get jobsSearchHelper;

  /// No description provided for @jobsSearchLabel.
  ///
  /// In tr, this message translates to:
  /// **'Arama'**
  String get jobsSearchLabel;

  /// No description provided for @jobsLocationFilterLabel.
  ///
  /// In tr, this message translates to:
  /// **'Konum filtresi'**
  String get jobsLocationFilterLabel;

  /// No description provided for @jobsTypeFilterLabel.
  ///
  /// In tr, this message translates to:
  /// **'İş tipi filtresi'**
  String get jobsTypeFilterLabel;

  /// No description provided for @jobsApplyFiltersAction.
  ///
  /// In tr, this message translates to:
  /// **'Filtreleri uygula'**
  String get jobsApplyFiltersAction;

  /// No description provided for @jobsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz iş ilanı yok.'**
  String get jobsEmpty;

  /// No description provided for @jobsApplicationStatus.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru durumu: {status}'**
  String jobsApplicationStatus(Object status);

  /// No description provided for @jobsShortNoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kısa başvuru notu'**
  String get jobsShortNoteLabel;

  /// No description provided for @jobsApplyAction.
  ///
  /// In tr, this message translates to:
  /// **'Başvur'**
  String get jobsApplyAction;

  /// No description provided for @jobsLoadApplicationsAction.
  ///
  /// In tr, this message translates to:
  /// **'Başvuruları yükle'**
  String get jobsLoadApplicationsAction;

  /// No description provided for @jobsRefreshApplicationsAction.
  ///
  /// In tr, this message translates to:
  /// **'Başvuruları yenile'**
  String get jobsRefreshApplicationsAction;

  /// No description provided for @jobsReviewNoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Karar notu'**
  String get jobsReviewNoteLabel;

  /// No description provided for @jobsMarkReviewedAction.
  ///
  /// In tr, this message translates to:
  /// **'İncelemede'**
  String get jobsMarkReviewedAction;

  /// No description provided for @jobsAcceptAction.
  ///
  /// In tr, this message translates to:
  /// **'Kabul et'**
  String get jobsAcceptAction;

  /// No description provided for @jobsApplicationsStatus.
  ///
  /// In tr, this message translates to:
  /// **'Durum: {status}'**
  String jobsApplicationsStatus(Object status);

  /// No description provided for @jobsCreateSuccess.
  ///
  /// In tr, this message translates to:
  /// **'İş ilanı yayınlandı.'**
  String get jobsCreateSuccess;

  /// No description provided for @jobsCreateFailed.
  ///
  /// In tr, this message translates to:
  /// **'İlan oluşturulamadı.'**
  String get jobsCreateFailed;

  /// No description provided for @jobsApplySuccess.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru gönderildi.'**
  String get jobsApplySuccess;

  /// No description provided for @jobsApplyFailed.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru gönderilemedi.'**
  String get jobsApplyFailed;

  /// No description provided for @jobsDeleteSuccess.
  ///
  /// In tr, this message translates to:
  /// **'İlan silindi.'**
  String get jobsDeleteSuccess;

  /// No description provided for @jobsDeleteFailed.
  ///
  /// In tr, this message translates to:
  /// **'İlan silinemedi.'**
  String get jobsDeleteFailed;

  /// No description provided for @jobsReviewSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru güncellendi.'**
  String get jobsReviewSuccess;

  /// No description provided for @jobsReviewFailed.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru güncellenemedi.'**
  String get jobsReviewFailed;

  /// No description provided for @jobsPosterPendingApproval.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get jobsPosterPendingApproval;

  /// No description provided for @eventVisibilityTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılım görünürlüğü'**
  String get eventVisibilityTitle;

  /// No description provided for @eventVisibilityHelper.
  ///
  /// In tr, this message translates to:
  /// **'Bu ayarlar etkinliği gören üyelerin hangi katılım bilgilerine erişebileceğini belirler.'**
  String get eventVisibilityHelper;

  /// No description provided for @eventVisibilityShowCounts.
  ///
  /// In tr, this message translates to:
  /// **'Sayıları göster'**
  String get eventVisibilityShowCounts;

  /// No description provided for @eventVisibilityShowCountsHint.
  ///
  /// In tr, this message translates to:
  /// **'Katılan ve katılamayan kişi sayıları görünür olur.'**
  String get eventVisibilityShowCountsHint;

  /// No description provided for @eventVisibilityShowAttendees.
  ///
  /// In tr, this message translates to:
  /// **'Katılan isimlerini göster'**
  String get eventVisibilityShowAttendees;

  /// No description provided for @eventVisibilityShowAttendeesHint.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği görebilen herkes katılan listesini de görebilir.'**
  String get eventVisibilityShowAttendeesHint;

  /// No description provided for @eventVisibilityShowDecliners.
  ///
  /// In tr, this message translates to:
  /// **'Katılamayan isimlerini göster'**
  String get eventVisibilityShowDecliners;

  /// No description provided for @eventVisibilityShowDeclinersHint.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği görebilen herkes katılamayanları da görür.'**
  String get eventVisibilityShowDeclinersHint;

  /// No description provided for @eventVisibilitySaveAction.
  ///
  /// In tr, this message translates to:
  /// **'Görünürlük ayarlarını kaydet'**
  String get eventVisibilitySaveAction;

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
