function notImplemented(name) {
  throw new Error(`${name} is not implemented`);
}

export class UserService {
  getUser(_id) { return notImplemented('UserService.getUser'); }
}

export class ProfileService {
  getProfile(_userId) { return notImplemented('ProfileService.getProfile'); }
}

export class FeedService {
  findFeedPage(_input) { return notImplemented('FeedService.findFeedPage'); }
}

export class PostService {
  createPost(_input) { return notImplemented('PostService.createPost'); }
  listPostComments(_input) { return notImplemented('PostService.listPostComments'); }
  createPostComment(_input) { return notImplemented('PostService.createPostComment'); }
  togglePostLike(_input) { return notImplemented('PostService.togglePostLike'); }
}

export class StoryService {
  listStories(_input) { return notImplemented('StoryService.listStories'); }
}

export class ConversationService {
  getConversation(_id) { return notImplemented('ConversationService.getConversation'); }
}

export class MessageService {
  listMessages(_input) { return notImplemented('MessageService.listMessages'); }
  sendMessage(_input) { return notImplemented('MessageService.sendMessage'); }
}

export class NotificationService {
  listNotifications(_input) { return notImplemented('NotificationService.listNotifications'); }
}

export class GroupService {
  getGroup(_id) { return notImplemented('GroupService.getGroup'); }
}

export class EventService {
  listEvents(_input) { return notImplemented('EventService.listEvents'); }
}

export class AnnouncementService {
  listAnnouncements(_input) { return notImplemented('AnnouncementService.listAnnouncements'); }
}

export class JobService {
  listJobs(_input) { return notImplemented('JobService.listJobs'); }
}

export class MediaService {
  getAsset(_id) { return notImplemented('MediaService.getAsset'); }
}

export class AdminService {
  updateUserRole(_input) { return notImplemented('AdminService.updateUserRole'); }
}
