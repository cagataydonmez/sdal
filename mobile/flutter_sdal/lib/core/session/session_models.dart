import '../config/app_config.dart';
import '../network/json_utils.dart';

class OAuthProviderLink {
  const OAuthProviderLink({
    required this.provider,
    required this.title,
    required this.startUrl,
    required this.enabled,
  });

  final String provider;
  final String title;
  final String startUrl;
  final bool enabled;

  factory OAuthProviderLink.fromMap(JsonMap map) {
    return OAuthProviderLink(
      provider: coalesceText([map['provider']], fallback: ''),
      title: coalesceText([map['title'], map['provider']], fallback: ''),
      startUrl: coalesceText([map['startUrl']], fallback: ''),
      enabled: asBool(map['enabled']) ?? true,
    );
  }
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.kadi,
    required this.isim,
    required this.soyisim,
    required this.photo,
    required this.role,
    required this.isAdmin,
    required this.isVerified,
    required this.isBanned,
    required this.state,
    this.graduationYear,
    this.oauthProvider,
  });

  final int id;
  final String kadi;
  final String isim;
  final String soyisim;
  final String photo;
  final String role;
  final bool isAdmin;
  final bool isVerified;
  final bool isBanned;
  final String state;
  final String? graduationYear;
  final String? oauthProvider;

  String get displayName {
    final fullName = '${isim.trim()} ${soyisim.trim()}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (kadi.isNotEmpty) return '@$kadi';
    return 'SDAL Üyesi';
  }

  factory SessionUser.fromMap(JsonMap map) {
    return SessionUser(
      id: asInt(map['id']) ?? 0,
      kadi: coalesceText([map['kadi']], fallback: ''),
      isim: coalesceText([map['isim']], fallback: ''),
      soyisim: coalesceText([map['soyisim']], fallback: ''),
      photo: coalesceText([map['photo'], map['resim']], fallback: ''),
      role: coalesceText([map['role']], fallback: 'user'),
      isAdmin: asBool(map['admin']) ?? false,
      isVerified: asBool(map['verified']) ?? false,
      isBanned: asBool(map['banned']) ?? asBool(map['yasak']) ?? false,
      state: coalesceText([map['state']], fallback: 'active'),
      graduationYear: asString(map['mezuniyetyili']),
      oauthProvider: asString(map['oauth_provider']),
    );
  }
}

class SiteAccessSnapshot {
  const SiteAccessSnapshot({
    required this.siteOpen,
    required this.maintenanceMessage,
    required this.modules,
    required this.defaultLandingPage,
  });

  final bool siteOpen;
  final String maintenanceMessage;
  final Map<String, bool> modules;
  final String defaultLandingPage;

  bool isModuleOpen(String key) => modules[key] ?? true;

  factory SiteAccessSnapshot.fromMap(JsonMap map) {
    final modulesRaw = asJsonMap(map['modules']);
    return SiteAccessSnapshot(
      siteOpen: asBool(map['siteOpen']) ?? true,
      maintenanceMessage: coalesceText([
        map['maintenanceMessage'],
        map['message'],
      ], fallback: ''),
      modules: modulesRaw.map(
        (key, value) => MapEntry(key, asBool(value) ?? true),
      ),
      defaultLandingPage: coalesceText([
        map['defaultLandingPage'],
      ], fallback: '/new'),
    );
  }
}

class SessionSnapshot {
  const SessionSnapshot({
    required this.config,
    required this.siteAccess,
    required this.user,
  });

  final AppConfig config;
  final SiteAccessSnapshot siteAccess;
  final SessionUser? user;

  bool get isAuthenticated => user != null;
  bool get isBanned => user?.isBanned ?? false;
  bool get requiresProfileCompletion => user?.state == 'incomplete';
  bool get requiresVerification =>
      isAuthenticated && !(user?.isVerified ?? false);

  bool isModuleOpen(String moduleKey) => siteAccess.isModuleOpen(moduleKey);

  String get defaultHomePath {
    final webPath = siteAccess.defaultLandingPage;
    if (webPath.startsWith('/new/explore')) return '/explore';
    if (webPath.startsWith('/new/notifications')) return '/notifications';
    if (webPath.startsWith('/new/profile')) return '/profile';
    if (webPath.startsWith('/new/messages') ||
        webPath.startsWith('/new/messenger')) {
      return '/inbox';
    }
    return '/feed';
  }
}
