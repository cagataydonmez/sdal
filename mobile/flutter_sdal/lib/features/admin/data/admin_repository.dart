import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_utils.dart';

class AdminSummarySnapshot {
  const AdminSummarySnapshot({
    required this.counts,
    required this.recentUsers,
    required this.recentPosts,
  });

  final Map<String, int> counts;
  final List<AdminActivityItem> recentUsers;
  final List<AdminActivityItem> recentPosts;

  factory AdminSummarySnapshot.fromMap(JsonMap map) {
    final rawCounts = asJsonMap(map['counts']);
    return AdminSummarySnapshot(
      counts: rawCounts.map((key, value) => MapEntry(key, asInt(value) ?? 0)),
      recentUsers: asJsonMapList(
        map['recentUsers'],
      ).map(AdminActivityItem.fromMap).toList(growable: false),
      recentPosts: asJsonMapList(
        map['recentPosts'],
      ).map(AdminActivityItem.fromMap).toList(growable: false),
    );
  }
}

class AdminLiveSnapshot {
  const AdminLiveSnapshot({required this.counts, required this.activity});

  final Map<String, int> counts;
  final List<AdminActivityItem> activity;

  factory AdminLiveSnapshot.fromMap(JsonMap map) {
    final rawCounts = asJsonMap(map['counts']);
    return AdminLiveSnapshot(
      counts: rawCounts.map((key, value) => MapEntry(key, asInt(value) ?? 0)),
      activity: asJsonMapList(
        map['activity'],
      ).map(AdminActivityItem.fromMap).toList(growable: false),
    );
  }
}

class AdminSecuritySnapshot {
  const AdminSecuritySnapshot({
    required this.totalRejections,
    required this.activeHelmetHeaders,
  });

  final int totalRejections;
  final int activeHelmetHeaders;

  factory AdminSecuritySnapshot.fromMap(JsonMap map) {
    final helmetHeaders = asJsonMapList(asJsonMap(map['helmet'])['headers']);
    return AdminSecuritySnapshot(
      totalRejections:
          asInt(asJsonMap(map['validation'])['totalRejections']) ?? 0,
      activeHelmetHeaders: helmetHeaders
          .where((row) => asBool(row['active']) ?? false)
          .length,
    );
  }
}

class AdminAuthSecuritySnapshot {
  const AdminAuthSecuritySnapshot({
    required this.counts,
    required this.verifiedPhones,
    required this.trustedDevices,
    required this.phoneAttempts,
    required this.auditLogs,
    required this.emailChallenges,
  });

  final Map<String, int> counts;
  final List<AdminVerifiedPhoneItem> verifiedPhones;
  final List<AdminTrustedDeviceItem> trustedDevices;
  final List<AdminPhoneAttemptItem> phoneAttempts;
  final List<AdminAuthAuditItem> auditLogs;
  final List<AdminEmailChallengeItem> emailChallenges;

  factory AdminAuthSecuritySnapshot.fromMap(JsonMap map) {
    final rawCounts = asJsonMap(map['counts']);
    return AdminAuthSecuritySnapshot(
      counts: rawCounts.map((key, value) => MapEntry(key, asInt(value) ?? 0)),
      verifiedPhones: asJsonMapList(
        map['verifiedPhones'],
      ).map(AdminVerifiedPhoneItem.fromMap).toList(growable: false),
      trustedDevices: asJsonMapList(
        map['trustedDevices'],
      ).map(AdminTrustedDeviceItem.fromMap).toList(growable: false),
      phoneAttempts: asJsonMapList(
        map['phoneAttempts'],
      ).map(AdminPhoneAttemptItem.fromMap).toList(growable: false),
      auditLogs: asJsonMapList(
        map['auditLogs'],
      ).map(AdminAuthAuditItem.fromMap).toList(growable: false),
      emailChallenges: asJsonMapList(
        map['emailChallenges'],
      ).map(AdminEmailChallengeItem.fromMap).toList(growable: false),
    );
  }
}

class AdminAuthSettingsSnapshot {
  const AdminAuthSettingsSnapshot({
    required this.smsVerificationEnabled,
    required this.updatedAt,
  });

  final bool smsVerificationEnabled;
  final String updatedAt;

  factory AdminAuthSettingsSnapshot.fromMap(JsonMap map) {
    final settings = asJsonMap(map['settings']);
    return AdminAuthSettingsSnapshot(
      smsVerificationEnabled:
          asBool(settings['smsVerificationEnabled']) ?? false,
      updatedAt: coalesceText([settings['updatedAt']], fallback: ''),
    );
  }
}

class AdminVerifiedPhoneItem {
  const AdminVerifiedPhoneItem({
    required this.userId,
    required this.handle,
    required this.name,
    required this.phoneHashPreview,
    required this.verifiedAt,
    required this.updatedAt,
    required this.verificationRequired,
    required this.manualReviewRequired,
    required this.suspiciousReason,
  });

  final int userId;
  final String handle;
  final String name;
  final String phoneHashPreview;
  final String verifiedAt;
  final String updatedAt;
  final bool verificationRequired;
  final bool manualReviewRequired;
  final String suspiciousReason;

  String get displayName => _adminAuthDisplayName(handle, name, userId);

  factory AdminVerifiedPhoneItem.fromMap(JsonMap map) {
    return AdminVerifiedPhoneItem(
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      name: _adminAuthFullName(map),
      phoneHashPreview: coalesceText([
        map['phone_number_hash_preview'],
      ], fallback: ''),
      verifiedAt: coalesceText([map['phone_verified_at']], fallback: ''),
      updatedAt: coalesceText([map['updated_at']], fallback: ''),
      verificationRequired: asBool(map['phone_verification_required']) ?? false,
      manualReviewRequired: asBool(map['manual_review_required']) ?? false,
      suspiciousReason: coalesceText([map['suspicious_reason']], fallback: ''),
    );
  }
}

class AdminTrustedDeviceItem {
  const AdminTrustedDeviceItem({
    required this.id,
    required this.userId,
    required this.handle,
    required this.name,
    required this.deviceHashPreview,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.createdAt,
    required this.lastSeenAt,
    required this.trustedAt,
    required this.revokedAt,
    required this.ipHashPreview,
    required this.userAgent,
  });

  final int id;
  final int userId;
  final String handle;
  final String name;
  final String deviceHashPreview;
  final String deviceName;
  final String platform;
  final String appVersion;
  final String createdAt;
  final String lastSeenAt;
  final String trustedAt;
  final String revokedAt;
  final String ipHashPreview;
  final String userAgent;

  bool get revoked => revokedAt.trim().isNotEmpty;
  String get displayName => _adminAuthDisplayName(handle, name, userId);

