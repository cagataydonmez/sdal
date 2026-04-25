import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/text/plain_text_from_rich_content.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../../auth/application/auth_action_controller.dart';

class LegalContentPage extends ConsumerStatefulWidget {
  const LegalContentPage({
    super.key,
    required this.title,
    required this.path,
    this.requireAcceptance = false,
  });

  final String title;
  final String path;
  final bool requireAcceptance;

  @override
  ConsumerState<LegalContentPage> createState() => _LegalContentPageState();
}

class _LegalContentPageState extends ConsumerState<LegalContentPage> {
  final _scrollController = ScrollController();
  bool _hasReachedEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncReachedEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncReachedEnd)
      ..dispose();
    super.dispose();
  }

  void _syncReachedEnd() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final reached =
        position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 12;
    if (reached != _hasReachedEnd && mounted) {
      setState(() => _hasReachedEnd = reached);
    }
  }

  void _checkContentExtentAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncReachedEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentState = ref.watch(_legalContentProvider(widget.path));
    final bottomPadding = widget.requireAcceptance ? 12.0 : 28.0;

    return FeatureScaffold(
      title: widget.title,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.requireAcceptance
                            ? 'Onaylamak için metni sonuna kadar okuyun.'
                            : 'Kayıt ve hesap akışlarında kullanılan yasal içerik burada okunabilir.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                contentState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => const ErrorView(compact: true),
                  data: (content) {
                    _checkContentExtentAfterLayout();
                    return SurfaceCard(
                      child: SelectableText(
                        plainTextFromRichContent(content),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.requireAcceptance)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _hasReachedEnd
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        child: const Text('Onayla'),
                      ),
                    ),
                  ],
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
