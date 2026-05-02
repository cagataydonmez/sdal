// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OAuthProviderLink _$OAuthProviderLinkFromJson(Map<String, dynamic> json) =>
    _OAuthProviderLink(
      provider: readRequiredText(json['provider']),
      title: readRequiredText(json['title']),
      startUrl: readRequiredText(json['startUrl']),
      enabled: readRequiredBool(json['enabled']),
    );

Map<String, dynamic> _$OAuthProviderLinkToJson(_OAuthProviderLink instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'title': instance.title,
      'startUrl': instance.startUrl,
      'enabled': instance.enabled,
    };

_SessionUser _$SessionUserFromJson(Map<String, dynamic> json) => _SessionUser(
  id: readRequiredInt(json['id']),
  kadi: readRequiredText(json['kadi']),
  isim: readRequiredText(json['isim']),
  soyisim: readRequiredText(json['soyisim']),
  photo: readRequiredText(json['photo']),
  role: readRequiredText(json['role']),
  isAdmin: readRequiredBool(json['admin']),
  isVerified: readRequiredBool(json['verified']),
  isBanned: readRequiredBool(json['banned']),
  state: readRequiredText(json['state']),
  graduationYear: readOptionalText(json['graduationYear']),
  oauthProvider: readOptionalText(json['oauthProvider']),
);

Map<String, dynamic> _$SessionUserToJson(_SessionUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kadi': instance.kadi,
      'isim': instance.isim,
      'soyisim': instance.soyisim,
      'photo': instance.photo,
      'role': instance.role,
      'admin': instance.isAdmin,
      'verified': instance.isVerified,
      'banned': instance.isBanned,
      'state': instance.state,
      'graduationYear': instance.graduationYear,
      'oauthProvider': instance.oauthProvider,
    };

_SiteAccessSnapshot _$SiteAccessSnapshotFromJson(Map<String, dynamic> json) =>
    _SiteAccessSnapshot(
      siteOpen: readRequiredBool(json['siteOpen']),
      maintenanceMessage: readRequiredText(json['maintenanceMessage']),
      modules: const SiteModulesConverter().fromJson(
        json['modules'] as Map<String, dynamic>?,
      ),
      defaultLandingPage: readRequiredText(json['defaultLandingPage']),
    );

Map<String, dynamic> _$SiteAccessSnapshotToJson(_SiteAccessSnapshot instance) =>
    <String, dynamic>{
      'siteOpen': instance.siteOpen,
      'maintenanceMessage': instance.maintenanceMessage,
      'modules': const SiteModulesConverter().toJson(instance.modules),
      'defaultLandingPage': instance.defaultLandingPage,
    };
