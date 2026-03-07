import { LegacyUserRepository } from '../repositories/legacy/legacyUserRepository.js';
import { LegacyGroupRepository } from '../repositories/legacy/legacyGroupRepository.js';
import { LegacyFeedRepository } from '../repositories/legacy/legacyFeedRepository.js';
import { LegacyPostRepository } from '../repositories/legacy/legacyPostRepository.js';
import { LegacyChatRepository } from '../repositories/legacy/legacyChatRepository.js';
import { LegacyAdminRepository } from '../repositories/legacy/legacyAdminRepository.js';
import {
  LegacyProfileRepository,
  LegacyStoryRepository,
  LegacyConversationRepository,
  LegacyNotificationRepository,
  LegacyEventRepository,
  LegacyAnnouncementRepository,
  LegacyJobRepository,
  LegacyMediaRepository
} from '../repositories/legacy/legacyPlaceholderRepositories.js';
import { AuthService } from '../services/authService.js';
import { FeedService } from '../services/feedService.js';
import { PostService } from '../services/postService.js';
import { ChatService } from '../services/chatService.js';
import { AdminService } from '../services/adminService.js';
import { createAuthController } from '../http/controllers/authController.js';
import { createFeedController } from '../http/controllers/feedController.js';
import { createPostController } from '../http/controllers/postController.js';
import { createChatController } from '../http/controllers/chatController.js';
import { createAdminController } from '../http/controllers/adminController.js';

export function createPhase1DomainLayer(deps) {
  const repositories = {
    users: new LegacyUserRepository({
      sqlGet: deps.sqlGet,
      sqlRun: deps.sqlRun,
      sqlGetAsync: deps.sqlGetAsync,
      sqlRunAsync: deps.sqlRunAsync,
      isPostgresDb: deps.isPostgresDb
    }),
    profiles: new LegacyProfileRepository(),
    feeds: new LegacyFeedRepository({
      sqlAll: deps.sqlAll,
      sqlAllAsync: deps.sqlAllAsync,
      isPostgresDb: deps.isPostgresDb,
      joinUserOnPostAuthorExpr: deps.joinUserOnPostAuthorExpr
    }),
    posts: new LegacyPostRepository({
      sqlGet: deps.sqlGet,
      sqlAll: deps.sqlAll,
      sqlRun: deps.sqlRun,
      sqlGetAsync: deps.sqlGetAsync,
      sqlAllAsync: deps.sqlAllAsync,
      sqlRunAsync: deps.sqlRunAsync,
      isPostgresDb: deps.isPostgresDb
    }),
    stories: new LegacyStoryRepository(),
    conversations: new LegacyConversationRepository(),
    messages: new LegacyChatRepository({
      sqlGet: deps.sqlGet,
      sqlAll: deps.sqlAll,
      sqlRun: deps.sqlRun,
      sqlGetAsync: deps.sqlGetAsync,
      sqlAllAsync: deps.sqlAllAsync,
      sqlRunAsync: deps.sqlRunAsync,
      isPostgresDb: deps.isPostgresDb
    }),
    notifications: new LegacyNotificationRepository(),
    groups: new LegacyGroupRepository({
      sqlGet: deps.sqlGet,
      sqlGetAsync: deps.sqlGetAsync,
      isPostgresDb: deps.isPostgresDb
    }),
    events: new LegacyEventRepository(),
    announcements: new LegacyAnnouncementRepository(),
    jobs: new LegacyJobRepository(),
    media: new LegacyMediaRepository(),
    admin: new LegacyAdminRepository({ sqlGet: deps.sqlGet, sqlRun: deps.sqlRun })
  };

  const rolePolicy = {
    normalizeRole: deps.normalizeRole,
    roleAtLeast: deps.roleAtLeast,
    getUserRole: deps.getUserRole,
    hasAdminRole: deps.hasAdminRole
  };

  const services = {
    auth: new AuthService({
      userRepository: repositories.users,
      verifyPassword: deps.verifyPassword,
      hashPassword: deps.hashPassword,
      rolePolicy
    }),
    feed: new FeedService({
      userRepository: repositories.users,
      groupRepository: repositories.groups,
      feedRepository: repositories.feeds
    }),
    posts: new PostService({
      postRepository: repositories.posts,
      groupRepository: repositories.groups
    }),
    chat: new ChatService({
      messageRepository: repositories.messages
    }),
    admin: new AdminService({
      adminRepository: repositories.admin,
      rolePolicy
    })
  };

  const controllers = {
    auth: createAuthController({
      authService: services.auth,
      applyUserSession: deps.applyUserSession
    }),
    feed: createFeedController({
      feedService: services.feed,
      enrichWithVariants: deps.enrichWithVariants,
      getImageVariants: deps.getImageVariants,
      getImageVariantsBatch: deps.getImageVariantsBatch,
      sqlGet: deps.sqlGet,
      sqlAll: deps.sqlAllAsync || deps.sqlAll,
      uploadsDir: deps.uploadsDir,
      getModuleControlMap: deps.getModuleControlMap,
      buildFeedCacheKey: deps.buildFeedCacheKey,
      getCacheJson: deps.getCacheJson,
      setCacheJson: deps.setCacheJson,
      feedCacheTtlSeconds: deps.feedCacheTtlSeconds
    }),
    posts: createPostController({
      postService: services.posts,
      formatUserText: deps.formatUserText,
      isFormattedContentEmpty: deps.isFormattedContentEmpty,
      getCurrentUser: deps.getCurrentUser,
      hasAdminRole: deps.hasAdminRole,
      notifyMentions: deps.notifyMentions,
      addNotification: deps.addNotification,
      scheduleEngagementRecalculation: deps.scheduleEngagementRecalculation,
      invalidateFeedCache: deps.invalidateFeedCache
    }),
    chat: createChatController({
      chatService: services.chat,
      formatUserText: deps.formatUserText,
      isFormattedContentEmpty: deps.isFormattedContentEmpty,
      canManageChatMessage: deps.canManageChatMessage,
      broadcastChatMessage: deps.broadcastChatMessage,
      broadcastChatUpdate: deps.broadcastChatUpdate,
      broadcastChatDelete: deps.broadcastChatDelete,
      scheduleEngagementRecalculation: deps.scheduleEngagementRecalculation
    }),
    admin: createAdminController({
      adminService: services.admin,
      rolePolicy,
      replaceModeratorPermissions: deps.replaceModeratorPermissions,
      moderationPermissionKeys: deps.moderationPermissionKeys,
      writeAuditLog: deps.writeAuditLog
    })
  };

  return {
    repositories,
    services,
    controllers
  };
}
