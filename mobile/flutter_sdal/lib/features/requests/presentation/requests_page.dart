import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/media/pick_cropped_image.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/text/sdal_date_time.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/requests_action_controller.dart';
import '../data/requests_repository.dart';

class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({
    super.key,
    this.initialCategoryKey = '',
    this.highlightedRequestId = 0,
    this.notificationId = 0,
    this.notificationStatus = '',
  });

  final String initialCategoryKey;
  final int highlightedRequestId;
  final int notificationId;
  final String notificationStatus;

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _requestKeys = <int, GlobalKey>{};
  final List<RequestAttachment> _attachments = <RequestAttachment>[];

  String _categoryKey = '';
  String _requestedGraduationYear = '';
  bool _categoryInitialized = false;
  _RequestListTab _activeTab = _RequestListTab.pending;

  @override
  void initState() {
    super.initState();
    final notificationStatus = widget.notificationStatus.trim().toLowerCase();
    if (notificationStatus.isNotEmpty &&
        !_isPendingRequestStatus(notificationStatus)) {
      _activeTab = _RequestListTab.completed;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final categoriesState = ref.watch(requestCategoriesProvider);
    final requestsState = ref.watch(myRequestsProvider);
    final actionState = ref.watch(requestsActionControllerProvider);
    final isUploading =
        actionState.isLoading && actionState.scope == 'requests:upload';
    final isSubmitting =
        actionState.isLoading && actionState.scope == 'requests:create';
    final requestItems = requestsState.value ?? const <MemberRequestItem>[];
    final filteredRequests = _filteredRequests(requestItems);

    categoriesState.whenData((categories) {
      if (_categoryInitialized || categories.isEmpty) return;
      final requested = widget.initialCategoryKey.trim();
      final resolved = categories.any((item) => item.categoryKey == requested)
          ? requested
          : categories.first.categoryKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _categoryInitialized) return;
        setState(() {
          _categoryKey = resolved;
          _categoryInitialized = true;
        });
      });
    });

    requestsState.whenData((items) {
      if (widget.highlightedRequestId <= 0) return;
      MemberRequestItem? highlightedItem;
      for (final item in items) {
        if (item.id == widget.highlightedRequestId) {
          highlightedItem = item;
          break;
        }
      }
      if (highlightedItem == null) return;
      final targetTab = _isPendingRequestStatus(highlightedItem.status)
          ? _RequestListTab.pending
          : _RequestListTab.completed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_activeTab != targetTab) {
          setState(() => _activeTab = targetTab);
          return;
        }
        final key = _requestKeys[widget.highlightedRequestId];
        final context = key?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });

    return FeatureScaffold(
      title: l10n.requestsTitle,
      background: FeatureScaffoldBackground.utility,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(requestCategoriesProvider);
          ref.invalidate(myRequestsProvider);
          await Future.wait([
            ref.read(requestCategoriesProvider.future),
            ref.read(myRequestsProvider.future),
          ]);
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.accentMuted,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: tokens.panelBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.requestsCreateTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.requestsCreateHelper,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  categoriesState.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (error, _) => const ErrorView(
                      compact: true,
                      kind: ErrorViewKind.network,
                    ),
                    data: (categories) => DropdownButtonFormField<String>(
                      initialValue:
                          categories.any(
                            (item) => item.categoryKey == _categoryKey,
                          )
                          ? _categoryKey
                          : null,
                      decoration: InputDecoration(
                        labelText: l10n.requestsCategoryLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.categoryKey,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: isSubmitting
                          ? null
                          : (value) =>
                                setState(() => _categoryKey = value ?? ''),
                    ),
                  ),
                  if (_categoryKey == 'graduation_year_change') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _requestedGraduationYear.isEmpty
                          ? null
                          : _requestedGraduationYear,
                      decoration: InputDecoration(
                        labelText: l10n.requestsGraduationYearLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: _graduationYearOptions
                          .map(
                            (year) => DropdownMenuItem<String>(
                              value: year,
                              child: Text(
                                year == 'teacher'
                                    ? l10n.requestsTeacherOption
                                    : year,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: isSubmitting
                          ? null
                          : (value) => setState(
                              () => _requestedGraduationYear = value ?? '',
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      labelText: l10n.requestsDescriptionLabel,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploading || isSubmitting
                            ? null
                            : () => _pickAndUpload(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          isUploading
                              ? l10n.submitInProgress
                              : l10n.requestsPickFromGallery,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: isUploading || isSubmitting
                            ? null
                            : () => _pickAndUpload(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.requestsUseCamera),
                      ),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._attachments.map(
                      (attachment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AttachmentChip(
                          attachment: attachment,
                          onRemove: isSubmitting
                              ? null
                              : () => setState(
                                  () => _attachments.remove(attachment),
                                ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSubmitting ? null : _submit,
                      child: Text(
                        isSubmitting
                            ? l10n.submitInProgress
                            : l10n.requestsSendAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.requestsListTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (widget.notificationId > 0 &&
                    widget.notificationStatus.trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.infoMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: tokens.panelBorder),
                    ),
                    child: Text(
                      widget.notificationStatus.trim().toLowerCase() ==
                              'approved'
                          ? l10n.requestsNotificationApproved
                          : l10n.requestsNotificationUpdated,
                      style: TextStyle(color: tokens.foreground),
                    ),
                  ),
                if (widget.notificationId > 0 &&
                    widget.notificationStatus.trim().isNotEmpty)
                  const SizedBox(height: 12),
                _RequestListTabs(
                  activeTab: _activeTab,
                  pendingCount: requestItems
                      .where((item) => _isPendingRequestStatus(item.status))
                      .length,
                  completedCount: requestItems
                      .where((item) => !_isPendingRequestStatus(item.status))
                      .length,
                  onChanged: (tab) => setState(() => _activeTab = tab),
                ),
                const SizedBox(height: 12),
              ],
            ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  requestsState.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ErrorView(
                          compact: true,
                          kind: ErrorViewKind.network,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(myRequestsProvider),
                          child: Text(l10n.retryAction),
                        ),
                      ],
                    ),
                    data: (items) => filteredRequests.isEmpty
                        ? EmptyStateView(
                            icon: _activeTab == _RequestListTab.pending
                                ? Icons.hourglass_top_rounded
                                : Icons.task_alt_rounded,
                            title: _requestsEmptyTitle(context, _activeTab),
                            message: _requestsEmptyMessage(context, _activeTab),
                            compact: true,
                          )
                        : Column(
                            children: filteredRequests
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _RequestCard(
                                      key: _requestKeys.putIfAbsent(
                                        item.id,
                                        GlobalKey.new,
                                      ),
                                      item: item,
                                      highlighted:
                                          item.id ==
                                          widget.highlightedRequestId,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await pickAndCropImage(
      context,
      source: source,
      title: 'Eki kırp',
    );
    if (picked == null || !mounted) return;
    final attachment = await ref
        .read(requestsActionControllerProvider.notifier)
        .uploadAttachment(picked);
    if (!mounted) return;
    final actionState = ref.read(requestsActionControllerProvider);
    if (attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actionState.message ?? context.l10n.requestsAttachmentUploadFailed,
          ),
        ),
      );
      return;
    }
    setState(() => _attachments.add(attachment));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ?? context.l10n.requestsAttachmentUploaded,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final categoryKey = _categoryKey.trim();
    if (categoryKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.requestsSelectCategoryError)),
      );
      return;
    }
    if (categoryKey == 'graduation_year_change' &&
        _requestedGraduationYear.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.requestsSelectGraduationYearError)),
      );
      return;
    }

    final payload = <String, dynamic>{
      if (_noteController.text.trim().isNotEmpty)
        'note': _noteController.text.trim(),
      if (_attachments.isNotEmpty)
        'attachments': _attachments.map((item) => item.toJson()).toList(),
      if (categoryKey == 'graduation_year_change')
        'requestedGraduationYear': _requestedGraduationYear.trim(),
    };

    final ok = await ref
        .read(requestsActionControllerProvider.notifier)
        .createRequest(categoryKey: categoryKey, payload: payload);
    if (!mounted) return;

    final actionState = ref.read(requestsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actionState.message ??
              (ok
                  ? context.l10n.requestsSubmitSuccess
                  : context.l10n.requestsSubmitFailed),
        ),
      ),
    );
    if (!ok) return;

    setState(() {
      _noteController.clear();
      _requestedGraduationYear = '';
      _attachments.clear();
    });
  }

  List<MemberRequestItem> _filteredRequests(List<MemberRequestItem> items) {
    return items
        .where(
          (item) => _activeTab == _RequestListTab.pending
              ? _isPendingRequestStatus(item.status)
              : !_isPendingRequestStatus(item.status),
        )
        .toList(growable: false);
  }
}