  factory AdminTrustedDeviceItem.fromMap(JsonMap map) {
    return AdminTrustedDeviceItem(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      name: _adminAuthFullName(map),
      deviceHashPreview: coalesceText([
        map['device_id_hash_preview'],
      ], fallback: ''),
      deviceName: coalesceText([
        map['device_name'],
      ], fallback: 'Bilinmeyen cihaz'),
      platform: coalesceText([map['platform']], fallback: ''),
      appVersion: coalesceText([map['app_version']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      lastSeenAt: coalesceText([map['last_seen_at']], fallback: ''),
      trustedAt: coalesceText([map['trusted_at']], fallback: ''),
      revokedAt: coalesceText([map['revoked_at']], fallback: ''),
      ipHashPreview: coalesceText([
        map['ip_created_hash_preview'],
      ], fallback: ''),
      userAgent: coalesceText([map['user_agent']], fallback: ''),
    );
  }
}

class AdminPhoneAttemptItem {
  const AdminPhoneAttemptItem({
    required this.id,
    required this.userId,
    required this.handle,
    required this.name,
    required this.phoneHashPreview,
    required this.ipHashPreview,
    required this.deviceHashPreview,
    required this.status,
    required this.reason,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String handle;
  final String name;
  final String phoneHashPreview;
  final String ipHashPreview;
  final String deviceHashPreview;
  final String status;
  final String reason;
  final String createdAt;

  String get displayName => _adminAuthDisplayName(handle, name, userId);

  factory AdminPhoneAttemptItem.fromMap(JsonMap map) {
    return AdminPhoneAttemptItem(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      name: _adminAuthFullName(map),
      phoneHashPreview: coalesceText([
        map['phone_number_hash_preview'],
      ], fallback: ''),
      ipHashPreview: coalesceText([map['ip_hash_preview']], fallback: ''),
      deviceHashPreview: coalesceText([
        map['device_id_hash_preview'],
      ], fallback: ''),
      status: coalesceText([map['status']], fallback: ''),
      reason: coalesceText([map['reason']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
    );
  }
}

class AdminAuthAuditItem {
  const AdminAuthAuditItem({
    required this.id,
    required this.userId,
    required this.handle,
    required this.name,
    required this.eventType,
    required this.riskLevel,
    required this.phoneHashPreview,
    required this.emailHashPreview,
    required this.deviceHashPreview,
    required this.ipHashPreview,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String handle;
  final String name;
  final String eventType;
  final String riskLevel;
  final String phoneHashPreview;
  final String emailHashPreview;
  final String deviceHashPreview;
  final String ipHashPreview;
  final String createdAt;

  String get displayName => _adminAuthDisplayName(handle, name, userId);

  factory AdminAuthAuditItem.fromMap(JsonMap map) {
    return AdminAuthAuditItem(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      name: _adminAuthFullName(map),
      eventType: coalesceText([map['event_type']], fallback: ''),
      riskLevel: coalesceText([map['risk_level']], fallback: 'info'),
      phoneHashPreview: coalesceText([
        map['phone_number_hash_preview'],
      ], fallback: ''),
      emailHashPreview: coalesceText([map['email_hash_preview']], fallback: ''),
      deviceHashPreview: coalesceText([
        map['device_id_hash_preview'],
      ], fallback: ''),
      ipHashPreview: coalesceText([map['ip_hash_preview']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
    );
  }
}

class AdminEmailChallengeItem {
  const AdminEmailChallengeItem({
    required this.id,
    required this.userId,
    required this.handle,
    required this.name,
    required this.deviceHashPreview,
    required this.expiresAt,
    required this.consumedAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String handle;
  final String name;
  final String deviceHashPreview;
  final String expiresAt;
  final String consumedAt;
  final String createdAt;

  bool get consumed => consumedAt.trim().isNotEmpty;
  String get displayName => _adminAuthDisplayName(handle, name, userId);

  factory AdminEmailChallengeItem.fromMap(JsonMap map) {
    return AdminEmailChallengeItem(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      name: _adminAuthFullName(map),
      deviceHashPreview: coalesceText([
        map['device_id_hash_preview'],
      ], fallback: ''),
      expiresAt: coalesceText([map['expires_at']], fallback: ''),
      consumedAt: coalesceText([map['consumed_at']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
    );
  }
}

String _adminAuthFullName(JsonMap map) {
  final firstName = coalesceText([map['isim']], fallback: '');
  final lastName = coalesceText([map['soyisim']], fallback: '');
  return '$firstName $lastName'.trim();
}

String _adminAuthDisplayName(String handle, String name, int userId) {
  if (handle.trim().isNotEmpty) return '@$handle';
  if (name.trim().isNotEmpty) return name;
  return userId > 0 ? 'Üye #$userId' : 'Anonim';
}

class AdminShellUser {
  const AdminShellUser({
    required this.id,
    required this.handle,
    required this.name,
    required this.role,
    required this.isAdmin,
  });

  final int id;
  final String handle;
  final String name;
  final String role;
  final bool isAdmin;

  bool get hasAdminAccess {
    final normalizedRole = role.trim().toLowerCase();
    return isAdmin || normalizedRole == 'admin' || normalizedRole == 'root';
  }

  factory AdminShellUser.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    final handle = coalesceText([map['kadi']], fallback: '');
    return AdminShellUser(
      id: asInt(map['id']) ?? 0,
      handle: handle,
      name: fullName.isNotEmpty
          ? fullName
          : handle.isNotEmpty
          ? '@$handle'
          : 'Admin kullanici',
      role: coalesceText([map['role']], fallback: 'user'),
      isAdmin:
          (asBool(map['admin']) ?? false) ||
          const {'admin', 'root'}.contains(
            coalesceText([map['role']], fallback: 'user').trim().toLowerCase(),
          ),
    );
  }
}

class AdminRootStatusSnapshot {
  const AdminRootStatusSnapshot({
    required this.hasRoot,
    required this.rootHandle,
    required this.bootstrapPasswordConfigured,
  });

  final bool hasRoot;
  final String rootHandle;
  final bool bootstrapPasswordConfigured;

  factory AdminRootStatusSnapshot.fromMap(JsonMap map) {
    final rootUser = asJsonMap(map['rootUser']);
    return AdminRootStatusSnapshot(
      hasRoot: asBool(map['hasRoot']) ?? false,
      rootHandle: coalesceText([rootUser['kadi']], fallback: ''),
      bootstrapPasswordConfigured:
          asBool(map['bootstrapPasswordConfigured']) ?? false,
    );
  }
}

class AdminPermissionSnapshot {
  const AdminPermissionSnapshot({
    required this.role,
    required this.isSuperModerator,
    required this.permissionKeys,
    required this.scopedGraduationYears,
  });

  final String role;
  final bool isSuperModerator;
  final List<String> permissionKeys;
  final List<String> scopedGraduationYears;

  factory AdminPermissionSnapshot.fromMap(JsonMap map) {
    return AdminPermissionSnapshot(
      role: coalesceText([map['role']], fallback: 'user'),
      isSuperModerator: asBool(map['isSuperModerator']) ?? false,
      permissionKeys:
          (map['permissionKeys'] is List
                  ? map['permissionKeys'] as List
                  : const <dynamic>[])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      scopedGraduationYears:
          (map['scopedGraduationYears'] is List
                  ? map['scopedGraduationYears'] as List
                  : const <dynamic>[])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
    );
  }
}

class AdminAccessSnapshot {
  const AdminAccessSnapshot({
    required this.user,
    required this.adminOk,
    required this.permissions,
    required this.rootStatus,
  });

  final AdminShellUser? user;
  final bool adminOk;
  final AdminPermissionSnapshot? permissions;
  final AdminRootStatusSnapshot? rootStatus;

  bool get canOpenAdminShell =>
      user != null &&
      (user!.hasAdminAccess ||
          adminOk ||
          user!.role.trim().toLowerCase() == 'mod');
}

class AdminUserListQuery {
  const AdminUserListQuery({
    this.query = '',
    this.filter = 'all',
    this.verifiedOnly = false,
    this.adminOnly = false,
    this.withPhotoOnly = false,
    this.page = 1,
    this.limit = 20,
  });

  final String query;
  final String filter;
  final bool verifiedOnly;
  final bool adminOnly;
  final bool withPhotoOnly;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is AdminUserListQuery &&
        other.query == query &&
        other.filter == filter &&
        other.verifiedOnly == verifiedOnly &&
        other.adminOnly == adminOnly &&
        other.withPhotoOnly == withPhotoOnly &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    query,
    filter,
    verifiedOnly,
    adminOnly,
    withPhotoOnly,
    page,
    limit,
  );
}

class AdminRequestNotificationItem {
  const AdminRequestNotificationItem({
    required this.categoryKey,
    required this.label,
    required this.pendingCount,
  });

  final String categoryKey;
  final String label;
  final int pendingCount;

  factory AdminRequestNotificationItem.fromMap(JsonMap map) {
    return AdminRequestNotificationItem(
      categoryKey: coalesceText([map['category_key']], fallback: ''),
      label: coalesceText([map['label'], map['category_key']], fallback: ''),
      pendingCount: asInt(map['pending_count']) ?? 0,
    );
  }
}

class AdminNotificationOpsSnapshot {
  const AdminNotificationOpsSnapshot({
    required this.deliverySummary,
    required this.alerts,
  });

  final Map<String, int> deliverySummary;
  final List<String> alerts;

  factory AdminNotificationOpsSnapshot.fromMap(JsonMap map) {
    final rawSummary = asJsonMap(map['delivery_summary']);
    return AdminNotificationOpsSnapshot(
      deliverySummary: rawSummary.map(
        (key, value) => MapEntry(key, asInt(value) ?? 0),
      ),
      alerts: asJsonMapList(map['alerts'])
          .map(
            (row) => coalesceText([row['message'], row['code']], fallback: ''),
          )
          .where((text) => text.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

class AdminPushSettingsSnapshot {
  const AdminPushSettingsSnapshot({
    required this.enabled,
    required this.firebaseConfigured,
    required this.mockMode,
    required this.registeredDevices,
    required this.registeredUsers,
    required this.platforms,
    required this.deliverySummary,
    required this.recentDeliveries,
  });

  final bool enabled;
  final bool firebaseConfigured;
  final bool mockMode;
  final int registeredDevices;
  final int registeredUsers;
  final List<AdminPushPlatformCount> platforms;
  final Map<String, int> deliverySummary;
  final List<AdminPushDeliveryItem> recentDeliveries;

  factory AdminPushSettingsSnapshot.fromMap(JsonMap map) {
    final rawSummary = asJsonMap(map['delivery_summary']);
    return AdminPushSettingsSnapshot(
      enabled: asBool(map['enabled']) ?? false,
      firebaseConfigured: asBool(map['firebase_configured']) ?? false,
      mockMode: asBool(map['mock_mode']) ?? false,
      registeredDevices: asInt(map['registered_devices']) ?? 0,
      registeredUsers: asInt(map['registered_users']) ?? 0,
      platforms: asJsonMapList(
        map['platforms'],
      ).map(AdminPushPlatformCount.fromMap).toList(growable: false),
      deliverySummary: rawSummary.map(
        (key, value) => MapEntry(key, asInt(value) ?? 0),
      ),
      recentDeliveries: asJsonMapList(
        map['recent_deliveries'],
      ).map(AdminPushDeliveryItem.fromMap).toList(growable: false),
    );
  }
}

class AdminPushPlatformCount {
  const AdminPushPlatformCount({required this.platform, required this.count});

  final String platform;
  final int count;

  factory AdminPushPlatformCount.fromMap(JsonMap map) {
    return AdminPushPlatformCount(
      platform: coalesceText([map['platform']], fallback: ''),
      count: asInt(map['count']) ?? 0,
    );
  }
}

class AdminPushDeliveryItem {
  const AdminPushDeliveryItem({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.deviceId,
    required this.notificationType,
    required this.platform,
    required this.deliveryStatus,
    required this.recipientStatus,
    required this.skipReason,
    required this.errorMessage,
    required this.userName,
    required this.userHandle,
    required this.createdAt,
    required this.recipientCreatedAt,
  });

  final int id;
  final int notificationId;
  final int userId;
  final int deviceId;
  final String notificationType;
  final String platform;
  final String deliveryStatus;
  final String recipientStatus;
  final String skipReason;
  final String errorMessage;
  final String userName;
  final String userHandle;
  final String createdAt;
  final String recipientCreatedAt;

  String get statusLabel {
    switch (deliveryStatus) {
      case 'sent':
        return 'İletildi';
      case 'failed':
        return 'Başarısız';
      case 'skipped':
        return _skipLabel;
      case 'inserted':
        return 'Uygulama içi eklendi';
      default:
        return deliveryStatus;
    }
  }

  String get _skipLabel {
    switch (skipReason) {
      case 'no_registered_device':
        return 'Cihaz kaydı yok';
      case 'push_disabled':
        return 'Push kapalı';
      case 'preference_disabled':
        return 'Kullanıcı tercihi kapalı';
      case 'firebase_not_configured':
        return 'Firebase yapılandırılmamış';
      default:
        return skipReason.isNotEmpty ? skipReason : 'Atlandı';
    }
  }

  String get platformLabel {
    switch (platform) {
      case 'ios':
        return 'iOS';
      case 'android':
        return 'Android';
      default:
        return platform.isEmpty ? 'Bilinmiyor' : platform;
    }
  }

  String get deviceLabel {
    if (id <= 0) return 'Push kaydı yok';
    if (deviceId <= 0) return 'Cihaz yok';
    return '$platformLabel #$deviceId';
  }

  factory AdminPushDeliveryItem.fromMap(JsonMap map) {
    return AdminPushDeliveryItem(
      id: asInt(map['id']) ?? asInt(map['delivery_id']) ?? 0,
      notificationId: asInt(map['notification_id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      deviceId: asInt(map['device_id']) ?? 0,
      notificationType: coalesceText([map['notification_type']], fallback: ''),
      platform: coalesceText([map['platform']], fallback: ''),
      deliveryStatus: coalesceText([
        map['delivery_status'],
        map['recipient_status'],
      ], fallback: ''),
      recipientStatus: coalesceText([map['recipient_status']], fallback: ''),
      skipReason: coalesceText([map['skip_reason']], fallback: ''),
      errorMessage: coalesceText([map['error_message']], fallback: ''),
      userName: coalesceText([map['user_name']], fallback: ''),
      userHandle: coalesceText([map['user_handle']], fallback: ''),
      createdAt: coalesceText([
        map['created_at'],
        map['delivery_created_at'],
      ], fallback: ''),
      recipientCreatedAt: coalesceText([
        map['recipient_created_at'],
      ], fallback: ''),
    );
  }
}

class AdminBroadcastResult {
  const AdminBroadcastResult({
    required this.id,
    required this.target,
    required this.requested,
    required this.inserted,
    required this.skipped,
    required this.imageUrl,
    required this.imageShape,
    required this.targetRoute,
    required this.targetLabel,
  });

  final int id;
  final String target;
  final int requested;
  final int inserted;
  final int skipped;
  final String imageUrl;
  final String imageShape;
  final String targetRoute;
  final String targetLabel;

  factory AdminBroadcastResult.fromMap(JsonMap map) {
    return AdminBroadcastResult(
      id: asInt(map['id']) ?? 0,
      target: coalesceText([map['target']], fallback: ''),
      requested: asInt(map['requested']) ?? 0,
      inserted: asInt(map['inserted']) ?? 0,
      skipped: asInt(map['skipped']) ?? 0,
      imageUrl: coalesceText([map['imageUrl'], map['image_url']], fallback: ''),
      imageShape: coalesceText([
        map['imageShape'],
        map['image_shape'],
      ], fallback: 'rounded'),
      targetRoute: coalesceText([
        map['targetRoute'],
        map['target_route'],
      ], fallback: ''),
      targetLabel: coalesceText([
        map['targetLabel'],
        map['target_label'],
      ], fallback: ''),
    );
  }
}

class AdminBroadcastHistoryItem {
  const AdminBroadcastHistoryItem({
    required this.id,
    required this.senderLabel,
    required this.senderUsername,
    required this.target,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.imageShape,
    required this.clickTargetRoute,
    required this.clickTargetLabel,
    required this.requested,
    required this.inserted,
    required this.skipped,
    required this.createdAt,
    required this.recipients,
    required this.platformSummary,
    required this.deliverySummary,
  });

  final int id;
  final String senderLabel;
  final String senderUsername;
  final String target;
  final String title;
  final String body;
  final String imageUrl;
  final String imageShape;
  final String clickTargetRoute;
  final String clickTargetLabel;
  final int requested;
  final int inserted;
  final int skipped;
  final String createdAt;
  final List<AdminPushDeliveryItem> recipients;
  final Map<String, int> platformSummary;
  final Map<String, int> deliverySummary;

  String get targetLabel {
    switch (target) {
      case 'verified':
        return 'Doğrulanmış üyeler';
      case 'admins':
        return 'Admin kullanıcılar';
      default:
        return 'Tüm aktif üyeler';
    }
  }

  String get summaryLabel {
    if (requested == 0) return 'Hedef kullanıcı bulunamadı';
    final parts = <String>[];
    if (inserted > 0) parts.add('$inserted kullanıcıya bildirim eklendi');
    if (skipped > 0) parts.add('$skipped atlandı');
    if (inserted == 0) parts.add('Hiçbirine ulaşamadı');
    return parts.join(' · ');
  }

  factory AdminBroadcastHistoryItem.fromMap(JsonMap map) {
    return AdminBroadcastHistoryItem(
      id: asInt(map['id']) ?? 0,
      senderLabel: coalesceText([
        map['sender_label'],
        map['senderLabel'],
      ], fallback: ''),
      senderUsername: coalesceText([
        map['sender_username'],
        map['senderUsername'],
      ], fallback: ''),
      target: coalesceText([map['target']], fallback: ''),
      title: coalesceText([map['title']], fallback: ''),
      body: coalesceText([map['body']], fallback: ''),
      imageUrl: coalesceText([map['image_url'], map['imageUrl']], fallback: ''),
      imageShape: coalesceText([
        map['image_shape'],
        map['imageShape'],
      ], fallback: 'rounded'),
      clickTargetRoute: coalesceText([
        map['target_route'],
        map['targetRoute'],
      ], fallback: ''),
      clickTargetLabel: coalesceText([
        map['target_label'],
        map['targetLabel'],
      ], fallback: ''),
      requested: asInt(map['requested_count']) ?? asInt(map['requested']) ?? 0,
      inserted: asInt(map['inserted_count']) ?? asInt(map['inserted']) ?? 0,
      skipped: asInt(map['skipped_count']) ?? asInt(map['skipped']) ?? 0,
      createdAt: coalesceText([
        map['created_at'],
        map['createdAt'],
      ], fallback: ''),
      recipients: asJsonMapList(
        map['recipients'],
      ).map(AdminPushDeliveryItem.fromMap).toList(growable: false),
      platformSummary: asJsonMap(
        map['platform_summary'],
      ).map((key, value) => MapEntry(key, asInt(value) ?? 0)),
      deliverySummary: asJsonMap(
        map['delivery_summary'],
      ).map((key, value) => MapEntry(key, asInt(value) ?? 0)),
    );
  }
}

class AdminActivityItem {
  const AdminActivityItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.type,
  });

  final String id;
  final String title;
  final String timestamp;
  final String type;

  factory AdminActivityItem.fromMap(JsonMap map) {
    final handle = coalesceText([map['kadi']], fallback: '');
    final content = coalesceText([
      map['content'],
      map['message'],
    ], fallback: '');
    final title = content.isNotEmpty
        ? content
        : handle.isNotEmpty
        ? '@$handle'
        : 'Admin kaydı';
    return AdminActivityItem(
      id: coalesceText([map['id']], fallback: ''),
      title: title,
      timestamp: coalesceText([
        map['at'],
        map['created_at'],
        map['ts'],
      ], fallback: ''),
      type: coalesceText([map['type']], fallback: ''),
    );
  }
}

class AdminPreviewList<T> {
  const AdminPreviewList({required this.total, required this.items});

  final int total;
  final List<T> items;
}

class AdminModerationItem {
  const AdminModerationItem({
    required this.id,
    required this.typeLabel,
    required this.content,
    required this.createdAt,
    required this.authorName,
    required this.authorHandle,
  });

  final int id;
  final String typeLabel;
  final String content;
  final String createdAt;
  final String authorName;
  final String authorHandle;

  factory AdminModerationItem.fromMap(
    JsonMap map, {
    required String typeLabel,
  }) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    return AdminModerationItem(
      id: asInt(map['id']) ?? 0,
      typeLabel: typeLabel,
      content: coalesceText([
        map['content'],
        map['body'],
        map['caption'],
      ], fallback: 'Icerik yok'),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      authorName: fullName.isNotEmpty
          ? fullName
          : coalesceText([map['kadi']], fallback: 'SDAL Uyesi'),
      authorHandle: coalesceText([map['kadi']], fallback: ''),
    );
  }
}

class AdminRequestQueueItem {
  const AdminRequestQueueItem({
    required this.id,
    required this.categoryKey,
    required this.categoryLabel,
    required this.status,
    required this.createdAt,
    required this.requesterName,
    required this.requesterHandle,
    required this.reviewerHandle,
    required this.requestedGraduationYear,
  });

  final int id;
  final String categoryKey;
  final String categoryLabel;
  final String status;
  final String createdAt;
  final String requesterName;
  final String requesterHandle;
  final String reviewerHandle;
  final String requestedGraduationYear;

  factory AdminRequestQueueItem.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    final payload = _decodeRequestPayload(map['payload_json']);
    return AdminRequestQueueItem(
      id: asInt(map['id']) ?? 0,
      categoryKey: coalesceText([map['category_key']], fallback: ''),
      categoryLabel: coalesceText([
        map['category_label'],
        map['category_key'],
      ], fallback: 'Talep'),
      status: coalesceText([map['status']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      requesterName: fullName.isNotEmpty
          ? fullName
          : coalesceText([map['kadi']], fallback: 'SDAL Uyesi'),
      requesterHandle: coalesceText([map['kadi']], fallback: ''),
      reviewerHandle: coalesceText([map['reviewer_kadi']], fallback: ''),
      requestedGraduationYear: coalesceText([
        payload['requestedGraduationYear'],
        payload['mezuniyetyili'],
      ], fallback: ''),
    );
  }
}

JsonMap _decodeRequestPayload(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

class AdminVerificationQueueItem {
  const AdminVerificationQueueItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.requesterName,
    required this.requesterHandle,
    required this.graduationYear,
    required this.requestType,
    required this.proofPath,
    required this.proofImageRecordId,
  });

  final int id;
  final String status;
  final String createdAt;
  final String requesterName;
  final String requesterHandle;
  final String graduationYear;
  final String requestType;
  final String proofPath;
  final String proofImageRecordId;

  bool get isTeacherVerification =>
      requestType == 'teacher_verification' ||
      graduationYear.trim().toLowerCase() == 'teacher' ||
      graduationYear.trim() == '9999';

  bool get hasProof => proofPath.isNotEmpty || proofImageRecordId.isNotEmpty;

  factory AdminVerificationQueueItem.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    return AdminVerificationQueueItem(
      id: asInt(map['id']) ?? 0,
      status: coalesceText([map['status']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      requesterName: fullName.isNotEmpty
          ? fullName
          : coalesceText([map['kadi']], fallback: 'SDAL Uyesi'),
      requesterHandle: coalesceText([map['kadi']], fallback: ''),
      graduationYear: coalesceText([map['mezuniyetyili']], fallback: ''),
      requestType: coalesceText([map['request_type']], fallback: ''),
      proofPath: coalesceText([map['proof_path']], fallback: ''),
      proofImageRecordId: coalesceText([
        map['proof_image_record_id'],
      ], fallback: ''),
    );
  }
}

class AdminTeacherNetworkLinkItem {
  const AdminTeacherNetworkLinkItem({
    required this.id,
    required this.reviewStatus,
    required this.relationshipType,
    required this.classYear,
    required this.notes,
    required this.createdAt,
    required this.confidenceScore,
    required this.teacherName,
    required this.teacherHandle,
    required this.teacherCohort,
    required this.alumniName,
    required this.alumniHandle,
    required this.alumniGraduationYear,
    required this.activePairLinkCount,
    required this.teacherActiveLinkCount,
    required this.reviewNote,
    required this.moderationLabel,
  });

  final int id;
  final String reviewStatus;
  final String relationshipType;
  final String classYear;
  final String notes;
  final String createdAt;
  final double confidenceScore;
  final String teacherName;
  final String teacherHandle;
  final String teacherCohort;
  final String alumniName;
  final String alumniHandle;
  final String alumniGraduationYear;
  final int activePairLinkCount;
  final int teacherActiveLinkCount;
  final String reviewNote;
  final String moderationLabel;

  factory AdminTeacherNetworkLinkItem.fromMap(JsonMap map) {
    final teacherFirst = coalesceText([map['teacher_isim']], fallback: '');
    final teacherLast = coalesceText([map['teacher_soyisim']], fallback: '');
    final alumniFirst = coalesceText([map['alumni_isim']], fallback: '');
    final alumniLast = coalesceText([map['alumni_soyisim']], fallback: '');
    final assessment = asJsonMap(map['moderation_assessment']);
    return AdminTeacherNetworkLinkItem(
      id: asInt(map['id']) ?? 0,
      reviewStatus: coalesceText([map['review_status']], fallback: 'pending'),
      relationshipType: coalesceText([map['relationship_type']], fallback: ''),
      classYear: coalesceText([map['class_year']], fallback: ''),
      notes: coalesceText([map['notes']], fallback: ''),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      confidenceScore: _asDouble(map['confidence_score']) ?? 0,
      teacherName: '$teacherFirst $teacherLast'.trim().isNotEmpty
          ? '$teacherFirst $teacherLast'.trim()
          : coalesceText([map['teacher_kadi']], fallback: 'Öğretmen'),
      teacherHandle: coalesceText([map['teacher_kadi']], fallback: ''),
      teacherCohort: coalesceText([map['teacher_cohort']], fallback: ''),
      alumniName: '$alumniFirst $alumniLast'.trim().isNotEmpty
          ? '$alumniFirst $alumniLast'.trim()
          : coalesceText([map['alumni_kadi']], fallback: 'Mezun'),
      alumniHandle: coalesceText([map['alumni_kadi']], fallback: ''),
      alumniGraduationYear: coalesceText([
        map['alumni_mezuniyetyili'],
      ], fallback: ''),
      activePairLinkCount: asInt(map['active_pair_link_count']) ?? 0,
      teacherActiveLinkCount: asInt(map['teacher_active_link_count']) ?? 0,
      reviewNote: coalesceText([map['review_note']], fallback: ''),
      moderationLabel: coalesceText([
        assessment['label'],
        assessment['risk_label'],
        assessment['summary'],
      ], fallback: ''),
    );
  }
}

class AdminTeacherNetworkLinksQuery {
  const AdminTeacherNetworkLinksQuery({
    this.status = 'pending',
    this.relationshipType = '',
    this.query = '',
    this.limit = 80,
  });

  final String status;
  final String relationshipType;
  final String query;
  final int limit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminTeacherNetworkLinksQuery &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          relationshipType == other.relationshipType &&
          query == other.query &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(status, relationshipType, query, limit);
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class AdminUserPreviewItem {
  const AdminUserPreviewItem({
    required this.id,
    required this.name,
    required this.handle,
    required this.email,
    required this.role,
    required this.graduationYear,
    required this.engagementScore,
  });

  final int id;
  final String name;
  final String handle;
  final String email;
  final String role;
  final String graduationYear;
  final int engagementScore;

  factory AdminUserPreviewItem.fromMap(JsonMap map) {
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    return AdminUserPreviewItem(
      id: asInt(map['id']) ?? 0,
      name: fullName.isNotEmpty
          ? fullName
          : coalesceText([map['kadi']], fallback: 'SDAL Uyesi'),
      handle: coalesceText([map['kadi']], fallback: ''),
      email: coalesceText([map['email']], fallback: ''),
      role: coalesceText([map['role']], fallback: 'user'),
      graduationYear: coalesceText([map['mezuniyetyili']], fallback: ''),
      engagementScore: asInt(map['engagement_score']) ?? 0,
    );
  }
}

class AdminApiMonitorUser {
  const AdminApiMonitorUser({
    required this.id,
    required this.handle,
    required this.name,
    required this.role,
    required this.isAdmin,
  });

  final int id;
  final String handle;
  final String name;
  final String role;
  final bool isAdmin;

  String get displayLabel => handle.isNotEmpty ? '@$handle' : name;

  factory AdminApiMonitorUser.fromMap(JsonMap map) {
    final handle = coalesceText([map['kadi']], fallback: '');
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    return AdminApiMonitorUser(
      id: asInt(map['id']) ?? 0,
      handle: handle,
      name: fullName.isNotEmpty
          ? fullName
          : handle.isNotEmpty
          ? '@$handle'
          : 'SDAL Uyesi',
      role: coalesceText([map['role']], fallback: 'user'),
      isAdmin: asBool(map['admin']) ?? false,
    );
  }
}

class AdminApiMonitorActivityItem {
  const AdminApiMonitorActivityItem({
    required this.requestId,
    required this.at,
    required this.method,
    required this.path,
    required this.status,
    required this.durationMs,
    required this.query,
    required this.ip,
    required this.userAgent,
    required this.bodySummary,
  });

  final String requestId;
  final String at;
  final String method;
  final String path;
  final int status;
  final int durationMs;
  final String query;
  final String ip;
  final String userAgent;
  final Object? bodySummary;

  bool get isWrite =>
      method == 'POST' ||
      method == 'PUT' ||
      method == 'PATCH' ||
      method == 'DELETE';

  bool get isSuccessful => status > 0 && status < 400;

  factory AdminApiMonitorActivityItem.fromMap(JsonMap map) {
    return AdminApiMonitorActivityItem(
      requestId: coalesceText([map['requestId']], fallback: ''),
      at: coalesceText([map['at']], fallback: ''),
      method: coalesceText([map['method']], fallback: 'GET').toUpperCase(),
      path: coalesceText([map['path']], fallback: ''),
      status: asInt(map['status']) ?? 0,
      durationMs: asInt(map['durationMs']) ?? 0,
      query: coalesceText([map['query']], fallback: ''),
      ip: coalesceText([map['ip']], fallback: ''),
      userAgent: coalesceText([map['userAgent']], fallback: ''),
      bodySummary: map['bodySummary'],
    );
  }
}

class AdminApiMonitorSnapshot {
  const AdminApiMonitorSnapshot({
    required this.user,
    required this.items,
    required this.returned,
    required this.limit,
    required this.source,
  });

  final AdminApiMonitorUser user;
  final List<AdminApiMonitorActivityItem> items;
  final int returned;
  final int limit;
  final String source;

  factory AdminApiMonitorSnapshot.fromMap(JsonMap map) {
    final meta = asJsonMap(map['meta']);
    return AdminApiMonitorSnapshot(
      user: AdminApiMonitorUser.fromMap(asJsonMap(map['user'])),
      items: asJsonMapList(
        map['activity'],
      ).map(AdminApiMonitorActivityItem.fromMap).toList(growable: false),
      returned: asInt(meta['returned']) ?? 0,
      limit: asInt(meta['limit']) ?? 0,
      source: coalesceText([meta['source']], fallback: ''),
    );
  }
}

class AdminApiMonitorQuery {
  const AdminApiMonitorQuery({
    required this.userId,
    this.limit = 40,
    this.pollInterval = const Duration(seconds: 3),
  });

  final int userId;
  final int limit;
  final Duration pollInterval;

  @override
  bool operator ==(Object other) {
    return other is AdminApiMonitorQuery &&
        other.userId == userId &&
        other.limit == limit &&
        other.pollInterval == pollInterval;
  }

  @override
  int get hashCode => Object.hash(userId, limit, pollInterval);
}

class AdminSiteControlsSnapshot {
  const AdminSiteControlsSnapshot({
    required this.siteOpen,
    required this.maintenanceMessage,
    required this.defaultLandingPage,
    required this.modules,
    required this.menuVisibility,
    required this.moduleMenuOrder,
    required this.openModuleCount,
    required this.totalModuleCount,
  });

  final bool siteOpen;
  final String maintenanceMessage;
  final String defaultLandingPage;
  final Map<String, bool> modules;
  final Map<String, bool> menuVisibility;
  final List<String> moduleMenuOrder;
  final int openModuleCount;
  final int totalModuleCount;

  factory AdminSiteControlsSnapshot.fromMap(JsonMap map) {
    final modules = asJsonMap(map['modules']);
    final menuVisibility = asJsonMap(map['menuVisibility']);
    final openCount = modules.values
        .where((value) => asBool(value) ?? false)
        .length;
    return AdminSiteControlsSnapshot(
      siteOpen: asBool(map['siteOpen']) ?? false,
      maintenanceMessage: coalesceText([
        map['maintenanceMessage'],
      ], fallback: ''),
      defaultLandingPage: coalesceText([
        map['defaultLandingPage'],
      ], fallback: ''),
      modules: modules.map(
        (key, value) => MapEntry(key, asBool(value) ?? true),
      ),
      menuVisibility: menuVisibility.map(
        (key, value) => MapEntry(key, asBool(value) ?? true),
      ),
      moduleMenuOrder:
          (map['moduleMenuOrder'] is List
                  ? map['moduleMenuOrder'] as List
                  : const <dynamic>[])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      openModuleCount: openCount,
      totalModuleCount: modules.length,
    );
  }
}

class AdminDbBackupItem {
  const AdminDbBackupItem({
    required this.name,
    required this.size,
    required this.createdAt,
  });

  final String name;
  final int size;
  final String createdAt;

  factory AdminDbBackupItem.fromMap(JsonMap map) {
    return AdminDbBackupItem(
      name: coalesceText([map['name'], map['file']], fallback: ''),
      size: asInt(map['size']) ?? 0,
      createdAt: coalesceText([
        map['createdAt'],
        map['created_at'],
        map['mtime'],
      ], fallback: ''),
    );
  }
}

class AdminDbDriverStatusSnapshot {
  const AdminDbDriverStatusSnapshot({
    required this.currentDriver,
    required this.targetDriver,
    required this.inProgress,
    required this.switchEnabled,
    required this.blockerCount,
    required this.blockers,
    required this.warnings,
    required this.expectedConfirmText,
    required this.challengeToken,
    required this.requiresSqliteDriftAck,
    required this.dataCopySupported,
    required this.lastError,
  });

  final String currentDriver;
  final String targetDriver;
  final bool inProgress;
  final bool switchEnabled;
  final int blockerCount;
  final List<String> blockers;
  final List<String> warnings;
  final String expectedConfirmText;
  final String challengeToken;
  final bool requiresSqliteDriftAck;
  final bool dataCopySupported;
  final String lastError;

  factory AdminDbDriverStatusSnapshot.fromMap(JsonMap map) {
    final blockers =
        (map['blockers'] is List ? map['blockers'] as List : const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false);
    final warnings =
        (map['warnings'] is List ? map['warnings'] as List : const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false);
    return AdminDbDriverStatusSnapshot(
      currentDriver: coalesceText([map['currentDriver']], fallback: ''),
      targetDriver: coalesceText([map['targetDriver']], fallback: ''),
      inProgress: asBool(map['inProgress']) ?? false,
      switchEnabled: asBool(map['switchEnabled']) ?? false,
      blockerCount: blockers.length,
      blockers: blockers,
      warnings: warnings,
      expectedConfirmText: coalesceText([
        map['expectedConfirmText'],
      ], fallback: ''),
      challengeToken: coalesceText([map['challengeToken']], fallback: ''),
      requiresSqliteDriftAck: asBool(map['requiresSqliteDriftAck']) ?? false,
      dataCopySupported: asBool(map['dataCopySupported']) ?? false,
      lastError: coalesceText([map['lastError']], fallback: ''),
    );
  }
}

class AdminLanguageItem {
  const AdminLanguageItem({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.isDefault,
    required this.isActive,
  });

  final String code;
  final String name;
  final String nativeName;
  final bool isDefault;
  final bool isActive;

  factory AdminLanguageItem.fromMap(JsonMap map) {
    return AdminLanguageItem(
      code: coalesceText([map['code']], fallback: ''),
      name: coalesceText([map['name']], fallback: ''),
      nativeName: coalesceText([
        map['native_name'],
        map['nativeName'],
      ], fallback: ''),
      isDefault: asBool(map['is_default']) ?? false,
      isActive: asBool(map['is_active']) ?? false,
    );
  }
}

class AdminLanguageConfigSnapshot {
  const AdminLanguageConfigSnapshot({
    required this.selectionEnabled,
    required this.defaultOpen,
    required this.defaultClosed,
  });

  final bool selectionEnabled;
  final String defaultOpen;
  final String defaultClosed;

  factory AdminLanguageConfigSnapshot.fromMap(JsonMap map) {
    return AdminLanguageConfigSnapshot(
      selectionEnabled: asBool(map['lang_selection_enabled']) ?? true,
      defaultOpen: coalesceText([map['default_lang_open']], fallback: ''),
      defaultClosed: coalesceText([map['default_lang_closed']], fallback: ''),
    );
  }
}

class AdminPageItem {
  const AdminPageItem({
    required this.id,
    required this.name,
    required this.url,
    required this.icon,
    required this.parentId,
    required this.menuVisible,
    required this.isRedirect,
    required this.layoutOption,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String url;
  final String icon;
  final int parentId;
  final bool menuVisible;
  final bool isRedirect;
  final int layoutOption;
  final int sortOrder;

  factory AdminPageItem.fromMap(JsonMap map) {
    return AdminPageItem(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['sayfaismi'], map['name']], fallback: ''),
      url: coalesceText([map['sayfaurl'], map['url']], fallback: ''),
      icon: coalesceText([map['resim'], map['icon']], fallback: 'yok'),
      parentId: asInt(map['babaid']) ?? 0,
      menuVisible: (asInt(map['menugorun']) ?? 0) == 1,
      isRedirect: (asInt(map['yonlendir']) ?? 0) == 1,
      layoutOption: asInt(map['mozellik']) ?? 0,
      sortOrder: asInt(map['sort_order']) ?? 0,
    );
  }
}

class AdminEmailCategoryItem {
  const AdminEmailCategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.description,
  });

  final int id;
  final String name;
  final String type;
  final String value;
  final String description;

  factory AdminEmailCategoryItem.fromMap(JsonMap map) {
    return AdminEmailCategoryItem(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['ad'], map['name']], fallback: ''),
      type: coalesceText([map['tur'], map['type']], fallback: ''),
      value: coalesceText([map['deger'], map['value']], fallback: ''),
      description: coalesceText([
        map['aciklama'],
        map['description'],
      ], fallback: ''),
    );
  }
}

class AdminLogFileItem {
  const AdminLogFileItem({
    required this.name,
    required this.size,
    required this.modifiedAt,
    required this.type,
  });

  final String name;
  final int size;
  final String modifiedAt;
  final String type;

  factory AdminLogFileItem.fromMap(JsonMap map) {
    return AdminLogFileItem(
      name: coalesceText([map['name'], map['file']], fallback: ''),
      size: asInt(map['size']) ?? 0,
      modifiedAt: coalesceText([map['mtime'], map['modifiedAt']], fallback: ''),
      type: coalesceText([map['type']], fallback: 'app'),
    );
  }
}

class AdminLanguageStringItem {
  const AdminLanguageStringItem({
    required this.langCode,
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  final String langCode;
  final String key;
  final String value;
  final String updatedAt;

  factory AdminLanguageStringItem.fromMap(JsonMap map) {
    return AdminLanguageStringItem(
      langCode: coalesceText([map['lang_code'], map['lang']], fallback: ''),
      key: coalesceText([map['key']], fallback: ''),
      value: coalesceText([map['value']], fallback: ''),
      updatedAt: coalesceText([map['updated_at']], fallback: ''),
    );
  }
}

class AdminLanguageKeyItem {
  const AdminLanguageKeyItem({required this.key, required this.languageCount});

  final String key;
  final int languageCount;

  factory AdminLanguageKeyItem.fromMap(JsonMap map) {
    return AdminLanguageKeyItem(
      key: coalesceText([map['key']], fallback: ''),
      languageCount: asInt(map['language_count']) ?? asInt(map['count']) ?? 0,
    );
  }
}

class AdminEmailTemplateItem {
  const AdminEmailTemplateItem({
    required this.id,
    required this.name,
    required this.subject,
    required this.bodyHtml,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String subject;
  final String bodyHtml;
  final String createdAt;

  factory AdminEmailTemplateItem.fromMap(JsonMap map) {
    return AdminEmailTemplateItem(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['ad'], map['name']], fallback: ''),
      subject: coalesceText([map['konu'], map['subject']], fallback: ''),
      bodyHtml: coalesceText([map['icerik'], map['body_html']], fallback: ''),
      createdAt: coalesceText([
        map['olusturma'],
        map['created_at'],
      ], fallback: ''),
    );
  }
}

class AdminLogContentSnapshot {
  const AdminLogContentSnapshot({
    required this.file,
    required this.content,
    required this.total,
    required this.matched,
    required this.returned,
  });

  final String file;
  final String content;
  final int total;
  final int matched;
  final int returned;

  factory AdminLogContentSnapshot.fromMap(JsonMap map) {
    return AdminLogContentSnapshot(
      file: coalesceText([map['file']], fallback: ''),
      content: coalesceText([map['content']], fallback: ''),
      total: asInt(map['total']) ?? 0,
      matched: asInt(map['matched']) ?? 0,
      returned: asInt(map['returned']) ?? 0,
    );
  }
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.id,
    required this.handle,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.activationToken,
    required this.isActive,
    required this.isBanned,
    required this.isProfileInitialized,
    required this.website,
    required this.signature,
    required this.profession,
    required this.city,
    required this.isEmailHidden,
    required this.profileViewCount,
    required this.isVerified,
    required this.graduationYear,
    required this.university,
    required this.birthDay,
    required this.birthMonth,
    required this.birthYear,
    required this.avatar,
  });

  final int id;
  final String handle;
  final String firstName;
  final String lastName;
  final String email;
  final String activationToken;
  final bool isActive;
  final bool isBanned;
  final bool isProfileInitialized;
  final String website;
  final String signature;
  final String profession;
  final String city;
  final bool isEmailHidden;
  final int profileViewCount;
  final bool isVerified;
  final String graduationYear;
  final String university;
  final String birthDay;
  final String birthMonth;
  final String birthYear;
  final String avatar;

  factory AdminUserDetail.fromMap(JsonMap map) {
    final user = map.containsKey('user') ? asJsonMap(map['user']) : map;
    return AdminUserDetail(
      id: asInt(user['id']) ?? 0,
      handle: coalesceText([user['kadi']], fallback: ''),
      firstName: coalesceText([user['isim']], fallback: ''),
      lastName: coalesceText([user['soyisim']], fallback: ''),
      email: coalesceText([user['email']], fallback: ''),
      activationToken: coalesceText([user['aktivasyon']], fallback: ''),
      isActive: (asInt(user['aktiv']) ?? 0) == 1,
      isBanned: (asInt(user['yasak']) ?? 0) == 1,
      isProfileInitialized: (asInt(user['ilkbd']) ?? 0) == 1,
      website: coalesceText([user['websitesi']], fallback: ''),
      signature: coalesceText([user['imza']], fallback: ''),
      profession: coalesceText([user['meslek']], fallback: ''),
      city: coalesceText([user['sehir']], fallback: ''),
      isEmailHidden: (asInt(user['mailkapali']) ?? 0) == 1,
      profileViewCount: asInt(user['hit']) ?? 0,
      isVerified: (asInt(user['verified']) ?? 0) == 1,
      graduationYear: coalesceText([user['mezuniyetyili']], fallback: ''),
      university: coalesceText([user['universite']], fallback: ''),
      birthDay: coalesceText([user['dogumgun']], fallback: ''),
      birthMonth: coalesceText([user['dogumay']], fallback: ''),
      birthYear: coalesceText([user['dogumyil']], fallback: ''),
      avatar: coalesceText([user['resim']], fallback: 'yok'),
    );
  }
}

class AdminPermissionDefinition {
  const AdminPermissionDefinition({
    required this.id,
    required this.key,
    required this.label,
    required this.description,
  });

  final int id;
  final String key;
  final String label;
  final String description;

  factory AdminPermissionDefinition.fromMap(JsonMap map) {
    return AdminPermissionDefinition(
      id: asInt(map['id']) ?? 0,
      key: coalesceText([map['key'], map['permission_key']], fallback: ''),
      label: coalesceText([map['label'], map['key']], fallback: ''),
      description: coalesceText([map['description']], fallback: ''),
    );
  }
}

class AdminGroupPermission {
  const AdminGroupPermission({
    required this.key,
    required this.canRead,
    required this.canWrite,
  });

  final String key;
  final bool canRead;
  final bool canWrite;

  JsonMap toJson() => {'key': key, 'canRead': canRead, 'canWrite': canWrite};

  factory AdminGroupPermission.fromMap(JsonMap map) {
    return AdminGroupPermission(
      key: coalesceText([map['key'], map['permission_key']], fallback: ''),
      canRead:
          asBool(map['canRead']) ??
          asBool(map['can_read']) ??
          asBool(map['read']) ??
          false,
      canWrite:
          asBool(map['canWrite']) ??
          asBool(map['can_write']) ??
          asBool(map['write']) ??
          false,
    );
  }
}

class AdminPermissionGroup {
  const AdminPermissionGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.isSystem,
    required this.permissions,
  });

  final int id;
  final String name;
  final String description;
  final bool isSystem;
  final List<AdminGroupPermission> permissions;

  bool get isDefaultGroup => const {'admin', 'mod', 'user'}.contains(name);

  factory AdminPermissionGroup.fromMap(JsonMap map) {
    return AdminPermissionGroup(
      id: asInt(map['id']) ?? 0,
      name: coalesceText([map['name']], fallback: ''),
      description: coalesceText([map['description']], fallback: ''),
      isSystem: asBool(map['isSystem']) ?? asBool(map['is_system']) ?? false,
      permissions: asJsonMapList(
        map['permissions'],
      ).map(AdminGroupPermission.fromMap).toList(growable: false),
    );
  }
}

class AdminPermissionUser {
  const AdminPermissionUser({
    required this.id,
    required this.handle,
    required this.name,
    required this.email,
    required this.role,
    required this.isRoot,
    required this.groupId,
    required this.groupName,
  });

  final int id;
  final String handle;
  final String name;
  final String email;
  final String role;
  final bool isRoot;
  final int groupId;
  final String groupName;

  factory AdminPermissionUser.fromMap(JsonMap map) {
    final firstName = coalesceText([
      map['firstName'],
      map['first_name'],
    ], fallback: '');
    final lastName = coalesceText([
      map['lastName'],
      map['last_name'],
    ], fallback: '');
    final group = asJsonMap(map['group']);
    return AdminPermissionUser(
      id: asInt(map['id']) ?? 0,
      handle: coalesceText([map['username'], map['kadi']], fallback: ''),
      name: '$firstName $lastName'.trim(),
      email: coalesceText([map['email']], fallback: ''),
      role: coalesceText([map['role']], fallback: 'user'),
      isRoot: asBool(map['isRoot']) ?? false,
      groupId: asInt(group['id']) ?? 0,
      groupName: coalesceText([group['name']], fallback: ''),
    );
  }
}

class AdminPermissionUsersSnapshot {
  const AdminPermissionUsersSnapshot({
    required this.total,
    required this.users,
  });

  final int total;
  final List<AdminPermissionUser> users;

  factory AdminPermissionUsersSnapshot.fromMap(JsonMap map) {
    final meta = asJsonMap(map['meta']);
    return AdminPermissionUsersSnapshot(
      total: asInt(meta['total']) ?? asJsonMapList(map['users']).length,
      users: asJsonMapList(
        map['users'],
      ).map(AdminPermissionUser.fromMap).toList(growable: false),
    );
  }
}

class AdminRepository {
  const AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminAccessSnapshot> fetchAdminAccess() async {
    final sessionResult = await _apiClient.get<JsonMap>(
      '/api/admin/session',
      decoder: asJsonMap,
    );
    final sessionMap = asJsonMap(sessionResult.rawData);
    final userMap = asJsonMap(sessionMap['user']);
    final user = userMap.isEmpty ? null : AdminShellUser.fromMap(userMap);
    final adminOk =
        (asBool(sessionMap['adminOk']) ?? false) ||
        (user?.hasAdminAccess ?? false);
    if (user == null) {
      return AdminAccessSnapshot(
        user: user,
        adminOk: false,
        permissions: null,
        rootStatus: null,
      );
    }

    final canLoadModerationAccess =
        user.hasAdminAccess ||
        adminOk ||
        user.role.trim().toLowerCase() == 'mod';
    if (!canLoadModerationAccess) {
      return AdminAccessSnapshot(
        user: user,
        adminOk: adminOk,
        permissions: null,
        rootStatus: null,
      );
    }

    final permissionsResult = await _apiClient.get<JsonMap>(
      '/api/admin/moderation/my-permissions',
      decoder: asJsonMap,
    );
    AdminRootStatusSnapshot? rootStatus;
    if (user.hasAdminAccess || adminOk) {
      final rootStatusResult = await _apiClient.get<JsonMap>(
        '/api/admin/root-status',
        decoder: asJsonMap,
      );
      rootStatus = AdminRootStatusSnapshot.fromMap(
        asJsonMap(rootStatusResult.rawData),
      );
    }

    return AdminAccessSnapshot(
      user: user,
      adminOk: adminOk,
      permissions: AdminPermissionSnapshot.fromMap(
        asJsonMap(permissionsResult.rawData),
      ),
      rootStatus: rootStatus,
    );
  }

  Future<void> loginToAdmin(String password) async {
    await _apiClient.post<dynamic>(
      '/api/admin/login',
      body: {'password': password},
    );
  }

  Future<void> logoutFromAdmin() async {
    await _apiClient.post<dynamic>('/api/admin/logout');
  }

  Future<AdminSummarySnapshot> fetchSummary() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/stats',
      decoder: asJsonMap,
    );
    return AdminSummarySnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<AdminLiveSnapshot> fetchLive() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/live',
      decoder: asJsonMap,
    );
    return AdminLiveSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<AdminSecuritySnapshot> fetchSecurityStatus() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/security/status',
      decoder: asJsonMap,
    );
    return AdminSecuritySnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<AdminAuthSecuritySnapshot> fetchAuthSecurity() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/auth-security',
      query: {'limit': '30'},
      decoder: asJsonMap,
    );
    return AdminAuthSecuritySnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<List<AdminRequestNotificationItem>> fetchRequestNotifications() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/requests/notifications',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(AdminRequestNotificationItem.fromMap).toList(growable: false);
  }

  Future<AdminNotificationOpsSnapshot> fetchNotificationOps() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/notifications/ops',
      query: {'window': '30d'},
      decoder: asJsonMap,
    );
    return AdminNotificationOpsSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<AdminPushSettingsSnapshot> fetchPushSettings() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/notifications/push-settings',
      decoder: asJsonMap,
    );
    return AdminPushSettingsSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<List<AdminBroadcastHistoryItem>> fetchBroadcastHistory({
    int limit = 10,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/notifications/broadcasts',
      query: {'limit': limit},
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(AdminBroadcastHistoryItem.fromMap).toList(growable: false);
  }

  Future<AdminPreviewList<AdminModerationItem>> fetchPostPreview({
    int limit = 5,
  }) async {
    return _fetchPreviewList(
      path: '/api/new/admin/posts',
      limit: limit,
      decoder: (map) => AdminModerationItem.fromMap(map, typeLabel: 'Gonderi'),
    );
  }

  Future<AdminPreviewList<AdminModerationItem>> fetchCommentPreview({
    int limit = 5,
  }) async {
    return _fetchPreviewList(
      path: '/api/new/admin/comments',
      limit: limit,
      decoder: (map) => AdminModerationItem.fromMap(map, typeLabel: 'Yorum'),
    );
  }

  Future<AdminPreviewList<AdminModerationItem>> fetchStoryPreview({
    int limit = 5,
  }) async {
    return _fetchPreviewList(
      path: '/api/new/admin/stories',
      limit: limit,
      decoder: (map) => AdminModerationItem.fromMap(map, typeLabel: 'Hikaye'),
    );
  }

  Future<AdminPreviewList<AdminRequestQueueItem>> fetchMemberRequestPreview({
    int limit = 6,
  }) async {
    return _fetchPreviewList(
      path: '/api/new/admin/requests',
      query: {'status': 'pending'},
      limit: limit,
      decoder: AdminRequestQueueItem.fromMap,
    );
  }

  Future<AdminPreviewList<AdminVerificationQueueItem>>
  fetchVerificationRequestPreview({int limit = 6}) async {
    return _fetchPreviewList(
      path: '/api/new/admin/verification-requests',
      query: {'status': 'pending'},
      limit: limit,
      decoder: AdminVerificationQueueItem.fromMap,
    );
  }

  Future<AdminPreviewList<AdminTeacherNetworkLinkItem>>
  fetchTeacherNetworkLinkPreview({int limit = 6}) async {
    return _fetchPreviewList(
      path: '/api/new/admin/teacher-network/links',
      query: {'review_status': 'pending'},
      limit: limit,
      decoder: AdminTeacherNetworkLinkItem.fromMap,
    );
  }

  Future<AdminPreviewList<AdminTeacherNetworkLinkItem>>
  fetchTeacherNetworkLinks({
    AdminTeacherNetworkLinksQuery query = const AdminTeacherNetworkLinksQuery(),
  }) async {
    return _fetchPreviewList(
      path: '/api/new/admin/teacher-network/links',
      query: {
        if (query.status.trim().isNotEmpty)
          'review_status': query.status.trim(),
        if (query.relationshipType.trim().isNotEmpty)
          'relationship_type': query.relationshipType.trim(),
        if (query.query.trim().isNotEmpty) 'q': query.query.trim(),
      },
      limit: query.limit,
      decoder: AdminTeacherNetworkLinkItem.fromMap,
    );
  }

  Future<AdminPreviewList<AdminUserPreviewItem>> fetchUserPreview({
    AdminUserListQuery query = const AdminUserListQuery(),
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/users/lists',
      query: {
        'page': query.page,
        'limit': query.limit,
        'sort': 'engagement_desc',
        if (query.query.trim().isNotEmpty) 'q': query.query.trim(),
        if (query.filter.trim().isNotEmpty) 'filter': query.filter.trim(),
        if (query.verifiedOnly) 'verified': '1',
        if (query.adminOnly) 'admin': '1',
        if (query.withPhotoOnly) 'photo': '1',
      },
      decoder: asJsonMap,
    );
    final raw = asJsonMap(result.rawData);
    final meta = asJsonMap(raw['meta']);
    return AdminPreviewList<AdminUserPreviewItem>(
      total: asInt(meta['total']) ?? asJsonMapList(raw['users']).length,
      items: asJsonMapList(
        raw['users'],
      ).map(AdminUserPreviewItem.fromMap).toList(growable: false),
    );
  }

  Future<AdminApiMonitorSnapshot> fetchUserApiActivity({
    required AdminApiMonitorQuery query,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/users/${query.userId}/api-activity',
      query: {'limit': query.limit},
      decoder: asJsonMap,
    );
    return AdminApiMonitorSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<AdminSiteControlsSnapshot> fetchSiteControls() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/site-controls',
      decoder: asJsonMap,
    );
    return AdminSiteControlsSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<AdminAuthSettingsSnapshot> fetchAuthSettings() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/auth-settings',
      decoder: asJsonMap,
    );
    return AdminAuthSettingsSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<void> updateAuthSettings({
    required bool smsVerificationEnabled,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/auth-settings',
      body: {'smsVerificationEnabled': smsVerificationEnabled},
    );
  }

  Future<void> updateSiteControls({
    required bool siteOpen,
    String? maintenanceMessage,
    String? defaultLandingPage,
    Map<String, bool>? modules,
    Map<String, bool>? menuVisibility,
    List<String>? moduleMenuOrder,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/site-controls',
      body: {
        'siteOpen': siteOpen,
        ...?maintenanceMessage == null
            ? null
            : {'maintenanceMessage': maintenanceMessage},
        ...?defaultLandingPage == null
            ? null
            : {'defaultLandingPage': defaultLandingPage},
        ...?modules == null ? null : {'modules': modules},
        ...?menuVisibility == null ? null : {'menuVisibility': menuVisibility},
        ...?moduleMenuOrder == null
            ? null
            : {'moduleMenuOrder': moduleMenuOrder},
      },
    );
  }

  Future<List<AdminDbBackupItem>> fetchDbBackups() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/db/backups',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(AdminDbBackupItem.fromMap).toList(growable: false);
  }

  Future<AdminDbDriverStatusSnapshot> fetchDbDriverStatus() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/admin/db/driver/status',
      decoder: asJsonMap,
    );
    return AdminDbDriverStatusSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<void> createDbBackup({String label = 'manual'}) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/db/backups',
      body: {'label': label},
    );
  }

