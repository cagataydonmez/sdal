import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../explore/data/explore_repository.dart';

String composeMentionText(
  String body,
  Iterable<MemberSummary> selectedMembers,
) {
  final trimmedBody = body.trim();
  final existingText = trimmedBody.toLowerCase();
  final handles = <String>[];
  for (final member in selectedMembers) {
    final handle = member.handle.trim();
    if (handle.isEmpty) continue;
    final token = '@$handle';
    if (existingText.contains(token.toLowerCase())) continue;
    handles.add(token);
  }
  if (handles.isEmpty) return trimmedBody;
  final prefix = handles.join(' ');
  if (trimmedBody.isEmpty) return prefix;
  return '$prefix $trimmedBody'.trim();
}

class MemberMentionComposer extends ConsumerStatefulWidget {
  const MemberMentionComposer({
    super.key,
    required this.controller,
    required this.selectedMembers,
    required this.onSelectedMembersChanged,
    this.labelText = 'Yorum',
    this.hintText = 'Bir şeyler yaz...',
    this.minLines = 2,
    this.maxLines = 5,
    this.enabled = true,
  });

  final TextEditingController controller;
  final List<MemberSummary> selectedMembers;
  final ValueChanged<List<MemberSummary>> onSelectedMembersChanged;
  final String labelText;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  ConsumerState<MemberMentionComposer> createState() =>
      _MemberMentionComposerState();
}

class _MemberMentionComposerState extends ConsumerState<MemberMentionComposer> {
  Timer? _debounce;
  List<MemberSummary> _results = const <MemberSummary>[];
  bool _isLoading = false;
  int? _mentionStart;
  int? _mentionEnd;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant MemberMentionComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleTextChanged);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final canShowSuggestions =
        widget.enabled && (_isLoading || _results.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
            color: widget.enabled
                ? theme.colorScheme.surface
                : theme.colorScheme.surfaceContainerHighest,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.labelText, style: theme.textTheme.labelLarge),
              if (widget.selectedMembers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.selectedMembers
                      .map(
                        (member) => InputChip(
                          label: Text(_chipLabel(member)),
                          onDeleted: widget.enabled
                              ? () => _removeMember(member.id)
                              : null,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        if (canShowSuggestions) ...[
          const SizedBox(height: 8),
          Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = _results[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: member.photo.trim().isEmpty
                                ? null
                                : NetworkImage(
                                    config.resolveUrl(member.photo).toString(),
                                  ),
                            child: member.photo.trim().isEmpty
                                ? Text(
                                    member.name.isEmpty
                                        ? '?'
                                        : member.name.substring(0, 1),
                                  )
                                : null,
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            [
                              if (member.handle.isNotEmpty) '@${member.handle}',
                              if (member.graduationYear.isNotEmpty)
                                member.graduationYear,
                            ].join(' • '),
                          ),
                          onTap: () => _selectMember(member),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }

  String _chipLabel(MemberSummary member) {
    final handle = member.handle.trim();
    if (handle.isEmpty) return member.name;
    return '@$handle';
  }

  void _removeMember(int memberId) {
    final next = widget.selectedMembers
        .where((member) => member.id != memberId)
        .toList(growable: false);
    widget.onSelectedMembersChanged(next);
  }

  void _handleTextChanged() {
    _debounce?.cancel();
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final caret = selection.isValid ? selection.baseOffset : text.length;
    if (caret < 0 || caret > text.length) {
      _clearSuggestions();
      return;
    }
    final match = RegExp(
      r'(^|\s)@([^\s@]*)$',
    ).firstMatch(text.substring(0, caret));
    if (match == null) {
      _clearSuggestions();
      return;
    }
    final prefix = match.group(1) ?? '';
    _mentionStart = match.start + prefix.length;
    _mentionEnd = caret;
    _activeQuery = (match.group(2) ?? '').trim();
    _debounce = Timer(const Duration(milliseconds: 220), _searchMembers);
  }

  void _clearSuggestions() {
    _mentionStart = null;
    _mentionEnd = null;
    _activeQuery = '';
    if (_results.isEmpty && !_isLoading) return;
    setState(() {
      _results = const <MemberSummary>[];
      _isLoading = false;
    });
  }

  Future<void> _searchMembers() async {
    if (!mounted || !widget.enabled) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(exploreRepositoryProvider);
      final items = _activeQuery.isEmpty
          ? await repo.fetchLatestMembers(limit: 8)
          : await repo.fetchMembers(q: _activeQuery, page: 1);
      if (!mounted) return;
      final selectedIds = widget.selectedMembers
          .map((member) => member.id)
          .toSet();
      setState(() {
        _results = items
            .where(
              (member) => member.id > 0 && !selectedIds.contains(member.id),
            )
            .take(8)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <MemberSummary>[];
        _isLoading = false;
      });
    }
  }

  void _selectMember(MemberSummary member) {
    final start = _mentionStart;
    final end = _mentionEnd;
    if (start == null || end == null) return;
    final text = widget.controller.text;
    final before = text.substring(0, start);
    final after = text.substring(end);
    final needsSpace =
        before.isNotEmpty && !before.endsWith(' ') && !after.startsWith(' ');
    final nextText = '$before${needsSpace ? ' ' : ''}${after.trimLeft()}';
    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: before.length.clamp(0, nextText.length),
      ),
    );
    final nextMembers = <MemberSummary>[...widget.selectedMembers, member];
    widget.onSelectedMembersChanged(nextMembers);
    _clearSuggestions();
  }
}
