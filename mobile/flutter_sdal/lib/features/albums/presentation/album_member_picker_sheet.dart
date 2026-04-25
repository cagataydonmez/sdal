import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../explore/data/explore_repository.dart';

class AlbumMemberPickerSheet extends ConsumerStatefulWidget {
  const AlbumMemberPickerSheet({
    super.key,
    this.initial = const <MemberSummary>[],
    this.title = 'Kişileri etiketle',
  });

  final List<MemberSummary> initial;
  final String title;

  @override
  ConsumerState<AlbumMemberPickerSheet> createState() =>
      _AlbumMemberPickerSheetState();
}

class _AlbumMemberPickerSheetState
    extends ConsumerState<AlbumMemberPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, MemberSummary> _selected = <int, MemberSummary>{};
  List<MemberSummary> _results = const <MemberSummary>[];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    for (final item in widget.initial) {
      _selected[item.id] = item;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_selected.values.toList(growable: false)),
                  child: const Text('Tamam'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'İsim veya kullanıcı adı ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _isLoading ? null : _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.values
                    .map(
                      (member) => InputChip(
                        label: Text(member.name),
                        onDeleted: () =>
                            setState(() => _selected.remove(member.id)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 16),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                  ? Center(child: Text(_error))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = _results[index];
                        final selected = _selected.containsKey(member.id);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(member.name),
                          subtitle: Text(
                            [
                              if (member.handle.isNotEmpty) '@${member.handle}',
                              if (member.graduationYear.isNotEmpty)
                                _formatGraduationYear(
                                  context,
                                  member.graduationYear,
                                ),
                            ].join(' • '),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => setState(() {
                            if (selected) {
                              _selected.remove(member.id);
                            } else {
                              _selected[member.id] = member;
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final members = await ref
          .read(exploreRepositoryProvider)
          .fetchMembers(q: _searchController.text.trim(), page: 1);
      if (!mounted) return;
      setState(() => _results = members);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

String _formatGraduationYear(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == '9999' ||
      normalized == 'teacher' ||
      normalized == 'ogretmen' ||
      normalized == 'öğretmen') {
    return Localizations.localeOf(context).languageCode == 'tr'
        ? 'Öğretmen'
        : 'Teacher';
  }
  return value;
}
