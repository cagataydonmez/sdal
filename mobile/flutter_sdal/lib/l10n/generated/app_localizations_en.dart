// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SDAL Sosyal';

  @override
  String get appInitFailedTitle => 'Could not start';

  @override
  String get retry => 'Retry';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get backAction => 'Back';

  @override
  String get quickMenuAction => 'Quick menu';

  @override
  String get profileOpenAction => 'Open profile';

  @override
  String openMemberProfileForName(Object name) {
    return 'Open profile for $name';
  }

  @override
  String get moreActions => 'More actions';

  @override
  String get removeImageAction => 'Remove image';

  @override
  String get quickAccessRemoveAction => 'Remove from quick access';

  @override
  String openPostByAuthor(Object name) {
    return 'Open post by $name';
  }

  @override
  String feedLikesCount(Object count) {
    return '$count likes';
  }

  @override
  String feedCommentsCount(Object count) {
    return '$count comments';
  }

  @override
  String get eventsTitle => 'Events';

  @override
  String get announcementsTitle => 'Announcements';

  @override
  String get networkingTitle => 'Networking';

  @override
  String get teacherConnectionsTitle => 'Teacher connections';

  @override
  String get opportunitiesTitle => 'Opportunities';

  @override
  String get exploreOpportunitySectionTitle => 'What needs attention';

  @override
  String get exploreOpportunitySectionDescription =>
      'People, jobs, and updates worth acting on from one stream.';

  @override
  String get opportunitiesTabAll => 'All';

  @override
  String get opportunitiesTabNow => 'Now';

  @override
  String get opportunitiesTabNetworking => 'People';

  @override
  String get opportunitiesTabJobs => 'Jobs';

  @override
  String get opportunitiesTabUpdates => 'Updates';

  @override
  String get opportunitiesPriorityNow => 'Priority';

  @override
  String get opportunitiesPrioritySoon => 'Soon';

  @override
  String get opportunitiesPriorityFollow => 'Follow up';

  @override
  String get opportunitiesCategoryNetworking => 'Networking';

  @override
  String get opportunitiesCategoryJob => 'Job';

  @override
  String get opportunitiesCategoryUpdate => 'Update';

  @override
  String get opportunitiesEmptyTitle => 'Nothing is waiting right now';

  @override
  String get opportunitiesEmptyDescription =>
      'Refresh in a bit to see new people, jobs, and updates that need attention.';

  @override
  String get opportunitiesLoadMoreAction => 'Load more';

  @override
  String get opportunitiesLoading => 'Preparing opportunities...';

  @override
  String get followingTitle => 'Following';

  @override
  String get followingEmptyTitle => 'No people followed yet';

  @override
  String get followingEmptyMessage =>
      'Follow members from Explore to build a quick list of people you want to revisit.';

  @override
  String get mainNavigationTitle => 'Main navigation';

  @override
  String get communitySectionTitle => 'Community';

  @override
  String get extraPagesSectionTitle => 'Extra pages';

  @override
  String get adminSectionTitle => 'Admin';

  @override
  String get adminPanelTitle => 'Admin panel';

  @override
  String get quickAccessTitle => 'Quick access';

  @override
  String get quickAccessRemovedMessage => 'Removed from quick access.';

  @override
  String get actionFailedGeneric => 'Action could not be completed.';

  @override
  String get feedPostNotFound => 'Post not found.';

  @override
  String get feedCommentAddTitle => 'Add comment';

  @override
  String get feedCommentFieldLabel => 'Your comment';

  @override
  String get feedCommentSubmitAction => 'Send comment';

  @override
  String get feedCommentsTitle => 'Comments';

  @override
  String get feedCommentsEmpty => 'No comments yet.';

  @override
  String get feedCommentsEmptyTitle => 'No comments yet';

  @override
  String get feedCommentsEmptyMessage =>
      'Start the conversation with the first comment so other members know what to respond to.';

  @override
  String get feedCommentDeleteTitle => 'Delete comment';

  @override
  String get feedCommentDeleteMessage => 'Do you want to delete this comment?';

  @override
  String get feedCommentDeleted => 'Comment deleted.';

  @override
  String get feedCommentDeleteFailed => 'Comment could not be deleted.';

  @override
  String get feedCommentSubmitFailed => 'Comment could not be sent.';

  @override
  String get feedPostDeleteTitle => 'Delete post';

  @override
  String get feedPostDeleteMessage =>
      'This post will be permanently deleted. Do you want to continue?';

  @override
  String get feedPostDeleted => 'Post deleted.';

  @override
  String get feedPostDeleteFailed => 'Post could not be deleted.';

  @override
  String get feedPostEditTitle => 'Edit post';

  @override
  String get feedPostEdited => 'Post updated.';

  @override
  String get feedPostEditFailed => 'Post could not be updated.';

  @override
  String get feedCommentEditTitle => 'Edit comment';

  @override
  String get feedCommentEdited => 'Comment updated.';

  @override
  String get feedCommentEditFailed => 'Comment could not be updated.';

  @override
  String get feedLikedBy => 'Likes';

  @override
  String get feedLikedByNone => 'No likes yet.';

  @override
  String sidebarOnlineUsersCount(Object count) {
    return '$count users online';
  }

  @override
  String sidebarNewMessagesCount(Object count) {
    return '$count new messages';
  }

  @override
  String sidebarNewMembersCount(Object count) {
    return '$count new members';
  }

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
  String get activationTitle => 'Email verification';

  @override
  String get activationSubtitle =>
      'Complete email verification here if the e-mail link opened the iOS app.';

  @override
  String get resendActivationTitle => 'Resend verification email';

  @override
  String get resendActivationSubtitle =>
      'Support screen for the legacy membership email verification flow.';

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
  String get resendActivation => 'Resend verification email';

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
  String get activationCode => 'Email verification code';

  @override
  String get captchaCode => 'Captcha code';

  @override
  String get graduationYear => 'Graduation year / Teacher';

  @override
  String get passwordRepeat => 'Repeat password';

  @override
  String registerFieldRequired(Object field) {
    return '$field is required.';
  }

  @override
  String registerFieldTooLong(Object field, Object max) {
    return '$field must be $max characters or fewer.';
  }

  @override
  String get registerEmailInvalid => 'Enter a valid e-mail address.';

  @override
  String get registerPasswordMismatch => 'The password fields must match.';

  @override
  String get registerPasswordHint =>
      'Use 8-20 characters. A mix of uppercase, lowercase, numbers, and symbols is easier to protect.';

  @override
  String get registerPasswordStrengthNone => 'Password strength';

  @override
  String get registerPasswordStrengthWeak => 'Password strength: Weak';

  @override
  String get registerPasswordStrengthMedium => 'Password strength: Medium';

  @override
  String get registerPasswordStrengthStrong => 'Password strength: Strong';

  @override
  String get registerGraduationYearInvalid =>
      'Enter a valid graduation year between 1999 and the current year, or Teacher.';

  @override
  String get registerKvkkConsentLabel =>
      'I have read and approve the KVKK clarification text.';

  @override
  String get registerKvkkConsentError =>
      'You need to approve the KVKK clarification text before registering.';

  @override
  String get registerKvkkTitle => 'KVKK Clarification Text';

  @override
  String get registerKvkkOpenAction => 'Open the KVKK text';

  @override
  String get registerDirectoryConsentLabel =>
      'I approve the Graduate Guide explicit consent text.';

  @override
  String get registerDirectoryConsentError =>
      'Graduate Guide explicit consent is required before registering.';

  @override
  String get registerDirectoryConsentTitle =>
      'Graduate Guide Explicit Consent Text';

  @override
  String get registerDirectoryConsentOpenAction =>
      'Open the explicit consent text';

  @override
  String get registerCaptchaLoading => 'Loading security code...';

  @override
  String get registerCaptchaUnavailable =>
      'The security code could not be loaded. Refresh it and try again.';

  @override
  String get registerCaptchaRetryAction => 'Reload code';

  @override
  String get registerCaptchaCodeRequired => 'Enter the security code.';

  @override
  String get registerCaptchaDigitsOnly =>
      'The security code should contain letters and digits only.';

  @override
  String get registerPreviewFailed =>
      'The registration details could not be verified.';

  @override
  String get registerAvailabilityCheckFailed =>
      'Availability could not be checked right now.';

  @override
  String get registerUsernameTaken => 'This username is already registered.';

  @override
  String get registerUsernameAvailable => 'This username looks available.';

  @override
  String get registerEmailTaken => 'This e-mail address is already registered.';

  @override
  String get registerEmailAvailable => 'This e-mail address looks available.';

  @override
  String get loginInProgress => 'Signing in...';

  @override
  String get loginAction => 'Sign in';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithX => 'Continue with X';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get submitInProgress => 'Submitting...';

  @override
  String get registerSubmitAction => 'Submit registration';

  @override
  String get resendAction => 'Resend';

  @override
  String get passwordResetSubmitAction => 'Send reset request';

  @override
  String get activationSubmitAction => 'Verify my email';

  @override
  String get activationChecking => 'Checking...';

  @override
  String get feedTitle => 'Main feed';

  @override
  String get feedRefresh => 'Refresh';

  @override
  String get feedPostAction => 'Post';

  @override
  String get feedLoadMore => 'Load more posts';

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
  String messagesUnreadCount(Object count) {
    return 'Unread messages: $count';
  }

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsDeleteAll => 'Delete All';

  @override
  String get notificationsDeleteAllConfirm =>
      'All notifications will be permanently deleted.';

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
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptyMessage =>
      'When activity needs your attention, it will appear here with quick actions.';

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
  String get profileDetailsGraduationYearLabel => 'Graduation year';

  @override
  String get editAction => 'Edit';

  @override
  String get profileEditPageTitle => 'Edit profile';

  @override
  String get profileEditIdentitySectionTitle => 'Core details';

  @override
  String get profileEditIdentitySectionDescription =>
      'Update the fields that appear on your member profile and help others recognize you.';

  @override
  String get profileEditContactSectionTitle => 'Links and background';

  @override
  String get profileEditContactSectionDescription =>
      'Share optional links, school context, and mentoring topics with a format that stays reliable across the app.';

  @override
  String get profileEditPrivacySectionTitle => 'Visibility and consent';

  @override
  String get profileEditPrivacySectionDescription =>
      'Control how your profile appears in the directory and keep the required privacy settings up to date.';

  @override
  String get profileEditFirstNameLabel => 'First name';

  @override
  String get profileEditLastNameLabel => 'Last name';

  @override
  String get profileEditGraduationYearLabel => 'Graduation year / Teacher';

  @override
  String get profileEditGraduationYearHint => '1999-2100 or Teacher';

  @override
  String get profileEditCityLabel => 'City';

  @override
  String get profileEditProfessionLabel => 'Profession';

  @override
  String get profileEditCompanyLabel => 'Company';

  @override
  String get profileEditTitleLabel => 'Title';

  @override
  String get profileEditExpertiseLabel => 'Expertise';

  @override
  String get profileEditWebsiteLabel => 'Website';

  @override
  String get profileEditLinkedinLabel => 'LinkedIn';

  @override
  String get profileEditUniversityLabel => 'University';

  @override
  String get profileEditDepartmentLabel => 'University department';

  @override
  String get profileEditMentorTopicsLabel => 'Mentoring topics';

  @override
  String get profileEditSignatureLabel => 'Signature';

  @override
  String get profileEditMentorVisibleLabel => 'Show me as a mentor';

  @override
  String get profileEditKvkkConsentLabel => 'KVKK consent';

  @override
  String get profileEditDirectoryConsentLabel => 'Directory consent';

  @override
  String get profileEditHideEmailLabel => 'Hide my e-mail';

  @override
  String get profileEditSaveInProgress => 'Saving...';

  @override
  String get profileEditSaved => 'Profile updated.';

  @override
  String get profileEditSaveFailed => 'Profile could not be updated.';

  @override
  String get profileEditGraduationYearError =>
      'Enter a graduation year between 1999 and 2100, or Teacher.';

  @override
  String get profileEditWebsiteError => 'Enter a valid website URL.';

  @override
  String get profileEditLinkedinError => 'Enter a valid LinkedIn URL.';

  @override
  String profileEditRequiredField(Object field) {
    return '$field is required.';
  }

  @override
  String get profileAccountActionsTitle => 'Account actions';

  @override
  String get changeEmailAction => 'Change e-mail';

  @override
  String get profileEmailChangeNewEmailLabel => 'New e-mail';

  @override
  String get profileEmailChangeSubmitAction => 'Send';

  @override
  String get profileEmailChangeSuccess => 'Verification e-mail sent.';

  @override
  String get profileEmailChangeFailed => 'Request failed.';

  @override
  String get changePasswordAction => 'Change password';

  @override
  String get profilePasswordChangeCurrentPasswordLabel => 'Current password';

  @override
  String get profilePasswordChangeNewPasswordLabel => 'New password';

  @override
  String get profilePasswordChangeRepeatPasswordLabel => 'Repeat new password';

  @override
  String get profilePasswordChangeSubmitAction => 'Update';

  @override
  String get profilePasswordChangeSuccess => 'Password updated.';

  @override
  String get profilePasswordChangeFailed => 'Password could not be updated.';

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
  String get messagesEmptyTitle => 'No conversations yet';

  @override
  String get messagesEmptyMessage =>
      'Start a new chat to reach a member directly from your inbox.';

  @override
  String get announcementsEmptyTitle => 'No announcements published yet';

  @override
  String get announcementsEmptyMessage =>
      'Announcements from the community team will appear here once they are approved and published.';

  @override
  String get eventsEmptyTitle => 'No events published yet';

  @override
  String get eventsEmptyMessage =>
      'Check back after refresh to see new community events and RSVP opportunities.';

  @override
  String get albumPhotoMissingTitle => 'Photo not available';

  @override
  String get albumPhotoMissingMessage =>
      'This photo could not be loaded right now. Refresh to try again.';

  @override
  String get albumCommentsEmptyTitle => 'No comments yet';

  @override
  String get albumCommentsEmptyMessage =>
      'Leave the first comment to help other members join the conversation around this photo.';

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
  String get threadEmptyTitle => 'No messages yet';

  @override
  String get threadEmptyMessage =>
      'Send the first message to start this conversation.';

  @override
  String get chatJumpToLatestAction => 'Jump to latest';

  @override
  String get chatNewMessagesAction => 'New messages';

  @override
  String get teacherSearchHintTitle => 'Search for a teacher';

  @override
  String get teacherSearchHintMessage =>
      'Use a name or username to find a teacher before adding a connection.';

  @override
  String get teacherSearchEmptyTitle => 'No matching teacher found';

  @override
  String get teacherSearchEmptyMessage =>
      'Try a different name, username, or spelling to widen the search.';

  @override
  String get teacherConnectionsEmptyTitle => 'No teacher connections yet';

  @override
  String get teacherConnectionsEmptyMessage =>
      'Search for a teacher above to create your first teacher connection.';

  @override
  String get networkConnectionsEmptyTitle =>
      'No connection requests in this view';

  @override
  String networkConnectionsEmptyMessage(Object direction, Object status) {
    return 'There are no $direction $status connection requests right now.';
  }

  @override
  String get networkMentorshipEmptyTitle =>
      'No mentorship requests in this view';

  @override
  String networkMentorshipEmptyMessage(Object direction, Object status) {
    return 'There are no $direction $status mentorship requests right now.';
  }

  @override
  String get networkDirectionIncoming => 'incoming';

  @override
  String get networkDirectionOutgoing => 'outgoing';

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
  String get previousAction => 'Previous';

  @override
  String get nextAction => 'Next';

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
  String get profileMainFeedStoriesTitle => 'My main feed stories';

  @override
  String get profileCommunityStoriesTitle => 'My community stories';

  @override
  String get profileExpiredMainFeedStoriesTitle => 'Expired main feed stories';

  @override
  String get profileExpiredCommunityStoriesTitle => 'Expired community stories';

  @override
  String profileExpiredStoriesCountLabel(Object title, Object count) {
    return '$title ($count)';
  }

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
  String get exploreLatestMembersTitle => 'Newest members';

  @override
  String get exploreSuggestionsTitle => 'Suggestions';

  @override
  String get exploreNoSuggestions => 'No suggestions right now.';

  @override
  String get exploreSuggestionsEmptyTitle => 'No suggestions right now';

  @override
  String get exploreSuggestionsEmptyMessage =>
      'Refresh this list later to see new members and recommendations.';

  @override
  String get exploreDirectoryTitle => 'Member directory';

  @override
  String get exploreDirectoryFiltersTitle => 'Directory filters';

  @override
  String get exploreSearchLabel => 'Search';

  @override
  String get exploreGraduationYearLabel => 'Graduation year';

  @override
  String get exploreApplyFiltersAction => 'Apply filters';

  @override
  String get exploreClearFiltersAction => 'Clear';

  @override
  String explorePageLabel(Object page) {
    return 'Page $page';
  }

  @override
  String memberGraduationYearValue(Object year) {
    return 'Class of $year';
  }

  @override
  String get followAction => 'Follow';

  @override
  String get unfollowAction => 'Unfollow';

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
  String get errorGenericTitle => 'Something went wrong.';

  @override
  String get errorGenericMessage =>
      'Try again in a moment or refresh this screen.';

  @override
  String get errorNetworkTitle => 'Connection problem';

  @override
  String get errorNetworkMessage =>
      'Check your internet connection and try again.';

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
  String get requestsEmptyTitle => 'No requests yet';

  @override
  String get requestsEmptyMessage =>
      'Use the form above to send a profile or membership request when you need admin review.';

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

  @override
  String get reportContentTitle => 'Report content';

  @override
  String get reportContentSubtitle =>
      'Why are you reporting this? Reports are reviewed within 24 hours.';

  @override
  String get reportReasonSpam => 'Spam or misleading';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonHate => 'Hate speech';

  @override
  String get reportReasonExplicit => 'Explicit content';

  @override
  String get reportReasonViolence => 'Violence or threats';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportSubmittedMessage =>
      'Thanks — your report was received and we\'ll review it shortly.';

  @override
  String get reportFailedMessage =>
      'Couldn\'t send the report. Please try again.';

  @override
  String get reportAction => 'Report';

  @override
  String get blockUserAction => 'Block user';

  @override
  String blockUserConfirm(Object name) {
    return 'Block $name? Their content will be removed from your feed immediately and our team will be notified.';
  }

  @override
  String get blockUserConfirmAction => 'Block';

  @override
  String userBlockedMessage(Object name) {
    return '$name has been blocked.';
  }

  @override
  String get blockFailedMessage =>
      'Couldn\'t block the user. Please try again.';

  @override
  String userUnblockedMessage(Object name) {
    return '$name has been unblocked.';
  }

  @override
  String get unblockFailedMessage => 'Couldn\'t unblock. Please try again.';

  @override
  String get eulaPageTitle => 'Terms of Use';

  @override
  String get eulaGateHeadline => 'Before you continue';

  @override
  String get eulaGateIntro =>
      'To use SDAL Sosyal you must accept the Terms of Use (EULA). We have zero tolerance for objectionable content and abusive users.';

  @override
  String get eulaAcceptAction => 'I have read and accept';

  @override
  String get eulaAcceptFailedMessage =>
      'Couldn\'t save your acceptance. Please try again.';

  @override
  String get registerEulaConsentTitle => 'Terms of Use (EULA)';

  @override
  String get registerEulaConsentLabel =>
      'I have read and accept the Terms of Use. I understand there is zero tolerance for objectionable content and abusive users.';

  @override
  String get registerEulaConsentError =>
      'You must read and accept the Terms of Use (EULA).';
}
