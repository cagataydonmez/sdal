import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/data/groups_repository.dart';

class AlbumGroupPickerSheet extends ConsumerStatefulWidget {
  const AlbumGroupPickerSheet({
    super.key,
    this.initial = const <GroupListItem>[],
  });

  final List<GroupListItem> initial;

  @override
  ConsumerState<AlbumGroupPickerSheet> createState() =>
      _AlbumGroupPickerSheetState();
}

class _AlbumGroupPickerSheetState extends ConsumerState<AlbumGroupPickerSheet> {
  final Map<int, GroupListItem> _selected = <int, GroupListItem>{};
  List<GroupListItem> _groups = const <GroupListItem>[];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    for (final group in widget.initial) {
      _selected[group.id] = group;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Grupları seç',
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
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.values
                    .map(
                      (group) => InputChip(
                        label: Text(group.name),
                        onDeleted: () =>
                            setState(() => _selected.remove(group.id)),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                  ? Center(child: Text(_error))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        final selected = _selected.containsKey(group.id);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(group.name),
                          subtitle: Text(
                            group.description.isNotEmpty
                                ? group.description
                                : '${group.membersCount} üye',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => setState(() {
                            if (selected) {
                              _selected.remove(group.id);
                            } else {
                              _selected[group.id] = group;
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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final page = await ref.read(groupsRepositoryProvider).fetchGroups();
      if (!mounted) return;
      setState(() => _groups = page.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
