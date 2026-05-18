import 'package:flutter/material.dart';

class AuditDiffEntry {
  const AuditDiffEntry({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  final String field;
  final String oldValue;
  final String newValue;
}

class AuditDiffViewer extends StatelessWidget {
  const AuditDiffViewer({super.key, required this.entries});

  final List<AuditDiffEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Bu işlemde karşılaştırılabilir fark yok.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.field,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DiffChip(
                      label: entry.oldValue,
                      deleted: true,
                      semanticLabel: 'Eski değer ${entry.oldValue}',
                    ),
                    _DiffChip(
                      label: entry.newValue,
                      deleted: false,
                      semanticLabel: 'Yeni değer ${entry.newValue}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiffChip extends StatelessWidget {
  const _DiffChip({
    required this.label,
    required this.deleted,
    required this.semanticLabel,
  });

  final String label;
  final bool deleted;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = deleted
        ? scheme.errorContainer
        : Colors.green.withValues(alpha: 0.16);
    final foreground = deleted
        ? scheme.onErrorContainer
        : Colors.green.shade900;
    return Semantics(
      label: semanticLabel,
      child: Chip(
        backgroundColor: background,
        label: Text(
          label,
          style: TextStyle(
            color: foreground,
            decoration: deleted ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
