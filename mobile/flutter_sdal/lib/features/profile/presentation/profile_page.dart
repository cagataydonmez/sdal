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
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/remote_avatar.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../../feed/data/feed_repository.dart';
import '../../albums/application/albums_action_controller.dart';
import '../../albums/data/albums_repository.dart';
import '../../stories/data/stories_repository.dart';
import '../../stories/presentation/stories_rail.dart';
import '../application/profile_action_controller.dart';
import '../data/profile_repository.dart';
import 'profile_album_section.dart';

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
    final session = ref.watch(sessionControllerProvider).value;
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    final selectedFeedType = _storyFeedType.apiValue;
    final expiredStories = ref
        .watch(myExpiredStoriesProvider(selectedFeedType))
        .value;
    final expiredStoriesCount = expiredStories?.length ?? 0;
    final requestsVisible = session?.isModuleVisible('requests') ?? false;
    final myAlbumsState = ref.watch(myAlbumsProvider);

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
        loading: () => const _ProfileLoadingView(),
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
                    Tooltip(
                      message: l10n.profilePhotoAction,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push('/profile/photo'),
                        child: Semantics(
                          button: true,
                          label: l10n.profilePhotoAction,
                          child: ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 68,
                              child: Center(
                                child: RemoteAvatar(
                                  label: user.displayName,
                                  imageUrl: config
                                      .resolveUrl(profile.photo)
                                      .toString(),
                                  radius: 34,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                              MemberBadgeStrip(
                                verified: user.isVerified,
                                role: user.role,
                                graduationYear: profile.graduationYear,
                              ),
                              if (!user.isVerified)
                                _StatusChip(
                                  label: l10n.profilePendingVerification,
                                  color: Theme.of(context).sdal.warning,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (profile.graduationYear.isNotEmpty)
                                _ProfileFactChip(
                                  icon: Icons.school_outlined,
                                  label: _formatGraduationYear(
                                    context,
                                    profile.graduationYear,
                                    withGraduateSuffix: true,
                                  ),
                                ),
                              if (profile.city.isNotEmpty)
                                _ProfileFactChip(
                                  icon: Icons.location_on_outlined,
                                  label: profile.city,
                                ),
                              if (profile.profession.isNotEmpty)
                                _ProfileFactChip(
                                  icon: Icons.work_outline_rounded,
                                  label: profile.profession,
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
              ProfileAlbumSection(
                title: 'Profil albümleri',
                subtitle:
                    'Profiline bakanlar anılarını ve seçtiğin koleksiyonları burada görür.',
                albumsState: myAlbumsState,
                isOwner: true,
                onCreateAlbum: () async {
                  await context.push('/albums/new?profile=1');
                  if (!mounted) return;
                  ref.invalidate(albumsDashboardProvider);
                  ref.invalidate(myAlbumsProvider);
                  ref.invalidate(memberProfileAlbumsProvider(profile.id));
                },
                onOpenAlbum: (album) async {
                  await context.push('/albums/${album.id}');
                  if (!mounted) return;
                  ref.invalidate(albumsDashboardProvider);
                  ref.invalidate(myAlbumsProvider);
                  ref.invalidate(memberProfileAlbumsProvider(profile.id));
                },
                onDeleteAlbum: _deleteProfileAlbum,
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
              if (requestsVisible) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/requests'),
                    icon: const Icon(Icons.assignment_outlined),
                    label: Text(l10n.requestsListTitle),
                  ),
                ),
              ],
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
                      value: _formatGraduationYear(
                        context,
                        profile.graduationYear,
                      ),
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

  Future<void> _deleteProfileAlbum(AlbumCategoryItem album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${album.title} silinsin mi?'),
        content: const Text(
          'Bu profil albümü kaldırılacak. İçindeki fotoğraflar da erişilemez hale gelir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(albumsActionControllerProvider.notifier)
        .deleteAlbum(album.id);
    if (!mounted) return;
    final state = ref.read(albumsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ??
              (ok ? 'Profil albümü silindi.' : 'Profil albümü silinemedi.'),
        ),
      ),
    );
    if (!ok) return;
    ref.invalidate(albumsDashboardProvider);
    ref.invalidate(myAlbumsProvider);
    ref.invalidate(memberProfileAlbumsProvider(album.ownerUserId ?? 0));
  }
}

String _formatGraduationYear(
  BuildContext context,
  String value, {
  bool withGraduateSuffix = false,
}) {
  final normalized = value.trim().toLowerCase();
  final isTeacher =
      normalized == '9999' ||
      normalized == 'teacher' ||
      normalized == 'ogretmen' ||
      normalized == 'öğretmen';
  if (isTeacher) {
    return Localizations.localeOf(context).languageCode == 'tr'
        ? 'Öğretmen'
        : 'Teacher';
  }
  if (!withGraduateSuffix) return value;
  return Localizations.localeOf(context).languageCode == 'tr'
      ? '$value mezunu'
      : '$value graduate';
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _ProfileHeaderSkeleton(),
        SizedBox(height: 16),
        _ProfileStoriesSkeleton(),
        SizedBox(height: 16),
        _ProfileDetailsSkeleton(),
      ],
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: const [
          SkeletonBox(height: 68, width: 68, shape: BoxShape.circle),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLines(widthFactors: [0.44, 0.3], lineHeight: 12),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonBox(width: 110, height: 30),
                    SizedBox(width: 8),
                    SkeletonBox(width: 84, height: 30),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStoriesSkeleton extends StatelessWidget {
  const _ProfileStoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 96, height: 18),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 42)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 42)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 108,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: EdgeInsets.only(right: index == 3 ? 0 : 12),
                    child: const SkeletonBox(width: 78, height: 108),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 42),
        ],
      ),
    );
  }
}

class _ProfileDetailsSkeleton extends StatelessWidget {
  const _ProfileDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 18)),
              SizedBox(width: 12),
              SkeletonBox(width: 84, height: 38),
            ],
          ),
          SizedBox(height: 14),
          SkeletonLines(widthFactors: [0.35, 0.78, 0.32, 0.67, 0.45, 0.72]),
          SizedBox(height: 16),
          SkeletonBox(width: 140, height: 18),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(width: 120, height: 38),
              SizedBox(width: 10),
              SkeletonBox(width: 132, height: 38),
            ],
          ),
        ],
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
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProfileFactChip extends StatelessWidget {
  const _ProfileFactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.panelRaised,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tokens.foregroundMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
