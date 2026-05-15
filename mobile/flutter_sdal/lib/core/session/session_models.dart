import 'package:freezed_annotation/freezed_annotation.dart';
import '../config/app_config.dart';
import '../network/json_utils.dart';
import '../theme/sdal_app_theme.dart';

part 'session_models.freezed.dart';
part 'session_models.g.dart';

@freezed
abstract class OAuthProviderLink with _$OAuthProviderLink {
  const factory OAuthProviderLink({
    @JsonKey(fromJson: readRequiredText) required String provider,
    @JsonKey(fromJson: readRequiredText) required String title,
    @JsonKey(fromJson: readRequiredText) required String startUrl,
    @JsonKey(fromJson: readRequiredBool) required bool enabled,
  }) = _OAuthProviderLink;

  factory OAuthProviderLink.fromJson(Map<String, dynamic> json) =>
      _$OAuthProviderLinkFromJson(
        normalizeJsonAliases(json, {
          'title': ['provider'],
          'enabled': const [],
        }),
      );

  factory OAuthProviderLink.fromMap(JsonMap map) =>
      OAuthProviderLink.fromJson(map);
}

@freezed
abstract class SessionUser with _$SessionUser {
  const SessionUser._();

  const factory SessionUser({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredText) required String kadi,
    @JsonKey(fromJson: readRequiredText) required String isim,
    @JsonKey(fromJson: readRequiredText) required String soyisim,
    @JsonKey(fromJson: readRequiredText) required String photo,
    @JsonKey(fromJson: readRequiredText) required String role,
    @JsonKey(name: 'admin', fromJson: readRequiredBool) required bool isAdmin,
    @JsonKey(name: 'verified', fromJson: readRequiredBool)
    required bool isVerified,
    @JsonKey(name: 'banned', fromJson: readRequiredBool) required bool isBanned,
    @JsonKey(fromJson: readRequiredText) required String state,
    @JsonKey(fromJson: readOptionalText) String? graduationYear,
    @JsonKey(fromJson: readOptionalText) String? oauthProvider,
  }) = _SessionUser;

  bool get isModerator => role.trim().toLowerCase() == 'mod';

  bool get isRootAdmin =>
      kadi.trim().toLowerCase() == 'cagatay' &&
      role.trim().toLowerCase() == 'root';

  bool get hasAdminAccess {
    final normalizedRole = role.trim().toLowerCase();
    return isAdmin || normalizedRole == 'admin' || normalizedRole == 'root';
  }

  String get displayName {
    final fullName = '${isim.trim()} ${soyisim.trim()}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (kadi.isNotEmpty) return '@$kadi';
    return 'SDAL Üyesi';
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) =>
      _$SessionUserFromJson(
        normalizeJsonAliases(json, {
          'photo': ['resim'],
          'banned': ['yasak'],
          'graduationYear': ['mezuniyetyili'],
          'oauthProvider': ['oauth_provider'],
        }),
      );

  factory SessionUser.fromMap(JsonMap map) => SessionUser.fromJson(map);
}

@freezed
abstract class SiteAccessSnapshot with _$SiteAccessSnapshot {
  const SiteAccessSnapshot._();

  const factory SiteAccessSnapshot({
    @JsonKey(fromJson: readRequiredBool) required bool siteOpen,
    @JsonKey(fromJson: readRequiredText) required String maintenanceMessage,
    @SiteModulesConverter() required Map<String, bool> modules,
    @JsonKey(fromJson: readRequiredText) required String defaultLandingPage,
    @JsonKey(fromJson: _themeFromJson) @Default(SdalAppTheme.kor) SdalAppTheme activeTheme,
  }) = _SiteAccessSnapshot;

  bool isModuleOpen(String key) => modules[key] ?? true;

  factory SiteAccessSnapshot.fromJson(Map<String, dynamic> json) =>
      _$SiteAccessSnapshotFromJson(
        normalizeJsonAliases(json, {
          'maintenanceMessage': ['message'],
          'defaultLandingPage': const [],
        }),
      );

  factory SiteAccessSnapshot.fromMap(JsonMap map) =>
      SiteAccessSnapshot.fromJson(map);
}

SdalAppTheme _themeFromJson(dynamic value) =>
    SdalAppTheme.fromString(value?.toString());

class SiteModulesConverter
    implements JsonConverter<Map<String, bool>, Map<String, dynamic>?> {
  const SiteModulesConverter();

  @override
  Map<String, bool> fromJson(Map<String, dynamic>? json) {
    if (json == null) return const <String, bool>{};
    return asJsonMap(
      json,
    ).map((key, value) => MapEntry(key, asBool(value) ?? true));
  }

  @override
  Map<String, dynamic> toJson(Map<String, bool> object) =>
      Map<String, dynamic>.from(object);
}

class SessionSnapshot {
  const SessionSnapshot({
    required this.config,
    required this.siteAccess,
    required this.user,
    this.menuVisibility = const <String, bool>{},
    this.moduleMenuOrder = const <String>[],
  });

  final AppConfig config;
  final SiteAccessSnapshot siteAccess;
  final SessionUser? user;
  final Map<String, bool> menuVisibility;
  final List<String> moduleMenuOrder;

  bool get isAuthenticated => user != null;
  bool get isBanned => user?.isBanned ?? false;
  bool get hasAdminAccess => user?.hasAdminAccess ?? false;
  bool get isModerator => user?.isModerator ?? false;
  bool get requiresProfileCompletion => user?.state == 'incomplete';
  bool get requiresPhoneVerification =>
      user?.state == 'phone_verification_required';
  bool get requiresVerification =>
      isAuthenticated && !(user?.isVerified ?? false);
  bool get requiresInitialGraduationClaim {
    if (!isAuthenticated) return false;
    final value = (user?.graduationYear ?? '').trim().toLowerCase();
    if (value == '9999' ||
        value == 'teacher' ||
        value == 'ogretmen' ||
        value == 'öğretmen') {
      return false;
    }
    final year = int.tryParse(value);
    final currentYear = DateTime.now().year;
    return year == null || year < 1999 || year > currentYear;
  }

  bool isModuleOpen(String moduleKey) => siteAccess.isModuleOpen(moduleKey);

  bool isModuleVisible(String moduleKey) =>
      (menuVisibility[moduleKey] ?? true) && isModuleOpen(moduleKey);

  String get managementEntryPath {
    if (hasAdminAccess) return '/admin';
    if (isModerator) return '/moderation';
    return defaultHomePath;
  }

  String get defaultHomePath {
    if (requiresPhoneVerification) return '/phone-verification';
    if (requiresInitialGraduationClaim) return '/profile/onboarding';
    final webPath = siteAccess.defaultLandingPage;
    if (webPath.startsWith('/new/explore')) return '/explore';
    if (webPath.startsWith('/new/opportunities')) return '/explore';
    if (webPath.startsWith('/new/notifications')) return '/notifications';
    if (webPath.startsWith('/new/profile')) return '/profile';
    if (webPath.startsWith('/new/following')) return '/following';
    if (webPath.startsWith('/new/requests')) return '/requests';
    if (webPath.startsWith('/new/messages') ||
        webPath.startsWith('/new/messenger')) {
      return '/messenger';
    }
    return '/feed';
  }
}
