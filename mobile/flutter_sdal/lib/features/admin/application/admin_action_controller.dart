import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../data/admin_repository.dart';

class AdminActionController extends Notifier<AsyncActionState> {
  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  bool _begin(String scope) {
    if (state.isLoading) return false;
    state = AsyncActionState.loading(scope: scope);
    return true;
  }

  Future<bool> deleteContent({
    required String type,
    required int id,
    String reason = '',
  }) async {
    final scope = 'admin:$type:delete:$id';
    if (!_begin(scope)) return false;
    try {
      switch (type) {
        case 'post':
          await _repository.deletePost(id, reason: reason);
          break;
        case 'comment':
          await _repository.deleteComment(id, reason: reason);
          break;
        case 'story':
          await _repository.deleteStory(id, reason: reason);
          break;
        case 'group':
          await _repository.deleteGroup(id, reason: reason);
          break;
        case 'album_photo':
          await _repository.deleteAlbumPhoto(id);
          break;
        case 'chat_message':
          await _repository.deleteChatMessage(id);
          break;
        case 'direct_message':
          await _repository.deleteDirectMessage(id);
          break;
        case 'follow':
          await _repository.deleteFollow(id);
          break;
        default:
          throw StateError('Unsupported admin content type: $type');
      }
      _invalidateContentPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> reviewMemberRequest({
    required int id,
    required String status,
    String graduationYearOverride = '',
  }) async {
    final scope = 'admin:request:review:$id:$status';
    if (!_begin(scope)) return false;
    try {
      await _repository.reviewMemberRequest(
        id: id,
        status: status,
        graduationYearOverride: graduationYearOverride,
      );
      _invalidateRequestPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> reviewVerificationRequest({
    required int id,
    required String status,
  }) async {
    final scope = 'admin:verification:review:$id:$status';
    if (!_begin(scope)) return false;
    try {
      await _repository.reviewVerificationRequest(id: id, status: status);
      _invalidateRequestPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> reviewTeacherNetworkLink({
    required int id,
    required String status,
    String note = '',
  }) async {
    final scope = 'admin:teacher-network:review:$id:$status';
    if (!_begin(scope)) return false;
    try {
      await _repository.reviewTeacherNetworkLink(
        id: id,
        status: status,
        note: note,
      );
      _invalidateRequestPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updatePushSettings({required bool enabled}) async {
    final scope = 'admin:notifications:push';
    if (!_begin(scope)) return false;
    try {
      await _repository.updatePushSettings(enabled: enabled);
      _invalidateNotificationPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateAuthSettings({
    required bool smsVerificationEnabled,
  }) async {
    const scope = 'admin:auth-settings';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateAuthSettings(
        smsVerificationEnabled: smsVerificationEnabled,
      );
      ref.invalidate(adminAuthSettingsProvider);
      ref.invalidate(adminAuthSecurityProvider);
      state = const AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<AdminBroadcastResult?> sendNotificationBroadcast({
    required String target,
    required String sender,
    required String title,
    required String body,
    String imageUrl = '',
    String imageShape = 'rounded',
    String targetRoute = '',
    String targetLabel = '',
  }) async {
    final scope = 'admin:notifications:broadcast';
    if (!_begin(scope)) return null;
    try {
      final result = await _repository.sendNotificationBroadcast(
        target: target,
        sender: sender,
        title: title,
        body: body,
        imageUrl: imageUrl,
        imageShape: imageShape,
        targetRoute: targetRoute,
        targetLabel: targetLabel,
      );
      _invalidateNotificationPreviews();
      state = AsyncActionState.success(scope: scope);
      return result;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return null;
    }
  }

  Future<bool> deleteMember({required int id}) async {
    final scope = 'admin:member:delete:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.deleteMember(id);
      _invalidateManagementPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateGraduationYear({
    required int id,
    required String graduationYear,
  }) async {
    final scope = 'admin:member:graduation:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateGraduationYear(
        id: id,
        graduationYear: graduationYear,
      );
      _invalidateManagementPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateUserRole({
    required int id,
    required String role,
    required String reason,
  }) async {
    final scope = 'admin:member:role:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateUserRole(id: id, role: role, reason: reason);
      _invalidateManagementPreviews();
      ref.invalidate(adminEffectiveAccessProvider);
      ref.invalidate(adminMobileSummaryProvider);
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateUserStatus({
    required int id,
    required String status,
    required String reason,
  }) async {
    final scope = 'admin:member:status:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateUserStatus(
        id: id,
        status: status,
        reason: reason,
      );
      _invalidateManagementPreviews();
      ref.invalidate(adminMobileSummaryProvider);
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> resendVerificationNotification({required int id}) async {
    final scope = 'admin:verification:resend:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.resendVerificationNotification(id: id);
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateVerificationSettings({
    required String type,
    required bool verificationRequired,
  }) async {
    final scope = 'admin:verification-settings:$type';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateVerificationSettings(
        type: type,
        verificationRequired: verificationRequired,
      );
      ref.invalidate(adminVerificationSettingsProvider);
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> verifyUserManually({required int userId}) async {
    final scope = 'admin:user:manual-verify:$userId';
    if (!_begin(scope)) return false;
    try {
      await _repository.verifyUserManually(userId: userId);
      _invalidateManagementPreviews();
      ref.invalidate(adminUserDetailProvider(userId));
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateSiteOpen({
    required bool siteOpen,
    String maintenanceMessage = '',
  }) async {
    final scope = 'admin:site-controls';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateSiteControls(
        siteOpen: siteOpen,
        maintenanceMessage: maintenanceMessage,
      );
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> createDbBackup({String label = 'manual'}) async {
    final scope = 'admin:db:backup';
    if (!_begin(scope)) return false;
    try {
      await _repository.createDbBackup(label: label);
      _invalidateDatabasePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> copyDbData({
    required String sourceDriver,
    required String targetDriver,
  }) async {
    final scope = 'admin:db:copy:$sourceDriver:$targetDriver';
    if (!_begin(scope)) return false;
    try {
      await _repository.copyDbData(
        sourceDriver: sourceDriver,
        targetDriver: targetDriver,
      );
      _invalidateDatabasePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> switchDbDriver({
    required String targetDriver,
    required String confirmText,
    required String challengeToken,
    bool acknowledgeSqliteDrift = false,
    bool copyData = false,
  }) async {
    final scope = 'admin:db:switch:$targetDriver';
    if (!_begin(scope)) return false;
    try {
      await _repository.switchDbDriver(
        targetDriver: targetDriver,
        confirmText: confirmText,
        challengeToken: challengeToken,
        acknowledgeSqliteDrift: acknowledgeSqliteDrift,
        copyData: copyData,
      );
      _invalidateDatabasePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> restoreDbBackupByName({required String name}) async {
    final scope = 'admin:db:restore:$name';
    if (!_begin(scope)) return false;
    try {
      await _repository.restoreDbBackupByName(name);
      _invalidateDatabasePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> addLanguage({
    required String code,
    required String name,
    required String nativeName,
  }) async {
    final scope = 'admin:language:add:$code';
    if (!_begin(scope)) return false;
    try {
      await _repository.addLanguage(
        code: code,
        name: name,
        nativeName: nativeName,
      );
      _invalidateLanguagePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> toggleLanguageActive({required AdminLanguageItem item}) async {
    final scope = 'admin:language:toggle:${item.code}';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateLanguage(
        code: item.code,
        name: item.name,
        nativeName: item.nativeName,
        isActive: !item.isActive,
      );
      _invalidateLanguagePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> deleteLanguage({required String code}) async {
    final scope = 'admin:language:delete:$code';
    if (!_begin(scope)) return false;
    try {
      await _repository.deleteLanguage(code);
      _invalidateLanguagePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateLanguageSelection({
    required bool enabled,
    required String defaultOpen,
    required String defaultClosed,
  }) async {
    final scope = 'admin:language:config';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateLanguageConfig(
        selectionEnabled: enabled,
        defaultOpen: defaultOpen,
        defaultClosed: defaultClosed,
      );
      _invalidateLanguagePreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> addPage({
    required String name,
    required String url,
    String icon = 'yok',
    int parentId = 0,
    bool menuVisible = true,
    bool isRedirect = false,
    int layoutOption = 0,
  }) async {
    final scope = 'admin:page:add';
    if (!_begin(scope)) return false;
    try {
      await _repository.addPage(
        name: name,
        url: url,
        icon: icon,
        parentId: parentId,
        menuVisible: menuVisible,
        isRedirect: isRedirect,
        layoutOption: layoutOption,
      );
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updatePage({
    required int id,
    required String name,
    required String url,
    required String icon,
    required int parentId,
    required bool menuVisible,
    required bool isRedirect,
    required int layoutOption,
  }) async {
    final scope = 'admin:page:update:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.updatePage(
        id: id,
        name: name,
        url: url,
        icon: icon,
        parentId: parentId,
        menuVisible: menuVisible,
        isRedirect: isRedirect,
        layoutOption: layoutOption,
      );
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> reorderPages({required List<int> order}) async {
    final scope = 'admin:page:reorder';
    if (!_begin(scope)) return false;
    try {
      await _repository.reorderPages(order);
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> deletePage({required int id}) async {
    final scope = 'admin:page:delete:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.deletePage(id);
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> addEmailCategory({
    required String name,
    required String type,
    String value = '',
    String description = '',
  }) async {
    final scope = 'admin:email-category:add';
    if (!_begin(scope)) return false;
    try {
      await _repository.addEmailCategory(
        name: name,
        type: type,
        value: value,
        description: description,
      );
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> deleteEmailCategory({required int id}) async {
    final scope = 'admin:email-category:delete:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.deleteEmailCategory(id);
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> addEmailTemplate({
    required String name,
    required String subject,
    required String bodyHtml,
  }) async {
    final scope = 'admin:email-template:add';
    if (!_begin(scope)) return false;
    try {
      await _repository.addEmailTemplate(
        name: name,
        subject: subject,
        bodyHtml: bodyHtml,
      );
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateEmailTemplate({
    required int id,
    required String name,
    required String subject,
    required String bodyHtml,
  }) async {
    final scope = 'admin:email-template:update:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateEmailTemplate(
        id: id,
        name: name,
        subject: subject,
        bodyHtml: bodyHtml,
      );
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> deleteEmailTemplate({required int id}) async {
    final scope = 'admin:email-template:delete:$id';
    if (!_begin(scope)) return false;
    try {
      await _repository.deleteEmailTemplate(id);
      _invalidateOperationsPreviews();
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> sendBulkEmail({
    required int categoryId,
    required String subject,
    required String html,
    String from = '',
  }) async {
    final scope = 'admin:email:bulk:$categoryId';
    if (!_begin(scope)) return false;
    try {
      await _repository.sendBulkEmail(
        categoryId: categoryId,
        subject: subject,
        html: html,
        from: from,
      );
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> saveLanguageString({
    required String lang,
    required String key,
    required String value,
  }) async {
    final scope = 'admin:language-string:$lang:$key';
    if (!_begin(scope)) return false;
    try {
      await _repository.saveLanguageString(lang: lang, key: key, value: value);
      _invalidateLanguagePreviews();
      ref.invalidate(adminLanguageStringsProvider(lang));
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> fillMissingLanguageStrings({required String lang}) async {
    final scope = 'admin:language-fill:$lang';
    if (!_begin(scope)) return false;
    try {
      await _repository.fillMissingLanguageStrings(lang);
      _invalidateLanguagePreviews();
      ref.invalidate(adminLanguageStringsProvider(lang));
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> bulkImportLanguageStrings({
    required String lang,
    required Map<String, String> strings,
  }) async {
    final scope = 'admin:language:bulk:$lang';
    if (!_begin(scope)) return false;
    try {
      await _repository.bulkImportLanguageStrings(lang: lang, strings: strings);
      _invalidateLanguagePreviews();
      ref.invalidate(adminLanguageStringsProvider(lang));
      ref.invalidate(adminLanguageKeysProvider);
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> deleteLanguageKey({required String key}) async {
    final scope = 'admin:language:key-delete:$key';
    if (!_begin(scope)) return false;
    try {
      await _repository.deleteLanguageKey(key);
      _invalidateLanguagePreviews();
      ref.invalidate(adminLanguageKeysProvider);
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  Future<bool> updateUserDetail({required AdminUserDetail detail}) async {
    final scope = 'admin:user:update:${detail.id}';
    if (!_begin(scope)) return false;
    try {
      await _repository.updateUserDetail(detail);
      _invalidateManagementPreviews();
      ref.invalidate(adminUserDetailProvider(detail.id));
      state = AsyncActionState.success(scope: scope);
      return true;
    } catch (error) {
      state = AsyncActionState.error(scope: scope, message: error.toString());
      return false;
    }
  }

  void reset() {
    state = const AsyncActionState.idle();
  }

  void _invalidateContentPreviews() {
    ref.invalidate(adminPostPreviewProvider);
    ref.invalidate(adminCommentPreviewProvider);
    ref.invalidate(adminStoryPreviewProvider);
    ref.invalidate(adminAppModuleContentProvider);
    ref.invalidate(adminSummaryProvider);
    ref.invalidate(adminLiveProvider);
  }

  void _invalidateRequestPreviews() {
    ref.invalidate(adminMemberRequestPreviewProvider);
    ref.invalidate(adminVerificationRequestPreviewProvider);
    ref.invalidate(adminApprovedVerificationRequestPreviewProvider);
    ref.invalidate(adminTeacherNetworkLinkPreviewProvider);
    ref.invalidate(adminRequestNotificationsProvider);
    ref.invalidate(adminSummaryProvider);
    ref.invalidate(adminLiveProvider);
  }

  void _invalidateManagementPreviews() {
    ref.invalidate(adminUserPreviewProvider);
    ref.invalidate(adminSummaryProvider);
    ref.invalidate(adminLiveProvider);
  }

  void _invalidateOperationsPreviews() {
    ref.invalidate(adminSiteControlsProvider);
    ref.invalidate(adminPagesProvider);
    ref.invalidate(adminEmailCategoriesProvider);
    ref.invalidate(adminEmailTemplatesProvider);
    ref.invalidate(adminAppLogFilesProvider);
    ref.invalidate(adminSummaryProvider);
  }

  void _invalidateNotificationPreviews() {
    ref.invalidate(adminNotificationOpsProvider);
    ref.invalidate(adminPushSettingsProvider);
    ref.invalidate(adminBroadcastHistoryProvider);
  }

  void _invalidateDatabasePreviews() {
    ref.invalidate(adminDbBackupsProvider);
    ref.invalidate(adminDbDriverStatusProvider);
  }

  void _invalidateLanguagePreviews() {
    ref.invalidate(adminLanguagesProvider);
    ref.invalidate(adminLanguageConfigProvider);
  }
}

final adminActionControllerProvider =
    NotifierProvider.autoDispose<AdminActionController, AsyncActionState>(
      AdminActionController.new,
    );
