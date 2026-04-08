import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/theme/theme_mode_store.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../feed/data/feed_repository.dart';
import '../../stories/data/stories_repository.dart';
import '../../stories/presentation/stories_rail.dart';
import '../application/profile_action_controller.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  FeedType _storyFeedType = FeedType.main;

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final selectedFeedType = _storyFeedType.apiValue;
    final expiredStories = ref
        .watch(myExpiredStoriesProvider(selectedFeedType))
        .valueOrNull;
    final expiredStoriesCount = expiredStories?.length ?? 0;

    return FeatureScaffold(
      title: l10n.profileTitle,
      background: FeatureScaffoldBackground.neutral,
      actions: [
        IconButton(
          tooltip: l10n.refreshAction,
          onPressed: () {
            ref.invalidate(profileProvider);
            ref.invalidate(myStoriesProvider(selectedFeedType));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const ErrorView(),
          ),
        ),
        data: (profile) {
          final user = session?.user;
          if (profile == null || user == null) {
            return Center(child: Text(l10n.profileMissing));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SurfaceCard(
                child: Row(
                  children: [
                    RemoteAvatar(
                      label: user.displayName,
                      imageUrl: config.resolveUrl(profile.photo).toString(),
                      radius: 34,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (user.kadi.isNotEmpty) Text('@${user.kadi}'),
                          if (profile.email.isNotEmpty)
                            Text(
                              profile.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(
                                label: user.isVerified
                                    ? l10n.profileVerified
                                    : l10n.profilePendingVerification,
                                color: user.isVerified
                                    ? const Color(0xFF0D7A4B)
                                    : const Color(0xFF9A6700),
                              ),
                              _StatusChip(
                                label: user.role,
                                color: const Color(0xFF173657),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.storiesTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _FeedTypePicker(
                      value: _storyFeedType,
                      onChanged: (next) =>
                          setState(() => _storyFeedType = next),
                    ),
                    const SizedBox(height: 16),
                    StoriesRail(
                      mode: StoryRailMode.mine,
                      showUpload: false,
                      title: _profileStoriesTitle(context, _storyFeedType),
                      feedType: selectedFeedType,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '/profile/stories/expired?feedType=$selectedFeedType',
                      ),
                      icon: const Icon(Icons.history_toggle_off_rounded),
                      label: Text(
                        expiredStories == null
                            ? _expiredStoriesTitle(context, _storyFeedType)
                            : expiredStoriesCount > 0
                            ? l10n.profileExpiredStoriesCountLabel(
                                _expiredStoriesTitle(context, _storyFeedType),
                                expiredStoriesCount,
                              )
                            : _expiredStoriesTitle(context, _storyFeedType),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/profile/photo'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.profilePhotoAction),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/profile/verification'),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(l10n.profileVerificationAction),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.profileAccountDetailsTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => context.push('/profile/edit'),
                          child: Text(l10n.editAction),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ProfileRow(
                      label: l10n.profileEditFirstNameLabel,
                      value: profile.firstName,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditLastNameLabel,
                      value: profile.lastName,
                    ),
                    _ProfileRow(
                      label: l10n.profileDetailsGraduationYearLabel,
                      value: profile.graduationYear,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditCityLabel,
                      value: profile.city,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditProfessionLabel,
                      value: profile.profession,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditCompanyLabel,
                      value: profile.company,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditTitleLabel,
                      value: profile.title,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditExpertiseLabel,
                      value: profile.expertise,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditWebsiteLabel,
                      value: profile.website,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditLinkedinLabel,
                      value: profile.linkedinUrl,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditUniversityLabel,
                      value: profile.university,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditDepartmentLabel,
                      value: profile.universityDepartment,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditMentorTopicsLabel,
                      value: profile.mentorTopics,
                    ),
                    _ProfileRow(
                      label: l10n.profileEditSignatureLabel,
                      value: profile.signature,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileAccountActionsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _ThemeModePreferenceCard(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () => _openEmailChangeDialog(context, ref),
                          child: Text(l10n.changeEmailAction),
                        ),
                        OutlinedButton(
                          onPressed: () => _openPasswordDialog(context, ref),
                          child: Text(l10n.changePasswordAction),
                        ),
                        FilledButton(
                          onPressed: () async {
                            final message = await ref
                                .read(sessionControllerProvider.notifier)
                                .logout();
                            if (!context.mounted) return;
                            if (message == null) {
                              context.go('/login');
                              return;
                            }
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          },
                          child: Text(l10n.logoutAction),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedTypePicker extends StatelessWidget {
  const _FeedTypePicker({required this.value, required this.onChanged});

  final FeedType value;
  final ValueChanged<FeedType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<FeedType>(
      segments: [
        ButtonSegment<FeedType>(
          value: FeedType.main,
          label: Text(l10n.feedTitle),
        ),
        ButtonSegment<FeedType>(
          value: FeedType.community,
          label: Text(l10n.communitySectionTitle),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        onChanged(selection.first);
      },
    );
  }
}

String _profileStoriesTitle(BuildContext context, FeedType feedType) {
  final l10n = context.l10n;
  return switch (feedType) {
    FeedType.main => l10n.profileMainFeedStoriesTitle,
    FeedType.community => l10n.profileCommunityStoriesTitle,
  };
}

String _expiredStoriesTitle(BuildContext context, FeedType feedType) {
  final l10n = context.l10n;
  return switch (feedType) {
    FeedType.main => l10n.profileExpiredMainFeedStoriesTitle,
    FeedType.community => l10n.profileExpiredCommunityStoriesTitle,
  };
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final shouldStack =
        MediaQuery.sizeOf(context).width < 420 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: shouldStack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: Text(value)),
              ],
            ),
    );
  }
}

class _ThemeModePreferenceCard extends ConsumerWidget {
  const _ThemeModePreferenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preference = ref.watch(themeModeControllerProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).sdal.panelRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).sdal.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.themeModeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.themeModeHelper,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeModePreference>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeModePreference.system,
                    label: Text(l10n.themeModeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeModePreference.light,
                    label: Text(l10n.themeModeLight),
                  ),
                  ButtonSegment(
                    value: ThemeModePreference.dark,
                    label: Text(l10n.themeModeDark),
                  ),
                ],
                selected: {preference},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  ref
                      .read(themeModeControllerProvider.notifier)
                      .setPreference(selection.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Future<void> _openEmailChangeDialog(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final controller = TextEditingController();
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeEmailAction),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.profileEmailChangeNewEmailLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(profileActionControllerProvider.notifier)
                  .requestEmailChange(controller.text.trim());
              if (!context.mounted) return;
              Navigator.of(context).pop();
              final actionState = ref.read(profileActionControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    actionState.message ??
                        (ok
                            ? l10n.profileEmailChangeSuccess
                            : l10n.profileEmailChangeFailed),
                  ),
                ),
              );
            },
            child: Text(l10n.profileEmailChangeSubmitAction),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _openPasswordDialog(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final currentController = TextEditingController();
  final nextController = TextEditingController();
  final repeatController = TextEditingController();
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changePasswordAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(
              currentController,
              l10n.profilePasswordChangeCurrentPasswordLabel,
              obscureText: true,
            ),
            _dialogField(
              nextController,
              l10n.profilePasswordChangeNewPasswordLabel,
              obscureText: true,
            ),
            _dialogField(
              repeatController,
              l10n.profilePasswordChangeRepeatPasswordLabel,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(profileActionControllerProvider.notifier)
                  .changePassword(
                    currentPassword: currentController.text,
                    nextPassword: nextController.text,
                    nextPasswordRepeat: repeatController.text,
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              final actionState = ref.read(profileActionControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    actionState.message ??
                        (ok
                            ? l10n.profilePasswordChangeSuccess
                            : l10n.profilePasswordChangeFailed),
                  ),
                ),
              );
            },
            child: Text(l10n.profilePasswordChangeSubmitAction),
          ),
        ],
      ),
    );
  } finally {
    currentController.dispose();
    nextController.dispose();
    repeatController.dispose();
  }
}

Widget _dialogField(
  TextEditingController controller,
  String label, {
  bool obscureText = false,
  int minLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: obscureText ? 1 : (minLines > 1 ? minLines + 2 : 1),
      decoration: InputDecoration(labelText: label),
    ),
  );
}
