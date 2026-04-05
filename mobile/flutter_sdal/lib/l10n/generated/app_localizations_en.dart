// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SDAL';

  @override
  String get appInitFailedTitle => 'Could not start';

  @override
  String get retry => 'Retry';

  @override
  String get siteClosedTitle => 'SDAL is currently closed';

  @override
  String get siteClosedFallbackMessage =>
      'The app is temporarily unavailable due to maintenance.';

  @override
  String get moduleClosedTitle => 'Module unavailable';

  @override
  String get moduleClosedDefaultMessage =>
      'This feature is currently unavailable.';

  @override
  String moduleClosedWithName(Object module) {
    return 'The $module module has been temporarily disabled.';
  }

  @override
  String get accountBannedTitle => 'Account access disabled';

  @override
  String get accountBannedMessage =>
      'This account is banned, so actions are disabled in the app. Contact SDAL support for help.';

  @override
  String get verificationRequiredTitle => 'Verification required';

  @override
  String verificationRequiredMessage(Object feature) {
    return 'Profile verification is required for $feature features. You can submit a request from your profile.';
  }

  @override
  String get splashLoading => 'Loading...';

  @override
  String get splashPreparing => 'Preparing SDAL';

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabInbox => 'Inbox';

  @override
  String get tabNotifications => 'Alerts';

  @override
  String get tabProfile => 'Profile';

  @override
  String get loginTitle => 'SDAL';

  @override
  String get loginSubtitle => 'Sign in to the new Flutter iOS client.';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle =>
      'Create an account from the new Flutter client for V1.';

  @override
  String get activationTitle => 'Activation';

  @override
  String get activationSubtitle =>
      'Complete the flow here if the e-mail link opened the iOS app.';

  @override
  String get resendActivationTitle => 'Resend activation';

  @override
  String get resendActivationSubtitle =>
      'Support screen for the legacy membership activation flow.';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordSubtitle =>
      'Uses the legacy SDAL account recovery endpoint.';

  @override
  String get oauthTitle => 'OAuth';

  @override
  String get oauthSubtitle => 'This screen usually appears only briefly.';

  @override
  String get oauthInfoMessage =>
      'The session opens automatically when the browser flow returns to the app.';

  @override
  String get register => 'Create account';

  @override
  String get resendActivation => 'Resend activation';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get email => 'E-mail';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get captionLabel => 'Caption';

  @override
  String get memberId => 'Member ID';

  @override
  String get activationCode => 'Activation code';

  @override
  String get captchaCode => 'Captcha code';

  @override
  String get graduationYear => 'Graduation year / Teacher';

  @override
  String get passwordRepeat => 'Repeat password';

  @override
  String get loginInProgress => 'Signing in...';

  @override
  String get loginAction => 'Sign in';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithX => 'Continue with X';

  @override
  String get submitInProgress => 'Submitting...';

  @override
  String get registerSubmitAction => 'Submit registration';

  @override
  String get resendAction => 'Resend';

  @override
  String get passwordResetSubmitAction => 'Send reset request';

  @override
  String get activationSubmitAction => 'Complete activation';

  @override
  String get activationChecking => 'Checking...';

  @override
  String get feedTitle => 'Main feed';

  @override
  String get feedRefresh => 'Refresh';

  @override
  String get feedPostAction => 'Post';

  @override
  String get feedEmptyContent => 'This post has no content.';

  @override
  String get feedComposerTitle => 'New post';

  @override
  String get feedComposerHint => 'What would you like to share?';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get shareInProgress => 'Sharing...';

  @override
  String get shareAction => 'Share';

  @override
  String get postShared => 'Post shared.';

  @override
  String get postShareFailed => 'Post could not be shared.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsUnreadLoading => 'Loading unread count...';

  @override
  String notificationsUnreadCount(Object count) {
    return 'Unread notifications: $count';
  }

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsUpdatedAllRead => 'Notifications marked as read.';

  @override
  String get notificationsActionFailed => 'The action failed.';

  @override
  String get notificationsPreferencesUpdated =>
      'Notification preferences updated.';

  @override
  String get notificationsPreferencesFailed =>
      'Preferences could not be saved.';

  @override
  String get notificationsInboxTitle => 'Inbox';

  @override
  String get notificationsEmpty => 'No notifications yet.';

  @override
  String get notificationsReadAction => 'Read';

  @override
  String get openAction => 'Open';

  @override
  String get notificationOpenedFailed => 'Notification could not be opened.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMissing => 'Profile data could not be found.';

  @override
  String get profileVerified => 'Verified';

  @override
  String get profilePendingVerification => 'Verification pending';

  @override
  String get profilePhotoAction => 'Photo';

  @override
  String get profileVerificationAction => 'Verification';

  @override
  String get profileAccountDetailsTitle => 'Account details';

  @override
  String get editAction => 'Edit';

  @override
  String get profileAccountActionsTitle => 'Account actions';

  @override
  String get changeEmailAction => 'Change e-mail';

  @override
  String get changePasswordAction => 'Change password';

  @override
  String get logoutAction => 'Sign out';

  @override
  String get profileVerificationPageTitle => 'Profile verification';

  @override
  String get statusLabel => 'Status';

  @override
  String get profileVerifiedMessage => 'Your profile already appears verified.';

  @override
  String get profileVerificationHint =>
      'Verification is required for networking and some social features. You can upload an image that shows your identity or school connection.';

  @override
  String get proofUploadTitle => 'Upload proof';

  @override
  String get proofUploadHint => 'Pick an image from your gallery or camera.';

  @override
  String proofSelectedFile(Object fileName) {
    return 'Selected file: $fileName';
  }

  @override
  String get proofReady => 'Uploaded proof is ready.';

  @override
  String get cameraAction => 'Camera';

  @override
  String get proofUploadInProgress => 'Uploading proof...';

  @override
  String get proofUploadAction => 'Upload proof';

  @override
  String get proofRequestTitle => 'Submit request';

  @override
  String get proofRequestHint =>
      'You can upload proof first or send only the verification request.';

  @override
  String get verificationSubmitInProgress => 'Submitting...';

  @override
  String get verificationSubmitAction => 'Submit verification request';

  @override
  String get proofUploadFailed => 'Proof could not be uploaded.';

  @override
  String get proofUploaded => 'Proof file uploaded.';

  @override
  String get verificationSubmitted => 'Verification request submitted.';

  @override
  String get verificationSubmitFailed => 'Request could not be submitted.';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get newChatAction => 'New chat';

  @override
  String get searchPeopleHint => 'Search people or usernames';

  @override
  String get noThreads =>
      'No conversations yet. Use the button in the lower-right corner to start one.';

  @override
  String get startNewChat => 'Start a new chat';

  @override
  String get newChatTitle => 'New chat';

  @override
  String get searchPersonHint => 'Search person';

  @override
  String get searchPrompt => 'Enter a username or name.';

  @override
  String get searchNoResults => 'No matching person found.';

  @override
  String get threadFallbackTitle => 'Chat';

  @override
  String get realtimeConnected => 'Live';

  @override
  String get realtimeReconnecting => 'Reconnecting';

  @override
  String get realtimeFailed => 'Offline';

  @override
  String get realtimeConnecting => 'Connecting';

  @override
  String get realtimeDisconnected => 'Closed';

  @override
  String get threadEmpty => 'No messages yet. Send the first one.';

  @override
  String get messageFieldLabel => 'Message';

  @override
  String get messageSendAction => 'Send';

  @override
  String get messageSendInProgress => 'Sending...';

  @override
  String get messageSendFailed => 'Message could not be sent.';

  @override
  String get themeModeTitle => 'Appearance';

  @override
  String get themeModeHelper =>
      'Follow the system setting or choose a persistent appearance for the app.';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get saveAction => 'Save';

  @override
  String get createAction => 'Create';

  @override
  String get deleteAction => 'Delete';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsNewGroupAction => 'New group';

  @override
  String get groupsOpenAction => 'Open';

  @override
  String get groupsLeaveAction => 'Leave';

  @override
  String get groupsWithdrawRequestAction => 'Withdraw request';

  @override
  String get groupsAcceptInviteAction => 'Accept invite';

  @override
  String get groupsJoinAction => 'Join';

  @override
  String get groupsPendingApproval => 'Awaiting approval';

  @override
  String get groupsInvitePending => 'Invite pending';

  @override
  String get groupsNewGroupTitle => 'New group';

  @override
  String get groupsNameLabel => 'Group name';

  @override
  String get groupsDescriptionLabel => 'Description';

  @override
  String get groupsCreating => 'Creating...';

  @override
  String groupsMembersCount(Object count) {
    return '$count members';
  }

  @override
  String get storiesTitle => 'Stories';

  @override
  String get storiesEmpty => 'No active stories yet.';

  @override
  String get storiesUploadAction => 'Add story';

  @override
  String get storiesUploadHint => 'Visible for 24 hours';

  @override
  String get storiesPublishAction => 'Share story';

  @override
  String get storiesViewed => 'Viewed';

  @override
  String storiesNewCount(Object count) {
    return '$count new';
  }

  @override
  String get storiesNewStoryTitle => 'New story';

  @override
  String get storiesEditTitleAction => 'Edit title';

  @override
  String get storiesDeleteAction => 'Delete story';

  @override
  String get storiesRepostAction => 'Share again';

  @override
  String get storiesCaptionDialogTitle => 'Story title';

  @override
  String get storiesCaptionHint => 'Add a short caption';

  @override
  String get storiesDeleteConfirmTitle => 'Delete this story?';

  @override
  String storiesViewStorySemantic(Object name) {
    return 'Open story from $name';
  }

  @override
  String get storiesPreviousStoryHint => 'Open the previous story';

  @override
  String get storiesNextStoryHint => 'Open the next story';

  @override
  String get liveChatTitle => 'Live chat';

  @override
  String get liveChatConnected => 'Live connection is active';

  @override
  String get liveChatReconnecting => 'Reconnecting...';

  @override
  String get liveChatComposerHint => 'Write your message';

  @override
  String get liveChatEditMessageAction => 'Edit message';

  @override
  String get liveChatDeleteMessageAction => 'Delete message';

  @override
  String get liveChatEditDialogTitle => 'Edit message';

  @override
  String get groupDetailTitle => 'Group details';

  @override
  String get groupNotFound => 'Group not found.';

  @override
  String get groupVisibilityPrivate => 'Private';

  @override
  String get groupVisibilityPublic => 'Public';

  @override
  String get groupManagersVisible => 'Managers visible';

  @override
  String get groupRejectInviteAction => 'Reject invite';

  @override
  String get groupSettingsAction => 'Settings';

  @override
  String get groupInviteMembersAction => 'Invite members';

  @override
  String get groupUpdateCoverAction => 'Update cover';

  @override
  String get groupManagersTitle => 'Managers';

  @override
  String get groupJoinRequestsTitle => 'Join requests';

  @override
  String get groupPendingInvitesTitle => 'Pending invites';

  @override
  String get groupPostsTitle => 'Posts';

  @override
  String get groupNoPosts => 'No group posts yet.';

  @override
  String get groupEventsTitle => 'Events';

  @override
  String get groupAddEventAction => 'Add event';

  @override
  String get groupNoEvents => 'No scheduled events for this group.';

  @override
  String get groupAnnouncementsTitle => 'Announcements';

  @override
  String get groupAddAnnouncementAction => 'Add announcement';

  @override
  String get groupNoAnnouncements => 'No announcements for this group.';

  @override
  String get groupMembersTitle => 'Members';

  @override
  String get groupContentMembersOnlyTitle => 'Content is for members only';

  @override
  String get groupContentMembersOnlyBody =>
      'Membership approval is required to view this group\'s content.';

  @override
  String get groupDetailLeaveAction => 'Leave group';

  @override
  String get groupDetailWithdrawRequestAction => 'Withdraw request';

  @override
  String get groupDetailAcceptInviteAction => 'Accept invite';

  @override
  String get groupDetailJoinAction => 'Send join request';

  @override
  String get groupAdminPanelTitle => 'Admin tools';

  @override
  String get groupAdminPanelHelper =>
      'Review join requests, invite new members, and adjust group visibility from one place.';

  @override
  String get groupTimelineTitle => 'Group timeline';

  @override
  String get groupPostsHelper =>
      'Share lightweight updates with the group without starting a full announcement.';

  @override
  String get groupTimelineHelper =>
      'Keep upcoming events and important announcements easy to scan.';

  @override
  String get groupMembersHelper =>
      'Managers are shown first. Role changes should be used carefully because they affect moderation access.';

  @override
  String get groupInviteSearchHint => 'Search by name or username';

  @override
  String groupSelectedCount(Object count) {
    return '$count people selected';
  }

  @override
  String groupInvitesSent(Object count) {
    return '$count invitations sent.';
  }

  @override
  String get groupRoleMakeMember => 'Make member';

  @override
  String get groupRoleMakeModerator => 'Make moderator';

  @override
  String get groupRoleMakeOwner => 'Transfer ownership';

  @override
  String get groupSettingsTitle => 'Group settings';

  @override
  String get groupVisibilityLabel => 'Visibility';

  @override
  String get groupVisibilityPublicOption => 'Public';

  @override
  String get groupVisibilityMembersOnlyOption => 'Members only';

  @override
  String get groupVisibilityHint =>
      'Members-only groups hide posts, events, announcements, and the member list until a join request is approved.';

  @override
  String get groupManagersVisibilityTitle => 'Show managers to non-members';

  @override
  String get groupManagersVisibilityHint =>
      'Turn this on only if you want visitors to know who to contact before they join.';

  @override
  String get groupNewPostTitle => 'New post';

  @override
  String get groupPostHint => 'Write a short update for the group';

  @override
  String get groupAddImageAction => 'Add image';

  @override
  String get groupCreatePostAction => 'Share post';

  @override
  String get groupNewEventTitle => 'New event';

  @override
  String get groupEventTitleLabel => 'Title';

  @override
  String get groupEventDescriptionLabel => 'Description';

  @override
  String get groupEventLocationLabel => 'Location';

  @override
  String get groupEventStartsAtLabel => 'Start date';

  @override
  String get groupEventEndsAtLabel => 'End date';

  @override
  String get groupEventScheduleHint =>
      'Dates are shown to members as entered, so include timezone or format details if needed.';

  @override
  String get groupCreateEventAction => 'Add event';

  @override
  String get groupNewAnnouncementTitle => 'New announcement';

  @override
  String get groupAnnouncementTitleLabel => 'Title';

  @override
  String get groupAnnouncementBodyLabel => 'Content';

  @override
  String get groupCreateAnnouncementAction => 'Add announcement';

  @override
  String groupEventLocationValue(Object value) {
    return 'Location: $value';
  }

  @override
  String groupEventStartsAtValue(Object value) {
    return 'Starts: $value';
  }

  @override
  String groupEventEndsAtValue(Object value) {
    return 'Ends: $value';
  }

  @override
  String groupLikesCount(Object count) {
    return '$count likes';
  }

  @override
  String groupCommentsCount(Object count) {
    return '$count comments';
  }

  @override
  String get approveAction => 'Approve';

  @override
  String get rejectAction => 'Reject';

  @override
  String get genericMemberLabel => 'SDAL Member';

  @override
  String get genericRequestFailed => 'The request could not be completed.';

  @override
  String get feedStoriesTitle => 'Stories from the community';

  @override
  String get exploreTitle => 'Explore';

  @override
  String get exploreSuggestionsTitle => 'Suggestions';

  @override
  String get exploreNoSuggestions => 'No suggestions right now.';

  @override
  String get exploreDirectoryTitle => 'Member directory';

  @override
  String get followAction => 'Follow';

  @override
  String get albumsTitle => 'Albums';

  @override
  String get albumsUploadAction => 'Upload';

  @override
  String get albumsEmpty => 'No album photos yet.';

  @override
  String get albumsLoadMore => 'Load more photos';

  @override
  String get albumTitleFallback => 'Album';

  @override
  String get albumsCategoryMissing => 'Category not found.';

  @override
  String albumsOpenPhotoSemantic(Object label) {
    return 'Open photo $label';
  }

  @override
  String get profileStoriesTitle => 'My stories';

  @override
  String get retryAction => 'Try again';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusReviewed => 'Reviewed';

  @override
  String get statusPending => 'Pending';

  @override
  String get requestsTitle => 'Member requests';

  @override
  String get requestsCreateTitle => 'Create a new request';

  @override
  String get requestsCreateHelper =>
      'Send profile or membership requests, attach supporting files, and track the current status below.';

  @override
  String get requestsCategoryLabel => 'Request category';

  @override
  String get requestsGraduationYearLabel => 'Requested graduation year';

  @override
  String get requestsTeacherOption => 'Teacher';

  @override
  String get requestsDescriptionLabel => 'Details';

  @override
  String get requestsPickFromGallery => 'Add from gallery';

  @override
  String get requestsUseCamera => 'Use camera';

  @override
  String get requestsSendAction => 'Send request';

  @override
  String get requestsListTitle => 'My requests';

  @override
  String get requestsNotificationApproved =>
      'Your request was updated. The approved item is highlighted below.';

  @override
  String get requestsNotificationUpdated =>
      'Your request was updated. The related item is highlighted below.';

  @override
  String get requestsEmpty => 'No requests have been sent yet.';

  @override
  String get requestsAttachmentUploadFailed =>
      'Attachment could not be uploaded.';

  @override
  String get requestsAttachmentUploaded => 'Attachment uploaded.';

  @override
  String get requestsSelectCategoryError => 'Choose a request category.';

  @override
  String get requestsSelectGraduationYearError =>
      'Choose the requested graduation year.';

  @override
  String get requestsSubmitSuccess => 'Request sent.';

  @override
  String get requestsSubmitFailed => 'Request could not be sent.';

  @override
  String requestsGraduationYearValue(Object value) {
    return 'Requested graduation year: $value';
  }

  @override
  String requestsResolutionNote(Object note) {
    return 'Note: $note';
  }

  @override
  String get jobsTitle => 'Job board';

  @override
  String get jobsCreateTitle => 'Publish a new job';

  @override
  String get jobsCreateHelper =>
      'Keep the post practical and specific so members can decide quickly whether to apply.';

  @override
  String get jobsCompanyLabel => 'Company';

  @override
  String get jobsPositionLabel => 'Role';

  @override
  String get jobsDescriptionLabel => 'Description';

  @override
  String get jobsLocationLabel => 'Location';

  @override
  String get jobsTypeLabel => 'Job type';

  @override
  String get jobsLinkLabel => 'Application link';

  @override
  String get jobsLinkHint => 'https://...';

  @override
  String get jobsCreateAction => 'Publish job';

  @override
  String get jobsCreateInProgress => 'Publishing...';

  @override
  String get jobsSearchTitle => 'Filter listings';

  @override
  String get jobsSearchHelper =>
      'Search by role, location, or job type to narrow the current board.';

  @override
  String get jobsSearchLabel => 'Search';

  @override
  String get jobsLocationFilterLabel => 'Location filter';

  @override
  String get jobsTypeFilterLabel => 'Job type filter';

  @override
  String get jobsApplyFiltersAction => 'Apply filters';

  @override
  String get jobsEmpty => 'No job listings yet.';

  @override
  String jobsApplicationStatus(Object status) {
    return 'Application status: $status';
  }

  @override
  String get jobsShortNoteLabel => 'Short application note';

  @override
  String get jobsApplyAction => 'Apply';

  @override
  String get jobsLoadApplicationsAction => 'Load applications';

  @override
  String get jobsRefreshApplicationsAction => 'Refresh applications';

  @override
  String get jobsReviewNoteLabel => 'Decision note';

  @override
  String get jobsMarkReviewedAction => 'Mark as reviewed';

  @override
  String get jobsAcceptAction => 'Accept';

  @override
  String jobsApplicationsStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get jobsCreateSuccess => 'Job listing published.';

  @override
  String get jobsCreateFailed => 'Job listing could not be created.';

  @override
  String get jobsApplySuccess => 'Application sent.';

  @override
  String get jobsApplyFailed => 'Application could not be sent.';

  @override
  String get jobsDeleteSuccess => 'Job listing deleted.';

  @override
  String get jobsDeleteFailed => 'Job listing could not be deleted.';

  @override
  String get jobsReviewSuccess => 'Application updated.';

  @override
  String get jobsReviewFailed => 'Application could not be updated.';

  @override
  String get jobsPosterPendingApproval => 'Awaiting approval';

  @override
  String get eventVisibilityTitle => 'Attendance visibility';

  @override
  String get eventVisibilityHelper =>
      'These settings control which attendance details other members can see on the event.';

  @override
  String get eventVisibilityShowCounts => 'Show attendance counts';

  @override
  String get eventVisibilityShowCountsHint =>
      'Members can see how many people joined or declined.';

  @override
  String get eventVisibilityShowAttendees => 'Show attendee names';

  @override
  String get eventVisibilityShowAttendeesHint =>
      'Anyone who can view the event can see the attendee list.';

  @override
  String get eventVisibilityShowDecliners => 'Show decliner names';

  @override
  String get eventVisibilityShowDeclinersHint =>
      'Anyone who can view the event can also see who declined.';

  @override
  String get eventVisibilitySaveAction => 'Save visibility settings';

  @override
  String oauthFailedWithReason(Object reason) {
    return 'OAuth flow could not be completed: $reason';
  }

  @override
  String get oauthTokenMissing => 'No session token was returned from OAuth.';
}