  Future<void> copyDbData({
    required String sourceDriver,
    required String targetDriver,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/db/driver/copy-data',
      body: {'sourceDriver': sourceDriver, 'targetDriver': targetDriver},
    );
  }

  Future<void> switchDbDriver({
    required String targetDriver,
    required String confirmText,
    required String challengeToken,
    bool acknowledgeSqliteDrift = false,
    bool copyData = false,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/db/driver/switch',
      body: {
        'targetDriver': targetDriver,
        'confirmText': confirmText,
        'challengeToken': challengeToken,
        'acknowledgeSqliteDrift': acknowledgeSqliteDrift,
        'copyData': copyData,
      },
    );
  }

  Future<void> restoreDbBackupByName(String name) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/db/restore-from-backup',
      body: {'name': name},
    );
  }

  Future<List<AdminPageItem>> fetchPages() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/pages',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['pages'],
    ).map(AdminPageItem.fromMap).toList(growable: false);
  }

  Future<void> addPage({
    required String name,
    required String url,
    String icon = 'yok',
    int parentId = 0,
    bool menuVisible = true,
    bool isRedirect = false,
    int layoutOption = 0,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/pages',
      body: {
        'sayfaismi': name,
        'sayfaurl': url,
        'babaid': parentId,
        'menugorun': menuVisible ? 1 : 0,
        'yonlendir': isRedirect ? 1 : 0,
        'mozellik': layoutOption,
        'resim': icon,
      },
    );
  }

  Future<void> updatePage({
    required int id,
    required String name,
    required String url,
    required String icon,
    required int parentId,
    required bool menuVisible,
    required bool isRedirect,
    required int layoutOption,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/pages/$id',
      body: {
        'sayfaismi': name,
        'sayfaurl': url,
        'babaid': parentId,
        'menugorun': menuVisible ? 1 : 0,
        'yonlendir': isRedirect ? 1 : 0,
        'mozellik': layoutOption,
        'resim': icon,
      },
    );
  }

  Future<void> reorderPages(List<int> order) async {
    await _apiClient.put<dynamic>(
      '/api/admin/pages/reorder',
      body: {'order': order},
    );
  }

  Future<void> deletePage(int id) async {
    await _apiClient.delete<dynamic>('/api/admin/pages/$id');
  }

  Future<List<AdminEmailCategoryItem>> fetchEmailCategories() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/email/categories',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['categories'],
    ).map(AdminEmailCategoryItem.fromMap).toList(growable: false);
  }

  Future<void> addEmailCategory({
    required String name,
    required String type,
    String value = '',
    String description = '',
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/email/categories',
      body: {'ad': name, 'tur': type, 'deger': value, 'aciklama': description},
    );
  }

  Future<void> deleteEmailCategory(int id) async {
    await _apiClient.delete<dynamic>('/api/admin/email/categories/$id');
  }

  Future<List<AdminEmailTemplateItem>> fetchEmailTemplates() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/email/templates',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['templates'],
    ).map(AdminEmailTemplateItem.fromMap).toList(growable: false);
  }

  Future<void> addEmailTemplate({
    required String name,
    required String subject,
    required String bodyHtml,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/email/templates',
      body: {'ad': name, 'konu': subject, 'icerik': bodyHtml},
    );
  }

  Future<void> updateEmailTemplate({
    required int id,
    required String name,
    required String subject,
    required String bodyHtml,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/email/templates/$id',
      body: {'ad': name, 'konu': subject, 'icerik': bodyHtml},
    );
  }

  Future<void> deleteEmailTemplate(int id) async {
    await _apiClient.delete<dynamic>('/api/admin/email/templates/$id');
  }

  Future<void> sendBulkEmail({
    required int categoryId,
    required String subject,
    required String html,
    String from = '',
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/email/bulk',
      body: {
        'categoryId': categoryId,
        'subject': subject,
        'html': html,
        if (from.trim().isNotEmpty) 'from': from.trim(),
      },
    );
  }

  Future<void> sendEmail({
    required String to,
    required String from,
    required String subject,
    required String html,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/email/send',
      body: {'to': to, 'from': from, 'subject': subject, 'html': html},
    );
  }

  Future<List<AdminLogFileItem>> fetchLogFiles({String type = 'app'}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/logs',
      query: {'type': type},
      decoder: asJsonMap,
    );
    return asJsonMapList(asJsonMap(result.rawData)['files'])
        .map((map) => AdminLogFileItem.fromMap({...map, 'type': type}))
        .toList(growable: false);
  }

  Future<AdminLogContentSnapshot> fetchLogContent({
    required String type,
    required String file,
    int limit = 4000,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/logs',
      query: {'type': type, 'file': file, 'limit': limit},
      decoder: asJsonMap,
    );
    return AdminLogContentSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<List<AdminLanguageItem>> fetchLanguages() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/languages',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['languages'],
    ).map(AdminLanguageItem.fromMap).toList(growable: false);
  }

  Future<AdminLanguageConfigSnapshot> fetchLanguageConfig() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/language-config',
      decoder: asJsonMap,
    );
    return AdminLanguageConfigSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<void> addLanguage({
    required String code,
    required String name,
    required String nativeName,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/languages',
      body: {'code': code, 'name': name, 'native_name': nativeName},
    );
  }

  Future<void> updateLanguage({
    required String code,
    String? name,
    String? nativeName,
    bool? isActive,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/languages/$code',
      body: {
        ...?name == null ? null : {'name': name},
        ...?nativeName == null ? null : {'native_name': nativeName},
        ...?isActive == null ? null : {'is_active': isActive},
      },
    );
  }

  Future<void> deleteLanguage(String code) async {
    await _apiClient.delete<dynamic>('/api/admin/languages/$code');
  }

  Future<void> updateLanguageConfig({
    required bool selectionEnabled,
    String? defaultOpen,
    String? defaultClosed,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/language-config',
      body: {
        'lang_selection_enabled': selectionEnabled,
        ...?defaultOpen == null ? null : {'default_lang_open': defaultOpen},
        ...?defaultClosed == null
            ? null
            : {'default_lang_closed': defaultClosed},
      },
    );
  }

  Future<List<AdminLanguageStringItem>> fetchLanguageStrings({
    required String lang,
    int limit = 8,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/language-strings',
      query: {'lang': lang, 'page': 1, 'limit': limit},
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['strings'],
    ).map(AdminLanguageStringItem.fromMap).toList(growable: false);
  }

  Future<List<AdminLanguageKeyItem>> fetchLanguageKeys({int limit = 12}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/language-strings/keys',
      query: {'page': 1, 'limit': limit},
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['keys'],
    ).map(AdminLanguageKeyItem.fromMap).toList(growable: false);
  }

  Future<void> saveLanguageString({
    required String lang,
    required String key,
    required String value,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/language-strings/$lang/$key',
      body: {'value': value},
    );
  }

  Future<void> fillMissingLanguageStrings(String lang) async {
    await _apiClient.post<dynamic>(
      '/api/admin/language-strings/fill-missing',
      body: {'lang': lang},
    );
  }

  Future<void> bulkImportLanguageStrings({
    required String lang,
    required Map<String, String> strings,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/admin/language-strings/bulk',
      body: {'lang': lang, 'strings': strings},
    );
  }

  Future<void> deleteLanguageKey(String key) async {
    await _apiClient.delete<dynamic>('/api/admin/language-strings/key/$key');
  }

  Future<AdminUserDetail> fetchUserDetail(int id) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/users/$id',
      decoder: asJsonMap,
    );
    return AdminUserDetail.fromMap(asJsonMap(result.rawData));
  }

  Future<void> updateUserDetail(AdminUserDetail detail) async {
    await _apiClient.put<dynamic>(
      '/api/admin/users/${detail.id}',
      body: {
        'isim': detail.firstName,
        'soyisim': detail.lastName,
        'aktivasyon': detail.activationToken,
        'email': detail.email,
        'aktiv': detail.isActive ? 1 : 0,
        'yasak': detail.isBanned ? 1 : 0,
        'ilkbd': detail.isProfileInitialized ? 1 : 0,
        'websitesi': detail.website,
        'imza': detail.signature,
        'meslek': detail.profession,
        'sehir': detail.city,
        'mailkapali': detail.isEmailHidden ? 1 : 0,
        'hit': detail.profileViewCount,
        'verified': detail.isVerified ? 1 : 0,
        'mezuniyetyili': detail.graduationYear,
        'universite': detail.university,
        'dogumgun': detail.birthDay,
        'dogumay': detail.birthMonth,
        'dogumyil': detail.birthYear,
        'resim': detail.avatar,
      },
    );
  }

  Future<List<AdminPermissionDefinition>> fetchPermissions() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/permissions',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['permissions'],
    ).map(AdminPermissionDefinition.fromMap).toList(growable: false);
  }

  Future<List<AdminPermissionGroup>> fetchPermissionGroups() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/permission-groups',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['groups'],
    ).map(AdminPermissionGroup.fromMap).toList(growable: false);
  }

  Future<void> savePermissionGroup({
    int? id,
    required String name,
    required String description,
    required List<AdminGroupPermission> permissions,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'permissions': permissions.map((item) => item.toJson()).toList(),
    };
    if (id == null || id <= 0) {
      await _apiClient.post<dynamic>(
        '/api/admin/permission-groups',
        body: body,
      );
      return;
    }
    await _apiClient.put<dynamic>(
      '/api/admin/permission-groups/$id',
      body: body,
    );
  }

  Future<void> deletePermissionGroup(int id) async {
    await _apiClient.delete<dynamic>('/api/admin/permission-groups/$id');
  }

  Future<AdminPermissionUsersSnapshot> fetchPermissionUsers({
    String query = '',
    int page = 1,
    int limit = 30,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/admin/users/permissions',
      query: {
        'page': page,
        'limit': limit,
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
      decoder: asJsonMap,
    );
    return AdminPermissionUsersSnapshot.fromMap(asJsonMap(result.rawData));
  }

  Future<void> assignUserPermissionGroup({
    required int userId,
    required int groupId,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/admin/users/$userId/permission-group',
      body: {'groupId': groupId},
    );
  }

  Future<void> factoryReset({
    required String confirmation,
    required String password,
    bool dryRun = false,
  }) async {
    final result = await _apiClient.post<dynamic>(
      '/api/admin/factory-reset',
      body: {
        'confirmation': confirmation,
        'password': password,
        'dryRun': dryRun,
      },
    );
    if (!result.ok) {
      throw Exception(
        result.message.isNotEmpty
            ? result.message
            : 'Factory reset başarısız (${result.statusCode}).',
      );
    }
  }

  Future<AdminPreviewList<T>> _fetchPreviewList<T>({
    required String path,
    required T Function(JsonMap map) decoder,
    Map<String, dynamic>? query,
    int limit = 5,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      path,
      query: {'page': 1, 'limit': limit, ...?query},
      decoder: asJsonMap,
    );
    final raw = asJsonMap(result.rawData);
    final meta = asJsonMap(raw['meta']);
    return AdminPreviewList<T>(
      total: asInt(meta['total']) ?? asJsonMapList(raw['items']).length,
      items: asJsonMapList(raw['items']).map(decoder).toList(growable: false),
    );
  }

  Future<void> deletePost(int id) async {
    await _apiClient.delete<dynamic>('/api/new/admin/posts/$id');
  }

  Future<void> deleteComment(int id) async {
    await _apiClient.delete<dynamic>('/api/new/admin/comments/$id');
  }

  Future<void> deleteStory(int id) async {
    await _apiClient.delete<dynamic>('/api/new/admin/stories/$id');
  }

  Future<void> reviewMemberRequest({
    required int id,
    required String status,
    String resolutionNote = '',
    String graduationYearOverride = '',
  }) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/requests/$id/review',
      body: {
        'status': status,
        if (resolutionNote.trim().isNotEmpty)
          'resolution_note': resolutionNote.trim(),
        if (graduationYearOverride.trim().isNotEmpty)
          'graduationYearOverride': graduationYearOverride.trim(),
      },
    );
  }

  Future<void> reviewVerificationRequest({
    required int id,
    required String status,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/verification-requests/$id',
      body: {'status': status},
    );
  }

  Future<void> reviewTeacherNetworkLink({
    required int id,
    required String status,
    String note = '',
    int? mergeIntoLinkId,
  }) async {
    await _apiClient.post<dynamic>(
      '/api/new/admin/teacher-network/links/$id/review',
      body: {
        'status': status,
        if (note.trim().isNotEmpty) 'note': note.trim(),
        if ((mergeIntoLinkId ?? 0) > 0) 'merge_into_link_id': mergeIntoLinkId,
      },
    );
  }

  Future<void> updatePushSettings({required bool enabled}) async {
    await _apiClient.put<dynamic>(
      '/api/new/admin/notifications/push-settings',
      body: {'enabled': enabled},
    );
  }

  Future<AdminBroadcastResult> sendNotificationBroadcast({
    required String target,
    required String sender,
    required String title,
    required String body,
    String imageUrl = '',
    String imageShape = 'rounded',
    String targetRoute = '',
    String targetLabel = '',
  }) async {
    final result = await _apiClient.post<JsonMap>(
      '/api/new/admin/notifications/broadcast',
      body: {
        'target': target,
        'sender': sender,
        'title': title,
        'body': body,
        if (imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl.trim(),
        'imageShape': imageShape,
        if (targetRoute.trim().isNotEmpty) 'targetRoute': targetRoute.trim(),
        if (targetLabel.trim().isNotEmpty) 'targetLabel': targetLabel.trim(),
      },
      decoder: asJsonMap,
    );
    if (!result.ok) {
      throw Exception(
        result.message.isNotEmpty
            ? result.message
            : 'Toplu bildirim gönderilemedi (${result.statusCode}).',
      );
    }
    return AdminBroadcastResult.fromMap(asJsonMap(result.rawData));
  }

  Future<String> uploadNotificationBroadcastImage(File imageFile) async {
    final result = await _apiClient.multipart<JsonMap>(
      '/api/upload-image',
      fields: {'entityType': 'notification_broadcast', 'entityId': '0'},
      files: {'image': imageFile},
      decoder: asJsonMap,
    );
    if (!result.ok) {
      throw Exception(
        result.message.isNotEmpty
            ? result.message
            : 'Görsel yüklenemedi (${result.statusCode}).',
      );
    }
    final variants = asJsonMap(asJsonMap(result.rawData)['variants']);
    return coalesceText([
      variants['thumbUrl'],
      variants['feedUrl'],
      variants['fullUrl'],
    ], fallback: '');
  }

  Future<void> deleteMember(int id) async {
    await _apiClient.delete<dynamic>('/api/new/admin/members/$id');
  }

  Future<void> updateGraduationYear({
    required int id,
    required String graduationYear,
  }) async {
    await _apiClient.put<dynamic>(
      '/api/new/admin/users/$id/graduation-year',
      body: {'mezuniyetyili': graduationYear},
    );
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

final adminAccessProvider = FutureProvider<AdminAccessSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAdminAccess(),
);

final adminSummaryProvider = FutureProvider<AdminSummarySnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchSummary(),
);

