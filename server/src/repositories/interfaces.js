function notImplemented(name) {
  throw new Error(`${name} is not implemented`);
}

export class UserRepository {
  findById(_id) { return notImplemented('UserRepository.findById'); }
  findByUsername(_username) { return notImplemented('UserRepository.findByUsername'); }
  updatePasswordHash(_id, _passwordHash) { return notImplemented('UserRepository.updatePasswordHash'); }
  setOnlineStatus(_id, _online) { return notImplemented('UserRepository.setOnlineStatus'); }
  findGraduationYearById(_id) { return notImplemented('UserRepository.findGraduationYearById'); }
}

export class ProfileRepository {
  findByUserId(_userId) { return notImplemented('ProfileRepository.findByUserId'); }
}

export class FeedRepository {
  findFeedPage(_query) { return notImplemented('FeedRepository.findFeedPage'); }
}

export class PostRepository {
  createPost(_input) { return notImplemented('PostRepository.createPost'); }
  findById(_postId) { return notImplemented('PostRepository.findById'); }
  listComments(_postId) { return notImplemented('PostRepository.listComments'); }
  createComment(_input) { return notImplemented('PostRepository.createComment'); }
  findLike(_postId, _userId) { return notImplemented('PostRepository.findLike'); }
  deleteLikeById(_likeId) { return notImplemented('PostRepository.deleteLikeById'); }
  createLike(_input) { return notImplemented('PostRepository.createLike'); }
}

export class StoryRepository {
  findActiveStories(_query) { return notImplemented('StoryRepository.findActiveStories'); }
}

export class ConversationRepository {
  findThreadById(_threadId) { return notImplemented('ConversationRepository.findThreadById'); }
}

export class MessageRepository {
  listMessages(_query) { return notImplemented('MessageRepository.listMessages'); }
  findMessageById(_messageId) { return notImplemented('MessageRepository.findMessageById'); }
  createMessage(_input) { return notImplemented('MessageRepository.createMessage'); }
  updateMessage(_messageId, _body) { return notImplemented('MessageRepository.updateMessage'); }
  deleteMessage(_messageId) { return notImplemented('MessageRepository.deleteMessage'); }
}

export class NotificationRepository {
  listForUser(_query) { return notImplemented('NotificationRepository.listForUser'); }
}

export class GroupRepository {
  findById(_groupId) { return notImplemented('GroupRepository.findById'); }
  findByName(_name) { return notImplemented('GroupRepository.findByName'); }
  findMember(_groupId, _userId) { return notImplemented('GroupRepository.findMember'); }
}

export class EventRepository {
  listEvents(_query) { return notImplemented('EventRepository.listEvents'); }
}

export class AnnouncementRepository {
  listAnnouncements(_query) { return notImplemented('AnnouncementRepository.listAnnouncements'); }
}

export class JobRepository {
  listJobs(_query) { return notImplemented('JobRepository.listJobs'); }
}

export class AdminRepository {
  findUserRoleTarget(_userId) { return notImplemented('AdminRepository.findUserRoleTarget'); }
  updateUserRole(_query) { return notImplemented('AdminRepository.updateUserRole'); }
}

export class MediaRepository {
  findById(_id) { return notImplemented('MediaRepository.findById'); }
}
