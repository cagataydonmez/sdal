import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../../auth/application/auth_action_controller.dart';

class LegalContentPage extends ConsumerWidget {
  const LegalContentPage({
    super.key,
    required this.title,
    required this.path,
  });

  final String title;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentState = ref.watch(_legalContentProvider(path));

    return FeatureScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Kayıt ve hesap akışlarında kullanılan yasal içerik burada okunabilir.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          contentState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => const ErrorView(compact: true),
            data: (content) => SurfaceCard(
              child: SelectableText(
                plainTextFromRichContent(content),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _legalContentProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) =>
      ref.read(authActionControllerProvider.notifier).fetchLegalContent(path),
);
