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
  String get genericMemberLabel => 'SDAL Member';

  @override
  String get genericRequestFailed => 'The request could not be completed.';

  @override
  String oauthFailedWithReason(Object reason) {
    return 'OAuth flow could not be completed: $reason';
  }

  @override
  String get oauthTokenMissing => 'No session token was returned from OAuth.';
}
