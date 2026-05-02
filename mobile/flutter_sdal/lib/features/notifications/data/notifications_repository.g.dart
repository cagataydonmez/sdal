// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationTarget _$NotificationTargetFromJson(Map<String, dynamic> json) =>
    _NotificationTarget(
      route: readRequiredText(json['route']),
      href: readRequiredText(json['href']),
      label: readRequiredText(json['label']),
    );

Map<String, dynamic> _$NotificationTargetToJson(_NotificationTarget instance) =>
    <String, dynamic>{
      'route': instance.route,
      'href': instance.href,
      'label': instance.label,
    };

_NotificationActionItem _$NotificationActionItemFromJson(
  Map<String, dynamic> json,
) => _NotificationActionItem(
  kind: readRequiredText(json['kind']),
  label: _readActionLabel(json['label']),
  endpoint: readRequiredText(json['endpoint']),
  method: _readActionMethod(json['method']),
);

Map<String, dynamic> _$NotificationActionItemToJson(
  _NotificationActionItem instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'label': instance.label,
  'endpoint': instance.endpoint,
  'method': instance.method,
};

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: readRequiredInt(json['id']),
      type: readRequiredText(json['type']),
      message: readRequiredText(json['message']),
      createdAt: readRequiredText(json['createdAt']),
      readAt: readRequiredText(json['readAt']),
      category: readRequiredText(json['category']),
      priority: readRequiredText(json['priority']),
      target: json['target'] == null
          ? null
          : NotificationTarget.fromJson(json['target'] as Map<String, dynamic>),
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    NotificationActionItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <NotificationActionItem>[],
      sourceName: readRequiredText(json['sourceName']),
      sourcePhoto: readRequiredText(json['sourcePhoto']),
      sourceInitials: readRequiredText(json['sourceInitials']),
      imageUrl: readRequiredText(json['imageUrl']),
      imageShape: readRequiredText(json['imageShape']),
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'message': instance.message,
      'createdAt': instance.createdAt,
      'readAt': instance.readAt,
      'category': instance.category,
      'priority': instance.priority,
      'target': instance.target,
      'actions': instance.actions,
      'sourceName': instance.sourceName,
      'sourcePhoto': instance.sourcePhoto,
      'sourceInitials': instance.sourceInitials,
      'imageUrl': instance.imageUrl,
      'imageShape': instance.imageShape,
    };

_NotificationPreferences _$NotificationPreferencesFromJson(
  Map<String, dynamic> json,
) => _NotificationPreferences(
  categories: const NotificationCategoryConverter().fromJson(
    json['categories'] as Map<String, dynamic>?,
  ),
  quietModeEnabled: readRequiredBool(json['quietModeEnabled']),
  quietModeStart: readRequiredText(json['quietModeStart']),
  quietModeEnd: readRequiredText(json['quietModeEnd']),
);

Map<String, dynamic> _$NotificationPreferencesToJson(
  _NotificationPreferences instance,
) => <String, dynamic>{
  'categories': const NotificationCategoryConverter().toJson(
    instance.categories,
  ),
  'quietModeEnabled': instance.quietModeEnabled,
  'quietModeStart': instance.quietModeStart,
  'quietModeEnd': instance.quietModeEnd,
};
