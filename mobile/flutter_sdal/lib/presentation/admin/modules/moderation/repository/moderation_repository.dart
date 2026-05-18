import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../features/admin/data/admin_repository.dart' as legacy;
import '../models/moderation_models.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => ModerationRepository(ref.watch(legacy.adminRepositoryProvider)),
);

class ModerationRepository {
  const ModerationRepository(this._adminRepository);

  final legacy.AdminRepository _adminRepository;

  Future<List<ModerationItem>> fetchQueue() async {
    final previews = await Future.wait([
      _adminRepository.fetchPostPreview(limit: 20),
      _adminRepository.fetchCommentPreview(limit: 20),
      _adminRepository.fetchStoryPreview(limit: 20),
      _adminRepository.fetchContentApprovalPreview(
        type: 'job',
        typeLabel: 'İş ilanı',
        limit: 20,
        query: const {'status': 'pending'},
      ),
      _adminRepository.fetchContentApprovalPreview(
        type: 'event',
        typeLabel: 'Etkinlik',
        limit: 20,
        query: const {'status': 'pending'},
      ),
    ]);
    return [
      for (final preview in previews)
        for (final item in preview.items) _fromLegacy(item),
    ];
  }

  Future<ModerationItem> lockItem(ModerationItem item) async {
    if (item.isLockedByOther) return item;
    final parts = _idParts(item.id);
    final response = await _adminRepository.lockModerationItem(
      entityType: parts.entityType,
      entityId: parts.entityId,
    );
    final rawLock = response['lock'];
    final lockMap = rawLock is Map
        ? rawLock.cast<String, Object?>()
        : const <String, Object?>{};
    final moderatorName = (lockMap['moderatorName'] ?? '').toString().trim();
    final lockedAt = DateTime.tryParse((lockMap['lockedAt'] ?? '').toString());
    return item.copyWith(
      lock: ModerationLock(
        moderatorName: moderatorName.isEmpty ? 'Mevcut Admin' : moderatorName,
        lockedAt: lockedAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> submitDecision(ModerationDecision decision) async {
    if (decision.reason.trim().length < 8) {
      throw ArgumentError('Karar gerekçesi en az 8 karakter olmalı.');
    }
    final parts = _idParts(decision.itemId);
    final typeKey = parts.entityType;
    final numericId = parts.entityId;
    switch (decision.actionType) {
      case ModerationActionType.approve:
        if (typeKey == 'job' || typeKey == 'event') {
          await _adminRepository.reviewContentApproval(
            entityType: typeKey,
            id: numericId,
            status: 'approved',
            note: decision.reason,
          );
        }
        await _adminRepository.resolveModerationItem(
          entityType: typeKey,
          entityId: numericId,
          policyCategory: policyCategoryLabel(decision.policyCategory),
          reason: decision.reason,
        );
        return;
      case ModerationActionType.removeContent:
        return _deleteByType(typeKey, numericId, decision.reason);
      case ModerationActionType.banUser:
        final item = await _findItem(decision.itemId);
        final authorUserId = item?.authorUserId ?? 0;
        if (authorUserId > 0) {
          await _adminRepository.updateUserStatus(
            id: authorUserId,
            status: 'suspended',
            reason: decision.reason,
          );
        } else {
          await _adminRepository.updateModerationAuthorStatus(
            entityType: typeKey,
            entityId: numericId,
            status: 'suspended',
            reason: decision.reason,
          );
        }
        return;
      case ModerationActionType.escalate:
        await _adminRepository.escalateModerationItem(
          entityType: typeKey,
          entityId: numericId,
          policyCategory: policyCategoryLabel(decision.policyCategory),
          reason: decision.reason,
        );
        return;
    }
  }

  ModerationItem _fromLegacy(legacy.AdminModerationItem item) {
    final type = _typeFromLabel(item.typeLabel);
    return ModerationItem(
      id: '${type.name}:${item.id}',
      type: type,
      title: item.typeLabel,
      body: item.content,
      authorUserId: item.authorUserId,
      authorName: item.authorName,
      authorRiskLabel: item.authorHandle.isEmpty
          ? 'Backend kayıt'
          : '@${item.authorHandle}',
      violationCategory: _categoryForType(type),
      severity: _severityForType(type),
      reporters: const <ModerationReporter>[],
      createdAt: DateTime.tryParse(item.createdAt) ?? DateTime.now(),
    );
  }

  ModerationContentType _typeFromLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('yorum')) return ModerationContentType.comment;
    if (normalized.contains('hikaye')) return ModerationContentType.story;
    if (normalized.contains('iş') || normalized.contains('ilan')) {
      return ModerationContentType.job;
    }
    if (normalized.contains('etkinlik')) return ModerationContentType.event;
    return ModerationContentType.post;
  }

  PolicyCategory _categoryForType(ModerationContentType type) {
    return switch (type) {
      ModerationContentType.post => PolicyCategory.spam,
      ModerationContentType.comment => PolicyCategory.harassment,
      ModerationContentType.story => PolicyCategory.inappropriateMedia,
      ModerationContentType.job => PolicyCategory.misinformation,
      ModerationContentType.event => PolicyCategory.misinformation,
    };
  }

  ModerationSeverity _severityForType(ModerationContentType type) {
    return switch (type) {
      ModerationContentType.post => ModerationSeverity.medium,
      ModerationContentType.comment => ModerationSeverity.high,
      ModerationContentType.story => ModerationSeverity.medium,
      ModerationContentType.job => ModerationSeverity.low,
      ModerationContentType.event => ModerationSeverity.low,
    };
  }

  Future<void> _deleteByType(String typeKey, int numericId, String reason) {
    return switch (typeKey) {
      'comment' => _adminRepository.deleteComment(numericId, reason: reason),
      'story' => _adminRepository.deleteStory(numericId, reason: reason),
      'job' => _adminRepository.reviewContentApproval(
        entityType: 'job',
        id: numericId,
        status: 'rejected',
        note: reason,
      ),
      'event' => _adminRepository.reviewContentApproval(
        entityType: 'event',
        id: numericId,
        status: 'rejected',
        note: reason,
      ),
      _ => _adminRepository.deletePost(numericId, reason: reason),
    };
  }

  ({String entityType, int entityId}) _idParts(String rawId) {
    final parts = rawId.split(':');
    final entityType = parts.length == 2 ? parts.first : 'post';
    final entityId = int.tryParse(parts.length == 2 ? parts.last : rawId) ?? 0;
    if (entityId <= 0) throw ArgumentError('Geçersiz moderasyon kaydı.');
    return (entityType: entityType, entityId: entityId);
  }

  Future<ModerationItem?> _findItem(String itemId) async {
    final items = await fetchQueue();
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }
}