enum _RequestListTab { pending, completed }

class _RequestListTabs extends StatelessWidget {
  const _RequestListTabs({
    required this.activeTab,
    required this.pendingCount,
    required this.completedCount,
    required this.onChanged,
  });

  final _RequestListTab activeTab;
  final int pendingCount;
  final int completedCount;
  final ValueChanged<_RequestListTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.panelBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _RequestTabButton(
              label: _requestsTabLabel(
                context,
                _RequestListTab.pending,
                pendingCount,
              ),
              selected: activeTab == _RequestListTab.pending,
              onTap: () => onChanged(_RequestListTab.pending),
            ),
          ),
          Expanded(
            child: _RequestTabButton(
              label: _requestsTabLabel(
                context,
                _RequestListTab.completed,
                completedCount,
              ),
              selected: activeTab == _RequestListTab.completed,
              onTap: () => onChanged(_RequestListTab.completed),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTabButton extends StatelessWidget {
  const _RequestTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Material(
      color: selected ? tokens.panel : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? tokens.foreground : tokens.foregroundMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, this.onRemove});

  final RequestAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.panelBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file_rounded, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(attachment.name, overflow: TextOverflow.ellipsis),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.item,
    required this.highlighted,
  });

  final MemberRequestItem item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: highlighted ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(tokens.panel, tokens.infoMuted, value),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Color.lerp(tokens.panelBorder, tokens.info, value)!,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.categoryLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusPill(status: item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '#${item.id} • ${formatSdalTimestamp(context, item.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.foregroundMuted),
          ),
          if (item.payload['requestedGraduationYear'] != null) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.requestsGraduationYearValue(
                item.payload['requestedGraduationYear'] == 'teacher'
                    ? context.l10n.requestsTeacherOption
                    : item.payload['requestedGraduationYear'].toString(),
              ),
            ),
          ],
          if ((item.payload['note'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.payload['note'].toString()),
          ],
          if (asJsonMapList(item.payload['attachments']).isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: asJsonMapList(item.payload['attachments'])
                  .map(RequestAttachment.fromMap)
                  .map(
                    (attachment) => Chip(
                      avatar: const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 16,
                      ),
                      label: Text(attachment.name),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (item.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.requestsResolutionNote(item.resolutionNote),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).sdal;
    final normalized = status.trim().toLowerCase();
    final (background, foreground, label) = switch (normalized) {
      'approved' => (tokens.successMuted, tokens.success, l10n.statusApproved),
      'rejected' => (tokens.dangerMuted, tokens.danger, l10n.statusRejected),
      'reviewed' => (tokens.warningMuted, tokens.warning, l10n.statusReviewed),
      _ => (tokens.infoMuted, tokens.info, l10n.statusPending),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

bool _isPendingRequestStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized.isEmpty || normalized == 'pending';
}

String _requestsTabLabel(BuildContext context, _RequestListTab tab, int count) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  final base = switch (tab) {
    _RequestListTab.pending =>
      isTurkish ? 'Bekleyen talepler' : 'Pending requests',
    _RequestListTab.completed =>
      isTurkish ? 'Tamamlanan talepler' : 'Completed requests',
  };
  return '$base ($count)';
}

String _requestsEmptyTitle(BuildContext context, _RequestListTab tab) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (tab) {
    _RequestListTab.pending =>
      isTurkish ? 'Bekleyen talep yok' : 'No pending requests',
    _RequestListTab.completed =>
      isTurkish ? 'Tamamlanan talep yok' : 'No completed requests',
  };
}

String _requestsEmptyMessage(BuildContext context, _RequestListTab tab) {
  final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
  return switch (tab) {
    _RequestListTab.pending =>
      isTurkish
          ? 'Şu anda değerlendirme bekleyen bir talebin görünmüyor.'
          : 'You have no requests waiting for review right now.',
    _RequestListTab.completed =>
      isTurkish
          ? 'Sonuçlanmış taleplerin burada görünecek.'
          : 'Completed requests will appear here.',
  };
}

final List<String> _graduationYearOptions = <String>[
  'teacher',
  for (var year = DateTime.now().year; year >= 1999; year--) '$year',
];