final adminLiveProvider = FutureProvider<AdminLiveSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchLive(),
);

final adminSecurityProvider = FutureProvider<AdminSecuritySnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchSecurityStatus(),
);

final adminAuthSecurityProvider = FutureProvider<AdminAuthSecuritySnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAuthSecurity(),
);

final adminAuthSettingsProvider = FutureProvider<AdminAuthSettingsSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchAuthSettings(),
);

final adminRequestNotificationsProvider =
    FutureProvider<List<AdminRequestNotificationItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchRequestNotifications(),
    );

final adminNotificationOpsProvider =
    FutureProvider<AdminNotificationOpsSnapshot>(
      (ref) => ref.watch(adminRepositoryProvider).fetchNotificationOps(),
    );

final adminPushSettingsProvider = FutureProvider<AdminPushSettingsSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchPushSettings(),
);

final adminBroadcastHistoryProvider =
    FutureProvider<List<AdminBroadcastHistoryItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchBroadcastHistory(),
    );

final adminPostPreviewProvider =
    FutureProvider<AdminPreviewList<AdminModerationItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchPostPreview(),
    );

final adminCommentPreviewProvider =
    FutureProvider<AdminPreviewList<AdminModerationItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchCommentPreview(),
    );

final adminStoryPreviewProvider =
    FutureProvider<AdminPreviewList<AdminModerationItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchStoryPreview(),
    );

