import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../../auth/application/auth_action_controller.dart';
import '../../safety/data/safety_repository.dart';

/// Full-screen, one-time gate that presents the zero-tolerance EULA and blocks
/// access to the app until the user accepts it (App Store Guideline 1.2).
class EulaAcceptancePage extends ConsumerStatefulWidget {
  const EulaAcceptancePage({super.key});

  /// Backend route that serves the EULA document (see userSafetyRoutes.js).
  static const String documentPath = '/kullanim-kosullari';

  @override
  ConsumerState<EulaAcceptancePage> createState() => _EulaAcceptancePageState();
}

class _EulaAcceptancePageState extends ConsumerState<EulaAcceptancePage> {
  bool _submitting = false;

  Future<void> _accept() async {
    setState(() => _submitting = true);
    final result = await ref.read(safetyRepositoryProvider).acceptEula();
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.eulaAcceptFailedMessage)),
      );
      return;
    }
    // Refresh the session so the router gate lets the user through. Use the
    // silent refresh to avoid the AsyncLoading MaterialApp swap (which causes a
    // Duplicate GlobalKey crash while GoRouter holds the navigator key).
    await ref.read(sessionControllerProvider.notifier).refreshSilently();
  }

  @override
  Widget build(BuildContext context) {
    final contentState = ref.watch(_eulaContentProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.eulaPageTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.eulaGateHeadline,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.eulaGateIntro,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  contentState.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => const ErrorView(compact: true),
                    data: (content) => SurfaceCard(
                      child: SelectableText(
                        plainTextFromRichContent(content),
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _accept,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.eulaAcceptAction),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _eulaContentProvider = FutureProvider.autoDispose<String>(
  (ref) => ref
      .read(authActionControllerProvider.notifier)
      .fetchLegalContent(EulaAcceptancePage.documentPath),
);
