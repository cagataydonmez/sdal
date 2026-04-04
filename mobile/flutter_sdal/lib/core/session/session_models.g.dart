// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OAuthProviderLinkImpl _$$OAuthProviderLinkImplFromJson(
  Map<String, dynamic> json,
) => _$OAuthProviderLinkImpl(
  provider: readRequiredText(json['provider']),
  title: readRequiredText(json['title']),
  startUrl: readRequiredText(json['startUrl']),
  enabled: readRequiredBool(json['enabled']),
);

Map<String, dynamic> _$$OAuthProviderLinkImplToJson(
  _$OAuthProviderLinkImpl instance,
) => <String, dynamic>{
  'provider': instance.provider,
  'title': instance.title,
  'startUrl': instance.startUrl,
  'enabled': instance.enabled,
};

_$SessionUserImpl _$$SessionUserImplFromJson(Map<String, dynamic> json) =>
    _$SessionUserImpl(
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

Map<String, dynamic> _$$SessionUserImplToJson(_$SessionUserImpl instance) =>
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

_$SiteAccessSnapshotImpl _$$SiteAccessSnapshotImplFromJson(
  Map<String, dynamic> json,
) => _$SiteAccessSnapshotImpl(
  siteOpen: readRequiredBool(json['siteOpen']),
  maintenanceMessage: readRequiredText(json['maintenanceMessage']),
  modules: const SiteModulesConverter().fromJson(
    json['modules'] as Map<String, dynamic>?,
  ),
  defaultLandingPage: readRequiredText(json['defaultLandingPage']),
);

Map<String, dynamic> _$$SiteAccessSnapshotImplToJson(
  _$SiteAccessSnapshotImpl instance,
) => <String, dynamic>{
  'siteOpen': instance.siteOpen,
  'maintenanceMessage': instance.maintenanceMessage,
  'modules': const SiteModulesConverter().toJson(instance.modules),
  'defaultLandingPage': instance.defaultLandingPage,
};
