import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/theme/theme_mode_store.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/profile_action_controller.dart';
import '../../../core/session/session_controller.dart';

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureScaffold(
      title: 'Ayarlar',
      background: FeatureScaffoldBackground.neutral,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _ThemeSection(),
          SizedBox(height: 16),
          _AppearanceSection(),
          SizedBox(height: 16),
          _AccountSection(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme picker
// ---------------------------------------------------------------------------

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).sdal;
    final activeTheme = ref.watch(sdalActiveThemeProvider);
    final adminDefault = ref.watch(sdalAdminThemeProvider);
    final userChoice = ref.watch(sdalUserThemeProvider);

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tema', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              if (userChoice == null)
                _Badge(
                  label: 'Varsayılan',
                  color: tokens.accentMuted,
                  textColor: tokens.accent,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Seçimin yalnızca bu cihazda geçerlidir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...SdalAppTheme.values.map(
            (theme) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThemeCard(
                theme: theme,
                isActive: activeTheme == theme,
                isAdminDefault: adminDefault == theme,
                onTap: () {
                  ref.read(sdalUserThemeProvider.notifier).set(theme);
                  ref.read(sdalUserThemeStoreProvider).save(theme);
                },
              ),
            ),
          ),
          if (userChoice != null) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Varsayılana dön'),
                onPressed: () {
                  ref.read(sdalUserThemeProvider.notifier).set(null);
                  ref.read(sdalUserThemeStoreProvider).save(null);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.isAdminDefault,
    required this.onTap,
  });

  final SdalAppTheme theme;
  final bool isActive;
  final bool isAdminDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeTokens = theme.tokensFor(
      isDark ? Brightness.dark : Brightness.light,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutQuart,
      decoration: BoxDecoration(
        color: isActive ? themeTokens.accentMuted : tokens.panelMuted,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: isActive ? themeTokens.accent : tokens.panelBorder,
          width: isActive ? 2.0 : tokens.panelBorderWidth.clamp(0.5, 2.0),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _Swatches(
                colors: theme.swatches,
                radius: themeTokens.cardRadius.clamp(6.0, 14.0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          theme.displayName,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? themeTokens.accent
                                : tokens.foreground,
                          ),
                        ),
                        if (isAdminDefault) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: 'Varsayılan',
                            color: tokens.accentMuted,
                            textColor: tokens.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.tagline,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? themeTokens.accent.withValues(alpha: 0.75)
                            : tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isActive
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('check'),
                        color: themeTokens.accent,
                        size: 22,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey('circle'),
                        color: tokens.panelBorder,
                        size: 22,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.radius});

  final List<Color> colors;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 36,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length && i < 3; i++)
            Positioned(
              left: i * 12.0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 20,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance (dark / light / system)
// ---------------------------------------------------------------------------

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preference = ref.watch(themeModeControllerProvider);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Görünüm', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.themeModeHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Account actions
// ---------------------------------------------------------------------------

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileAccountActionsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
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
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () async {
                  final message = await ref
                      .read(sessionControllerProvider.notifier)
                      .logout();
                  if (!context.mounted) return;
                  if (message == null) {
                    context.go('/login');
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                },
                child: Text(l10n.logoutAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog helpers (mirrors profile_page.dart)
// ---------------------------------------------------------------------------

Future<void> _openEmailChangeDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