final adminMemberRequestPreviewProvider =
    FutureProvider<AdminPreviewList<AdminRequestQueueItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchMemberRequestPreview(),
    );

final adminVerificationRequestPreviewProvider =
    FutureProvider<AdminPreviewList<AdminVerificationQueueItem>>(
      (ref) =>
          ref.watch(adminRepositoryProvider).fetchVerificationRequestPreview(),
    );

final adminTeacherNetworkLinkPreviewProvider =
    FutureProvider<AdminPreviewList<AdminTeacherNetworkLinkItem>>(
      (ref) =>
          ref.watch(adminRepositoryProvider).fetchTeacherNetworkLinkPreview(),
    );

final adminTeacherNetworkLinksProvider =
    FutureProvider.family<
      AdminPreviewList<AdminTeacherNetworkLinkItem>,
      AdminTeacherNetworkLinksQuery
    >(
      (ref, query) => ref
          .watch(adminRepositoryProvider)
          .fetchTeacherNetworkLinks(query: query),
    );

final adminUserPreviewProvider =
    FutureProvider.family<
      AdminPreviewList<AdminUserPreviewItem>,
      AdminUserListQuery
    >(
      (ref, query) =>
          ref.watch(adminRepositoryProvider).fetchUserPreview(query: query),
    );

