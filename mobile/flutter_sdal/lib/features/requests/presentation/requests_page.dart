import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/json_utils.dart';
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
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _requestKeys = <int, GlobalKey>{};
  final List<RequestAttachment> _attachments = <RequestAttachment>[];

  String _categoryKey = '';
  String _requestedGraduationYear = '';
  bool _categoryInitialized = false;

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(requestCategoriesProvider);
    final requestsState = ref.watch(myRequestsProvider);
    final actionState = ref.watch(requestsActionControllerProvider);
    final isUploading =
        actionState.isLoading && actionState.scope == 'requests:upload';
    final isSubmitting =
        actionState.isLoading && actionState.scope == 'requests:create';

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
      final target = items.any(
        (item) => item.id == widget.highlightedRequestId,
      );
      if (!target) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      title: 'Üye talepleri',
      actions: [
        IconButton(
          onPressed: () {
            ref.invalidate(requestCategoriesProvider);
            ref.invalidate(myRequestsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni talep oluştur',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profil ve üyelik işlemleri için talep oluşturabilir, ek dosya yükleyebilir ve son durumunu aşağıda takip edebilirsin.',
                ),
                const SizedBox(height: 16),
                categoriesState.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => Text(error.toString()),
                  data: (categories) => DropdownButtonFormField<String>(
                    initialValue:
                        categories.any(
                          (item) => item.categoryKey == _categoryKey,
                        )
                        ? _categoryKey
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Talep kategorisi',
                      border: OutlineInputBorder(),
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
                        : (value) => setState(() => _categoryKey = value ?? ''),
                  ),
                ),
                if (_categoryKey == 'graduation_year_change') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _requestedGraduationYear.isEmpty
                        ? null
                        : _requestedGraduationYear,
                    decoration: const InputDecoration(
                      labelText: 'İstenen mezuniyet yılı',
                      border: OutlineInputBorder(),
                    ),
                    items: _graduationYearOptions
                        .map(
                          (year) => DropdownMenuItem<String>(
                            value: year,
                            child: Text(year == 'teacher' ? 'Öğretmen' : year),
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
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
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
                        isUploading ? 'Yükleniyor...' : 'Galeriden ekle',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: isUploading || isSubmitting
                          ? null
                          : () => _pickAndUpload(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Kamera'),
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
                      isSubmitting ? 'Gönderiliyor...' : 'Talebi gönder',
                    ),
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
                  'Taleplerim',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.notificationId > 0 &&
                    widget.notificationStatus.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.notificationStatus.trim().toLowerCase() ==
                              'approved'
                          ? 'Talep sonucu güncellendi. Onaylanan kayıt aşağıda vurgulandı.'
                          : 'Talep sonucu güncellendi. İlgili kayıt aşağıda vurgulandı.',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                requestsState.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(error.toString()),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(myRequestsProvider),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                  data: (items) => items.isEmpty
                      ? const Text('Henüz gönderilmiş talep yok.')
                      : Column(
                          children: items
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
                                        item.id == widget.highlightedRequestId,
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
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (picked == null || !mounted) return;
    final attachment = await ref
        .read(requestsActionControllerProvider.notifier)
        .uploadAttachment(File(picked.path));
    if (!mounted) return;
    final actionState = ref.read(requestsActionControllerProvider);
    if (attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionState.message ?? 'Ek dosya yüklenemedi.')),
      );
      return;
    }
    setState(() => _attachments.add(attachment));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(actionState.message ?? 'Ek dosya yüklendi.')),
    );
  }

  Future<void> _submit() async {
    final categoryKey = _categoryKey.trim();
    if (categoryKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir talep kategorisi seç.')),
      );
      return;
    }
    if (categoryKey == 'graduation_year_change' &&
        _requestedGraduationYear.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İstenen mezuniyet yılını seç.')),
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
              (ok ? 'Talep gönderildi.' : 'Talep gönderilemedi.'),
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
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, this.onRemove});

  final RequestAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(14),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF6EA8FF)
              : const Color(0xFFE5ECF3),
        ),
      ),
      padding: const EdgeInsets.all(16),
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
            '#${item.id} • ${_formatDate(item.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          if (item.payload['requestedGraduationYear'] != null) ...[
            const SizedBox(height: 10),
            Text(
              'İstenen mezuniyet yılı: ${item.payload['requestedGraduationYear'] == 'teacher' ? 'Öğretmen' : item.payload['requestedGraduationYear']}',
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
              'Not: ${item.resolutionNote}',
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
    final normalized = status.trim().toLowerCase();
    final (background, foreground, label) = switch (normalized) {
      'approved' => (
        const Color(0xFFE6F6EA),
        const Color(0xFF1B7F3B),
        'Onaylandı',
      ),
      'rejected' => (
        const Color(0xFFFFECEA),
        const Color(0xFFC73B2A),
        'Reddedildi',
      ),
      'reviewed' => (
        const Color(0xFFF4EEFF),
        const Color(0xFF6B46C1),
        'İncelendi',
      ),
      _ => (const Color(0xFFEAF2FF), const Color(0xFF2457A5), 'Bekliyor'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

final List<String> _graduationYearOptions = <String>[
  'teacher',
  for (var year = DateTime.now().year; year >= 1999; year--) '$year',
];
