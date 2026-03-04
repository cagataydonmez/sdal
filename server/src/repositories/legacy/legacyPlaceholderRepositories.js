import {
  ProfileRepository,
  StoryRepository,
  ConversationRepository,
  NotificationRepository,
  EventRepository,
  AnnouncementRepository,
  JobRepository,
  MediaRepository
} from '../interfaces.js';

export class LegacyProfileRepository extends ProfileRepository {
  findByUserId() { return null; }
}

export class LegacyStoryRepository extends StoryRepository {
  findActiveStories() { return []; }
}

export class LegacyConversationRepository extends ConversationRepository {
  findThreadById() { return null; }
}

export class LegacyNotificationRepository extends NotificationRepository {
  listForUser() { return []; }
}

export class LegacyEventRepository extends EventRepository {
  listEvents() { return []; }
}

export class LegacyAnnouncementRepository extends AnnouncementRepository {
  listAnnouncements() { return []; }
}

export class LegacyJobRepository extends JobRepository {
  listJobs() { return []; }
}

export class LegacyMediaRepository extends MediaRepository {
  findById() { return null; }
}