final adminUserApiActivityProvider = StreamProvider.autoDispose
    .family<AdminApiMonitorSnapshot, AdminApiMonitorQuery>((ref, query) async* {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final repository = ref.watch(adminRepositoryProvider);

      while (!disposed) {
        yield await repository.fetchUserApiActivity(query: query);
        if (disposed) break;
        await Future<void>.delayed(query.pollInterval);
      }
    });

final adminSiteControlsProvider = FutureProvider<AdminSiteControlsSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchSiteControls(),
);

final adminDbBackupsProvider = FutureProvider<List<AdminDbBackupItem>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchDbBackups(),
);

final adminDbDriverStatusProvider = FutureProvider<AdminDbDriverStatusSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchDbDriverStatus(),
);

final adminLanguagesProvider = FutureProvider<List<AdminLanguageItem>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchLanguages(),
);

final adminLanguageConfigProvider = FutureProvider<AdminLanguageConfigSnapshot>(
  (ref) => ref.watch(adminRepositoryProvider).fetchLanguageConfig(),
);

final adminPagesProvider = FutureProvider<List<AdminPageItem>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchPages(),
);

final adminEmailCategoriesProvider =
    FutureProvider<List<AdminEmailCategoryItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchEmailCategories(),
    );

final adminEmailTemplatesProvider =
    FutureProvider<List<AdminEmailTemplateItem>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchEmailTemplates(),
    );

final adminAppLogFilesProvider = FutureProvider<List<AdminLogFileItem>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchLogFiles(type: 'app'),
);

final adminLogContentProvider =
    FutureProvider.family<
      AdminLogContentSnapshot,
      ({String type, String file})
    >(
      (ref, params) => ref
          .watch(adminRepositoryProvider)
          .fetchLogContent(type: params.type, file: params.file),
    );

final adminLanguageStringsProvider =
    FutureProvider.family<List<AdminLanguageStringItem>, String>((ref, lang) {
      if (lang.trim().isEmpty) {
        return Future.value(const <AdminLanguageStringItem>[]);
      }
      return ref
          .watch(adminRepositoryProvider)
          .fetchLanguageStrings(lang: lang);
    });

final adminLanguageKeysProvider = FutureProvider<List<AdminLanguageKeyItem>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchLanguageKeys(),
);

final adminUserDetailProvider = FutureProvider.family<AdminUserDetail, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).fetchUserDetail(id),
);

final adminPermissionsProvider =
    FutureProvider<List<AdminPermissionDefinition>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchPermissions(),
    );

final adminPermissionGroupsProvider =
    FutureProvider<List<AdminPermissionGroup>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchPermissionGroups(),
    );

final adminPermissionUsersProvider =
    FutureProvider.family<
      AdminPermissionUsersSnapshot,
      ({String query, int page})
    >(
      (ref, query) => ref
          .watch(adminRepositoryProvider)
          .fetchPermissionUsers(query: query.query, page: query.page),
    );
